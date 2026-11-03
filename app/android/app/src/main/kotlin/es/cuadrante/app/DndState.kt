package es.cuadrante.app

import android.app.NotificationManager
import android.content.Context
import android.os.Build

/**
 * What the app remembers about the silence it has put on the phone: the mode
 * the phone had before (to put it back when the shift ends), the filter the
 * app set and the window that set it (to know whether the user changed the
 * mode by hand, and which window owns the silence).
 */
object DndState {
    private const val PREFERENCES = "cuadrante_dnd"
    private const val KEY_APPLIED = "applied"
    private const val KEY_APPLIED_FILTER = "applied_filter"
    private const val KEY_APPLIED_ID = "applied_id"
    private const val KEY_PREVIOUS = "previous_filter"
    private const val KEY_ARMED = "armed_ids"

    /** The filter the phone is in, or null when it cannot be read. */
    fun currentFilter(context: Context): Int? {
        if (Build.VERSION.SDK_INT < DndPolicy.MIN_SDK) return null
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                ?: return null
        return try {
            manager.currentInterruptionFilter
        } catch (e: SecurityException) {
            // The permission was taken away.
            null
        }
    }

    /**
     * Puts the phone in [filter], remembering the mode it had the first time
     * (so it can be put back when the shift ends).
     */
    fun silence(context: Context, id: Int, filter: Int) {
        val current = currentFilter(context) ?: return
        val prefs = prefs(context)
        val editor = prefs.edit()
        if (!prefs.getBoolean(KEY_APPLIED, false)) {
            // The first silence: remember the mode the phone had.
            editor.putInt(KEY_PREVIOUS, current)
            editor.putBoolean(KEY_APPLIED, true)
        }
        // Back-to-back or overlapping windows: the latest one owns the
        // silence now (so the end of the earlier one does not free the phone
        // early), and the mode from before the first one is kept.
        editor.putInt(KEY_APPLIED_FILTER, filter)
        editor.putInt(KEY_APPLIED_ID, id)
        editor.apply()
        setFilter(context, filter)
    }

    /**
     * Frees the phone at the end of the window [id], unless the user changed
     * the mode by hand: then the phone is left as it is.
     *
     * [id] null means "the silence is over" (the whole feature was turned
     * off), so the phone is freed whatever window had silenced it.
     */
    fun release(context: Context, id: Int?) {
        val prefs = prefs(context)
        if (!prefs.getBoolean(KEY_APPLIED, false)) return
        val appliedId = prefs.getInt(KEY_APPLIED_ID, Int.MIN_VALUE)
        if (id != null && appliedId != id) {
            // Another window is the one that silenced the phone: it is the
            // one that frees it.
            return
        }
        val applied = prefs.getInt(KEY_APPLIED_FILTER, DndPolicy.FILTER_ALL)
        val previous = prefs.getInt(KEY_PREVIOUS, DndPolicy.FILTER_ALL)
        val current = currentFilter(context) ?: return
        val restore = DndPolicy.filterToRestore(applied, current, previous)
        if (restore != null) setFilter(context, restore)
        forget(context)
    }

    /** Forgets the silence (the window ended, or it was cancelled). */
    fun forget(context: Context) {
        prefs(context).edit()
            .remove(KEY_APPLIED)
            .remove(KEY_APPLIED_FILTER)
            .remove(KEY_APPLIED_ID)
            .remove(KEY_PREVIOUS)
            .apply()
    }

    /** The ids of the windows that are armed. */
    fun armedIds(context: Context): Set<Int> =
        prefs(context).getStringSet(KEY_ARMED, emptySet())
            ?.mapNotNull { it.toIntOrNull() }
            ?.toSet()
            ?: emptySet()

    /** Remembers the windows that are armed. */
    fun setArmedIds(context: Context, ids: Set<Int>) {
        prefs(context).edit()
            .putStringSet(KEY_ARMED, ids.map { it.toString() }.toSet())
            .apply()
    }

    private fun setFilter(context: Context, filter: Int) {
        if (Build.VERSION.SDK_INT < DndPolicy.MIN_SDK) return
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                ?: return
        try {
            manager.setInterruptionFilter(filter)
        } catch (e: SecurityException) {
            // The permission was taken away: the phone stays as it is.
        }
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
}
