package com.snowteeth.app

import com.snowteeth.app.model.LocationData
import com.snowteeth.app.model.VelocityBucket
import com.snowteeth.app.util.AppPreferences
import com.snowteeth.app.util.VelocityCalculator
import org.junit.Before
import org.junit.Test
import org.junit.Assert.*
import org.mockito.Mockito.*
import org.mockito.kotlin.whenever

class VelocityCalculatorTest {

    private lateinit var mockPrefs: AppPreferences
    private lateinit var velocityCalculator: VelocityCalculator

    @Before
    fun setup() {
        mockPrefs = mock(AppPreferences::class.java)

        // Set default thresholds (in mph)
        whenever(mockPrefs.downhillHardThreshold).thenReturn(10.0f)
        whenever(mockPrefs.downhillMediumThreshold).thenReturn(6.0f)
        whenever(mockPrefs.downhillEasyThreshold).thenReturn(2.0f)
        whenever(mockPrefs.uphillHardThreshold).thenReturn(5.0f)
        whenever(mockPrefs.uphillMediumThreshold).thenReturn(3.0f)
        whenever(mockPrefs.uphillEasyThreshold).thenReturn(1.0f)

        velocityCalculator = VelocityCalculator(mockPrefs)
    }

    @Test
    fun testCalculateBucket_NoPreviousLocation_ReturnsIdle() {
        val current = createLocationData(0.0, 0.0, 100.0, 5.0f)
        val bucket = velocityCalculator.calculateBucket(current, null)
        assertEquals(VelocityBucket.IDLE, bucket)
    }

    @Test
    fun testCalculateBucket_DownhillHard() {
        // Speed: 11 mph = ~4.92 m/s, Elevation decrease
        val previous = createLocationData(0.0, 0.0, 100.0, 0f)
        val current = createLocationData(0.0001, 0.0001, 50.0, 4.92f)

        val bucket = velocityCalculator.calculateBucket(current, previous)
        assertEquals(VelocityBucket.DOWNHILL_HARD, bucket)
    }

    @Test
    fun testCalculateBucket_DownhillMedium() {
        // Speed: 7 mph = ~3.13 m/s, Elevation decrease
        val previous = createLocationData(0.0, 0.0, 100.0, 0f)
        val current = createLocationData(0.0001, 0.0001, 50.0, 3.13f)

        val bucket = velocityCalculator.calculateBucket(current, previous)
        assertEquals(VelocityBucket.DOWNHILL_MEDIUM, bucket)
    }

    @Test
    fun testCalculateBucket_DownhillEasy() {
        // Speed: 3 mph = ~1.34 m/s, Elevation decrease
        val previous = createLocationData(0.0, 0.0, 100.0, 0f)
        val current = createLocationData(0.0001, 0.0001, 50.0, 1.34f)

        val bucket = velocityCalculator.calculateBucket(current, previous)
        assertEquals(VelocityBucket.DOWNHILL_EASY, bucket)
    }

    @Test
    fun testCalculateBucket_UphillHard() {
        // Speed: 6 mph = ~2.68 m/s, Elevation increase
        val previous = createLocationData(0.0, 0.0, 50.0, 0f)
        val current = createLocationData(0.0001, 0.0001, 100.0, 2.68f)

        val bucket = velocityCalculator.calculateBucket(current, previous)
        assertEquals(VelocityBucket.UPHILL_HARD, bucket)
    }

    @Test
    fun testCalculateBucket_UphillMedium() {
        // Speed: 4 mph = ~1.79 m/s, Elevation increase
        val previous = createLocationData(0.0, 0.0, 50.0, 0f)
        val current = createLocationData(0.0001, 0.0001, 100.0, 1.79f)

        val bucket = velocityCalculator.calculateBucket(current, previous)
        assertEquals(VelocityBucket.UPHILL_MEDIUM, bucket)
    }

    @Test
    fun testCalculateBucket_UphillEasy() {
        // Speed: 2 mph = ~0.89 m/s, Elevation increase
        val previous = createLocationData(0.0, 0.0, 50.0, 0f)
        val current = createLocationData(0.0001, 0.0001, 100.0, 0.89f)

        val bucket = velocityCalculator.calculateBucket(current, previous)
        assertEquals(VelocityBucket.UPHILL_EASY, bucket)
    }

    @Test
    fun testCalculateBucket_Idle_LowSpeed() {
        // Speed: 0.5 mph = ~0.22 m/s, Elevation increase
        val previous = createLocationData(0.0, 0.0, 50.0, 0f)
        val current = createLocationData(0.0001, 0.0001, 50.5, 0.22f)

        val bucket = velocityCalculator.calculateBucket(current, previous)
        assertEquals(VelocityBucket.IDLE, bucket)
    }

    @Test
    fun testInterpolationFactor_BetweenBuckets() {
        // Speed halfway between medium and hard thresholds
        val previous = createLocationData(0.0, 0.0, 100.0, 0f)
        val current = createLocationData(0.0001, 0.0001, 50.0, 3.58f) // 8 mph

        val factor = velocityCalculator.calculateInterpolationFactor(
            current,
            previous,
            VelocityBucket.DOWNHILL_MEDIUM,
            VelocityBucket.DOWNHILL_HARD
        )

        // Should be around 0.5 since 8 is halfway between 6 and 10
        assertTrue(factor > 0.4f && factor < 0.6f)
    }

    @Test
    fun testInterpolationFactor_ClampedToZero() {
        val previous = createLocationData(0.0, 0.0, 100.0, 0f)
        val current = createLocationData(0.0001, 0.0001, 50.0, 2.68f) // 6 mph

        val factor = velocityCalculator.calculateInterpolationFactor(
            current,
            previous,
            VelocityBucket.DOWNHILL_MEDIUM,
            VelocityBucket.DOWNHILL_HARD
        )

        // Should be 0 since we're at the lower threshold
        assertEquals(0f, factor, 0.01f)
    }

    @Test
    fun testInterpolationFactor_ClampedToOne() {
        val previous = createLocationData(0.0, 0.0, 100.0, 0f)
        val current = createLocationData(0.0001, 0.0001, 50.0, 4.92f) // 11 mph

        val factor = velocityCalculator.calculateInterpolationFactor(
            current,
            previous,
            VelocityBucket.DOWNHILL_MEDIUM,
            VelocityBucket.DOWNHILL_HARD
        )

        // Should be 1.0 since we're at or above the upper threshold
        assertEquals(1f, factor, 0.01f)
    }

    private fun createLocationData(
        lat: Double,
        lon: Double,
        altitude: Double,
        speed: Float
    ): LocationData {
        return LocationData(
            latitude = lat,
            longitude = lon,
            altitude = altitude,
            timestamp = System.currentTimeMillis(),
            speed = speed
        )
    }
}
