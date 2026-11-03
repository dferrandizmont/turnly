package es.cuadrante.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri

/**
 * Receives the two alarms of the silence windows (P13): the one that silences
 * the phone and the one that frees it.
 *
 * It also listens to the boot: the pending alarms do not survive a reboot, so
 * the phone is freed then (the app arms the windows again the next time it
 * opens).
 */
class DndAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_SILENCE ->
                DndState.silence(
                    context,
                    intent.getIntExtra(EXTRA_ID, Int.MIN_VALUE),
                    intent.getIntExtra(EXTRA_FILTER, DndPolicy.FILTER_PRIORITY),
                )
            ACTION_RELEASE ->
                DndState.release(context, intent.getIntExtra(EXTRA_ID, Int.MIN_VALUE))
            ACTION_BOOT -> {
                // The pending alarms are gone: the phone is freed and the
                // windows are not armed any more.
                DndState.release(context, null)
                DndState.setArmedIds(context, emptySet())
            }
        }
    }

    companion object {
        /** Our own actions: they never collide with the ones of the plugin. */
        const val ACTION_SILENCE = "es.cuadrante.app.DND_SILENCE"
        const val ACTION_RELEASE = "es.cuadrante.app.DND_RELEASE"
        const val ACTION_BOOT = "android.intent.action.BOOT_COMPLETED"

        /** The window the alarm belongs to. */
        const val EXTRA_ID = "id"

        /** The filter the window puts the phone in. */
        const val EXTRA_FILTER = "filter"

        /** The intent that silences the phone for the window [id]. */
        fun silenceIntent(context: Context, id: Int, filter: Int): Intent =
            intent(context, ACTION_SILENCE, id, filter)

        /** The intent that frees the phone at the end of the window [id]. */
        fun releaseIntent(context: Context, id: Int, filter: Int): Intent =
            intent(context, ACTION_RELEASE, id, filter)

        private fun intent(
            context: Context,
            action: String,
            id: Int,
            filter: Int,
        ): Intent = Intent(context, DndAlarmReceiver::class.java).apply {
            this.action = action
            // The data makes every window an intent of its own: the pending
            // intent of one window never replaces another's.
            data = Uri.parse("es.cuadrante.app://dnd/$action/$id")
            putExtra(EXTRA_ID, id)
            putExtra(EXTRA_FILTER, filter)
        }
    }
}
