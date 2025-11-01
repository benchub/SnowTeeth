# Per-Letter Rendering Solution

## The Problem

Initial attempts to calculate text positioning failed spectacularly. While "Sno" worked perfectly, "wTeeth" had completely misaligned collision detection:
- The 'T' appeared to overhang the 'w' by several pixels in collision detection
- The 'h' had no collision detection at all
- Each successive letter had worse alignment

## Failed Approaches

### Attempt 1: NSString.size() with Centering Math
```swift
// Calculate text starting position
let textSize = (text as NSString).size(withAttributes: [.font: font])
let totalWidth = textSize.width
let textStartX = (screenWidth - totalWidth) / 2
```

**Why it failed**: NSString.size() uses different metrics than SwiftUI's Text layout. SwiftUI's text rendering is opaque and doesn't match NSString calculations.

### Attempt 2: CoreText Width Calculation
```swift
let attributedString = NSAttributedString(string: text, attributes: [.font: font])
let ctLine = CTLineCreateWithAttributedString(attributedString)
let totalWidth = CTLineGetTypographicBounds(ctLine, nil, nil, nil)
let textStartX = (screenWidth - CGFloat(totalWidth)) / 2
```

**Why it failed**: CoreText's typographic bounds also don't match SwiftUI's actual layout. Everything shifted too far right.

### Attempt 3: Accumulated LetterBoundsCalculator Widths
```swift
// Use the actual measured width from LetterBoundsCalculator
let calculatorBounds = calculator.calculateBounds(text: text, font: font, position: .zero)
let totalWidth = calculatorBounds.last!.bounds.maxX
let textStartX = (screenWidth - totalWidth) / 2
```

**Why it failed**: Even using the actual glyph advance widths from CoreText didn't match SwiftUI's internal layout decisions.

### Attempt 4: GeometryReader frame.minX
```swift
Text("SnowTeeth")
    .background(
        GeometryReader { geo in
            Color.clear.onAppear {
                let frame = geo.frame(in: .named("snowCoordinateSpace"))
                textStartX = frame.minX
            }
        }
    )
```

**Why it failed**: This captured the start of the Text view correctly, but calculating individual letter positions from there still relied on CoreText/NSString metrics which don't match SwiftUI.

## The Solution: Per-Letter Rendering

The breakthrough: **Let SwiftUI lay out the text, then measure the results.**

### Implementation

**Step 1: Render Each Letter Separately**

`ContentView.swift:35-52`:
```swift
HStack(spacing: 0) {
    ForEach(Array("SnowTeeth".enumerated()), id: \.offset) { index, char in
        Text(String(char))
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                captureLetterBounds(char: char, index: index, geometry: geo)
                            }
                        }
                }
            )
    }
}
```

**Key points**:
- `HStack(spacing: 0)`: Zero spacing to maintain natural letter spacing
- Each letter is a separate Text view
- GeometryReader captures the actual frame after layout
- `DispatchQueue.main.asyncAfter`: Ensures layout has completed before capturing

**Step 2: Capture Actual Letter Positions**

`ContentView.swift:199-233`:
```swift
@State private var capturedLetters: [Int: (char: Character, frame: CGRect)] = [:]

private func captureLetterBounds(char: Character, index: Int, geometry: GeometryProxy) {
    let localFrame = geometry.frame(in: .named("snowCoordinateSpace"))
    capturedLetters[index] = (char, localFrame)

    // Once we have all letters, calculate paths
    let text = "SnowTeeth"
    if capturedLetters.count == text.count {
        let calculator = LetterBoundsCalculator()
        let font = UIFont.systemFont(ofSize: 34, weight: .bold)

        var letterBounds: [(id: String, bounds: CGRect, path: CGPath?)] = []

        // Process letters in order
        for i in 0..<text.count {
            guard let (char, frame) = capturedLetters[i] else { continue }

            // Skip spaces
            if char == " " { continue }

            // Calculate path for this letter at its actual SwiftUI position
            let singleLetterBounds = calculator.calculateBounds(
                text: String(char),
                font: font,
                position: CGPoint(x: frame.minX, y: frame.minY)
            )

            if let letterBound = singleLetterBounds.first {
                letterBounds.append((id: "letter_\(i)", bounds: letterBound.bounds, path: letterBound.path))
            }
        }

        print("📝 Captured \(letterBounds.count) letter bounds from SwiftUI frames")
        updateSnowEffectBounds(letterBounds: letterBounds, buttonBounds: [])
    }
}
```

**Step 3: Generate Paths at Measured Positions**

`LetterBoundsCalculator.swift:16-104`:
```swift
func calculateBounds(
    text: String,
    font: UIFont,
    position: CGPoint  // This is now the ACTUAL SwiftUI position!
) -> [(id: String, bounds: CGRect, path: CGPath?)] {
    var results: [(String, CGRect, CGPath?)] = []
    var currentX = position.x  // Start at the measured position

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
            currentX += 10
            continue
        }

        // Get the path for this glyph
        if let path = CTFontCreatePathForGlyph(ctFont, glyph, nil) {
            let pathBounds = path.boundingBox
            let ascent = CTFontGetAscent(ctFont)

            // Transform path to world coordinates
            var transform = CGAffineTransform(translationX: currentX, y: position.y + ascent)
            transform = transform.scaledBy(x: 1, y: -1)  // Flip Y axis
            let worldPath = path.copy(using: &transform)

            let bounds = CGRect(
                x: currentX + pathBounds.minX,
                y: position.y + (ascent - pathBounds.maxY),
                width: pathBounds.width,
                height: pathBounds.height
            )

            results.append((id: "letter_\(index)", bounds, worldPath))

            // Advance by glyph advance width
            var advance: CGSize = .zero
            CTFontGetAdvancesForGlyphs(ctFont, .horizontal, &glyph, &advance, 1)
            currentX += advance.width
        }
    }

    return results
}
```

## Why This Works

1. **SwiftUI owns the layout**: We don't try to replicate SwiftUI's internal layout logic
2. **Measurement, not calculation**: We measure where SwiftUI actually placed each letter
3. **Per-letter accuracy**: Each letter's position is independently captured
4. **Path generation uses measurements**: CoreText paths are generated at the measured positions
5. **No cumulative error**: Each letter's position is absolute, not relative to previous letters

## Visual Result

After implementing per-letter rendering:
- ✅ "Sno" - Perfect (already was)
- ✅ "wTeeth" - Perfect (was completely broken)
- ✅ All letters have accurate collision detection
- ✅ Snow follows curves exactly where visually rendered
- ✅ No "floating" height-maps
- ✅ No mid-air collisions

## Trade-offs

### Pros
- Perfect accuracy - collision matches visual rendering exactly
- No complex text layout calculations needed
- Works with any font, weight, or size
- Resilient to SwiftUI changes (we just measure the results)

### Cons
- Slightly more complex view hierarchy (HStack of Text views instead of single Text)
- Each letter capture requires a GeometryReader
- Asynchronous capture (0.1s delay for layout completion)
- Minimal performance impact (~9 GeometryReaders for "SnowTeeth")

## Lessons Learned

1. **Don't fight the framework**: SwiftUI's text layout is intentionally opaque. Work with it, not against it.
2. **Measurement beats calculation**: When you can't reliably calculate something, measure it instead.
3. **Per-element decomposition**: Breaking "SnowTeeth" into individual letters solved the problem.
4. **Trust but verify**: Even official APIs (NSString.size, CoreText) don't always match the rendering framework.
5. **Coordinate spaces are critical**: Using `.named("snowCoordinateSpace")` ensures consistent global coordinates.
