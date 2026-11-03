package es.cuadrante.app.widget

import es.cuadrante.app.widget.WidgetModelBuilder.Kind
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * The four-week widget (UW), read from the snapshot the Dart builder wrote
 * (`widget_snapshot_four_weeks.json`, 35 days from Monday 2026-10-19; the
 * timeline is 2026-10-19..2026-11-22 and the auxiliary range reaches
 * 2026-12-19):
 *
 *  - four Monday-first weeks of 28 cells, starting on the Monday of today;
 *  - the next day off of today as a header label (`nextOff`);
 *  - the first line of the note under the day number, never from an absence
 *    (2026-10-21 "Cambio de turno", 2026-10-28 "Formación"; 2026-10-23 is a
 *    vacation day with a private note that must never leave).
 */
class WidgetFourWeeksTest {
    private val madrid = ZoneId.of("Europe/Madrid")
    private val json: String = javaClass.getResource("/widget_snapshot_four_weeks.json")!!.readText()

    private fun at(date: String, h: Int = 12): Long =
        ZonedDateTime.of(LocalDateTime.parse(date + "T00:00"), madrid).plusHours(h.toLong())
            .toInstant().toEpochMilli()

    private fun build(date: String = "2026-10-19", data: String = json): WidgetContent =
        WidgetModelBuilder.build(data, Kind.FOUR_WEEKS, at(date), madrid)

    private fun fourWeeks(date: String = "2026-10-19", data: String = json) =
        build(date, data) as WidgetContent.FourWeeks

    @Test
    fun fourMondayFirstWeeksStartOnTheMondayOfToday() {
        val c = fourWeeks("2026-10-19")
        assertEquals(28, WidgetRenderPlan.MAX_FOUR_WEEKS_DAYS)
        assertEquals("2026-10-19", c.date)
        assertEquals(28, c.days.size)
        assertEquals("2026-10-19", c.days.first().date)
        assertEquals("2026-11-15", c.days.last().date)
        assertEquals(
            listOf("lun", "mar", "mié", "jue", "vie", "sáb", "dom"),
            c.days.take(7).map { it.weekdayShort },
        )
        for (i in c.days.indices) {
            assertEquals(
                LocalDate.parse("2026-10-19").plusDays(i.toLong()).toString(),
                c.days[i].date,
            )
        }
    }

    @Test
    fun midWeekKeepsTheSameMondayAndTheNextMondayAdvancesAWeek() {
        // Wednesday: the grid still starts on Monday of that week.
        val midWeek = fourWeeks("2026-10-21")
        assertEquals("2026-10-21", midWeek.date)
        assertEquals("2026-10-19", midWeek.days.first().date)
        assertEquals("2026-11-15", midWeek.days.last().date)
        // The following Monday the whole grid moves one week.
        val next = fourWeeks("2026-10-26")
        assertEquals("2026-10-26", next.days.first().date)
        assertEquals("2026-11-22", next.days.last().date)
        // Sunday is the last day that keeps the Monday before it.
        assertEquals("2026-10-19", fourWeeks("2026-10-25").days.first().date)
    }

    @Test
    fun theNextDayOffOfTodayIsShown() {
        assertEquals("Libras el jueves 22", fourWeeks("2026-10-19").nextOff)
        assertEquals("Mañana libras", fourWeeks("2026-10-21").nextOff)
        assertEquals("Hoy libras; vuelves el sábado 24", fourWeeks("2026-10-22").nextOff)
        // A day of the tail with no known next day off: no label, no crash.
        val forged = JSONObject(json).apply { remove("nextOff") }.toString()
        assertNull(fourWeeks("2026-10-19", forged).nextOff)
    }

    @Test
    fun theFirstLineOfTheNoteTravelsUnderTheNumber() {
        val c = fourWeeks("2026-10-19")
        val day = c.days.single { it.date == "2026-10-21" }
        assertEquals("Cambio de turno", day.note)
        assertTrue(day.hasNote)
        assertEquals(listOf("M", "T"), day.shifts.map { it.code })
        assertEquals("Formación", c.days.single { it.date == "2026-10-28" }.note)
    }

    @Test
    fun theSecondLineOfANoteAndAnAbsenceNoteNeverLeave() {
        assertFalse(json.contains("segunda línea privada"))
        assertFalse(json.contains("Cita médica"))
        assertEquals("Cambio de turno", JSONObject(json).getJSONObject("notes").getString("2026-10-21"))
        assertFalse(JSONObject(json).getJSONObject("notes").has("2026-10-23"))
    }

    @Test
    fun anAbsenceDayHasNoNoteAndStaysAnonymous() {
        val day = fourWeeks("2026-10-23").days.single { it.date == "2026-10-23" }
        val shift = day.shifts.single()
        assertEquals("absence", shift.category)
        assertEquals("Ausencia", shift.code)
        assertEquals(shift.code, shift.name)
        assertNull(shift.timeLabel)
        assertNull(shift.compactTime)
        assertNull(day.note)
        assertFalse(day.hasNote)
    }

    @Test
    fun aForgedNoteOrMarkerOnAnAbsenceIsStillIgnored() {
        val root = JSONObject(json)
        root.getJSONObject("notes").put("2026-10-23", "Diagnóstico privado")
        val days = root.getJSONArray("displayDays")
        for (i in 0 until days.length()) {
            if (days.getJSONObject(i).getString("date") == "2026-10-23") {
                days.getJSONObject(i).put("hasNote", true)
            }
        }
        val day = fourWeeks("2026-10-23", root.toString()).days.single { it.date == "2026-10-23" }
        assertNull(day.note)
        assertFalse(day.hasNote)
    }

    @Test
    fun aMissingAuxiliaryDateIsTheMessageNeverHalfAGrid() {
        val root = JSONObject(json)
        val days = root.getJSONArray("displayDays")
        var idx = -1
        for (i in 0 until days.length()) {
            if (days.getJSONObject(i).getString("date") == "2026-11-10") {
                idx = i
                break
            }
        }
        assertTrue(idx >= 0)
        days.remove(idx)
        assertTrue(build("2026-10-19", root.toString()) is WidgetContent.Stale)
    }

    @Test
    fun outsideTheTimelineIsTheHonestMessage() {
        // The last timeline day is still a four-week grid, and so is a day of
        // its last Monday-to-Sunday week.
        assertTrue(build("2026-11-22") is WidgetContent.FourWeeks)
        assertTrue(build("2026-11-20") is WidgetContent.FourWeeks)
        for (date in listOf("2026-11-23", "2026-12-19")) {
            val after = build(date) as WidgetContent.Stale
            assertEquals(WidgetDayLogic.StaleReason.AFTER_LAST, after.reason)
        }
        val before = build("2026-10-18") as WidgetContent.Stale
        assertEquals(WidgetDayLogic.StaleReason.BEFORE_FIRST, before.reason)
    }

    @Test
    fun theOtherWidgetsStillReadTheSameSnapshot() {
        val small = WidgetModelBuilder.build(json, Kind.SMALL, at("2026-10-19"), madrid) as WidgetContent.Small
        assertEquals("N", small.big)
        val twoWeeks = WidgetModelBuilder.build(json, Kind.TWO_WEEKS, at("2026-10-19"), madrid) as WidgetContent.TwoWeeks
        assertEquals("2026-10-19", twoWeeks.days.first().date)
        assertEquals(14, twoWeeks.days.size)
    }

    @Test
    fun aV1SnapshotCannotServeTheFourWeekWidget() {
        val old = javaClass.getResource("/widget_snapshot_v1.json")!!.readText()
        assertTrue(build("2026-10-19", old) is WidgetContent.Stale)
    }
}
