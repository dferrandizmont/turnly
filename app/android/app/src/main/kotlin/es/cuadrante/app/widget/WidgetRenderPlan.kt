package es.cuadrante.app.widget

/**
 * The visibility decisions of a draw, as plain data so the JVM tests can check
 * them without `RemoteViews`.
 *
 * Why this exists (H-T12-2): when the launcher receives a new `RemoteViews`
 * with the SAME layout id as the one it already shows, it does not inflate a
 * fresh tree, it re-applies the actions on the existing views
 * (`RemoteViews.reapply`). Whatever a previous draw left on a view (the "open
 * the app" message made visible, the content hidden) stays unless the new
 * draw sets it again. A draw that only changed the visibility on the stale
 * path left the message on screen for ever after the data came back. So every
 * draw states the visibility of BOTH the message and the content, whatever
 * state it paints.
 */
object WidgetRenderPlan {
    const val MAX_AGENDA_ROWS = 14

    /** Days of the four-week widget: four Monday-first weeks. */
    const val MAX_FOUR_WEEKS_DAYS = 28

    /** Current launcher bounds in dp, after selecting portrait/landscape options. */
    data class Size(val width: Int = 250, val height: Int = 110, val fontScale: Float = 1f)

    /** Extra text must leave the date and the shift codes visible. */
    fun extraLines(availableHeight: Float, fontScale: Float, limit: Int): Int =
        (availableHeight / (13 * fontScale.coerceAtLeast(1f))).toInt().coerceIn(0, limit)

    private fun completeLines(availableHeight: Float, lineHeight: Float, limit: Int): Int =
        (availableHeight / lineHeight).toInt().coerceIn(0, limit)

    /** Heights come from the same font metrics and sizes used by RemoteViews.
     * Reserve padding, the bottom bar and its margin before allocating extras.
     * Hidden extras remain in the root's complete spoken description.
     */
    fun smallExtraLines(size: Size, padding: Int, dateHeight: Float, codeHeight: Float,
                        detailHeight: Float, tomorrowHeight: Float, extraLineHeight: Float,
                        limit: Int): Int = completeLines(
        size.height - 2 * padding - 11 - dateHeight - codeHeight - detailHeight - tomorrowHeight,
        extraLineHeight, limit,
    )

    data class TwoWeeksLayout(val showTimes: List<Boolean>, val extraLines: Int)

    /** Both XML cell margins consume 8dp vertically. Shift rows have equal
     * weights, so EVERY row needs the height of the tallest code/time/bar.
     * Optional times must fit before extras can use any remaining height.
     */
    fun twoWeeksLayout(size: Size, dateHeight: Float, codeHeights: List<Float>,
                       timeCandidates: List<Boolean>, timeHeight: Float,
                       extraLineHeight: Float): TwoWeeksLayout {
        val available = (size.height - 16) / 2f - 8 - dateHeight
        fun shiftsHeight(times: List<Boolean>): Float = codeHeights.indices.maxOfOrNull {
            codeHeights[it] + (if (times[it]) timeHeight else 0f) + 3
        }?.times(codeHeights.size) ?: 0f
        val times = if (shiftsHeight(timeCandidates) <= available) timeCandidates
            else List(codeHeights.size) { false }
        return TwoWeeksLayout(times,
            completeLines(available - shiftsHeight(times), extraLineHeight, 3))
    }

    /** Native ellipsize can split a word. Pack whole words into bounded lines.
     * The complete localized label remains in the cell's spoken description.
     */
    fun wholeWordLines(text: String, width: Float, maxLines: Int,
                       measure: (String) -> Float): String {
        if (text.isBlank() || maxLines <= 0) return ""
        val lines = mutableListOf<String>()
        var line = ""
        for (word in text.split(Regex("\\s+"))) {
            val next = if (line.isEmpty()) word else "$line $word"
            if (measure(next) <= width) {
                line = next
            } else {
                if (line.isNotEmpty()) lines.add(line)
                if (lines.size >= maxLines || measure(word) > width) {
                    if (lines.isEmpty()) return "…"
                    var last = lines.removeAt(lines.lastIndex)
                    while (last.isNotEmpty() && measure("$last …") > width) {
                        last = last.substringBeforeLast(' ', "")
                    }
                    lines.add(if (last.isEmpty()) "…" else "$last …")
                    return lines.joinToString("\n")
                }
                line = word
            }
        }
        if (line.isNotEmpty()) lines.add(line)
        return lines.joinToString("\n")
    }

    fun monday(today: java.time.LocalDate): java.time.LocalDate =
        today.minusDays((today.dayOfWeek.value - 1).toLong())

    fun agendaDayHeight(size: Size, day: DisplayDay): Int =
        16 + kotlin.math.ceil((
            28 * agendaSlots(day, size).size.coerceAtLeast(1) +
                if (day.extras.isEmpty()) 0 else 48
            ) * size.fontScale.coerceAtLeast(1f)).toInt()

    /** A crowded first date still fits completely, with the rest named by +N. */
    fun agendaSlots(day: DisplayDay, size: Size): List<ShiftSlot> =
        agendaSlots(day.shifts, size, reserveExtras = day.extras.isNotEmpty())

    fun agendaSlots(shifts: List<DisplayShift>, size: Size, reserveExtras: Boolean = false): List<ShiftSlot> {
        val shiftHeight = kotlin.math.ceil(28 * size.fontScale.coerceAtLeast(1f)).toInt()
        val reserved = if (reserveExtras) kotlin.math.ceil(48 * size.fontScale.coerceAtLeast(1f)).toInt() else 0
        val count = ((size.height - 32 - reserved) / shiftHeight).coerceAtLeast(1).coerceAtMost(shifts.size)
        return shifts.take(count).mapIndexed { i, shift ->
            ShiftSlot(shift, if (i == count - 1) shifts.size - count else 0)
        }
    }

    fun agendaRows(size: Size, days: List<DisplayDay>): Int {
        var used = 16
        var count = 0
        for (day in days.take(MAX_AGENDA_ROWS)) {
            used += agendaDayHeight(size, day)
            if (used > size.height && count > 0) break
            count++
            if (used > size.height) break
        }
        return count
    }

    /** Keep a whole compact time range or hide it; never truncate a range. */
    fun timeFits(timeWidthDp: Float, cellWidthDp: Float, size: Size, shiftCount: Int): Boolean =
        size.height >= 140 * size.fontScale.coerceAtLeast(1f) && shiftCount <= 2 &&
            timeWidthDp <= (cellWidthDp - 8).coerceAtLeast(0f)

    data class ShiftSlot(val shift: DisplayShift, val hidden: Int) {
        val code: String get() = shift.code + if (hidden > 0) " +$hidden" else ""
    }

    /** At most two codes, with an explicit overflow count and full spoken content. */
    fun twoWeeksSlots(shifts: List<DisplayShift>, size: Size): List<ShiftSlot> {
        val scale = size.fontScale.coerceAtLeast(1f)
        val available = (size.height - 16) / 2f - 8 - 12 * scale
        val count = (available / (16 * scale + 3)).toInt().coerceIn(1, 2).coerceAtMost(shifts.size)
        return shifts.take(count).mapIndexed { i, shift ->
            ShiftSlot(shift, if (i == count - 1) shifts.size - count else 0)
        }
    }

    /** Whether the "open the app" message and the normal content are shown. */
    data class Root(val showStale: Boolean, val showContent: Boolean)

    fun root(content: WidgetContent): Root {
        val stale = content is WidgetContent.Stale
        return Root(showStale = stale, showContent = !stale)
    }

    /**
     * Visibility of each of the [slots] bar segments of a cell with [bands]
     * shifts: a segment per shift, the rest hidden. With no shift, all hidden
     * (a previous draw may have shown several).
     */
    fun barVisibility(bands: Int, slots: Int): List<Boolean> =
        List(slots) { it < bands }
}
