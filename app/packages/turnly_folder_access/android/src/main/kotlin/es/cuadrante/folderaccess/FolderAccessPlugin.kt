package es.cuadrante.folderaccess

import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.system.ErrnoException
import android.system.OsConstants
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.IOException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * The folder of Turnly's automatic folder copies (docs/copia-de-seguridad.md,
 * section 11), over the Storage Access Framework: the user picks a folder in
 * the system picker (`ACTION_OPEN_DOCUMENT_TREE`; Drive, Dropbox, OneDrive or
 * a local folder show up there as system providers), the app keeps a
 * persistable permission to it, and later writes, lists, reads and deletes
 * **its own** files in it. No account, no storage permission.
 *
 * A plugin (not code in MainActivity) so the channel also exists in the
 * background engine that WorkManager starts for the daily copy. The picker
 * needs an activity; every other method works without one.
 *
 * Channel `app.cuadrante/folder_backup`:
 * - `pick()` -> `{uri, name}` or `null` (cancelled). Takes the persistable
 *   read and write permission of the chosen tree.
 * - `check({uri})` -> `{state, name}`, `state` one of `ok`, `revoked` (no
 *   persisted permission any more), `missing` (deleted, moved, provider gone),
 *   `unwritable` (the folder does not take new files). Never fails.
 * - `list({uri})` -> `[{id, name, sizeBytes, modifiedAtMs}]`, the plain files
 *   directly in the folder (no sub-folders).
 * - `write({uri, name, bytes})` -> `{id, name, sizeBytes}`. Only names of
 *   Turnly's automatic copies ([FolderNames.isOwn]), at most [MAX_BYTES]. If
 *   the provider gives the new file another name, it is deleted (`renamed`).
 * - `read({uri, id})` -> the **path** of a file in the app's cache
 *   (`incoming/folder-*.turnly`) the copy was streamed to, never a byte array
 *   of the whole copy (a 130 MiB array does not fit twice in a 256 MiB heap).
 *   Dart reads the file and deletes it; leftovers older than an hour are swept
 *   when the plugin attaches. Only a direct child of the folder with one of
 *   Turnly's own names, at most [MAX_BYTES].
 * - `delete({uri, id})` -> `null`. Only a direct child whose name is one of
 *   Turnly's automatic copies; a file that is gone counts as deleted.
 * - `release({uri})` -> `null`. Gives the persisted permission back.
 *
 * Errors (`PlatformException.code`): `revoked`, `missing`, `unwritable`,
 * `no_space`, `too_large`, `bad_name`, `renamed`, `bad_args`, `busy`, `no_activity`,
 * `unavailable`, `not_persistable`, `failed`.
 *
 * It trusts nothing Dart sends: every folder URI must be a tree URI the app
 * holds a persisted read and write permission for, file ids are looked up
 * among the folder's own children, and names and sizes are checked here too.
 */
class FolderAccessPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    PluginRegistry.ActivityResultListener {

    private var channel: MethodChannel? = null
    private var resolver: ContentResolver? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingPick: MethodChannel.Result? = null
    private val main = Handler(Looper.getMainLooper())
    private var io: ExecutorService? = null
    private var cacheDir: File? = null

    // ---- plugin life ----------------------------------------------------

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        resolver = binding.applicationContext.contentResolver
        cacheDir = binding.applicationContext.cacheDir
        io = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "turnly-folder").apply { isDaemon = true }
        }
        // What an earlier crash left in the cache (copies nobody picked up).
        sweepIncoming()
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        io?.shutdown()
        io = null
        resolver = null
        cacheDir = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = detachActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        detachActivity()
        // The activity is gone for good: the picker's answer will never come
        // here, so the waiting call is completed as "cancelled".
        val waiting = pendingPick
        pendingPick = null
        try {
            waiting?.success(null)
        } catch (e: Exception) {
            // The engine went away too.
        }
    }

    private fun detachActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
    }

    // ---- calls ------------------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pick" -> pick(result)
            "check" -> background(result) { check(call.argument<String>("uri")) }
            "list" -> background(result) { list(grantedTree(call.argument("uri"))) }
            "write" -> background(result) {
                write(
                    grantedTree(call.argument("uri")),
                    call.argument<String>("name"),
                    call.argument<ByteArray>("bytes"),
                )
            }
            "read" -> background(result) {
                read(grantedTree(call.argument("uri")), call.argument<String>("id"))
            }
            "delete" -> background(result) {
                delete(grantedTree(call.argument("uri")), call.argument<String>("id"))
                null
            }
            "release" -> background(result) {
                release(call.argument<String>("uri"))
                null
            }
            else -> result.notImplemented()
        }
    }

    /** Runs [work] off the main thread (providers may be slow: a cloud). */
    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        val executor = io
        if (executor == null) {
            result.error("unavailable", "Detached", null)
            return
        }
        try {
            executor.execute {
                val outcome: Result<Any?> = try {
                    Result.success(work())
                } catch (e: OutOfMemoryError) {
                    // A copy too big for this phone's memory: refused, not a crash.
                    Result.failure(FolderError("too_large"))
                } catch (e: Exception) {
                    Result.failure(e)
                }
                main.post {
                    try {
                        outcome.fold(
                            onSuccess = { result.success(it) },
                            onFailure = { e ->
                                val error = e as? FolderError ?: FolderError(codeFor(e))
                                result.error(error.code, error.code, null)
                            },
                        )
                    } catch (e: Exception) {
                        // The engine went away meanwhile.
                    }
                }
            }
        } catch (e: Exception) {
            result.error("unavailable", "Busy", null)
        }
    }

    // ---- pick ---------------------------------------------------------------

    private fun pick(result: MethodChannel.Result) {
        val activity: Activity? = activityBinding?.activity
        if (activity == null) {
            result.error("no_activity", "No activity", null)
            return
        }
        if (pendingPick != null) {
            result.error("busy", "The picker is already open", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        pendingPick = result
        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, REQUEST_PICK_FOLDER)
        } catch (e: Exception) {
            pendingPick = null
            result.error("unavailable", "No folder picker", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PICK_FOLDER) return false
        val result = pendingPick ?: return true
        pendingPick = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        val cr = resolver
        if (cr == null || !DocumentsContract.isTreeUri(uri)) {
            result.error("unavailable", "Not a folder", null)
            return true
        }
        // Only the read and write grants the picker gave us.
        val flags = (data?.flags ?: 0) and
            (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        try {
            cr.takePersistableUriPermission(uri, flags)
        } catch (e: Exception) {
            result.error("not_persistable", "The folder cannot be kept", null)
            return true
        }
        background(result) {
            mapOf("uri" to uri.toString(), "name" to (rootName(cr, uri) ?: ""))
        }
        return true
    }

    // ---- folder operations --------------------------------------------------

    private fun cr(): ContentResolver = resolver ?: throw FolderError("unavailable")

    /** The folder, only if it is a tree we hold read and write grants for. */
    private fun grantedTree(raw: String?): Uri {
        val uri = parseTree(raw)
        val held = cr().persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission && it.isWritePermission
        }
        if (!held) throw FolderError("revoked")
        return uri
    }

    private fun parseTree(raw: String?): Uri {
        if (raw.isNullOrEmpty()) throw FolderError("bad_args")
        val uri = try {
            Uri.parse(raw)
        } catch (e: Exception) {
            throw FolderError("bad_args")
        }
        if (uri.scheme != ContentResolver.SCHEME_CONTENT || !DocumentsContract.isTreeUri(uri)) {
            throw FolderError("revoked")
        }
        return uri
    }

    private fun check(raw: String?): Map<String, Any?> {
        val tree = try {
            grantedTree(raw)
        } catch (e: FolderError) {
            return mapOf("state" to "revoked", "name" to null)
        }
        return try {
            val root = rootDocument(tree)
            cr().query(root, ROOT_COLUMNS, null, null, null).use { c ->
                if (c == null || !c.moveToFirst()) {
                    return mapOf("state" to "missing", "name" to null)
                }
                val name = c.getString(0)
                val mime = c.getString(1)
                val flags = if (c.isNull(2)) 0 else c.getInt(2)
                val state = when {
                    mime != DocumentsContract.Document.MIME_TYPE_DIR -> "missing"
                    flags and DocumentsContract.Document.FLAG_DIR_SUPPORTS_CREATE == 0 ->
                        "unwritable"
                    else -> "ok"
                }
                mapOf("state" to state, "name" to name)
            }
        } catch (e: Exception) {
            mapOf("state" to codeFor(e).let { if (it == "revoked") it else "missing" }, "name" to null)
        }
    }

    private fun list(tree: Uri): List<Map<String, Any?>> =
        children(tree).map {
            mapOf(
                "id" to it.id,
                "name" to it.name,
                "sizeBytes" to it.size,
                "modifiedAtMs" to it.modified,
            )
        }

    private fun write(tree: Uri, name: String?, bytes: ByteArray?): Map<String, Any?> {
        if (name == null || bytes == null) throw FolderError("bad_args")
        if (!FolderNames.isOwn(name)) throw FolderError("bad_name")
        if (bytes.size > MAX_BYTES) throw FolderError("too_large")
        val cr = cr()
        val maybeCreated: Uri? = try {
            DocumentsContract.createDocument(cr, rootDocument(tree), MIME_TYPE, name)
        } catch (e: Exception) {
            throw FolderError(writeCodeFor(e))
        }
        val created = maybeCreated ?: throw FolderError("unwritable")
        // A provider that renamed it ("... (1).turnly") would leave a file out
        // of the rotation for ever: remove it and fail before writing.
        val createdName = displayName(cr, created)
        if (createdName != null && createdName != name) {
            try {
                DocumentsContract.deleteDocument(cr, created)
            } catch (ignored: Exception) {
                // Nothing more can be done; it is empty.
            }
            throw FolderError("renamed")
        }
        try {
            val out = cr.openOutputStream(created, "w") ?: throw IOException("no stream")
            out.use {
                it.write(bytes)
                it.flush()
            }
        } catch (e: Exception) {
            // Never leave a half-written copy behind.
            try {
                DocumentsContract.deleteDocument(cr, created)
            } catch (ignored: Exception) {
                // The provider does not allow it; Dart reads it back and fails.
            }
            throw FolderError(writeCodeFor(e))
        }
        val id = DocumentsContract.getDocumentId(created)
        var shownName = name
        var size = bytes.size.toLong()
        try {
            cr.query(created, FILE_COLUMNS, null, null, null)?.use { c ->
                if (c.moveToFirst()) {
                    c.getString(0)?.let { shownName = it }
                    if (!c.isNull(1)) size = c.getLong(1)
                }
            }
        } catch (e: Exception) {
            // Informational only.
        }
        return mapOf("id" to id, "name" to shownName, "sizeBytes" to size)
    }

    private fun read(tree: Uri, id: String?): String {
        if (id.isNullOrEmpty()) throw FolderError("bad_args")
        val child = children(tree).firstOrNull { it.id == id } ?: throw FolderError("missing")
        if (!FolderNames.isOwn(child.name)) throw FolderError("bad_name")
        if (child.size > MAX_BYTES) throw FolderError("too_large")
        val input = cr().openInputStream(DocumentsContract.buildDocumentUriUsingTree(tree, id))
            ?: throw FolderError("missing")
        // Streamed to a file of the app's cache in 64 KiB chunks: the copy
        // never exists as one byte array here, and Dart reads it from disk.
        val target = newIncomingFile()
        try {
            input.use { stream ->
                FileOutputStream(target).use { out ->
                    val buffer = ByteArray(64 * 1024)
                    var total = 0L
                    while (true) {
                        val n = stream.read(buffer)
                        if (n < 0) break
                        total += n
                        if (total > MAX_BYTES) throw FolderError("too_large")
                        out.write(buffer, 0, n)
                    }
                    out.flush()
                }
            }
        } catch (e: Throwable) {
            target.delete()
            throw e
        }
        return target.absolutePath
    }

    private fun newIncomingFile(): File {
        val base = cacheDir ?: throw FolderError("unavailable")
        val dir = File(base, INCOMING_DIR)
        dir.mkdirs()
        try {
            return File.createTempFile("folder-", ".turnly", dir)
        } catch (e: IOException) {
            throw FolderError(if (isNoSpace(e)) "no_space" else "failed")
        }
    }

    /** Deletes the leftovers in the cache's `incoming/` older than an hour. */
    private fun sweepIncoming() {
        val base = cacheDir ?: return
        val executor = io ?: return
        try {
            executor.execute {
                try {
                    val files = File(base, INCOMING_DIR).listFiles() ?: return@execute
                    val now = System.currentTimeMillis()
                    for (file in files) {
                        if (file.isFile && now - file.lastModified() > INCOMING_MAX_AGE_MS) {
                            file.delete()
                        }
                    }
                } catch (e: Exception) {
                    // Housekeeping only.
                }
            }
        } catch (e: Exception) {
            // Detached already.
        }
    }

    private fun delete(tree: Uri, id: String?) {
        if (id.isNullOrEmpty()) throw FolderError("bad_args")
        val child = children(tree).firstOrNull { it.id == id } ?: return
        if (!FolderNames.isOwn(child.name)) throw FolderError("bad_name")
        try {
            DocumentsContract.deleteDocument(cr(), DocumentsContract.buildDocumentUriUsingTree(tree, id))
        } catch (e: FileNotFoundException) {
            // Already gone.
        } catch (e: UnsupportedOperationException) {
            throw FolderError("unwritable")
        }
    }

    private fun release(raw: String?) {
        val uri = parseTree(raw)
        try {
            cr().releasePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        } catch (e: SecurityException) {
            // Not held any more: nothing to give back.
        }
    }

    // ---- helpers ------------------------------------------------------------

    private class Child(
        val id: String,
        val name: String,
        val size: Long,
        val modified: Long,
    )

    private fun rootDocument(tree: Uri): Uri =
        DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))

    private fun displayName(cr: ContentResolver, document: Uri): String? = try {
        cr.query(document, FILE_COLUMNS, null, null, null)?.use { c ->
            if (c.moveToFirst()) c.getString(0) else null
        }
    } catch (e: Exception) {
        null
    }

    private fun rootName(cr: ContentResolver, tree: Uri): String? = try {
        cr.query(rootDocument(tree), ROOT_COLUMNS, null, null, null)?.use { c ->
            if (c.moveToFirst()) c.getString(0) else null
        }
    } catch (e: Exception) {
        null
    }

    /** The plain files directly in [tree]. */
    private fun children(tree: Uri): List<Child> {
        val uri = DocumentsContract.buildChildDocumentsUriUsingTree(
            tree,
            DocumentsContract.getTreeDocumentId(tree),
        )
        val maybeCursor: Cursor? = try {
            cr().query(uri, CHILD_COLUMNS, null, null, null)
        } catch (e: Exception) {
            throw FolderError(codeFor(e))
        }
        val cursor = maybeCursor ?: throw FolderError("missing")
        return cursor.use { c ->
            val found = ArrayList<Child>()
            while (c.moveToNext()) {
                val id = c.getString(0) ?: continue
                val name = c.getString(1) ?: continue
                if (c.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR) continue
                found += Child(
                    id = id,
                    name = name,
                    size = if (c.isNull(3)) 0L else c.getLong(3),
                    modified = if (c.isNull(4)) 0L else c.getLong(4),
                )
            }
            found
        }
    }

    private fun codeFor(e: Throwable): String = when (e) {
        is FolderError -> e.code
        is SecurityException -> "revoked"
        is FileNotFoundException, is IllegalArgumentException, is IllegalStateException -> "missing"
        else -> if (isNoSpace(e)) "no_space" else "failed"
    }

    private fun writeCodeFor(e: Throwable): String = when {
        e is FolderError -> e.code
        isNoSpace(e) -> "no_space"
        e is SecurityException -> "revoked"
        e is FileNotFoundException -> "missing"
        e is UnsupportedOperationException -> "unwritable"
        else -> "failed"
    }

    /** ENOSPC anywhere in the chain (also as text: providers wrap it). */
    private fun isNoSpace(e: Throwable): Boolean {
        var current: Throwable? = e
        var depth = 0
        while (current != null && depth < 8) {
            if (current is ErrnoException && current.errno == OsConstants.ENOSPC) return true
            val message = current.message ?: ""
            if (message.contains("ENOSPC") || message.contains("No space left", ignoreCase = true)) {
                return true
            }
            current = current.cause
            depth++
        }
        return false
    }

    private class FolderError(val code: String) : Exception(code)

    companion object {
        const val CHANNEL = "app.cuadrante/folder_backup"
        private const val REQUEST_PICK_FOLDER = 4209
        private const val MIME_TYPE = "application/octet-stream"
        private const val INCOMING_DIR = "incoming"
        private const val INCOMING_MAX_AGE_MS = 60L * 60L * 1000L

        /**
         * Same cap as `BackupCodec.maxImportBytes` (`BackupContainer.maxContainerBytes`:
         * 128 MiB of attachments + 8 MiB of backup + 1 MiB of ZIP structure). A plain
         * `.turnly` is a few MiB; a copy with photos is a container and can be this big.
         */
        const val MAX_BYTES = 137 * 1024 * 1024

        private val ROOT_COLUMNS = arrayOf(
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_FLAGS,
        )
        private val FILE_COLUMNS = arrayOf(
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_SIZE,
        )
        private val CHILD_COLUMNS = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        )
    }
}

/** The names of Turnly's automatic folder copies (same rule as the Dart side). */
object FolderNames {
    private val OWN = Regex("""^turnly-auto-\d{8}-\d{6}(-\d{1,3})?\.turnly$""")

    fun isOwn(name: String): Boolean = OWN.matches(name)
}
