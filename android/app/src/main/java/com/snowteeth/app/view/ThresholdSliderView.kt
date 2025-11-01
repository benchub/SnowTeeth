package com.snowteeth.app.view

import android.content.Context
import android.graphics.*
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

class ThresholdSliderView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    init {
        // Enable hardware layer for shadow rendering
        setLayerType(LAYER_TYPE_SOFTWARE, null)
    }

    // Threshold values
    var easyThreshold: Float = 2.0f
        set(value) {
            field = value
            invalidate()
        }

    var mediumThreshold: Float = 6.0f
        set(value) {
            field = value
            invalidate()
        }

    var hardThreshold: Float = 10.0f
        set(value) {
            field = value
            invalidate()
        }

    var minValue: Float = 0.5f
    var maxValue: Float = 30.0f

    // Callback for threshold changes
    var onThresholdsChanged: ((easy: Float, medium: Float, hard: Float) -> Unit)? = null

    // Colors
    private val idleColor = Color.parseColor("#33999999")
    private val easyColor = Color.parseColor("#4CAF50")
    private val mediumColor = Color.parseColor("#FFEB3B")
    private val hardColor = Color.parseColor("#F44336")
    private val handleStrokeColor = Color.WHITE

    // Paints
    private val barPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val handlePaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val handleShadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        // Shadow layer for depth
        setShadowLayer(8f, 0f, 4f, Color.argb(60, 0, 0, 0))
    }
    private val handleStrokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 8f  // Thicker white border for polish
        color = handleStrokeColor
    }
    private val handleOuterBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 1f
        color = Color.parseColor("#808080")  // Dark grey outer edge
    }
    private val handleInnerBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 1f
        color = Color.parseColor("#808080")  // Dark grey inner edge
    }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textSize = 28f
        color = Color.BLACK
    }
    private val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG)

    // Dimensions
    private val barHeight = 100f
    private val handleRadius = 36f
    private val padding = 50f
    private val topPadding = 80f

    // Touch handling
    private var draggingHandle: Handle? = null
    private enum class Handle { EASY, MEDIUM, HARD }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val desiredHeight = (topPadding + barHeight + padding + 80f).toInt()
        val height = resolveSize(desiredHeight, heightMeasureSpec)
        setMeasuredDimension(widthMeasureSpec, height)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        val width = width.toFloat() - 2 * padding
        val range = maxValue - minValue

        // Calculate positions
        val easyPos = padding + (easyThreshold - minValue) / range * width
        val mediumPos = padding + (mediumThreshold - minValue) / range * width
        val hardPos = padding + (hardThreshold - minValue) / range * width

        val barTop = topPadding
        val barBottom = barTop + barHeight
        val cornerRadius = 12f  // Rounded corners for polish

        // Draw idle section (gray) - rounded on LEFT side only
        barPaint.color = idleColor
        val greyPath = Path().apply {
            moveTo(easyPos, barTop)
            lineTo(padding + cornerRadius, barTop)
            arcTo(padding, barTop, padding + 2 * cornerRadius, barTop + 2 * cornerRadius, 270f, -90f, false)
            lineTo(padding, barBottom - cornerRadius)
            arcTo(padding, barBottom - 2 * cornerRadius, padding + 2 * cornerRadius, barBottom, 180f, -90f, false)
            lineTo(easyPos, barBottom)
            close()
        }
        canvas.drawPath(greyPath, barPaint)

        // Draw easy section (green) - no rounding
        barPaint.color = easyColor
        canvas.drawRect(
            easyPos,
            barTop,
            mediumPos,
            barBottom,
            barPaint
        )

        // Draw medium section (yellow) - no rounding
        barPaint.color = mediumColor
        canvas.drawRect(
            mediumPos,
            barTop,
            hardPos,
            barBottom,
            barPaint
        )

        // Draw hard section (red) - rounded on RIGHT side only
        barPaint.color = hardColor
        val redPath = Path().apply {
            moveTo(hardPos, barTop)
            lineTo(padding + width - cornerRadius, barTop)
            arcTo(padding + width - 2 * cornerRadius, barTop, padding + width, barTop + 2 * cornerRadius, 270f, 90f, false)
            lineTo(padding + width, barBottom - cornerRadius)
            arcTo(padding + width - 2 * cornerRadius, barBottom - 2 * cornerRadius, padding + width, barBottom, 0f, 90f, false)
            lineTo(hardPos, barBottom)
            close()
        }
        canvas.drawPath(redPath, barPaint)

        // Draw bar outline with rounded corners
        barPaint.style = Paint.Style.STROKE
        barPaint.strokeWidth = 2f
        barPaint.color = Color.GRAY
        canvas.drawRoundRect(
            padding,
            barTop,
            padding + width,
            barBottom,
            cornerRadius,
            cornerRadius,
            barPaint
        )
        barPaint.style = Paint.Style.FILL

        // Draw labels above the bar
        val labelY = barTop - 20f
        val dotRadius = 8f
        val dotTextGap = 6f

        // Easy label with green dot
        textPaint.color = Color.BLACK
        var text = String.format("Easy: %.1f", easyThreshold)
        val easyDotX = padding
        val easyDotY = labelY - textPaint.textSize / 3
        dotPaint.color = Color.parseColor("#4CAF50")
        canvas.drawCircle(easyDotX, easyDotY, dotRadius, dotPaint)
        canvas.drawText(text, easyDotX + dotRadius + dotTextGap, labelY, textPaint)

        // Medium label with yellow dot (centered at colon)
        textPaint.color = Color.BLACK
        val medLabelPart = "Med:"
        val medLabelWidth = textPaint.measureText(medLabelPart)
        val medNumberPart = String.format(" %.1f", mediumThreshold)
        val centerX = padding + width / 2

        // Position dot and label so colon is centered, number grows to the right
        val medDotX = centerX - medLabelWidth - dotRadius - dotTextGap
        val medDotY = labelY - textPaint.textSize / 3
        dotPaint.color = Color.parseColor("#FFEB3B")
        canvas.drawCircle(medDotX, medDotY, dotRadius, dotPaint)
        canvas.drawText(medLabelPart, medDotX + dotRadius + dotTextGap, labelY, textPaint)
        canvas.drawText(medNumberPart, centerX, labelY, textPaint)

        // Hard label with red dot (anchored at colon from right edge)
        textPaint.color = Color.BLACK
        val hardLabelPart = "Hard:"
        val hardLabelWidth = textPaint.measureText(hardLabelPart)
        val hardNumberPart = String.format(" %.1f", hardThreshold)

        // Reserve space for max number width (e.g., " 99.9") from right edge
        val maxNumberSpace = 70f
        val hardColonX = padding + width - maxNumberSpace
        val hardDotX = hardColonX - hardLabelWidth - dotRadius - dotTextGap
        val hardDotY = labelY - textPaint.textSize / 3
        dotPaint.color = Color.parseColor("#F44336")
        canvas.drawCircle(hardDotX, hardDotY, dotRadius, dotPaint)
        canvas.drawText(hardLabelPart, hardDotX + dotRadius + dotTextGap, labelY, textPaint)
        canvas.drawText(hardNumberPart, hardColonX, labelY, textPaint)

        // Draw handles with shadows and borders
        val handleY = barTop + barHeight / 2
        val whiteStrokeHalf = handleStrokePaint.strokeWidth / 2

        // Easy handle (green) - shadow, fill, white border, then grey borders
        handleShadowPaint.color = Color.parseColor("#4CAF50")
        canvas.drawCircle(easyPos, handleY, handleRadius, handleShadowPaint)
        handlePaint.color = Color.parseColor("#4CAF50")
        canvas.drawCircle(easyPos, handleY, handleRadius, handlePaint)
        canvas.drawCircle(easyPos, handleY, handleRadius, handleStrokePaint)
        // Dark grey outer edge of white ring
        canvas.drawCircle(easyPos, handleY, handleRadius + whiteStrokeHalf, handleOuterBorderPaint)
        // Dark grey inner edge of white ring
        canvas.drawCircle(easyPos, handleY, handleRadius - whiteStrokeHalf, handleInnerBorderPaint)

        // Medium handle (yellow) - shadow, fill, white border, then grey borders
        handleShadowPaint.color = Color.parseColor("#FFEB3B")
        canvas.drawCircle(mediumPos, handleY, handleRadius, handleShadowPaint)
        handlePaint.color = Color.parseColor("#FFEB3B")
        canvas.drawCircle(mediumPos, handleY, handleRadius, handlePaint)
        canvas.drawCircle(mediumPos, handleY, handleRadius, handleStrokePaint)
        // Dark grey outer edge of white ring
        canvas.drawCircle(mediumPos, handleY, handleRadius + whiteStrokeHalf, handleOuterBorderPaint)
        // Dark grey inner edge of white ring
        canvas.drawCircle(mediumPos, handleY, handleRadius - whiteStrokeHalf, handleInnerBorderPaint)

        // Hard handle (red) - shadow, fill, white border, then grey borders
        handleShadowPaint.color = Color.parseColor("#F44336")
        canvas.drawCircle(hardPos, handleY, handleRadius, handleShadowPaint)
        handlePaint.color = Color.parseColor("#F44336")
        canvas.drawCircle(hardPos, handleY, handleRadius, handlePaint)
        canvas.drawCircle(hardPos, handleY, handleRadius, handleStrokePaint)
        // Dark grey outer edge of white ring
        canvas.drawCircle(hardPos, handleY, handleRadius + whiteStrokeHalf, handleOuterBorderPaint)
        // Dark grey inner edge of white ring
        canvas.drawCircle(hardPos, handleY, handleRadius - whiteStrokeHalf, handleInnerBorderPaint)

        // Draw min/max labels below the bar
        textPaint.color = Color.GRAY
        textPaint.textSize = 28f
        canvas.drawText(String.format("%.1f", minValue), padding, barBottom + 50f, textPaint)

        text = String.format("%.1f", maxValue)
        val maxLabelX = padding + width - textPaint.measureText(text)
        canvas.drawText(text, maxLabelX, barBottom + 50f, textPaint)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val width = width.toFloat() - 2 * padding
        val range = maxValue - minValue
        val minGap = 0.5f

        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                val x = event.x
                val y = event.y

                val handleY = topPadding + barHeight / 2
                val easyPos = padding + (easyThreshold - minValue) / range * width
                val mediumPos = padding + (mediumThreshold - minValue) / range * width
                val hardPos = padding + (hardThreshold - minValue) / range * width

                // Check which handle was touched
                draggingHandle = when {
                    abs(x - easyPos) < handleRadius * 1.5f && abs(y - handleY) < handleRadius * 1.5f -> Handle.EASY
                    abs(x - mediumPos) < handleRadius * 1.5f && abs(y - handleY) < handleRadius * 1.5f -> Handle.MEDIUM
                    abs(x - hardPos) < handleRadius * 1.5f && abs(y - handleY) < handleRadius * 1.5f -> Handle.HARD
                    else -> null
                }
                return draggingHandle != null
            }

            MotionEvent.ACTION_MOVE -> {
                if (draggingHandle != null) {
                    val x = max(padding, min(event.x, padding + width))
                    val newValue = ((x - padding) / width * range + minValue)
                    val rounded = (newValue * 2).roundToInt() / 2f

                    when (draggingHandle) {
                        Handle.EASY -> {
                            easyThreshold = max(minValue, min(rounded, mediumThreshold - minGap))
                        }
                        Handle.MEDIUM -> {
                            mediumThreshold = max(easyThreshold + minGap, min(rounded, hardThreshold - minGap))
                        }
                        Handle.HARD -> {
                            hardThreshold = max(mediumThreshold + minGap, min(rounded, maxValue))
                        }
                        null -> {}
                    }

                    onThresholdsChanged?.invoke(easyThreshold, mediumThreshold, hardThreshold)
                    invalidate()
                    return true
                }
            }

            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                draggingHandle = null
                return true
            }
        }

        return super.onTouchEvent(event)
    }
}
