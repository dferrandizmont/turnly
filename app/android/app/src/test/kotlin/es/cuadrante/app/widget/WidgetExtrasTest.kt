package es.cuadrante.app.widget

import org.junit.Assert.*
import org.junit.Test
import java.time.ZoneId
import java.time.ZonedDateTime

class WidgetExtrasTest {
    private val zone = ZoneId.of("Europe/Madrid")
    private val now = ZonedDateTime.of(2026, 10, 19, 12, 0, 0, 0, zone).toInstant().toEpochMilli()
    private fun resource(name: String) = javaClass.getResource("/$name")!!.readText()

    @Test fun extrasAreVisibleWithoutChangingBaseTimesAndAreSpoken() {
        val json = resource("widget_snapshot.json")
        val small = WidgetModelBuilder.build(json, WidgetModelBuilder.Kind.SMALL, now, zone) as WidgetContent.Small
        assertEquals(listOf("+2 h extra", "Salí 1 h antes"), small.extras)
        assertEquals("22:00–06:00", small.detail)
        assertTrue(small.description!!.contains("+2 h extra. Salí 1 h antes"))
        val medium = WidgetModelBuilder.build(json, WidgetModelBuilder.Kind.MEDIUM, now, zone) as WidgetContent.Medium
        assertEquals("7 días: 49 h", medium.totalLabel)
        assertEquals(small.extras, medium.cells.first().extras)
        val agenda = WidgetModelBuilder.build(json, WidgetModelBuilder.Kind.AGENDA, now, zone) as WidgetContent.Agenda
        assertEquals(small.extras, agenda.days.first().extras)
        val large = WidgetModelBuilder.build(json, WidgetModelBuilder.Kind.LARGE, now, zone) as WidgetContent.Large
        assertEquals(small.extras, large.cells.single { it.date == "2026-10-19" }.extras)
    }

    @Test fun oldVersionsRemainReadableWithNoInventedExtrasOrTotal() {
        for (v in listOf(1, 2)) {
            val json = resource("widget_snapshot_v$v.json")
            val small = WidgetModelBuilder.build(json, WidgetModelBuilder.Kind.SMALL, now, zone) as WidgetContent.Small
            val medium = WidgetModelBuilder.build(json, WidgetModelBuilder.Kind.MEDIUM, now, zone) as WidgetContent.Medium
            assertTrue(small.extras.isEmpty())
            assertNull(medium.totalLabel)
        }
    }

    @Test fun missingV3DataIsStaleAndTheNextDateHasNoOldExtras() {
        val json = resource("widget_snapshot.json")
        for (key in listOf("dayExtras", "stripTotals")) {
            val broken = org.json.JSONObject(json).apply { remove(key) }.toString()
            assertTrue(WidgetModelBuilder.build(broken, WidgetModelBuilder.Kind.MEDIUM, now, zone) is WidgetContent.Stale)
        }
        val tomorrow = ZonedDateTime.of(2026, 10, 20, 0, 1, 0, 0, zone).toInstant().toEpochMilli()
        val day = WidgetModelBuilder.build(json, WidgetModelBuilder.Kind.SMALL, tomorrow, zone) as WidgetContent.Small
        assertTrue(day.extras.isEmpty())
        val agenda = WidgetModelBuilder.build(json, WidgetModelBuilder.Kind.AGENDA, now, zone) as WidgetContent.Agenda
        val first = agenda.days.first()
        val size = WidgetRenderPlan.Size()
        assertTrue(WidgetRenderPlan.agendaDayHeight(size, first) >
            WidgetRenderPlan.agendaDayHeight(size, first.copy(extras = emptyList())))
        val crowded = first.copy(shifts = first.shifts + first.shifts)
        assertEquals(1, WidgetRenderPlan.agendaSlots(crowded, size).size)
        assertEquals(1, WidgetRenderPlan.agendaSlots(crowded, size).single().hidden)
        assertTrue(WidgetRenderPlan.agendaDayHeight(size, crowded) <= size.height)
    }

    @Test fun boundedLabelsWrapOrEllipsizeOnlyAtWordBoundaries() {
        fun fit(text: String, width: Int, lines: Int) = WidgetRenderPlan.wholeWordLines(text, width.toFloat(), lines) { it.length.toFloat() }
        assertEquals("+2 h\nOtro\ntrabajo", fit("+2 h Otro trabajo", 7, 3))
        assertEquals("+2 h …", fit("+2 h Otro trabajo", 7, 1))
        assertEquals("…", fit("Formación", 5, 2))
        assertEquals("Salí 1 h\nantes", fit("Salí 1 h antes", 9, 2))
        assertEquals("", fit("", 5, 2))
    }

    @Test fun extraLinesNeverUseTheSpaceReservedForBaseCodes() {
        assertEquals(0, WidgetRenderPlan.extraLines(-10f, 1f, 3))
        assertEquals(0, WidgetRenderPlan.extraLines(12f, 1f, 3))
        assertEquals(2, WidgetRenderPlan.extraLines(26f, 1f, 3))
        assertEquals(1, WidgetRenderPlan.extraLines(26f, 2f, 3))
        assertEquals(3, WidgetRenderPlan.extraLines(200f, 1f, 3))
    }

    @Test fun twoWeeksReservesTimesBarsAndBothCellMarginsBeforeExtras() {
        fun plan(height: Int, times: List<Boolean> = listOf(true, true)) =
            WidgetRenderPlan.twoWeeksLayout(WidgetRenderPlan.Size(400, height),
                13f, listOf(17f, 17f), times, 13f, 13f)

        // 400x190: each row has 87dp. The margins (8), date (13) and
        // two complete shifts (2 * (17 + 13 + 3)) use all of it.
        val minimum = plan(190)
        assertEquals(listOf(true, true), minimum.showTimes)
        assertEquals(0, minimum.extraLines)
        assertEquals(0, plan(215).extraLines) // Less than one complete extra line.
        assertEquals(1, plan(216).extraLines)
        assertEquals(2, plan(242).extraLines)
        assertEquals(3, plan(400).extraLines)
        // XML weights give both shifts the tallest row's height, even if
        // just one of them has a time. Summing heights would allow clipping.
        assertEquals(0, plan(190, listOf(true, false)).extraLines)
        assertEquals(2, plan(190, listOf(false, false)).extraLines)
    }

    @Test fun twoWeeksDropsOptionalTimesWhenTheyCannotFitEvenWithoutExtras() {
        val plan = WidgetRenderPlan.twoWeeksLayout(WidgetRenderPlan.Size(400, 190, 1.3f),
            17f, listOf(22f, 22f), listOf(true, true), 17f, 17f)
        assertEquals(listOf(false, false), plan.showTimes)
        assertEquals(0, plan.extraLines)
        val oneShift = WidgetRenderPlan.twoWeeksLayout(WidgetRenderPlan.Size(400, 190, 1.3f),
            17f, listOf(22f), listOf(true), 17f, 17f)
        assertEquals(listOf(true), oneShift.showTimes)
        assertEquals(1, oneShift.extraLines)
    }

    @Test fun smallMinimumLimitsExtrasToCompleteLinesAsTextGrows() {
        fun plan(scale: Float, detail: Boolean = true) = WidgetRenderPlan.smallExtraLines(
            WidgetRenderPlan.Size(110, 110, scale), 6,
            16 * scale, 17 * scale, if (detail) 16 * scale else 0f,
            0f, 13 * scale, 3,
        )
        assertEquals(2, plan(1f))
        assertEquals(1, plan(1.3f))
        assertEquals(0, plan(1.5f))
        assertEquals(0, plan(2f))
        assertEquals(1, plan(1.5f, detail = false))

        val small = WidgetModelBuilder.build(resource("widget_snapshot.json"),
            WidgetModelBuilder.Kind.SMALL, now, zone) as WidgetContent.Small
        // Omitting visual lines never removes the adjustments or tomorrow
        // from the data used by the renderer's complete root description.
        assertTrue(small.description!!.contains("+2 h extra. Salí 1 h antes"))
        assertTrue(small.tomorrow.isNotBlank())
    }

    @Test fun smallBudgetAlsoReservesTomorrowAndFullPaddingWhenThereIsRoom() {
        fun plan(height: Int) = WidgetRenderPlan.smallExtraLines(
            WidgetRenderPlan.Size(180, height), 12, 17f, 29f, 19f, 32f, 13f, 4)
        // Padding 24 + bar/margin 11 + date/code/time/tomorrow 97 = 132.
        assertEquals(0, plan(144))
        assertEquals(1, plan(145))
        assertEquals(3, plan(183))
        assertEquals(4, plan(184))
    }
}
