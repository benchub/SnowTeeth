package com.snowteeth.app.view

import android.content.Context
import android.content.res.AssetFileDescriptor
import android.media.MediaPlayer
import android.net.Uri
import android.util.AttributeSet
import android.view.SurfaceHolder
import android.view.SurfaceView
import com.snowteeth.app.model.VelocityBucket
import java.io.IOException

/**
 * Yeti Visualization View using state machine and video transitions
 */
class YetiVisualizationView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : SurfaceView(context, attrs), SurfaceHolder.Callback {

    private var mediaPlayer: MediaPlayer? = null
    private var nextMediaPlayer: MediaPlayer? = null
    private var currentState: Int = 0
    private var currentBucket: VelocityBucket = VelocityBucket.IDLE
    private var surfaceReady = false
    private var hasQueuedNext = false
    private val progressCheckRunnable = object : Runnable {
        override fun run() {
            checkQueueStatus()
            // Check again in 500ms
            handler.postDelayed(this, 500)
        }
    }
    private val handler = android.os.Handler(android.os.Looper.getMainLooper())

    // Bucket to state mapping (from shared/constants/yeti_state_mapping.json)
    private val bucketToState = mapOf(
        VelocityBucket.IDLE to 0,
        VelocityBucket.DOWNHILL_EASY to 1,
        VelocityBucket.UPHILL_EASY to 1,
        VelocityBucket.DOWNHILL_MEDIUM to 2,
        VelocityBucket.UPHILL_MEDIUM to 2,
        VelocityBucket.DOWNHILL_HARD to 3,
        VelocityBucket.UPHILL_HARD to 3
    )

    // Video variants for same-state loops with weights
    // (from shared/constants/yeti_video_weights.json)
    private val sameStateVariants = mapOf(
        "0 to 0" to listOf(
            VideoVariant("0 to 0 a", 2.0f),
            VideoVariant("0 to 0 b", 1.0f),
            VideoVariant("0 to 0 c", 1.5f),
            VideoVariant("0 to 0 d", 5.0f),
            VideoVariant("0 to 0 e", 3.0f),
            VideoVariant("0 to 0 f", 2.0f),
            VideoVariant("0 to 0 g", 3.0f),
            VideoVariant("0 to 0 h", 2.0f),
            VideoVariant("0 to 0 i", 2.0f)
        ),
        "1 to 1" to listOf(
            VideoVariant("1 to 1 a", 1.0f),
            VideoVariant("1 to 1 b", 1.0f),
            VideoVariant("1 to 1 c", 1.0f),
            VideoVariant("1 to 1 d", 3.0f),
            VideoVariant("1 to 1 e", 3.0f)
        ),
        "2 to 2" to listOf(
            VideoVariant("2 to 2 a", 1.0f),
            VideoVariant("2 to 2 b", 1.0f),
            VideoVariant("2 to 2 c", 1.0f),
            VideoVariant("2 to 2 e", 5.0f),
            VideoVariant("2 to 2 f", 1.0f),
            VideoVariant("2 to 2 g", 1.0f)
        ),
        "3 to 3" to listOf(
            VideoVariant("3 to 3 a", 2.0f),
            VideoVariant("3 to 3 b", 1.0f),
            VideoVariant("3 to 3 c", 1.0f),
            VideoVariant("3 to 3 d", 2.0f)
        )
    )

    private data class VideoVariant(val name: String, val weight: Float)

    init {
        holder.addCallback(this)
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        surfaceReady = true
        // Start with idle state
        playTransitionVideo(0, 0)
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        // Handle surface changes if needed
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        surfaceReady = false
        handler.removeCallbacks(progressCheckRunnable)
        releaseMediaPlayer()
        releaseNextMediaPlayer()
    }

    fun updateBucket(bucket: VelocityBucket) {
        currentBucket = bucket
    }

    private fun getTargetState(bucket: VelocityBucket): Int {
        return bucketToState[bucket] ?: 0
    }

    private fun getNextState(): Int {
        val targetState = getTargetState(currentBucket)

        // Gradual transitions - move one state at a time
        return when {
            targetState > currentState -> currentState + 1
            targetState < currentState -> currentState - 1
            else -> currentState
        }
    }

    private fun getVideoFilename(from: Int, to: Int): String? {
        return if (from == to) {
            // Same state - pick weighted random variant
            val key = "$from to $to"
            val variants = sameStateVariants[key]
            if (variants.isNullOrEmpty()) {
                android.util.Log.w("YetiView", "No variants found for $key")
                null
            } else {
                weightedRandomSelection(variants)
            }
        } else {
            // State transition
            "$from to $to"
        }
    }

    // Weighted random selection algorithm
    private fun weightedRandomSelection(variants: List<VideoVariant>): String {
        val totalWeight = variants.sumOf { it.weight.toDouble() }.toFloat()
        var random = (Math.random() * totalWeight).toFloat()

        for (variant in variants) {
            random -= variant.weight
            if (random < 0) {
                return variant.name
            }
        }

        // Fallback (should never happen)
        return variants.first().name
    }

    private fun checkQueueStatus() {
        val player = mediaPlayer ?: return
        if (hasQueuedNext) return

        try {
            val currentPosition = player.currentPosition
            val duration = player.duration

            // If we're past 70% of the video and haven't queued the next one yet, queue it now
            if (duration > 0 && currentPosition.toFloat() / duration.toFloat() > 0.7f) {
                prepareNextVideo()
            }
        } catch (e: Exception) {
            // Player might not be ready yet, ignore
        }
    }

    private fun prepareNextVideo() {
        if (hasQueuedNext) return

        val nextState = getNextState()
        val videoFilename = getVideoFilename(currentState, nextState)

        if (videoFilename == null) {
            android.util.Log.w("YetiView", "No video found for next transition")
            return
        }

        try {
            releaseNextMediaPlayer()

            nextMediaPlayer = MediaPlayer().apply {
                // Load video from assets
                val afd: AssetFileDescriptor = context.assets.openFd("videos/$videoFilename.mp4")
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()

                // Prepare asynchronously to avoid blocking
                setOnPreparedListener {
                    com.snowteeth.app.util.DebugLog.d("YetiView", "Next video prepared: $videoFilename")
                }

                setOnErrorListener { _, what, extra ->
                    android.util.Log.e("YetiView", "Next MediaPlayer error: what=$what, extra=$extra")
                    true
                }

                prepareAsync()
            }

            hasQueuedNext = true
            com.snowteeth.app.util.DebugLog.d("YetiView", "Queued next video: $videoFilename")

        } catch (e: IOException) {
            android.util.Log.e("YetiView", "Error preparing next video: $videoFilename", e)
        }
    }

    private fun playTransitionVideo(from: Int, to: Int) {
        if (!surfaceReady) return

        val videoFilename = getVideoFilename(from, to)
        if (videoFilename == null) {
            android.util.Log.e("YetiView", "No video found for transition $from to $to")
            return
        }

        try {
            // If we have a prepared next video, use it for seamless playback
            if (nextMediaPlayer != null && hasQueuedNext) {
                releaseMediaPlayer()
                mediaPlayer = nextMediaPlayer
                nextMediaPlayer = null
                hasQueuedNext = false

                mediaPlayer?.apply {
                    setDisplay(holder)

                    setOnCompletionListener {
                        handleVideoEnd()
                    }

                    setOnErrorListener { _, what, extra ->
                        android.util.Log.e("YetiView", "MediaPlayer error: what=$what, extra=$extra")
                        true
                    }

                    start()
                }

                currentState = to

                // Start checking for next video queue point
                handler.post(progressCheckRunnable)

            } else {
                // Fallback: load and play immediately (may have brief black frame)
                releaseMediaPlayer()

                mediaPlayer = MediaPlayer().apply {
                    setDisplay(holder)

                    // Load video from assets
                    val afd: AssetFileDescriptor = context.assets.openFd("videos/$videoFilename.mp4")
                    setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    afd.close()

                    setOnPreparedListener { mp ->
                        mp.start()
                    }

                    setOnCompletionListener {
                        handleVideoEnd()
                    }

                    setOnErrorListener { _, what, extra ->
                        android.util.Log.e("YetiView", "MediaPlayer error: what=$what, extra=$extra")
                        true
                    }

                    prepareAsync()
                }

                currentState = to
                hasQueuedNext = false

                // Start checking for next video queue point
                handler.post(progressCheckRunnable)
            }

        } catch (e: IOException) {
            android.util.Log.e("YetiView", "Error loading video: $videoFilename", e)
        }
    }

    private fun handleVideoEnd() {
        handler.removeCallbacks(progressCheckRunnable)

        // Determine next state
        val nextState = getNextState()

        // Play transition video
        playTransitionVideo(currentState, nextState)
    }

    private fun releaseMediaPlayer() {
        mediaPlayer?.apply {
            if (isPlaying) {
                stop()
            }
            reset()
            release()
        }
        mediaPlayer = null
    }

    private fun releaseNextMediaPlayer() {
        nextMediaPlayer?.apply {
            reset()
            release()
        }
        nextMediaPlayer = null
        hasQueuedNext = false
    }

    fun cleanup() {
        handler.removeCallbacks(progressCheckRunnable)
        releaseMediaPlayer()
        releaseNextMediaPlayer()
    }
}
