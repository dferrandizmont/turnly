package es.cuadrante.app

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The `app.cuadrante/dnd` channel (P13, docs/ola3-logica.md): the phone is
 * silenced while a shift lasts and freed when it ends.
 *
 * Dart asks:
 * - `permissionStatus`: "granted", "denied" or "unsupported" (the platform
 *   has no interruption filters). It never prompts: the permission is given
 *   in the system settings ("Acceso a No molestar").
 * - `openPermissionSettings`: opens that screen; replies whether a screen
 *   opened.
 * - `currentFilter`: the filter the phone is in ("all", "priority", "none",
 *   "alarms"), or null when it cannot be read.
 * - `replaceWindows`: makes the armed windows exactly the ones it gets
 *   (`windows`: a list of `{id, start, end, filter}`, the instants in
 *   milliseconds since the epoch). The new ones are armed and the ones that
 *   are gone are cancelled.
 * - `cancelAll`: cancels every armed window.
 *
 * The windows are armed with two **alarm clocks** of our own (`AlarmManager`
 * with `SCHEDULE_EXACT_ALARM`, the same permission the shift alarms use): one
 * that silences the phone and one that frees it. They use `setAlarmClock`,
 * like the shift alarms, because some manufacturers (seen on a OnePlus with
 * OxygenOS) align `setExactAndAllowWhileIdle` into a window of up to an hour:
 * the phone would be silenced late and, worse, stay silenced after the shift.
 * Our request codes are in a range of their own (`DndPolicy`), so they never
 * collide with the alarms of the shift (the notification plugin uses the id
 * of the alarm) and the renewal of those alarms is not touched either.
 *
 * A window whose start is already past when it is armed is **active**: the
 * phone is silenced at once (an alarm in the past never rings) and freed at
 * its end.
 *
 * The mode the phone had before is read when it is silenced and put back when
 * the window ends, **only if the user did not change it by hand** in the
 * meantime: if the phone is no longer in the filter the app put it in, the
 * app does not touch it. That check is here, in the native side, because the
 * window may end with the app closed.
 */
class DndChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL).also {
        it.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "permissionStatus" -> result.success(permissionStatus())
            "openPermissionSettings" -> result.success(openPermissionSettings())
            "currentFilter" -> result.success(currentFilter())
            "replaceWindows" -> {
                replaceWindows(call)
                result.success(null)
            }
            "cancelAll" -> {
                cancelAll()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /** Detaches the channel (the activity goes away). */
    fun shutdown() {
        channel.setMethodCallHandler(null)
    }

    // ---- the answers --------------------------------------------------------

    private fun permissionStatus(): String {
        if (Build.VERSION.SDK_INT < DndPolicy.MIN_SDK) return "unsupported"
        return if (hasAccess()) "granted" else "denied"
    }

    private fun openPermissionSettings(): Boolean {
        if (Build.VERSION.SDK_INT < DndPolicy.MIN_SDK) return false
        val access = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
        val details = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", context.packageName, null),
        )
        for (intent in listOf(access, details)) {
            try {
                context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (e: ActivityNotFoundException) {
                // Try the next screen.
            } catch (e: SecurityException) {
                // Same.
            }
        }
        return false
    }

    private fun currentFilter(): String? {
        val filter = DndState.currentFilter(context) ?: return null
        return DndPolicy.nameOf(filter)
    }

    // ---- the windows --------------------------------------------------------

    private fun replaceWindows(call: MethodCall) {
        // Without the permission nothing is armed: the phone cannot be
        // silenced anyway.
        if (!hasAccess()) return
        val raw = call.argument<List<Any?>>("windows") ?: emptyList()
        val now = System.currentTimeMillis()
        val wanted = mutableSetOf<Int>()
        for (item in raw) {
            val window = item as? Map<*, *> ?: continue
            val id = (window["id"] as? Number)?.toInt() ?: continue
            val start = (window["start"] as? Number)?.toLong() ?: continue
            val end = (window["end"] as? Number)?.toLong() ?: continue
            val filter = DndPolicy.filterOf(window["filter"] as? String) ?: continue
            // A window that ends before it begins (or at the same instant)
            // would silence the phone and never free it.
            if (end <= start) continue
            wanted.add(id)
            // The end of the window is always armed.
            arm(
                DndPolicy.releaseRequestCode(id),
                end,
                DndAlarmReceiver.releaseIntent(context, id, filter),
            )
            if (DndPolicy.isActive(start, end, now)) {
                // The window already began (the app was closed): the phone is
                // silenced at once, because an alarm in the past never rings.
                DndState.silence(context, id, filter)
            } else {
                arm(
                    DndPolicy.silenceRequestCode(id),
                    start,
                    DndAlarmReceiver.silenceIntent(context, id, filter),
                )
            }
        }
        // The windows that are gone: their alarms are cancelled.
        cancelMissing(wanted)
    }

    private fun cancelAll() {
        cancelMissing(emptySet())
        // The phone is freed, unless the user changed the mode by hand.
        DndState.release(context, null)
    }

    /**
     * Cancels the alarms of the windows that are not wanted any more. A
     * window that is running and is gone frees the phone at once: it is not
     * silenced any more.
     */
    private fun cancelMissing(wanted: Set<Int>) {
        for (id in DndState.armedIds(context)) {
            if (wanted.contains(id)) continue
            cancel(id, release = false)
            cancel(id, release = true)
            // The window that was silencing the phone is gone: free it.
            DndState.release(context, id)
        }
        DndState.setArmedIds(context, wanted)
    }

    private fun arm(requestCode: Int, triggerAt: Long, intent: Intent) {
        if (triggerAt <= System.currentTimeMillis()) return
        val manager =
            context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val pending = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        try {
            when (DndPolicy.scheduleMode(canScheduleExact(manager))) {
                DndPolicy.ScheduleMode.ALARM_CLOCK ->
                    manager.setAlarmClock(
                        AlarmManager.AlarmClockInfo(triggerAt, showIntent()),
                        pending,
                    )
                // Without "Alarmas y recordatorios" the alarm may be late.
                DndPolicy.ScheduleMode.INEXACT ->
                    manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pending)
            }
        } catch (e: SecurityException) {
            // The exact-alarm permission was taken away between the check and
            // now: an inexact alarm is better than none.
            try {
                manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pending)
            } catch (e2: SecurityException) {
                // Nothing to do: this window is not armed.
            }
        }
    }

    /**
     * The intent the alarm clock shows to the system: tapping it (the alarm
     * icon of the status bar, «next alarm» in the clock) opens the app. It is
     * an activity of its own, not the broadcast that silences or frees the
     * phone, so the request code is [DndPolicy.SHOW_REQUEST_CODE].
     */
    private fun showIntent(): PendingIntent = PendingIntent.getActivity(
        context,
        DndPolicy.SHOW_REQUEST_CODE,
        Intent(context, MainActivity::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun cancel(id: Int, release: Boolean) {
        val manager =
            context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = if (release) {
            DndAlarmReceiver.releaseIntent(context, id, DndPolicy.FILTER_PRIORITY)
        } else {
            DndAlarmReceiver.silenceIntent(context, id, DndPolicy.FILTER_PRIORITY)
        }
        val requestCode = if (release) {
            DndPolicy.releaseRequestCode(id)
        } else {
            DndPolicy.silenceRequestCode(id)
        }
        val pending = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        ) ?: return // nothing scheduled under this id
        manager.cancel(pending)
    }

    /**
     * «Acceso a No molestar» is a special access the user gives in the system
     * settings, not a runtime permission: `checkSelfPermission` answers
     * "granted" for it whatever the user did. The real answer is
     * [NotificationManager.isNotificationPolicyAccessGranted].
     */
    private fun hasAccess(): Boolean {
        if (Build.VERSION.SDK_INT < DndPolicy.MIN_SDK) return false
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                ?: return false
        return try {
            manager.isNotificationPolicyAccessGranted
        } catch (e: SecurityException) {
            false
        }
    }

    private fun canScheduleExact(manager: AlarmManager): Boolean =
        if (Build.VERSION.SDK_INT >= 31) manager.canScheduleExactAlarms() else true

    companion object {
        const val CHANNEL = "app.cuadrante/dnd"
    }
}
