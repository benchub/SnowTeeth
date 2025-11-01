package com.snowteeth.app

import android.content.Context
import com.snowteeth.app.model.LocationData
import com.snowteeth.app.util.GpxWriter
import org.junit.Before
import org.junit.Test
import org.junit.Assert.*
import org.mockito.Mockito.*
import java.io.File

class GpxWriterTest {

    private lateinit var mockContext: Context
    private lateinit var testDir: File

    @Before
    fun setup() {
        mockContext = mock(Context::class.java)
        testDir = File.createTempFile("test", "dir").parentFile
        whenever(mockContext.getExternalFilesDir(null)).thenReturn(testDir)
    }

    @Test
    fun testStartNewTrack_CreatesFile() {
        val gpxWriter = GpxWriter(mockContext)
        gpxWriter.startNewTrack()

        val gpxFile = gpxWriter.getGpxFile()
        assertTrue(gpxFile.exists())

        val content = gpxFile.readText()
        assertTrue(content.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        assertTrue(content.contains("<gpx"))
        assertTrue(content.contains("<trk>"))
        assertTrue(content.contains("<trkseg>"))

        // Cleanup
        gpxFile.delete()
    }

    @Test
    fun testAppendPoint_AddsLocationToFile() {
        val gpxWriter = GpxWriter(mockContext)
        gpxWriter.startNewTrack()

        val location = LocationData(
            latitude = 37.7749,
            longitude = -122.4194,
            altitude = 10.0,
            timestamp = System.currentTimeMillis(),
            speed = 5.0f
        )

        gpxWriter.appendPoint(location)

        val gpxFile = gpxWriter.getGpxFile()
        val content = gpxFile.readText()

        assertTrue(content.contains("lat=\"37.7749\""))
        assertTrue(content.contains("lon=\"-122.4194\""))
        assertTrue(content.contains("<ele>10.0</ele>"))
        assertTrue(content.contains("</trkseg>"))
        assertTrue(content.contains("</trk>"))
        assertTrue(content.contains("</gpx>"))

        // Cleanup
        gpxFile.delete()
    }

    @Test
    fun testAppendMultiplePoints() {
        val gpxWriter = GpxWriter(mockContext)
        gpxWriter.startNewTrack()

        val location1 = LocationData(37.7749, -122.4194, 10.0, System.currentTimeMillis(), 5.0f)
        val location2 = LocationData(37.7750, -122.4195, 15.0, System.currentTimeMillis(), 6.0f)
        val location3 = LocationData(37.7751, -122.4196, 20.0, System.currentTimeMillis(), 7.0f)

        gpxWriter.appendPoint(location1)
        gpxWriter.appendPoint(location2)
        gpxWriter.appendPoint(location3)

        val gpxFile = gpxWriter.getGpxFile()
        val content = gpxFile.readText()

        // Check all three points are in the file
        assertTrue(content.contains("lat=\"37.7749\""))
        assertTrue(content.contains("lat=\"37.7750\""))
        assertTrue(content.contains("lat=\"37.7751\""))

        // File should still be properly closed
        assertTrue(content.contains("</gpx>"))

        // Cleanup
        gpxFile.delete()
    }

    @Test
    fun testHasTrack_ReturnsFalseWhenNoFile() {
        val gpxWriter = GpxWriter(mockContext)
        assertFalse(gpxWriter.hasTrack())
    }

    @Test
    fun testHasTrack_ReturnsTrueWhenFileExists() {
        val gpxWriter = GpxWriter(mockContext)
        gpxWriter.startNewTrack()
        assertTrue(gpxWriter.hasTrack())

        // Cleanup
        gpxWriter.getGpxFile().delete()
    }
}
