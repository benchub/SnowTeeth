package com.snowteeth.app.effects

import android.graphics.Path
import android.graphics.PointF
import android.graphics.RectF
import android.graphics.Region
import kotlin.math.pow
import kotlin.random.Random

/**
 * Height-map based fallen snow tracking (inspired by xsnow)
 * Much more efficient than tracking individual stuck particles
 * Each X coordinate has its own baseline Y that follows the surface contour
 */
class FallenSnow(
    private var width: Int,
    private val bounds: RectF,
    private val path: Path?,
    private var offsetX: Float = 0f,
    private val density: Float = 1f,  // Screen density for dp conversion
    isGround: Boolean = false
) {
    private var heights: FloatArray = FloatArray(width) { 0f }
    private var baselineYs: FloatArray = FloatArray(width) { 0f }
    // Ground can stack 3x higher than other surfaces
    private val comfortableHeight: Float = if (isGround) 15f else 5f  // Height below which stacking is always allowed
    private val maxHeight: Float = if (isGround) 45f else 15f  // Absolute maximum snow accumulation height

    // Surface offset in dp (converted to pixels based on screen density)
    // This accounts for antialiasing and subpixel rendering differences
    private val surfaceOffsetDp = 5f  // ~13px at xxhdpi (2.625 density), ~10px at xhdpi (2.0)
    private val surfaceOffset = surfaceOffsetDp * density

    init {
        // Sample the path to determine the baseline Y at each X coordinate
        var debugCount = 0
        var cornerCount = 0
        var middleCount = 0

        for (i in 0 until width) {
            val x = offsetX + i.toFloat()
            baselineYs[i] = if (path != null) {
                // Find the topmost point of the path at this X coordinate
                // Paths are in global/world coordinates already (from getTextPath)
                findTopOfPathAt(x, path, bounds)
            } else {
                // No path - for buttons, exclude rounded corners
                // Use density-aware corner radius (20dp to better match button rendering)
                val cornerRadiusDp = 20f
                val cornerRadius = cornerRadiusDp * density
                val leftEdge = bounds.left + cornerRadius
                val rightEdge = bounds.right - cornerRadius

                if (x < leftEdge || x > rightEdge) {
                    // In corner area - set baseline very low so snow doesn't accumulate
                    cornerCount++
                    bounds.bottom + 1000f
                } else {
                    // Flat middle section
                    middleCount++
                    bounds.top + surfaceOffset
                }
            }
        }

    }

    private fun hasPathContentAt(x: Float, path: Path, bounds: RectF): Boolean {
        // Check if X is within the path bounds
        if (x < bounds.left || x > bounds.right) {
            return false
        }

        // Set up region for path testing
        val region = Region()
        val pathBounds = Region(
            bounds.left.toInt(),
            bounds.top.toInt(),
            bounds.right.toInt(),
            bounds.bottom.toInt()
        )
        region.setPath(path, pathBounds)

        // Sample vertically to see if there's any filled pixels at this X
        val step = 1f
        var y = bounds.top
        while (y <= bounds.bottom) {
            if (region.contains(x.toInt(), y.toInt())) {
                return true  // Found filled pixels
            }
            y += step
        }
        return false  // No filled pixels at this X
    }

    private fun findTopOfPathAt(x: Float, path: Path, bounds: RectF): Float {
        // Paths are in global/world coordinates (from getTextPath with position)
        // Only check if X is within the actual path bounds
        if (x < bounds.left || x > bounds.right) {
            // X is outside the path bounds - return a baseline far below so no collision
            return bounds.bottom + 1000f
        }

        // Sample the path vertically at this X coordinate to find the topmost point
        // Use fine sampling (0.1 pixels) to catch thin strokes like the arch of 'h'
        val step = 0.1f
        var y = bounds.top

        // Set up region for path testing in global coordinates
        val region = Region()
        val pathBounds = Region(
            bounds.left.toInt(),
            bounds.top.toInt(),
            bounds.right.toInt(),
            bounds.bottom.toInt()
        )
        region.setPath(path, pathBounds)

        while (y <= bounds.bottom) {
            // Check if this point is inside the filled path (using global coords)
            if (region.contains(x.toInt(), y.toInt())) {
                // Add offset to make snow land on the visual surface
                // The path detection finds the first filled pixel, but we want to land
                // slightly lower to sit on the rendered surface (accounting for antialiasing)
                return y + surfaceOffset
            }
            y += step
        }
        // If no intersection found within bounds, return far below
        return bounds.bottom + 1000f
    }

    /**
     * Add snow at the given x position (returns false if rejected)
     * Uses probabilistic stacking: always allowed up to 5px, increasingly unlikely 5-15px, hard cap at 15px
     * When rejected, attempts to spread to neighboring columns with lower height
     * If current stack is 2x higher than neighbor, spreads to neighbor instead
     */
    fun addSnow(x: Float, amount: Float = 1.0f, depth: Int = 0): Boolean {
        val ix = (x - offsetX).toInt()
        if (ix < 0 || ix >= width) return false

        val currentHeight = heights[ix]
        val baseline = baselineYs[ix]

        // Reject snow in corner columns (for buttons, corners have baseline = bounds.bottom + 1000)
        // This prevents snow from accumulating and rendering at incorrect positions
        if (path == null && baseline > bounds.bottom + 100f) {
            return false  // Don't add snow to corner columns
        }

        // Hard cap at maxHeight
        if (currentHeight >= maxHeight) {
            // Try spreading to neighbors
            return trySpreadToNeighbors(ix, currentHeight, depth)
        }

        // Check if current stack is 2x higher than any neighbor that can support snow
        // If so, add to the shorter neighbor instead (but only for initial call to prevent infinite recursion)
        if (depth == 0) {
            val neighborIx = findBalancedNeighbor(ix, currentHeight)
            if (neighborIx != null) {
                val neighborX = offsetX + neighborIx.toFloat()
                return addSnow(neighborX, amount, depth + 1)
            }
        }

        // Always allow stacking below comfortable height
        if (currentHeight < comfortableHeight) {
            heights[ix] = minOf(heights[ix] + amount, maxHeight)
            return true
        }

        // Above comfortable height: probabilistic stacking
        // Exponentially decreasing probability from 5 to 15
        val excessHeight = currentHeight - comfortableHeight
        val maxExcess = maxHeight - comfortableHeight  // 10 pixels
        val probability = (1.0f - (excessHeight / maxExcess)).pow(3.0f)  // Cubic falloff

        if (Random.nextFloat() < probability) {
            heights[ix] = minOf(heights[ix] + amount, maxHeight)
            return true
        }

        // Rejected by probability - try spreading to neighbors
        return trySpreadToNeighbors(ix, currentHeight, depth)
    }

    /**
     * Find a neighbor to balance with if current stack is 2x higher
     * Returns neighbor index if current height >= 2 * neighbor height and neighbor can support snow
     */
    private fun findBalancedNeighbor(ix: Int, currentHeight: Float): Int? {
        val candidates = mutableListOf<Pair<Int, Float>>()

        // Check left neighbor
        if (ix > 0) {
            val leftHeight = heights[ix - 1]
            val leftBaseline = baselineYs[ix - 1]
            // Can support snow if baseline is reasonable (not far out of bounds)
            if (leftBaseline < 1000f && currentHeight >= 2.0f * leftHeight) {
                candidates.add(Pair(ix - 1, leftHeight))
            }
        }

        // Check right neighbor
        if (ix < width - 1) {
            val rightHeight = heights[ix + 1]
            val rightBaseline = baselineYs[ix + 1]
            // Can support snow if baseline is reasonable (not far out of bounds)
            if (rightBaseline < 1000f && currentHeight >= 2.0f * rightHeight) {
                candidates.add(Pair(ix + 1, rightHeight))
            }
        }

        // If we have candidates, return the one with the smallest height
        return candidates.minByOrNull { it.second }?.first
    }

    /**
     * Try to spread snow to neighboring columns with lower height
     */
    private fun trySpreadToNeighbors(ix: Int, currentHeight: Float, depth: Int): Boolean {
        val lowerNeighbors = mutableListOf<Int>()

        // Check left neighbor
        if (ix > 0 && heights[ix - 1] < currentHeight) {
            lowerNeighbors.add(ix - 1)
        }

        // Check right neighbor
        if (ix < width - 1 && heights[ix + 1] < currentHeight) {
            lowerNeighbors.add(ix + 1)
        }

        // Spread to a random lower neighbor
        if (lowerNeighbors.isNotEmpty()) {
            val neighborIx = lowerNeighbors.random()
            val neighborX = offsetX + neighborIx.toFloat()
            return addSnow(neighborX, 1.0f, depth + 1)  // Add 1 pixel to neighbor
        }

        return false  // No valid neighbors, snow discarded
    }

    /**
     * Erode a random snow column by 1 pixel (for natural melting effect)
     */
    fun erodeRandom() {
        // Find all columns with snow
        val snowyColumns = heights.indices.filter { heights[it] > 0 }
        if (snowyColumns.isEmpty()) return

        // Pick a random snowy column and reduce by 1
        val randomIndex = snowyColumns.random()
        heights[randomIndex] = maxOf(0f, heights[randomIndex] - 1.0f)
    }

    /**
     * Get the baseline Y coordinate for a given X position
     * Returns a large value (bounds.bottom + 1000) if X is out of range or column is invalid
     */
    fun getBaselineY(x: Float): Float {
        val ix = (x - offsetX).toInt()
        if (ix < 0 || ix >= width) return bounds.bottom + 1000f
        return baselineYs[ix]
    }

    /**
     * Get the height of snow at the given x position
     */
    fun heightAt(x: Float): Float {
        val ix = (x - offsetX).toInt()
        return if (ix >= 0 && ix < width) heights[ix] else 0f
    }

    /**
     * Get the baseline Y (where snow lands) at the given x position
     */
    fun baselineY(x: Float): Float {
        val ix = (x - offsetX).toInt()
        return if (ix >= 0 && ix < width) baselineYs[ix] else 0f
    }

    /**
     * Get the Y position of the top of snow at the given x position
     */
    fun topY(x: Float): Float {
        return baselineY(x) - heightAt(x)
    }

    /**
     * Check if a point would collide with fallen snow (within surface bounds)
     */
    fun collides(x: Float, y: Float): Boolean {
        // Check if x is within this surface's bounds
        if (x < offsetX || x >= offsetX + width) return false

        val baseline = baselineY(x)
        val snowTop = topY(x)

        // Only collide if the snowflake is close to this surface's baseline at this X
        // Allow a small buffer (3 pixels) below the surface for collision detection
        return y >= snowTop && y <= baseline + 3f
    }

    /**
     * Reset all fallen snow
     */
    fun reset() {
        heights.fill(0f)
    }

    /**
     * Get all heights for rendering
     */
    fun getHeights(): List<Triple<Float, Float, Float>> {
        return heights.indices
            .filter { heights[it] > 0 }
            .map { Triple(it.toFloat() + offsetX, heights[it], baselineYs[it]) }
    }
}
