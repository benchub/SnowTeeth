package com.snowteeth.app.view

import android.content.Context
import android.graphics.*
import android.util.AttributeSet
import android.view.View
import com.snowteeth.app.model.VelocityBucket
import com.snowteeth.app.model.VisualizationStyle

class VisualizationView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private var currentBucket: VelocityBucket = VelocityBucket.IDLE
    private var visualizationStyle: VisualizationStyle = VisualizationStyle.FLAME
    private var interpolationFactor: Float = 0f

    private val paint = Paint().apply {
        isAntiAlias = true
        style = Paint.Style.FILL
    }

    fun updateVisualization(
        bucket: VelocityBucket,
        style: VisualizationStyle,
        interpFactor: Float = 0f
    ) {
        currentBucket = bucket
        visualizationStyle = style
        interpolationFactor = interpFactor
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        when (visualizationStyle) {
            VisualizationStyle.FLAME -> drawFlameStyle(canvas)
            VisualizationStyle.DATA -> {
                // DATA visualization is handled separately by DataVisualizationView
                // This view is not used for data display
            }
            VisualizationStyle.YETI -> {
                // YETI visualization is handled separately in VisualizationActivity
                // This view is not used for video playback
            }
        }
    }

    private fun drawFlameStyle(canvas: Canvas) {
        val centerX = width / 2f
        val centerY = height / 2f
        val size = minOf(width, height) / 3f

        when (currentBucket) {
            VelocityBucket.IDLE -> {
                // Purple circle
                paint.color = Color.parseColor("#9C27B0")
                canvas.drawCircle(centerX, centerY, size, paint)
            }
            VelocityBucket.DOWNHILL_EASY, VelocityBucket.UPHILL_EASY -> {
                // Green triangle
                paint.color = Color.parseColor("#4CAF50")
                drawTriangle(canvas, centerX, centerY, size)
            }
            VelocityBucket.DOWNHILL_MEDIUM, VelocityBucket.UPHILL_MEDIUM -> {
                // Yellow triangle
                paint.color = Color.parseColor("#FFEB3B")
                drawTriangle(canvas, centerX, centerY, size)
            }
            VelocityBucket.DOWNHILL_HARD, VelocityBucket.UPHILL_HARD -> {
                // Red triangle
                paint.color = Color.parseColor("#F44336")
                drawTriangle(canvas, centerX, centerY, size)
            }
        }
    }

    private fun drawTriangle(canvas: Canvas, centerX: Float, centerY: Float, size: Float) {
        val path = Path().apply {
            moveTo(centerX, centerY - size)
            lineTo(centerX - size, centerY + size)
            lineTo(centerX + size, centerY + size)
            close()
        }
        canvas.drawPath(path, paint)
    }

    private fun drawColorsStyle(canvas: Canvas) {
        val color = when (currentBucket) {
            VelocityBucket.IDLE -> Color.parseColor("#9C27B0") // Purple
            VelocityBucket.DOWNHILL_EASY, VelocityBucket.UPHILL_EASY ->
                Color.parseColor("#4CAF50") // Green
            VelocityBucket.DOWNHILL_MEDIUM, VelocityBucket.UPHILL_MEDIUM ->
                Color.parseColor("#FFEB3B") // Yellow
            VelocityBucket.DOWNHILL_HARD, VelocityBucket.UPHILL_HARD ->
                Color.parseColor("#F44336") // Red
        }

        // Apply interpolation for smooth transitions between colors
        val finalColor = if (interpolationFactor > 0) {
            val nextColor = getNextBucketColor(currentBucket)
            interpolateColor(color, nextColor, interpolationFactor)
        } else {
            color
        }

        paint.color = finalColor
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)
    }

    private fun getNextBucketColor(bucket: VelocityBucket): Int {
        return when (bucket) {
            VelocityBucket.DOWNHILL_EASY, VelocityBucket.UPHILL_EASY ->
                Color.parseColor("#FFEB3B") // Green -> Yellow
            VelocityBucket.DOWNHILL_MEDIUM, VelocityBucket.UPHILL_MEDIUM ->
                Color.parseColor("#F44336") // Yellow -> Red
            else -> Color.parseColor("#9C27B0") // Default to purple
        }
    }

    private fun interpolateColor(startColor: Int, endColor: Int, factor: Float): Int {
        val clampedFactor = factor.coerceIn(0f, 1f)

        val startA = Color.alpha(startColor)
        val startR = Color.red(startColor)
        val startG = Color.green(startColor)
        val startB = Color.blue(startColor)

        val endA = Color.alpha(endColor)
        val endR = Color.red(endColor)
        val endG = Color.green(endColor)
        val endB = Color.blue(endColor)

        val a = (startA + clampedFactor * (endA - startA)).toInt()
        val r = (startR + clampedFactor * (endR - startR)).toInt()
        val g = (startG + clampedFactor * (endG - startG)).toInt()
        val b = (startB + clampedFactor * (endB - startB)).toInt()

        return Color.argb(a, r, g, b)
    }
}
