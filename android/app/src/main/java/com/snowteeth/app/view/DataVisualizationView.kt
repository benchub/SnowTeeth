package com.snowteeth.app.view

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import android.util.Log
import android.view.View
import android.view.animation.LinearInterpolator

/**
 * Data visualization view with animated character morphing
 * Shows velocity, location, altitude, and satellite count
 */
class DataVisualizationView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : View(context, attrs) {

    companion object {
        private const val TAG = "DataVisualizationView"
        private const val UPDATE_THROTTLE_MS = 2000L // Only update display every 2 seconds
    }

    // Display data
    private var velocity: String = "0.0"
    private var velocityUnit: String = "miles per hour"
    private var direction: String = ""
    private var latitude: String = "Latitude: --"
    private var longitude: String = "Longitude: --"
    private var altitude: String = "Altitude:   -- ft"
    private var accuracy: String = "Accuracy:   -- ft"
    private var satellites: String = "Satellites: --"

    // Character morphing state for each field
    private val velocityMorphing = mutableMapOf<Int, MorphState>()
    private val latitudeMorphing = mutableMapOf<Int, MorphState>()
    private val longitudeMorphing = mutableMapOf<Int, MorphState>()
    private val altitudeMorphing = mutableMapOf<Int, MorphState>()
    private val accuracyMorphing = mutableMapOf<Int, MorphState>()
    private val satellitesMorphing = mutableMapOf<Int, MorphState>()
    private var morphAnimator: ValueAnimator? = null

    // Throttling
    private var lastUpdateTime: Long = 0

    // Paint objects
    private val velocityPaint = Paint().apply {
        color = Color.WHITE
        isAntiAlias = true
        textAlign = Paint.Align.CENTER
        typeface = android.graphics.Typeface.create(android.graphics.Typeface.DEFAULT, android.graphics.Typeface.BOLD)
        // Use tabular numbers (tnum) to make digits monospaced while keeping punctuation proportional
        fontFeatureSettings = "tnum"
    }

    private val unitPaint = Paint().apply {
        color = Color.parseColor("#B0B0B0")
        isAntiAlias = true
        textAlign = Paint.Align.CENTER
    }

    private val infoPaint = Paint().apply {
        color = Color.parseColor("#B0B0B0")
        isAntiAlias = true
        // Use default proportional font for better fit
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        // Draw black background
        canvas.drawColor(Color.BLACK)

        val width = width.toFloat()
        val height = height.toFloat()

        // Calculate sizes
        val velocitySize = height * 0.15f  // Reduced to ensure triple digits fit with padding
        val unitSize = height * 0.03f
        val infoSize = height * 0.04f
        val lineSpacing = infoSize * 1.5f

        // Set paint sizes
        velocityPaint.textSize = velocitySize
        unitPaint.textSize = unitSize
        infoPaint.textSize = infoSize

        // Draw velocity in top half (monospace keeps decimal aligned)
        val velocityY = height * 0.22f
        drawMorphingText(canvas, velocity, width / 2f, velocityY, velocityPaint, velocityMorphing)

        // Draw unit label below velocity
        val unitY = velocityY + velocitySize * 0.7f
        canvas.drawText(velocityUnit, width / 2f, unitY, unitPaint)

        // Draw direction label below unit if available
        if (direction.isNotEmpty()) {
            val directionY = unitY + unitSize * 1.5f
            canvas.drawText(direction, width / 2f, directionY, unitPaint)
        }

        // Draw GPS info in bottom half (left-aligned) with morphing
        val leftPadding = width * 0.05f
        val bottomHalfStart = height * 0.5f + height * 0.05f

        drawMorphingTextLeftAlign(canvas, latitude, leftPadding, bottomHalfStart, infoPaint, latitudeMorphing)
        drawMorphingTextLeftAlign(canvas, longitude, leftPadding, bottomHalfStart + lineSpacing, infoPaint, longitudeMorphing)
        drawMorphingTextLeftAlign(canvas, altitude, leftPadding, bottomHalfStart + lineSpacing * 2f, infoPaint, altitudeMorphing)
        drawMorphingTextLeftAlign(canvas, accuracy, leftPadding, bottomHalfStart + lineSpacing * 3f, infoPaint, accuracyMorphing)
        drawMorphingTextLeftAlign(canvas, satellites, leftPadding, bottomHalfStart + lineSpacing * 4f, infoPaint, satellitesMorphing)
    }

    private fun drawMorphingTextLeftAlign(canvas: Canvas, text: String, x: Float, y: Float, paint: Paint, morphing: Map<Int, MorphState>) {
        val characters = text.toCharArray()
        var currentX = x

        for (i in characters.indices) {
            val char = if (morphing.containsKey(i)) {
                getMorphedCharacter(i, morphing)
            } else {
                characters[i]
            }

            val scaleX = if (morphing.containsKey(i)) {
                getMorphScale(i, morphing)
            } else {
                1.0f
            }

            val charWidth = paint.measureText(char.toString())

            // Apply horizontal scaling
            canvas.save()
            canvas.scale(scaleX, 1f, currentX + charWidth / 2f, y)
            canvas.drawText(char.toString(), currentX, y, paint)
            canvas.restore()

            currentX += charWidth
        }
    }

    private fun drawMorphingText(canvas: Canvas, text: String, centerX: Float, centerY: Float, paint: Paint, morphing: Map<Int, MorphState>) {
        val characters = text.toCharArray()

        // Measure total width for centering
        val charWidths = FloatArray(characters.size)
        var totalWidth = 0f
        for (i in characters.indices) {
            val char = if (morphing.containsKey(i)) {
                getMorphedCharacter(i, morphing)
            } else {
                characters[i]
            }
            charWidths[i] = paint.measureText(char.toString())
            totalWidth += charWidths[i]
        }

        // Draw each character
        var currentX = centerX - totalWidth / 2f
        for (i in characters.indices) {
            val char = if (morphing.containsKey(i)) {
                getMorphedCharacter(i, morphing)
            } else {
                characters[i]
            }

            val scaleX = if (morphing.containsKey(i)) {
                getMorphScale(i, morphing)
            } else {
                1.0f
            }

            // Apply horizontal scaling
            canvas.save()
            canvas.scale(scaleX, 1f, currentX + charWidths[i] / 2f, centerY)
            canvas.drawText(char.toString(), currentX + charWidths[i] / 2f, centerY, paint)
            canvas.restore()

            currentX += charWidths[i]
        }
    }

    private fun getMorphedCharacter(index: Int, morphing: Map<Int, MorphState>): Char {
        val state = morphing[index] ?: return ' '
        val progress = state.progress

        // Show old char in first half, new char in second half
        // The horizontal scaling creates the morph effect
        return if (progress < 0.5) {
            state.oldChar
        } else {
            state.newChar
        }
    }

    private fun getMorphScale(index: Int, morphing: Map<Int, MorphState>): Float {
        val state = morphing[index] ?: return 1.0f
        val progress = state.progress

        return when {
            progress < 0.5 -> 1.0f - (progress / 0.5f * 0.8f) // Compress to 20%
            else -> 0.2f + ((progress - 0.5f) / 0.5f * 0.8f) // Expand to 100%
        }
    }

    fun updateData(velocity: String, latitude: String, longitude: String, altitude: String, accuracy: String, satellites: String, velocityUnit: String, direction: String = "") {
        // Throttle updates to allow animations to complete smoothly
        val currentTime = System.currentTimeMillis()
        if (currentTime - lastUpdateTime < UPDATE_THROTTLE_MS) {
            return // Skip this update
        }
        lastUpdateTime = currentTime

        // Trigger morphing animations for all changed fields
        val hasChanges = velocity != this.velocity ||
                        latitude != this.latitude ||
                        longitude != this.longitude ||
                        altitude != this.altitude ||
                        accuracy != this.accuracy ||
                        satellites != this.satellites ||
                        direction != this.direction

        if (hasChanges) {
            if (velocity != this.velocity) {
                startMorphAnimation(this.velocity, velocity, velocityMorphing)
            }
            if (latitude != this.latitude) {
                startMorphAnimation(this.latitude, latitude, latitudeMorphing)
            }
            if (longitude != this.longitude) {
                startMorphAnimation(this.longitude, longitude, longitudeMorphing)
            }
            if (altitude != this.altitude) {
                startMorphAnimation(this.altitude, altitude, altitudeMorphing)
            }
            if (accuracy != this.accuracy) {
                startMorphAnimation(this.accuracy, accuracy, accuracyMorphing)
            }
            if (satellites != this.satellites) {
                startMorphAnimation(this.satellites, satellites, satellitesMorphing)
            }
        }

        this.velocity = velocity
        this.velocityUnit = velocityUnit
        this.direction = direction
        this.latitude = latitude
        this.longitude = longitude
        this.altitude = altitude
        this.accuracy = accuracy
        this.satellites = satellites

        invalidate()
    }

    private fun startMorphAnimation(oldText: String, newText: String, morphingMap: MutableMap<Int, MorphState>) {
        // Clear old morphing states for this field
        morphingMap.clear()

        // Find changed characters
        val maxLength = maxOf(oldText.length, newText.length)
        for (i in 0 until maxLength) {
            val oldChar = if (i < oldText.length) oldText[i] else ' '
            val newChar = if (i < newText.length) newText[i] else ' '

            if (oldChar != newChar) {
                morphingMap[i] = MorphState(oldChar, newChar, 0f)
            }
        }

        // Cancel and restart animation if needed
        morphAnimator?.cancel()

        // Animate over 1 second
        morphAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 1000
            interpolator = LinearInterpolator()
            addUpdateListener { animation ->
                val progress = animation.animatedValue as Float
                // Update all morphing maps
                velocityMorphing.keys.forEach { index ->
                    velocityMorphing[index]?.progress = progress
                }
                latitudeMorphing.keys.forEach { index ->
                    latitudeMorphing[index]?.progress = progress
                }
                longitudeMorphing.keys.forEach { index ->
                    longitudeMorphing[index]?.progress = progress
                }
                altitudeMorphing.keys.forEach { index ->
                    altitudeMorphing[index]?.progress = progress
                }
                accuracyMorphing.keys.forEach { index ->
                    accuracyMorphing[index]?.progress = progress
                }
                satellitesMorphing.keys.forEach { index ->
                    satellitesMorphing[index]?.progress = progress
                }
                invalidate()
            }
            start()
        }

        // Clean up after animation
        postDelayed({
            velocityMorphing.clear()
            latitudeMorphing.clear()
            longitudeMorphing.clear()
            altitudeMorphing.clear()
            accuracyMorphing.clear()
            satellitesMorphing.clear()
            invalidate()
        }, 1000)
    }

    private data class MorphState(
        val oldChar: Char,
        val newChar: Char,
        var progress: Float
    )

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        morphAnimator?.cancel()
    }
}
