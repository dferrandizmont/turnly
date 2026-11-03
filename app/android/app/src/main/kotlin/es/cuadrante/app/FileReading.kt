package es.cuadrante.app

import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.ThreadFactory
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference
import java.util.concurrent.ExecutorService

/**
 * What came of reading a file another app handed over. Pure Kotlin on purpose
 * (no Android classes), so the JVM unit tests in `src/test` cover it.
 */
sealed interface ReadOutcome {
    class Bytes(val bytes: ByteArray) : ReadOutcome

    /**
     * The file was streamed to [file] on disk (never held in memory); the
     * receiver owns it and deletes it once it has been read.
     */
    class Saved(val file: File) : ReadOutcome

    /** Larger than the cap: not a backup. */
    data object TooLarge : ReadOutcome

    /** Could not be read: no permission, a provider that died, or too slow. */
    data object Unreadable : ReadOutcome
}

class TooLargeException : Exception()

/** Reads a stream in chunks and never holds more than the cap. */
object CappedRead {
    const val CHUNK_BYTES = 64 * 1024

    /** @throws TooLargeException as soon as more than [maxBytes] have come in. */
    fun read(input: InputStream, maxBytes: Int, chunkBytes: Int = CHUNK_BYTES): ByteArray {
        val out = ByteArrayOutputStream()
        val chunk = ByteArray(chunkBytes)
        var total = 0
        while (true) {
            val n = input.read(chunk)
            if (n < 0) break
            total += n
            if (total > maxBytes) throw TooLargeException()
            out.write(chunk, 0, n)
        }
        return out.toByteArray()
    }

    /**
     * Streams [input] into [target] in chunks, never holding more than one
     * chunk in memory. If it fails or goes over [maxBytes], [target] is
     * deleted before the exception leaves.
     *
     * @throws TooLargeException as soon as more than [maxBytes] have come in.
     */
    fun copyToFile(
        input: InputStream,
        target: File,
        maxBytes: Int,
        chunkBytes: Int = CHUNK_BYTES,
    ) {
        try {
            FileOutputStream(target).use { out ->
                val chunk = ByteArray(chunkBytes)
                var total = 0L
                while (true) {
                    val n = input.read(chunk)
                    if (n < 0) break
                    total += n
                    if (total > maxBytes) throw TooLargeException()
                    out.write(chunk, 0, n)
                }
                out.flush()
            }
        } catch (e: Throwable) {
            target.delete()
            throw e
        }
    }
}

/**
 * The folder where files handed over by other apps (and the copies read from
 * the chosen folder) are streamed to, inside the app's cache: `incoming/`.
 * Dart reads each one and deletes it; what a crash leaves behind is swept at
 * the next start.
 */
object IncomingFiles {
    const val DIR_NAME = "incoming"
    const val SUFFIX = ".turnly"
    const val MAX_AGE_MILLIS = 60L * 60L * 1000L

    /** A new, empty, unique file in [cacheDir]/incoming. */
    fun newFile(cacheDir: File): File {
        val dir = File(cacheDir, DIR_NAME)
        dir.mkdirs()
        return File.createTempFile("incoming-", SUFFIX, dir)
    }

    /** Deletes the files in [cacheDir]/incoming that are older than [maxAgeMillis]. */
    fun sweep(cacheDir: File, now: Long, maxAgeMillis: Long = MAX_AGE_MILLIS) {
        val files = File(cacheDir, DIR_NAME).listFiles() ?: return
        for (file in files) {
            if (file.isFile && now - file.lastModified() > maxAgeMillis) {
                file.delete()
            }
        }
    }
}

/**
 * Reads a stream with an overall deadline.
 *
 * A content provider can hang (a Drive file with no network, a provider that
 * died mid-read): a blocking `read` never returns. So every read runs on a
 * worker thread of its own (a stuck one cannot hold up the next file), and a
 * timer answers [ReadOutcome.Unreadable] when [deadlineMillis] pass, closing
 * the stream so a blocked `read` throws and the thread ends.
 *
 * [onDone] is called exactly once per [start], from whichever thread decided
 * (worker or timer); the caller moves to the UI thread itself.
 */
class DeadlineReader(
    private val deadlineMillis: Long,
    private val workers: ExecutorService = Executors.newCachedThreadPool(daemonThreads("cuadrante-read")),
    private val timer: ScheduledExecutorService =
        Executors.newSingleThreadScheduledExecutor(daemonThreads("cuadrante-read-timer")),
) {
    /**
     * Opens the stream with [open] (also on the worker: opening can block),
     * reads at most [maxBytes] and reports once.
     *
     * With [into], the stream goes to that file on disk and the outcome is
     * [ReadOutcome.Saved] (no byte array of the whole file ever exists). The
     * file is deleted here whenever the outcome is anything but a delivered
     * [ReadOutcome.Saved].
     */
    fun start(
        open: () -> InputStream?,
        maxBytes: Int,
        into: File? = null,
        onDone: (ReadOutcome) -> Unit,
    ) {
        val finished = AtomicBoolean(false)
        val stream = AtomicReference<InputStream?>(null)
        val job = AtomicReference<Future<*>?>(null)

        fun finish(outcome: ReadOutcome): Boolean {
            if (!finished.compareAndSet(false, true)) return false
            onDone(outcome)
            return true
        }

        job.set(
            workers.submit(Runnable {
                val outcome: ReadOutcome = try {
                    val input = open() ?: throw IOException("no stream")
                    stream.set(input)
                    // The deadline may have fired while opening.
                    if (finished.get()) {
                        closeQuietly(input)
                        into?.delete()
                        return@Runnable
                    }
                    input.use {
                        if (into != null) {
                            CappedRead.copyToFile(it, into, maxBytes)
                            ReadOutcome.Saved(into)
                        } else {
                            ReadOutcome.Bytes(CappedRead.read(it, maxBytes))
                        }
                    }
                } catch (e: TooLargeException) {
                    ReadOutcome.TooLarge
                } catch (e: OutOfMemoryError) {
                    // Only the in-memory read can get here; a file this big is
                    // refused instead of taking the app down.
                    ReadOutcome.TooLarge
                } catch (e: Exception) {
                    // SecurityException (grant gone), IOException (including the
                    // one a close from the timer causes), a provider that died...
                    ReadOutcome.Unreadable
                } catch (e: Throwable) {
                    ReadOutcome.Unreadable
                }
                // Not delivered (the deadline answered first) or not a file:
                // nothing is left on disk.
                if (!finish(outcome) || outcome !is ReadOutcome.Saved) into?.delete()
            }),
        )

        timer.schedule(
            {
                if (finish(ReadOutcome.Unreadable)) {
                    // Unblock the stuck read, from a thread that is not the
                    // timer's: a close can itself take a moment.
                    val input = stream.get()
                    workers.execute {
                        closeQuietly(input)
                        job.get()?.cancel(true)
                        into?.delete()
                    }
                    if (input == null) job.get()?.cancel(true)
                }
            },
            deadlineMillis,
            TimeUnit.MILLISECONDS,
        )
    }

    fun shutdown() {
        timer.shutdownNow()
        workers.shutdownNow()
    }

    private fun closeQuietly(input: InputStream?) {
        try {
            input?.close()
        } catch (e: Exception) {
            // Nothing more can be done with it.
        }
    }

    companion object {
        const val DEFAULT_DEADLINE_MILLIS = 60_000L

        fun daemonThreads(name: String): ThreadFactory = ThreadFactory { runnable ->
            Thread(runnable, name).apply { isDaemon = true }
        }
    }
}
