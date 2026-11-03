package es.cuadrante.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DndPolicyTest {
    // ---- the request codes ---------------------------------------------------

    @Test
    fun theRequestCodesAreInARangeOfOurOwn() {
        // The notification plugin uses the id of the alarm (a 31-bit hash) for
        // its own: ours start well inside the int, in a range of their own.
        assertTrue(DndPolicy.silenceRequestCode(1234) >= 0x40000000)
        assertTrue(DndPolicy.releaseRequestCode(1234) >= 0x40000000)
    }

    @Test
    fun theSilenceAndTheReleaseOfAWindowNeverShareTheirCode() {
        for (id in listOf(0, 1, 1234, 987654, Int.MAX_VALUE, Int.MIN_VALUE)) {
            assertTrue(
                DndPolicy.silenceRequestCode(id) != DndPolicy.releaseRequestCode(id),
            )
        }
    }

    @Test
    fun twoWindowsNeverShareTheirCode() {
        assertTrue(
            DndPolicy.silenceRequestCode(1) != DndPolicy.silenceRequestCode(2),
        )
        assertTrue(
            DndPolicy.releaseRequestCode(1) != DndPolicy.releaseRequestCode(2),
        )
    }

    @Test
    fun theRequestCodesStayInTheRangeOfAnInt() {
        for (id in listOf(0, 1, 1234, 987654, Int.MAX_VALUE, Int.MIN_VALUE)) {
            assertTrue(DndPolicy.silenceRequestCode(id) > 0)
            assertTrue(DndPolicy.releaseRequestCode(id) > 0)
            assertTrue(DndPolicy.silenceRequestCode(id) < Int.MAX_VALUE)
            assertTrue(DndPolicy.releaseRequestCode(id) < Int.MAX_VALUE)
        }
    }

    // ---- the mode the window is armed with ----------------------------------

    @Test
    fun withExactAlarmsTheWindowIsAnAlarmClock() {
        // Only an alarm clock is safe from the window manufacturers give
        // `setExactAndAllowWhileIdle` (up to an hour on a OnePlus).
        assertEquals(
            DndPolicy.ScheduleMode.ALARM_CLOCK,
            DndPolicy.scheduleMode(canExact = true),
        )
    }

    @Test
    fun withoutExactAlarmsTheWindowIsInexact() {
        assertEquals(
            DndPolicy.ScheduleMode.INEXACT,
            DndPolicy.scheduleMode(canExact = false),
        )
    }

    @Test
    fun theShowCodeOfTheAlarmClockIsOutsideTheBroadcastRanges() {
        for (id in listOf(0, 1, 1234, 987654, Int.MAX_VALUE, Int.MIN_VALUE)) {
            assertTrue(DndPolicy.SHOW_REQUEST_CODE != DndPolicy.silenceRequestCode(id))
            assertTrue(DndPolicy.SHOW_REQUEST_CODE != DndPolicy.releaseRequestCode(id))
        }
        assertTrue(DndPolicy.SHOW_REQUEST_CODE > 0)
    }

    // ---- the window that is running -----------------------------------------

    @Test
    fun aWindowThatHasBegunAndHasNotEndedIsRunning() {
        val start = 1_000L
        val end = 2_000L
        assertTrue(DndPolicy.isActive(start, end, start))
        assertTrue(DndPolicy.isActive(start, end, 1_500L))
        assertTrue(DndPolicy.isActive(start, end, end - 1))
    }

    @Test
    fun aWindowThatHasNotBegunYetIsNotRunning() {
        assertFalse(DndPolicy.isActive(1_000L, 2_000L, 999L))
        assertFalse(DndPolicy.isActive(1_000L, 2_000L, 0L))
    }

    @Test
    fun aWindowThatHasEndedIsNotRunning() {
        // The end is not included: the phone is freed at that very minute.
        assertFalse(DndPolicy.isActive(1_000L, 2_000L, 2_000L))
        assertFalse(DndPolicy.isActive(1_000L, 2_000L, 2_001L))
    }

    // ---- the mode the phone had ----------------------------------------------

    @Test
    fun theModeThePhoneHadComesBackWhenNobodyTouchedIt() {
        assertEquals(
            DndPolicy.FILTER_ALL,
            DndPolicy.filterToRestore(
                applied = DndPolicy.FILTER_PRIORITY,
                current = DndPolicy.FILTER_PRIORITY,
                previous = DndPolicy.FILTER_ALL,
            ),
        )
    }

    @Test
    fun aModeChangedByHandIsLeftAlone() {
        // The user turned the filter off (or into another one) while the
        // shift lasted: the app does not touch the phone.
        assertNull(
            DndPolicy.filterToRestore(
                applied = DndPolicy.FILTER_PRIORITY,
                current = DndPolicy.FILTER_ALL,
                previous = DndPolicy.FILTER_ALL,
            ),
        )
        assertNull(
            DndPolicy.filterToRestore(
                applied = DndPolicy.FILTER_PRIORITY,
                current = DndPolicy.FILTER_NONE,
                previous = DndPolicy.FILTER_ALL,
            ),
        )
    }

    // ---- the names ------------------------------------------------------------

    @Test
    fun theNamesOfTheDartSideAreTheAndroidFilters() {
        assertEquals(DndPolicy.FILTER_ALL, DndPolicy.filterOf("all"))
        assertEquals(DndPolicy.FILTER_PRIORITY, DndPolicy.filterOf("priority"))
        assertEquals(DndPolicy.FILTER_NONE, DndPolicy.filterOf("none"))
        assertEquals(DndPolicy.FILTER_ALARMS, DndPolicy.filterOf("alarms"))
    }

    @Test
    fun anUnknownNameHasNoFilter() {
        assertNull(DndPolicy.filterOf("silence"))
        assertNull(DndPolicy.filterOf(null))
        assertNull(DndPolicy.filterOf(""))
    }

    @Test
    fun theFiltersHaveTheirNameBack() {
        assertEquals("all", DndPolicy.nameOf(DndPolicy.FILTER_ALL))
        assertEquals("priority", DndPolicy.nameOf(DndPolicy.FILTER_PRIORITY))
        assertEquals("none", DndPolicy.nameOf(DndPolicy.FILTER_NONE))
        assertEquals("alarms", DndPolicy.nameOf(DndPolicy.FILTER_ALARMS))
        // An unknown one reads as "all": the phone is not silenced.
        assertEquals("all", DndPolicy.nameOf(99))
    }

    @Test
    fun theFiltersAreTheValuesOfAndroid() {
        // NotificationManager.INTERRUPTION_FILTER_ALL, _PRIORITY, _NONE and
        // _ALARMS: an off-by-one here turned «priority» into «all» (3-nov-2026).
        assertEquals(1, DndPolicy.FILTER_ALL)
        assertEquals(2, DndPolicy.FILTER_PRIORITY)
        assertEquals(3, DndPolicy.FILTER_NONE)
        assertEquals(4, DndPolicy.FILTER_ALARMS)
    }
}
