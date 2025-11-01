#!/usr/bin/env swift

import Foundation

// Simulate the shader coordinate system

func testCoordinateSystem() {
    print("=== Coordinate System Unit Test ===\n")

    // Screen positions we care about
    let screenPositions: [(name: String, normalizedY: Float)] = [
        ("Top of screen", 0.0),
        ("25% from top", 0.25),
        ("Middle of screen", 0.5),
        ("75% from top", 0.75),
        ("Bottom of screen", 1.0)
    ]

    // Test at different march distances
    let testZ: Float = 0.5

    print("Testing at march distance z = \(testZ)\n")
    print("Goal: Bottom screen should sample p.y=0, Top screen should sample p.y=2\n")

    for (name, normalizedY) in screenPositions {
        // Convert normalized screen position to uv.y
        // normalizedY: 0.0 = top, 1.0 = bottom
        // After normalization: uv ranges from -1 to +1 based on screen height
        // For simplicity, assume square aspect ratio
        let uvY = normalizedY * 2.0 - 1.0  // Maps [0,1] to [-1,+1]

        // uv.y flip in shader: uv.y = -uv.y
        let flippedUvY = -uvY
        // After flip: top (normalizedY=0) → uv.y=+1, bottom (normalizedY=1) → uv.y=-1
        // Wait, that's backwards from what I said before!

        // Let me recalculate properly
        // In shader: vec2 uv = (fragCoord * 2.0 - iResolution) / iResolution.y;
        // For a pixel at the top (fragCoord.y = 0):
        // uv.y = (0 * 2.0 - height) / height = -1.0
        // Then: uv.y = -uv.y → uv.y = +1.0

        // For a pixel at the bottom (fragCoord.y = height):
        // uv.y = (height * 2.0 - height) / height = +1.0
        // Then: uv.y = -uv.y → uv.y = -1.0

        // So after the flip:
        // Top of screen → uv.y = +1
        // Bottom of screen → uv.y = -1

        let actualUvY = 1.0 - normalizedY * 2.0  // Maps [0,1] to [+1,-1]

        // Ray direction
        let rayDirY = actualUvY / sqrt(actualUvY * actualUvY + 1.0)

        // Position along ray at distance z (before shift)
        let pYBeforeShift = testZ * rayDirY

        // Test different shift formulas
        let shift1 = 1.0 - actualUvY  // My current formula
        let shift2 = actualUvY + 1.0  // Alternative
        let shift3 = -actualUvY + 1.0 // Another alternative

        let pY_withShift1 = pYBeforeShift + shift1
        let pY_withShift2 = pYBeforeShift + shift2
        let pY_withShift3 = pYBeforeShift + shift3

        print("\(name):")
        print("  normalizedY: \(normalizedY)")
        print("  uv.y after flip: \(actualUvY)")
        print("  ray.y direction: \(rayDirY)")
        print("  p.y before shift: \(pYBeforeShift)")
        print("  p.y with shift (1.0 - uv.y): \(pY_withShift1)")
        print("  p.y with shift (uv.y + 1.0): \(pY_withShift2)")
        print("  p.y with shift (-uv.y + 1.0): \(pY_withShift3)")
        print()
    }

    print("\n=== Evaluation ===")
    print("We want: Top screen → p.y ≈ 2.0, Bottom screen → p.y ≈ 0.0")
    print("Check the values above to see which shift formula is correct.\n")
}

testCoordinateSystem()
