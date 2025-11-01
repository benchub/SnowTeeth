package com.snowteeth.app.effects

import android.graphics.Path
import android.graphics.PointF
import android.graphics.RectF
import android.util.Log

/**
 * Testable collision detection logic
 * Ported from iOS Swift implementation
 */
class CollisionDetector(private val stickThreshold: Float = 2.0f) {

    data class CollisionTarget(val id: String, val bounds: RectF, val path: Path? = null)

    /**
     * Checks if a snowflake collides with a target rectangle
     * Returns the target ID if collision detected, null otherwise
     */
    fun checkCollision(
        snowflake: Snowflake,
        targets: List<CollisionTarget>
    ): String? {
        if (snowflake.state !is ParticleState.Falling) {
            return null
        }

        val snowBottom = snowflake.position.y + snowflake.size

        // Check targets in order - we want to hit the TOP surface as snow falls
        // Since y increases downward, we check if snow reaches the top edge (top)
        for (target in targets) {
            val bounds = target.bounds

            // Check if snow is approaching from ABOVE and hitting the TOP edge
            if (snowflake.position.y <= bounds.top + stickThreshold &&
                snowBottom >= bounds.top) {
                // Check if horizontally within the target
                if (snowflake.position.x >= bounds.left &&
                    snowflake.position.x <= bounds.right) {

                    // If this is a button (has "button" in ID), only allow snow on the flat part
                    if (target.id.contains("button", ignoreCase = true)) {
                        val cornerRadius = 15f

                        // Only allow collision on the flat middle section
                        // The flat part is from (left + cornerRadius) to (right - cornerRadius)
                        val flatStartX = bounds.left + cornerRadius
                        val flatEndX = bounds.right - cornerRadius

                        // If snow is outside the flat zone, don't collide
                        if (snowflake.position.x < flatStartX || snowflake.position.x > flatEndX) {
                            continue
                        }
                    }

                    Log.d("CollisionDetector", "💥 Collision! Snow at (${snowflake.position.x}, ${snowflake.position.y}) hit TOP of ${target.id} at y=${bounds.top}")
                    return target.id
                }
            }
        }

        return null
    }

    /**
     * Checks if snowflake bottom is clear (not overlapping with anything)
     */
    fun isPositionClear(
        snowflake: Snowflake,
        targets: List<CollisionTarget>
    ): Boolean {
        val snowBottom = snowflake.position.y + snowflake.size

        // Sample 3 points across the bottom of the snowflake
        val testPoints = listOf(
            PointF(snowflake.position.x, snowBottom),
            PointF(snowflake.position.x - snowflake.size/3, snowBottom),
            PointF(snowflake.position.x + snowflake.size/3, snowBottom)
        )

        for (testPoint in testPoints) {
            for (target in targets) {
                val bounds = target.bounds

                if (testPoint.x < bounds.left || testPoint.x > bounds.right) {
                    continue
                }

                if (testPoint.y >= bounds.top && testPoint.y <= bounds.bottom &&
                    testPoint.x >= bounds.left && testPoint.x <= bounds.right) {
                    return false  // Overlapping with rectangle
                }
            }
        }

        return true  // Position is clear
    }

    /**
     * Checks if a snowflake is fully supported at the given position
     * A snowflake is "fully supported" if 100% of sample points have solid support below
     */
    fun isFullySupported(
        snowflake: Snowflake,
        targets: List<CollisionTarget>
    ): Boolean {
        val snowBottom = snowflake.position.y + snowflake.size
        val checkDepth = 1.0f  // Check 1 pixel below

        // Snowflakes are circles, so sample across the circular diameter (not the square)
        // Use 70% of size to approximate the inscribed circle
        val circularWidth = snowflake.size * 0.7f

        // Sample 5 points across the circular footprint
        val samplePoints = 5
        var supportedPoints = 0

        for (i in 0 until samplePoints) {
            val fraction = i.toFloat() / (samplePoints - 1).toFloat()  // 0.0 to 1.0
            val testX = snowflake.position.x - circularWidth/2 + (circularWidth * fraction)
            val testY = snowBottom + checkDepth

            // Check if there's something solid at this point
            for (target in targets) {
                val bounds = target.bounds

                // Quick bounds check
                if (testX < bounds.left || testX > bounds.right) {
                    continue
                }

                // Rectangle-based check
                if (testY >= bounds.top && testY <= bounds.bottom &&
                    testX >= bounds.left && testX <= bounds.right) {
                    supportedPoints++
                    break
                }
            }
        }

        // Need 100% support (5 out of 5 points) for small flakes
        return supportedPoints >= 5
    }

    /**
     * Finds the lowest Y position where snow can rest with full support
     * Used for settling snow to prevent "branching"
     */
    fun findSettledPosition(
        snowflake: Snowflake,
        targets: List<CollisionTarget>,
        maxY: Float
    ): Pair<PointF, String?>? {
        val startY = snowflake.position.y
        val snowX = snowflake.position.x
        val snowSize = snowflake.size

        // Scan downward from current position to find lowest resting spot
        var testY = startY
        val scanStep = 1.0f  // Scan in 1-pixel increments
        var lastClearY = startY
        var lastClearSnowflake = snowflake

        while (testY < maxY) {
            val testSnowflake = Snowflake(
                position = PointF(snowX, testY),
                velocity = snowflake.velocity,
                size = snowSize,
                opacity = snowflake.opacity
            )

            // Check if this position would collide
            if (checkCollision(testSnowflake, targets) != null) {
                // Hit something - use the last clear position and check support
                if (isFullySupported(lastClearSnowflake, targets)) {
                    // Found a good resting spot - find which target is supporting us
                    val supportingTarget = findSupportingTarget(lastClearSnowflake, targets)
                    return Pair(PointF(snowX, lastClearY), supportingTarget)
                } else {
                    // Not well supported - keep falling
                    return null
                }
            }

            // No collision yet, remember this position and keep going
            lastClearY = testY
            lastClearSnowflake = testSnowflake
            testY += scanStep
        }

        // Reached bottom without collision
        return null
    }

    /**
     * Finds which target is directly below and supporting the snowflake
     */
    private fun findSupportingTarget(
        snowflake: Snowflake,
        targets: List<CollisionTarget>
    ): String? {
        val snowBottom = snowflake.position.y + snowflake.size
        val checkPoint = PointF(snowflake.position.x, snowBottom + 2f)

        for (target in targets) {
            val bounds = target.bounds

            if (checkPoint.x < bounds.left || checkPoint.x > bounds.right) {
                continue
            }

            if (checkPoint.y >= bounds.top && checkPoint.y <= bounds.bottom) {
                return target.id
            }
        }

        return null
    }

    /**
     * Calculates the stick position (on top of the target)
     */
    fun calculateStickPosition(
        snowflake: Snowflake,
        targetBounds: RectF
    ): PointF {
        return PointF(
            snowflake.position.x,
            targetBounds.top - snowflake.size
        )
    }
}
