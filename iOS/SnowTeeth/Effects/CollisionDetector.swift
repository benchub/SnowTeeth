//
//  CollisionDetector.swift
//  SnowTeeth
//
//  Testable collision detection logic
//

import Foundation
import CoreGraphics

class CollisionDetector {

    private let stickThreshold: CGFloat

    init(stickThreshold: CGFloat = 2.0) {
        self.stickThreshold = stickThreshold
    }

    /// Checks if a snowflake collides with a target rectangle or path
    /// Returns the target ID if collision detected, nil otherwise
    func checkCollision(
        snowflake: Snowflake,
        targets: [(id: String, bounds: CGRect, path: CGPath?)]
    ) -> String? {
        guard snowflake.state == .falling else {
            return nil
        }

        let snowBottom = snowflake.position.y + snowflake.size

        // Check targets in order - we want to hit the TOP surface as snow falls
        // Since y increases downward, we check if snow reaches the top edge (minY)
        for target in targets {
            let bounds = target.bounds

            // First check if snow is within horizontal bounds
            if snowflake.position.x < bounds.minX || snowflake.position.x > bounds.maxX {
                continue
            }

            // If this target has a path (letter), use path-based collision
            if let path = target.path {
                // For path-based collision, scan vertically to find the top surface
                // Check multiple points along the bottom of the snowflake
                let testPoints = [
                    CGPoint(x: snowflake.position.x, y: snowBottom),
                    CGPoint(x: snowflake.position.x - snowflake.size/4, y: snowBottom),
                    CGPoint(x: snowflake.position.x + snowflake.size/4, y: snowBottom)
                ]

                for testPoint in testPoints {
                    // Check if this point is inside the path
                    if path.contains(testPoint) {
                        print("💥 Collision! Snow at (\(snowflake.position.x), \(snowflake.position.y)) hit path of \(target.id)")
                        return target.id
                    }

                    // Also check just below (within threshold)
                    let belowPoint = CGPoint(x: testPoint.x, y: testPoint.y + stickThreshold)
                    if path.contains(belowPoint) {
                        print("💥 Collision! Snow at (\(snowflake.position.x), \(snowflake.position.y)) hit TOP of path \(target.id)")
                        return target.id
                    }
                }
            } else {
                // No path, use rectangle-based collision
                // Check if snow is approaching from ABOVE and hitting the TOP edge
                if snowflake.position.y <= bounds.minY + stickThreshold &&
                   snowBottom >= bounds.minY {

                    // If this is a button (has "button" in ID), only allow snow on the flat part
                    if target.id.contains("button") {
                        let cornerRadius: CGFloat = 15

                        // Only allow collision on the flat middle section
                        // The flat part is from (minX + cornerRadius) to (maxX - cornerRadius)
                        let flatStartX = bounds.minX + cornerRadius
                        let flatEndX = bounds.maxX - cornerRadius

                        // If snow is outside the flat zone, don't collide
                        if snowflake.position.x < flatStartX || snowflake.position.x > flatEndX {
                            continue
                        }
                    }

                    print("💥 Collision! Snow at (\(snowflake.position.x), \(snowflake.position.y)) hit TOP of \(target.id) at y=\(bounds.minY)")
                    return target.id
                }
            }
        }

        return nil
    }

    /// Checks if snowflake bottom is clear (not overlapping with anything)
    func isPositionClear(
        snowflake: Snowflake,
        targets: [(id: String, bounds: CGRect, path: CGPath?)]
    ) -> Bool {
        // Check if the snowflake bottom is intersecting with any target
        let snowBottom = snowflake.position.y + snowflake.size

        // Sample 3 points across the bottom of the snowflake
        let testPoints = [
            CGPoint(x: snowflake.position.x, y: snowBottom),
            CGPoint(x: snowflake.position.x - snowflake.size/3, y: snowBottom),
            CGPoint(x: snowflake.position.x + snowflake.size/3, y: snowBottom)
        ]

        for testPoint in testPoints {
            for target in targets {
                let bounds = target.bounds

                if testPoint.x < bounds.minX || testPoint.x > bounds.maxX {
                    continue
                }

                if let path = target.path {
                    if path.contains(testPoint) {
                        return false  // Overlapping with path
                    }
                } else {
                    if testPoint.y >= bounds.minY && testPoint.y <= bounds.maxY &&
                       testPoint.x >= bounds.minX && testPoint.x <= bounds.maxX {
                        return false  // Overlapping with rectangle
                    }
                }
            }
        }

        return true  // Position is clear
    }

    /// Checks if a snowflake is fully supported at the given position
    /// A snowflake is "fully supported" if 100% of sample points have solid support below
    func isFullySupported(
        snowflake: Snowflake,
        targets: [(id: String, bounds: CGRect, path: CGPath?)]
    ) -> Bool {
        let snowBottom = snowflake.position.y + snowflake.size
        let checkDepth: CGFloat = 1.0  // Check 1 pixel below

        // Snowflakes are circles, so sample across the circular diameter (not the square)
        // Use 70% of size to approximate the inscribed circle
        let circularWidth = snowflake.size * 0.7

        // Sample 5 points across the circular footprint
        let samplePoints = 5
        var supportedPoints = 0

        for i in 0..<samplePoints {
            let fraction = CGFloat(i) / CGFloat(samplePoints - 1)  // 0.0 to 1.0
            let testX = snowflake.position.x - circularWidth/2 + (circularWidth * fraction)
            let testPoint = CGPoint(x: testX, y: snowBottom + checkDepth)

            // Check if there's something solid at this point
            for target in targets {
                let bounds = target.bounds

                // Quick bounds check
                if testPoint.x < bounds.minX || testPoint.x > bounds.maxX {
                    continue
                }

                if let path = target.path {
                    if path.contains(testPoint) {
                        supportedPoints += 1
                        break
                    }
                } else {
                    // Rectangle-based check
                    if testPoint.y >= bounds.minY && testPoint.y <= bounds.maxY &&
                       testPoint.x >= bounds.minX && testPoint.x <= bounds.maxX {
                        supportedPoints += 1
                        break
                    }
                }
            }
        }

        // Need 100% support (5 out of 5 points) for small flakes
        return supportedPoints >= 5
    }

    /// Finds the lowest Y position where snow can rest with full support
    /// Used for settling snow to prevent "branching"
    func findSettledPosition(
        snowflake: Snowflake,
        targets: [(id: String, bounds: CGRect, path: CGPath?)],
        maxY: CGFloat
    ) -> (position: CGPoint, targetId: String?)? {
        let startY = snowflake.position.y
        let snowX = snowflake.position.x
        let snowSize = snowflake.size

        // Scan downward from current position to find lowest resting spot
        var testY = startY
        let scanStep: CGFloat = 1.0  // Scan in 1-pixel increments
        var lastClearY = startY
        var lastClearSnowflake = snowflake

        while testY < maxY {
            let testSnowflake = Snowflake(
                position: CGPoint(x: snowX, y: testY),
                velocity: snowflake.velocity,
                size: snowSize,
                opacity: snowflake.opacity
            )

            // Check if this position would collide
            if checkCollision(snowflake: testSnowflake, targets: targets) != nil {
                // Hit something - use the last clear position and check support
                if isFullySupported(snowflake: lastClearSnowflake, targets: targets) {
                    // Found a good resting spot - find which target is supporting us
                    let supportingTarget = findSupportingTarget(snowflake: lastClearSnowflake, targets: targets)
                    return (CGPoint(x: snowX, y: lastClearY), supportingTarget)
                } else {
                    // Not well supported - keep falling
                    return nil
                }
            }

            // No collision yet, remember this position and keep going
            lastClearY = testY
            lastClearSnowflake = testSnowflake
            testY += scanStep
        }

        // Reached bottom without collision
        return nil
    }

    /// Finds which target is directly below and supporting the snowflake
    private func findSupportingTarget(
        snowflake: Snowflake,
        targets: [(id: String, bounds: CGRect, path: CGPath?)]
    ) -> String? {
        let snowBottom = snowflake.position.y + snowflake.size
        let checkPoint = CGPoint(x: snowflake.position.x, y: snowBottom + 2)

        for target in targets {
            let bounds = target.bounds

            if checkPoint.x < bounds.minX || checkPoint.x > bounds.maxX {
                continue
            }

            if let path = target.path {
                if path.contains(checkPoint) {
                    return target.id
                }
            } else {
                if checkPoint.y >= bounds.minY && checkPoint.y <= bounds.maxY {
                    return target.id
                }
            }
        }

        return nil
    }

    /// Calculates the stick position (on top of the target)
    func calculateStickPosition(
        snowflake: Snowflake,
        targetBounds: CGRect
    ) -> CGPoint {
        return CGPoint(
            x: snowflake.position.x,
            y: targetBounds.minY - snowflake.size
        )
    }
}
