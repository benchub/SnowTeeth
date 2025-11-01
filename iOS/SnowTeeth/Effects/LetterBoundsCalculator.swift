//
//  LetterBoundsCalculator.swift
//  SnowTeeth
//
//  Calculates bounding rectangles for individual letters in text using actual glyph paths
//

import Foundation
import CoreGraphics
import CoreText
import UIKit

class LetterBoundsCalculator {

    /// Returns array of paths and bounds for each character's actual shape
    func calculateBounds(
        text: String,
        font: UIFont,
        position: CGPoint
    ) -> [(id: String, bounds: CGRect, path: CGPath?)] {
        var results: [(String, CGRect, CGPath?)] = []
        var currentX = position.x

        let ctFont = CTFontCreateWithName(font.fontName as CFString, font.pointSize, nil)

        for (index, char) in text.enumerated() {
            // Get the glyph for this character
            let charString = String(char)
            guard let unichar = charString.utf16.first else {
                currentX += 10
                continue
            }

            var character = unichar
            var glyph: CGGlyph = 0
            let success = withUnsafeMutablePointer(to: &character) { charPtr in
                withUnsafeMutablePointer(to: &glyph) { glyphPtr in
                    CTFontGetGlyphsForCharacters(ctFont, charPtr, glyphPtr, 1)
                }
            }

            guard success else {
                currentX += 10 // fallback width
                continue
            }

            // Get the path for this glyph
            if let path = CTFontCreatePathForGlyph(ctFont, glyph, nil) {
                // Get the tight bounding box of the actual letter shape
                let pathBounds = path.boundingBox

                // CoreText coordinates: origin at baseline, Y+ goes up
                // UIKit coordinates: origin at top-left, Y+ goes down
                // position.y is the top of the Text view frame

                // Get font metrics to understand where baseline is
                let ascent = CTFontGetAscent(ctFont)
                let _ = CTFontGetDescent(ctFont)

                // The baseline is 'ascent' pixels down from the frame top
                // pathBounds.maxY is pixels above baseline
                // So the visual top is at: frameTop + (ascent - pathBounds.maxY)
                let visualTopY = position.y + (ascent - pathBounds.maxY)

                // Translate to world coordinates
                let bounds = CGRect(
                    x: currentX + pathBounds.minX,
                    y: visualTopY,
                    width: pathBounds.width,
                    height: pathBounds.height
                )

                // Transform path to world coordinates
                // We need to translate the path from baseline-origin to screen coordinates
                var transform = CGAffineTransform(translationX: currentX, y: position.y + ascent)
                // Flip Y axis (CoreText Y+ is up, UIKit Y+ is down)
                transform = transform.scaledBy(x: 1, y: -1)
                let worldPath = path.copy(using: &transform)

                let id = "letter_\(index)"
                results.append((id, bounds, worldPath))

                // Advance by glyph advance width
                var advance: CGSize = .zero
                CTFontGetAdvancesForGlyphs(ctFont, .horizontal, &glyph, &advance, 1)
                currentX += advance.width
            } else {
                // Fallback if no path available
                currentX += 10
            }
        }

        return results
    }

    /// Alternative method that returns button bounds
    func buttonBounds(
        rect: CGRect,
        id: String
    ) -> (id: String, bounds: CGRect, path: CGPath?) {
        return (id, rect, nil)
    }
}
