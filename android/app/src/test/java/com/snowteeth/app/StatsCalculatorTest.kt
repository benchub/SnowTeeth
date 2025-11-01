package com.snowteeth.app

import com.snowteeth.app.model.LocationData
import com.snowteeth.app.util.StatsCalculator
import org.junit.Before
import org.junit.Test
import org.junit.Assert.*

class StatsCalculatorTest {

    private lateinit var statsCalculator: StatsCalculator

    @Before
    fun setup() {
        statsCalculator = StatsCalculator()
    }

    @Test
    fun testCalculateStats_EmptyList_ReturnsZeros() {
        val stats = statsCalculator.calculateStats(emptyList(), false)

        assertEquals(0.0, stats.verticalFeetUp, 0.01)
        assertEquals(0.0, stats.verticalFeetDown, 0.01)
        assertEquals(0.0, stats.horizontalDistance, 0.01)
        assertEquals(0, stats.numUphills)
        assertEquals(0, stats.numDownhills)
    }

    @Test
    fun testCalculateStats_SinglePoint_ReturnsZeros() {
        val points = listOf(
            createLocationData(0.0, 0.0, 100.0)
        )

        val stats = statsCalculator.calculateStats(points, false)

        assertEquals(0.0, stats.verticalFeetUp, 0.01)
        assertEquals(0.0, stats.verticalFeetDown, 0.01)
        assertEquals(0.0, stats.horizontalDistance, 0.01)
    }

    @Test
    fun testCalculateStats_SimpleUphill() {
        val points = listOf(
            createLocationData(0.0, 0.0, 0.0),
            createLocationData(0.001, 0.001, 10.0),
            createLocationData(0.002, 0.002, 20.0),
            createLocationData(0.003, 0.003, 30.0)
        )

        val stats = statsCalculator.calculateStats(points, false)

        // 30 meters up = ~98.4 feet
        assertTrue(stats.verticalFeetUp > 95.0)
        assertTrue(stats.verticalFeetUp < 102.0)
        assertEquals(0.0, stats.verticalFeetDown, 0.01)
        assertTrue(stats.numUphills >= 1)
    }

    @Test
    fun testCalculateStats_SimpleDownhill() {
        val points = listOf(
            createLocationData(0.0, 0.0, 100.0),
            createLocationData(0.001, 0.001, 90.0),
            createLocationData(0.002, 0.002, 80.0),
            createLocationData(0.003, 0.003, 70.0)
        )

        val stats = statsCalculator.calculateStats(points, false)

        // 30 meters down = ~98.4 feet
        assertTrue(stats.verticalFeetDown > 95.0)
        assertTrue(stats.verticalFeetDown < 102.0)
        assertEquals(0.0, stats.verticalFeetUp, 0.01)
        assertTrue(stats.numDownhills >= 1)
    }

    @Test
    fun testCalculateStats_MixedElevation() {
        val points = listOf(
            createLocationData(0.0, 0.0, 0.0),
            createLocationData(0.001, 0.001, 10.0),  // +10m
            createLocationData(0.002, 0.002, 20.0),  // +10m
            createLocationData(0.003, 0.003, 15.0),  // -5m
            createLocationData(0.004, 0.004, 10.0),  // -5m
            createLocationData(0.005, 0.005, 5.0)    // -5m
        )

        val stats = statsCalculator.calculateStats(points, false)

        // Total up: 20m = ~65.6 feet
        assertTrue(stats.verticalFeetUp > 60.0)
        assertTrue(stats.verticalFeetUp < 70.0)

        // Total down: 15m = ~49.2 feet
        assertTrue(stats.verticalFeetDown > 45.0)
        assertTrue(stats.verticalFeetDown < 55.0)
    }

    @Test
    fun testCalculateStats_HorizontalDistance_Imperial() {
        // Create points roughly 100 meters apart
        val points = listOf(
            createLocationData(0.0, 0.0, 0.0),
            createLocationData(0.001, 0.0, 0.0),  // ~111 meters east
            createLocationData(0.002, 0.0, 0.0)   // ~111 meters more
        )

        val stats = statsCalculator.calculateStats(points, useMetric = false)

        // Total distance should be around ~0.138 miles (222 meters)
        assertTrue(stats.horizontalDistance > 0.10)
        assertTrue(stats.horizontalDistance < 0.20)
    }

    @Test
    fun testCalculateStats_HorizontalDistance_Metric() {
        // Create points roughly 100 meters apart
        val points = listOf(
            createLocationData(0.0, 0.0, 0.0),
            createLocationData(0.001, 0.0, 0.0),  // ~111 meters east
            createLocationData(0.002, 0.0, 0.0)   // ~111 meters more
        )

        val stats = statsCalculator.calculateStats(points, useMetric = true)

        // Total distance should be around ~0.222 km
        assertTrue(stats.horizontalDistance > 0.18)
        assertTrue(stats.horizontalDistance < 0.26)
    }

    @Test
    fun testParseGpxFile_ValidFormat() {
        val gpxContent = """
            <?xml version="1.0" encoding="UTF-8"?>
            <gpx version="1.1">
              <trk>
                <trkseg>
                  <trkpt lat="37.7749" lon="-122.4194">
                    <ele>10.0</ele>
                    <time>2024-01-01T12:00:00Z</time>
                  </trkpt>
                  <trkpt lat="37.7750" lon="-122.4195">
                    <ele>20.0</ele>
                    <time>2024-01-01T12:00:10Z</time>
                  </trkpt>
                </trkseg>
              </trk>
            </gpx>
        """.trimIndent()

        val points = statsCalculator.parseGpxFile(gpxContent)

        assertEquals(2, points.size)
        assertEquals(37.7749, points[0].latitude, 0.0001)
        assertEquals(-122.4194, points[0].longitude, 0.0001)
        assertEquals(10.0, points[0].altitude, 0.01)
        assertEquals(37.7750, points[1].latitude, 0.0001)
        assertEquals(-122.4195, points[1].longitude, 0.0001)
        assertEquals(20.0, points[1].altitude, 0.01)
    }

    @Test
    fun testParseGpxFile_EmptyFile() {
        val gpxContent = """
            <?xml version="1.0" encoding="UTF-8"?>
            <gpx version="1.1">
            </gpx>
        """.trimIndent()

        val points = statsCalculator.parseGpxFile(gpxContent)
        assertEquals(0, points.size)
    }

    private fun createLocationData(lat: Double, lon: Double, altitude: Double): LocationData {
        return LocationData(
            latitude = lat,
            longitude = lon,
            altitude = altitude,
            timestamp = System.currentTimeMillis(),
            speed = 0f
        )
    }
}
