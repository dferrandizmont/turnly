package es.cuadrante.app

/**
 * The pure decisions of the silence windows (P13, docs/ola3-logica.md), kept
 * apart from the Android classes so the JVM tests can run them.
 */
object DndPolicy {
    /**
     * The interruption filters of Android (`NotificationManager`), with the
     * platform's own values: 0 is `INTERRUPTION_FILTER_UNKNOWN`, so ALL is 1.
     * They must match exactly, because they go straight to
     * `setInterruptionFilter` and come back from `currentInterruptionFilter`.
     */
    const val FILTER_ALL = 1
    const val FILTER_PRIORITY = 2
    const val FILTER_NONE = 3
    const val FILTER_ALARMS = 4

    /** The names the Dart side sends and reads. */
    const val NAME_ALL = "all"
    const val NAME_PRIORITY = "priority"
    const val NAME_NONE = "none"
    const val NAME_ALARMS = "alarms"

    /** First Android version with the interruption filters (Android 6). */
    const val MIN_SDK = 23

    /**
     * How a window is armed. With the exact-alarm permission it is an **alarm
     * clock** (`setAlarmClock`), the only kind no manufacturer delays; without
     * it, an inexact alarm that may arrive a few minutes late.
     */
    enum class ScheduleMode { ALARM_CLOCK, INEXACT }

    /** The mode a window is armed with, for whether exact alarms are allowed. */
    fun scheduleMode(canExact: Boolean): ScheduleMode =
        if (canExact) ScheduleMode.ALARM_CLOCK else ScheduleMode.INEXACT

    // Request codes in ranges of our own, so ours are easy to tell apart from
    // the notification plugin's (the id of the alarm, a 31-bit hash, and its
    // multiples). A shared number would not clash anyway: our alarms target
    // [DndAlarmReceiver], so their PendingIntents are never the same as the
    // plugin's (which target its own receivers). Two ranges, one for the alarm
    // that silences the phone and one for the one that frees it.
    private const val REQUEST_BASE = 0x40000000
    private const val REQUEST_SPAN = 0x00FFFFFF

    /** Request code of the alarm that silences the phone for the window [id]. */
    fun silenceRequestCode(id: Int): Int = REQUEST_BASE + (id and REQUEST_SPAN)

    /** Request code of the alarm that frees the phone at the end of [id]. */
    fun releaseRequestCode(id: Int): Int =
        REQUEST_BASE + REQUEST_SPAN + 1 + (id and REQUEST_SPAN)

    /**
     * Request code of the `PendingIntent` that opens the app from the alarm
     * clock the system shows (`AlarmClockInfo`). It is outside the two ranges
     * above, so it never replaces a broadcast alarm.
     */
    const val SHOW_REQUEST_CODE = 0x42000000

    /**
     * Whether the window has to be silenced right now: it has already begun
     * and it has not ended yet. An alarm in the past never rings, so a window
     * that is running is silenced at once.
     */
    fun isActive(start: Long, end: Long, now: Long): Boolean =
        now >= start && now < end

    /**
     * The filter the phone goes back to when the window ends, or null when the
     * phone must not be touched: the user changed the mode by hand (the
     * phone is no longer in the filter the app put it in).
     */
    fun filterToRestore(applied: Int, current: Int, previous: Int): Int? =
        if (current == applied) previous else null

    /** The Android filter of the name the Dart side sends, or null. */
    fun filterOf(name: String?): Int? = when (name) {
        NAME_ALL -> FILTER_ALL
        NAME_PRIORITY -> FILTER_PRIORITY
        NAME_NONE -> FILTER_NONE
        NAME_ALARMS -> FILTER_ALARMS
        else -> null
    }

    /** The name of the Android filter, for the reads. */
    fun nameOf(filter: Int): String = when (filter) {
        FILTER_PRIORITY -> NAME_PRIORITY
        FILTER_NONE -> NAME_NONE
        FILTER_ALARMS -> NAME_ALARMS
        else -> NAME_ALL
    }
}
