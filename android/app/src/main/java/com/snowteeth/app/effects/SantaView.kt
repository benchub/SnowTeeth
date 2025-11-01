package com.snowteeth.app.effects

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.os.Handler
import android.os.Looper
import android.util.AttributeSet
import android.util.Log
import android.view.View
import com.snowteeth.app.R

/**
 * Santa flying animation view
 */
class SantaView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private var santaX: Float = -150f  // Start off-screen left
    private var santaY: Float = 0f
    private var currentFrame: Int = 0
    private var isFlying: Boolean = false
    private var lastFlyTime: Long = 0L
    private var flyStartTime: Long = 0L
    private var flyingLeftToRight: Boolean = true  // Randomized for each flight

    private val santaFrames: List<Bitmap> = listOf(
        BitmapFactory.decodeResource(resources, R.drawable.santa_1),
        BitmapFactory.decodeResource(resources, R.drawable.santa_2),
        BitmapFactory.decodeResource(resources, R.drawable.santa_3),
        BitmapFactory.decodeResource(resources, R.drawable.santa_4)
    )

    private val handler = Handler(Looper.getMainLooper())
    private val mainRunnable = object : Runnable {
        override fun run() {
            val currentTime = System.currentTimeMillis()

            if (isFlying) {
                // Cycle sprite frames
                currentFrame = (currentFrame + 1) % santaFrames.size

                // Check if Santa is off-screen and enough time has passed
                val isOffScreen = if (flyingLeftToRight) {
                    santaX >= width + 150f
                } else {
                    santaX <= -150f
                }

                if (isOffScreen && (currentTime - flyStartTime) > 8000) {
                    isFlying = false
                }
                invalidate()
            }

            // Trigger flight every 42 seconds
            if (!isFlying && width > 0 && (currentTime - lastFlyTime) >= 42000) {
                startFlying()
            }

            handler.postDelayed(this, 100)  // Run at 10 FPS
        }
    }

    init {
        // Start first flight after a short delay
        handler.postDelayed({
            if (width > 0) {
                startFlying()
            }
        }, 2000)

        // Start main update loop
        handler.postDelayed(mainRunnable, 100)
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        // santaY will be randomized for each flight in startFlying()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        if (isFlying && currentFrame < santaFrames.size) {
            val bitmap = santaFrames[currentFrame]

            // Preserve aspect ratio - scale to height of 50, adjust width proportionally
            val targetHeight = 50f
            val aspectRatio = bitmap.width.toFloat() / bitmap.height.toFloat()
            val santaWidth = targetHeight * aspectRatio
            val santaHeight = targetHeight

            // Scale bitmap to desired size
            var scaledBitmap = Bitmap.createScaledBitmap(
                bitmap,
                santaWidth.toInt(),
                santaHeight.toInt(),
                true
            )

            // Flip bitmap horizontally if flying right-to-left
            if (!flyingLeftToRight) {
                val matrix = android.graphics.Matrix()
                matrix.preScale(-1f, 1f)
                val flippedBitmap = Bitmap.createBitmap(
                    scaledBitmap,
                    0, 0,
                    scaledBitmap.width,
                    scaledBitmap.height,
                    matrix,
                    false
                )
                if (scaledBitmap != bitmap) {
                    scaledBitmap.recycle()
                }
                scaledBitmap = flippedBitmap
            }

            canvas.drawBitmap(scaledBitmap, santaX - santaWidth / 2, santaY - santaHeight / 2, paint)

            if (scaledBitmap != bitmap) {
                scaledBitmap.recycle()
            }
        }
    }

    private fun startFlying() {
        if (isFlying || width <= 0 || height <= 0) return

        lastFlyTime = System.currentTimeMillis()
        flyStartTime = lastFlyTime
        isFlying = true

        // Randomize direction (left-to-right or right-to-left)
        flyingLeftToRight = kotlin.random.Random.nextBoolean()

        // Randomize vertical position
        // In landscape: top/bottom 15% (closer to center to avoid UI elements)
        // In portrait: top/bottom 10% (closer to edges)
        val isLandscape = width > height
        val topPercent = if (isLandscape) 0.15f else 0.05f
        val bottomPercent = if (isLandscape) 0.85f else 0.95f

        santaY = if (kotlin.random.Random.nextBoolean()) {
            height * topPercent  // Top track
        } else {
            height * bottomPercent  // Bottom track
        }

        // Set start and end positions based on direction
        val (startX, targetX) = if (flyingLeftToRight) {
            Pair(-150f, width + 150f)
        } else {
            Pair(width + 150f, -150f)
        }

        santaX = startX
        currentFrame = 0

        // Animate position across screen
        val duration = 8000L  // 8 seconds to cross screen

        val positionAnimationRunnable = object : Runnable {
            override fun run() {
                if (!isFlying) return  // Animation was cancelled

                val elapsed = System.currentTimeMillis() - flyStartTime
                val progress = elapsed.toFloat() / duration.toFloat()

                if (progress < 1.0f) {
                    santaX = startX + (targetX - startX) * progress
                    handler.postDelayed(this, 16)  // ~60 FPS
                } else {
                    // Animation complete - Santa is now off-screen
                    santaX = targetX
                }
            }
        }

        handler.post(positionAnimationRunnable)
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        handler.removeCallbacksAndMessages(null)
    }
}
