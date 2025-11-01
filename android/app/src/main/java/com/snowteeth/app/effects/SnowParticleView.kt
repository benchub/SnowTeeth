package com.snowteeth.app.effects

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PointF
import android.graphics.RectF
import android.util.AttributeSet
import android.util.Log
import android.view.View
import android.view.WindowManager
import kotlin.math.roundToInt

/**
 * Custom view for rendering snow particles
 * Ported from iOS Swift implementation
 */
class SnowParticleView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private val snowEffect = SnowEffect()
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val letterBoundsCalculator = LetterBoundsCalculator()

    private var isAnimating = false
    private val updateRunnable = object : Runnable {
        override fun run() {
            if (isAnimating) {
                snowEffect.update()
                invalidate()
                postDelayed(this, 16) // ~60 FPS
            }
        }
    }

    init {
        // Transparent background so we can see through to UI below
        setBackgroundColor(Color.TRANSPARENT)
        paint.color = Color.WHITE
        paint.style = Paint.Style.FILL

        // Pass screen density to snow effect for dp-based calculations
        snowEffect.setDensity(resources.displayMetrics.density)
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        startAnimation()

        // Update screen size
        snowEffect.setScreenSize(width.toFloat(), height.toFloat())
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        stopAnimation()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        snowEffect.setScreenSize(w.toFloat(), h.toFloat())

        // Reset stuck snow on size change (rotation)
        if (oldw != 0 && oldh != 0) {
            snowEffect.reset()
        }

        Log.d("SnowParticleView", "📐 Size changed: ${w}x${h}")
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        // Draw fallen snow from all surface height maps
        paint.alpha = 255
        val surfaceMaps = snowEffect.getSurfaceSnowMaps()
        for ((surfaceId, surfaceMap) in surfaceMaps) {
            val heights = surfaceMap.getHeights()
            for ((x, height, baselineY) in heights) {
                val topY = baselineY - height
                // Draw a wider vertical rectangle representing accumulated snow at this x coordinate
                // For ground, draw to bottom of screen; for other surfaces, draw just the height
                val bottomY = if (surfaceId == "ground") this.height.toFloat() else baselineY


                // Draw a 3-pixel wide rectangle instead of 1-pixel line for better visibility
                val stackWidth = 3f
                canvas.drawRect(
                    x - stackWidth / 2f,
                    topY,
                    x + stackWidth / 2f,
                    bottomY,
                    paint
                )
            }
        }

        // Draw all snowflakes
        for (snowflake in snowEffect.getSnowflakes()) {
            val alpha = (snowflake.opacity * 255).roundToInt()
            paint.alpha = alpha

            canvas.drawCircle(
                snowflake.position.x,
                snowflake.position.y,
                snowflake.size / 2f,
                paint
            )
        }
    }

    /**
     * Sets collision targets from UI elements
     * Converts from screen coordinates to view local coordinates
     */
    fun setTargetBounds(bounds: List<CollisionDetector.CollisionTarget>) {
        // Get this view's position on screen to convert coordinates
        val viewLocation = IntArray(2)
        getLocationOnScreen(viewLocation)
        val viewLocationInWindow = IntArray(2)
        getLocationInWindow(viewLocationInWindow)
        val offsetX = viewLocation[0].toFloat()
        val offsetY = viewLocation[1].toFloat()

        android.util.Log.d("SnowParticleView", "🎯 View position on screen: x=$offsetX, y=$offsetY")
        android.util.Log.d("SnowParticleView", "   View position in window: x=${viewLocationInWindow[0]}, y=${viewLocationInWindow[1]}")
        android.util.Log.d("SnowParticleView", "   Converting ${bounds.size} bounds from screen to local coordinates")

        // Convert all bounds from screen coordinates to view local coordinates
        val localBounds = bounds.map { target ->
            val localRect = RectF(
                target.bounds.left - offsetX,
                target.bounds.top - offsetY,
                target.bounds.right - offsetX,
                target.bounds.bottom - offsetY
            )

            // Also translate the path to local coordinates
            val localPath = target.path?.let { screenPath ->
                val translatedPath = android.graphics.Path(screenPath)
                val matrix = android.graphics.Matrix()
                matrix.setTranslate(-offsetX, -offsetY)
                translatedPath.transform(matrix)
                translatedPath
            }

            if (target.id.startsWith("button_") || target.id.startsWith("letter_")) {
                android.util.Log.d("SnowParticleView", "   ${target.id}: screen=${target.bounds} -> local=$localRect")
            }

            CollisionDetector.CollisionTarget(target.id, localRect, localPath)
        }

        snowEffect.setTargetBounds(localBounds)
    }

    /**
     * Resets the snow effect by clearing all snowflakes
     */
    fun reset() {
        snowEffect.reset()
    }

    /**
     * Pauses snow animation to save battery
     */
    fun pause() {
        stopAnimation()
    }

    /**
     * Resumes snow animation
     */
    fun resume() {
        startAnimation()
    }

    /**
     * Captures letter bounds from a title TextView
     */
    fun captureLetterBounds(text: String, textSize: Float, textPosition: PointF) {
        // Create paint with matching text properties
        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        textPaint.textSize = textSize
        textPaint.typeface = android.graphics.Typeface.DEFAULT_BOLD

        val letterBounds = letterBoundsCalculator.calculateBounds(
            text = text,
            paint = textPaint,
            position = textPosition
        )

        Log.d("SnowParticleView", "📝 Captured letter bounds: ${letterBounds.map { "${it.id}: ${it.bounds}" }}")

        // Update snow effect with new bounds
        setTargetBounds(letterBounds)
    }

    /**
     * Captures button bounds
     */
    fun captureButtonBounds(id: String, bounds: RectF) {
        Log.d("SnowParticleView", "🔘 Captured button bounds: $id: $bounds")

        // Get current targets and add/update this button
        val currentTargets = mutableListOf<CollisionDetector.CollisionTarget>()
        // Add this button
        currentTargets.add(CollisionDetector.CollisionTarget(id, bounds))

        setTargetBounds(currentTargets)
    }

    private fun startAnimation() {
        if (!isAnimating) {
            isAnimating = true
            post(updateRunnable)
            Log.d("SnowParticleView", "❄️ Snow animation started")
        }
    }

    private fun stopAnimation() {
        isAnimating = false
        removeCallbacks(updateRunnable)
        Log.d("SnowParticleView", "❄️ Snow animation stopped")
    }
}
