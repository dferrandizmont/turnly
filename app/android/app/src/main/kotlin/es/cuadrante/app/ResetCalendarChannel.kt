package es.cuadrante.app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.provider.CalendarContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** Event rows, never Instances: a reset must not expand years of recurrences. */
class ResetCalendarChannel(private val context: Context, messenger: BinaryMessenger) {
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val channel = MethodChannel(messenger, "app.cuadrante/reset_calendar")

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "list" && call.method != "delete") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            executor.execute {
                try {
                    if (!allowed()) {
                        main.post { result.error("permissionDenied", null, null) }
                    } else if (call.method == "list") {
                        val writable = writableCalendarIds()
                        val selection = writableSelection(writable)
                        val rows = mutableListOf<Map<String, String>>()
                        val cursor = requireNotNull(context.contentResolver.query(
                            CalendarContract.Events.CONTENT_URI,
                            arrayOf(CalendarContract.Events._ID, CalendarContract.Events.DESCRIPTION),
                            "$selection AND ${CalendarContract.Events.DELETED} = 0 AND " +
                                "(${CalendarContract.Events.DESCRIPTION} LIKE ? OR ${CalendarContract.Events.DESCRIPTION} LIKE ?)",
                            (writable + listOf("Creado con Turnly%", "Creado con Cuadrante%")).toTypedArray(),
                            null,
                        ))
                        cursor.use {
                            while (it.moveToNext()) {
                                rows.add(mapOf("id" to it.getString(0), "description" to (it.getString(1) ?: "")))
                            }
                        }
                        main.post { result.success(rows) }
                    } else {
                        val id = requireNotNull(call.argument<String>("id"))
                        val description = requireNotNull(call.argument<String>("description"))
                        require(id.toLongOrNull() != null)
                        // Dart checked ExportTag.parse. The exact description
                        // check also protects an event edited since the read.
                        val writable = writableCalendarIds()
                        val deleted = context.contentResolver.delete(
                            CalendarContract.Events.CONTENT_URI,
                            "${writableSelection(writable)} AND ${CalendarContract.Events._ID} = ? AND ${CalendarContract.Events.DESCRIPTION} = ?",
                            (writable + listOf(id, description)).toTypedArray(),
                        )
                        // Dart records a fixed-code failure and continues with
                        // the next event. No descriptions/ids enter diagnostics.
                        if (deleted == 0) {
                            main.post { result.error("calendarFailed", null, null) }
                        } else {
                            main.post { result.success(null) }
                        }
                    }
                } catch (_: SecurityException) {
                    main.post { result.error("permissionDenied", null, null) }
                } catch (_: Exception) {
                    main.post { result.error("calendarFailed", null, null) }
                }
            }
        }
    }

    private fun writableCalendarIds(): List<String> {
        val ids = mutableListOf<String>()
        requireNotNull(context.contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            arrayOf(CalendarContract.Calendars._ID),
            "${CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL} >= ?",
            arrayOf(CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR.toString()),
            null,
        )).use { cursor ->
            while (cursor.moveToNext()) ids.add(cursor.getString(0))
        }
        return ids
    }

    private fun writableSelection(ids: List<String>): String =
        if (ids.isEmpty()) "0 = 1"
        else "${CalendarContract.Events.CALENDAR_ID} IN (${ids.joinToString(",") { "?" }})"

    private fun allowed() = listOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR).all {
        context.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
    }

    fun shutdown() {
        channel.setMethodCallHandler(null)
        executor.shutdown()
    }
}
