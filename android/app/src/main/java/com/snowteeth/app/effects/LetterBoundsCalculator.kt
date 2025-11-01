package com.snowteeth.app.effects

import android.graphics.Paint
import android.graphics.Path
import android.graphics.PointF
import android.graphics.RectF
import android.util.Log

/**
 * Calculates bounding rectangles for individual letters in text using actual glyph paths
 * Ported from iOS Swift implementation
 */
class LetterBoundsCalculator {

    /**
     * Returns array of bounds for each character's actual shape
     * @param text The text to analyze
     * @param paint Paint object with the desired font
     * @param position Starting position (top-left corner of text)
     */
    fun calculateBounds(
        text: String,
        paint: Paint,
        position: PointF
    ): List<CollisionDetector.CollisionTarget> {
        val results = mutableListOf<CollisionDetector.CollisionTarget>()
        var currentX = position.x

        val widths = FloatArray(1)

        // Calculate baseline Y from top position
        val fontMetrics = paint.fontMetrics
        val ascent = -fontMetrics.ascent  // Distance from baseline to top
        val baselineY = position.y + ascent

        if (text.length > 0) {
            Log.d("LetterBounds", "🔤 Starting bounds calculation:")
            Log.d("LetterBounds", "   position.y (TOP of text frame): ${position.y}")
            Log.d("LetterBounds", "   ascent: $ascent")
            Log.d("LetterBounds", "   baselineY: $baselineY (= position.y + ascent)")
        }

        for ((index, char) in text.withIndex()) {
            val charString = char.toString()

            // Create a new path for this glyph
            val path = Path()
            // getTextPath expects baseline Y
            paint.getTextPath(charString, 0, 1, currentX, baselineY, path)

            // Set fill type so the path represents the filled area, not just the outline
            path.fillType = Path.FillType.WINDING

            // Get the tight bounding box of the actual letter shape
            val pathBounds = RectF()
            path.computeBounds(pathBounds, true)

            // Get character width for advancing
            paint.getTextWidths(charString, widths)
            val charWidth = widths[0]

            // Only add bounds if the path is non-empty (not a space)
            if (!pathBounds.isEmpty) {
                // Android's getTextPath positions the glyph at the baseline
                // pathBounds are in screen coordinates
                // They are already correct in absolute screen coordinates
                val bounds = RectF(
                    pathBounds.left,
                    pathBounds.top,
                    pathBounds.right,
                    pathBounds.bottom
                )

                if (index < 3) {
                    Log.d("LetterBounds", "   Letter '$charString' (index $index):")
                    Log.d("LetterBounds", "      currentX: $currentX")
                    Log.d("LetterBounds", "      pathBounds: $pathBounds")
                    Log.d("LetterBounds", "      final bounds: $bounds")
                }

                val id = "letter_$index"
                // Include the path for contour-following height-maps
                results.add(CollisionDetector.CollisionTarget(id, bounds, path))
            }

            // Advance by character width
            currentX += charWidth
        }

        return results
    }

    /**
     * Alternative method that returns button bounds
     */
    fun buttonBounds(rect: RectF, id: String): CollisionDetector.CollisionTarget {
        return CollisionDetector.CollisionTarget(id, rect)
    }
}
