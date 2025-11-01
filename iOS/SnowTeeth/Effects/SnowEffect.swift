//
//  SnowEffect.swift
//  SnowTeeth
//
//  Main coordinator for snow particle system
//

import Foundation
import CoreGraphics
import UIKit
import Combine

class SnowEffect: ObservableObject {
    @Published var snowflakes: [Snowflake] = []

    private let collisionDetector = CollisionDetector()
    private let boundsCalculator = LetterBoundsCalculator()
    private var surfaceSnowMaps: [String: FallenSnow] = [:]  // Height-map for each surface

    private var targetBounds: [(id: String, bounds: CGRect, path: CGPath?)] = []
    private var currentGravity: CGVector = CGVector(dx: 0, dy: 1)
    private var screenSize: CGSize = .zero

    private var lastSpawnTime: TimeInterval = 0
    private let spawnInterval: TimeInterval = 0.15 // 150ms between spawn attempts
    private let maxFallingParticles = 80  // Reduced from 300 to improve performance
    private var lastDiagnosticLog: TimeInterval = 0
    private let diagnosticLogInterval: TimeInterval = 5.0  // Log every 5 seconds

    // Global wind direction that affects all snow
    private var windDirection: CGFloat = 0  // negative = left, positive = right
    private var lastWindChange: TimeInterval = 0
    private let windChangeInterval: TimeInterval = 5.0  // Change wind every 5 seconds

    private var displayLink: CADisplayLink?
    private var lastUpdateTime: TimeInterval = 0

    init() {
        // Initialize with random wind direction
        windDirection = CGFloat.random(in: -40...40)

        setupDisplayLink()
        setupOrientationObserver()
    }

    // MARK: - Setup

    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.add(to: .current, forMode: .common)
    }

    private func setupOrientationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    deinit {
        displayLink?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Configuration

    func setScreenSize(_ size: CGSize) {
        screenSize = size
        // Note: surfaceSnowMaps will be recreated when setTargetBounds is called again
    }

    func reset() {
        // Clear all snowflakes and fallen snow
        snowflakes.removeAll()
        for (_, snowMap) in surfaceSnowMaps {
            snowMap.reset()
        }
    }

    func pause() {
        displayLink?.isPaused = true
    }

    func resume() {
        displayLink?.isPaused = false
        // Reset lastUpdateTime to avoid large delta when resuming
        lastUpdateTime = 0
    }

    func getSurfaceSnowMaps() -> [String: FallenSnow] {
        return surfaceSnowMaps
    }

    func setTargetBounds(_ bounds: [(id: String, bounds: CGRect, path: CGPath?)]) {
        targetBounds = bounds

        // Create a height-map for each surface
        surfaceSnowMaps.removeAll()
        for target in bounds {
            // Only sample integer X coordinates that are actually inside the bounds
            let startX = Int(ceil(target.bounds.minX))
            let endX = Int(floor(target.bounds.maxX))
            let width = max(0, endX - startX + 1)
            let offsetX = CGFloat(startX)

            surfaceSnowMaps[target.id] = FallenSnow(
                width: width,
                bounds: target.bounds,
                path: target.path,
                offsetX: offsetX
            )
        }

        // Add ground target at bottom of screen
        // Place it starting AT screen height so snow stacks from below the visible screen
        if screenSize.height > 0 {
            let groundBounds = CGRect(
                x: 0,
                y: screenSize.height,
                width: screenSize.width,
                height: 10
            )
            targetBounds.append(("ground", groundBounds, nil))

            let groundOffsetX = floor(groundBounds.minX)
            let groundEndX = ceil(groundBounds.maxX)
            let groundWidth = Int(groundEndX - groundOffsetX)

            surfaceSnowMaps["ground"] = FallenSnow(
                width: groundWidth,
                bounds: groundBounds,
                path: nil,
                offsetX: groundOffsetX,
                isGround: true
            )
        }
    }

    // MARK: - Update Loop

    @objc private func update(displayLink: CADisplayLink) {
        let currentTime = displayLink.timestamp

        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            return
        }

        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // Change wind direction periodically
        if currentTime - lastWindChange >= windChangeInterval {
            windDirection = CGFloat.random(in: -40...40)
            lastWindChange = currentTime
        }

        // Sort targets by Y position (top to bottom) for collision detection
        let sortedTargets = targetBounds.sorted { $0.bounds.minY < $1.bounds.minY }

        // Update all snowflakes
        var activeFallingCount = 0
        var slidingCount = 0

        for i in 0..<snowflakes.count {
            var snowflake = snowflakes[i]

            // Check for collisions if falling
            if snowflake.state == .falling {
                // Check collision with each surface's height-map (from top to bottom)
                for target in sortedTargets {
                    if let surfaceMap = surfaceSnowMaps[target.id] {
                        // Check collision at snowflake center, not bottom, to avoid "floating" appearance
                        if surfaceMap.collides(x: snowflake.position.x, y: snowflake.position.y) {
                            // Hit this surface - add snow to all columns covered by the snowflake's width
                            let radius = snowflake.size / 2.0
                            let leftEdge = snowflake.position.x - radius
                            let rightEdge = snowflake.position.x + radius

                            // Add 1 pixel of snow to each column that the snowflake overlaps
                            // Snow is lost for any columns that don't have valid baselines
                            let startColumn = Int(ceil(leftEdge))
                            let endColumn = Int(floor(rightEdge))

                            for columnX in startColumn...endColumn {
                                _ = surfaceMap.addSnow(at: CGFloat(columnX), amount: 1.0)
                            }

                            // Erode a random stack somewhere else for natural dynamics
                            surfaceMap.erodeRandom()

                            snowflake.state = .gone
                            break
                        }
                    }
                }
            }

            // Update position
            snowflake.update(deltaTime: deltaTime)

            // Check if offscreen
            if snowflake.isOffscreen(screenHeight: screenSize.height, screenWidth: screenSize.width) {
                snowflake.state = .gone
            }

            // Count states
            switch snowflake.state {
            case .falling: activeFallingCount += 1
            case .stuck: break
            case .sliding: slidingCount += 1
            case .gone: break
            }

            snowflakes[i] = snowflake
        }

        // Remove gone particles
        snowflakes.removeAll { $0.state == .gone }

        // Spawn new snowflakes if needed (only limit falling particles)
        if currentTime - lastSpawnTime >= spawnInterval && activeFallingCount < maxFallingParticles {
            // Spawn fewer particles per interval for better performance
            let particlesToSpawn = Int.random(in: 3...7)  // 3-7 particles per spawn (was 50-100)
            let remainingCapacity = maxFallingParticles - activeFallingCount
            let actualSpawnCount = min(particlesToSpawn, remainingCapacity)

            for _ in 0..<actualSpawnCount {
                spawnSnowflake()
            }
            lastSpawnTime = currentTime
        }

        // Diagnostic logging every 5 seconds
        if currentTime - lastDiagnosticLog >= diagnosticLogInterval {
            let totalSnowColumns = surfaceSnowMaps.values.reduce(0) { $0 + $1.getHeights().count }
            print("❄️ Performance: \(snowflakes.count) particles (\(activeFallingCount) falling, \(slidingCount) sliding), \(surfaceSnowMaps.count) surfaces, \(totalSnowColumns) snow columns")
            lastDiagnosticLog = currentTime
        }
    }

    // MARK: - Spawning

    private func spawnSnowflake() {
        let size = CGFloat.random(in: 2...3.5)  // Smaller snowflakes (30% of original max)
        let speed = CGFloat.random(in: 20...50)

        // Use global wind direction with occasional gusts
        let gustChance = CGFloat.random(in: 0...1)
        let windSpeed = gustChance < 0.15 ? windDirection * 1.5 : windDirection  // 15% chance of strong gust

        // Randomly choose spawn location based on wind direction
        // If wind blows right, spawn from left edge; if wind blows left, spawn from right edge
        let spawnChoice = CGFloat.random(in: 0...1)

        let position: CGPoint
        let velocity: CGVector

        if spawnChoice < 0.7 {
            // Spawn from top of screen (most common)
            let x = CGFloat.random(in: 0...screenSize.width)
            position = CGPoint(x: x, y: -size)

            velocity = CGVector(
                dx: windSpeed,
                dy: speed  // Always fall downward on screen
            )
        } else {
            // Spawn from the upwind edge so snow blows across screen
            // If wind is positive (blowing right), spawn from left
            // If wind is negative (blowing left), spawn from right
            let y = CGFloat.random(in: 0...screenSize.height)

            if windDirection > 0 {
                // Wind blowing right, spawn from left
                position = CGPoint(x: -size, y: y)
            } else {
                // Wind blowing left, spawn from right
                position = CGPoint(x: screenSize.width + size, y: y)
            }

            // All snow moves with the wind and downward
            velocity = CGVector(
                dx: windSpeed * 0.7,  // Less horizontal when spawning from edge
                dy: speed * 0.5  // Downward movement
            )
        }

        let snowflake = Snowflake(
            position: position,
            velocity: velocity,
            size: size,
            opacity: Float.random(in: 0.6...1.0)
        )

        snowflakes.append(snowflake)
    }

    // MARK: - Orientation Handling

    @objc private func orientationDidChange() {
        // Reset all fallen snow when orientation changes
        // Snow now always falls downward on screen, not based on device rotation
        for (_, snowMap) in surfaceSnowMaps {
            snowMap.reset()
        }

        // Remove all stuck particles (using pattern matching for associated value)
        snowflakes.removeAll { if case .stuck(_) = $0.state { return true } else { return false } }
    }
}

// MARK: - FallenSnow Helper Class

/// Height-map based fallen snow tracking (inspired by xsnow)
/// Much more efficient than tracking individual stuck particles
/// Each X coordinate has its own baseline Y that follows the surface contour
class FallenSnow {
    private var heights: [CGFloat]  // Height of snow accumulated at each x-coordinate
    private var baselineYs: [CGFloat]  // Y coordinate where snow lands at each x-coordinate (follows surface contour)
    private var width: Int
    private var offsetX: CGFloat   // X offset for this surface
    private let comfortableHeight: CGFloat  // Height below which stacking is always allowed
    private let maxHeight: CGFloat  // Absolute maximum snow accumulation height

    init(width: Int, bounds: CGRect, path: CGPath?, offsetX: CGFloat = 0, isGround: Bool = false) {
        self.width = width
        self.offsetX = offsetX
        self.heights = Array(repeating: 0, count: width)
        self.baselineYs = Array(repeating: 0, count: width)

        // Ground can stack 3x higher than other surfaces
        if isGround {
            self.comfortableHeight = 15.0  // 3x normal (5.0 * 3)
            self.maxHeight = 45.0  // 3x normal (15.0 * 3)
        } else {
            self.comfortableHeight = 5.0
            self.maxHeight = 15.0
        }

        // Sample the path to determine the baseline Y at each X coordinate
        for i in 0..<width {
            let x = offsetX + CGFloat(i)
            if let path = path {
                // Find the topmost point of the path at this X coordinate
                // Paths are in global/world coordinates already
                self.baselineYs[i] = findTopOfPathAt(x: x, path: path, bounds: bounds)
            } else {
                // No path - for buttons, exclude rounded corners
                // Assume 15pt corner radius for buttons
                let cornerRadius: CGFloat = 15.0
                let leftEdge = bounds.minX + cornerRadius
                let rightEdge = bounds.maxX - cornerRadius

                if x < leftEdge || x > rightEdge {
                    // In corner area - set baseline very low so snow doesn't accumulate
                    self.baselineYs[i] = bounds.maxY + 1000
                } else {
                    // Flat middle section
                    self.baselineYs[i] = bounds.minY
                }
            }
        }
    }

    private func hasPathContentAt(x: CGFloat, path: CGPath, bounds: CGRect) -> Bool {
        // Check if X is within the path bounds
        if x < bounds.minX || x > bounds.maxX {
            return false
        }

        // Sample vertically to see if there's any filled pixels at this X
        let step: CGFloat = 1.0
        for y in stride(from: bounds.minY, through: bounds.maxY, by: step) {
            if path.contains(CGPoint(x: x, y: y)) {
                return true  // Found filled pixels
            }
        }
        return false  // No filled pixels at this X
    }

    private func findTopOfPathAt(x: CGFloat, path: CGPath, bounds: CGRect) -> CGFloat {
        // Paths are in global/world coordinates (already transformed)
        // Only check if X is within the actual path bounds
        if x < bounds.minX || x > bounds.maxX {
            // X is outside the path bounds - return a baseline far below so no collision
            return bounds.maxY + 1000
        }

        // Sample the path vertically at this X coordinate to find the topmost point
        // Use fine sampling (0.1 pixels) to catch thin strokes like the arch of 'h'
        let step: CGFloat = 0.1
        var samplesChecked = 0
        for y in stride(from: bounds.minY, through: bounds.maxY, by: step) {
            // Check if this point is inside the filled path
            if path.contains(CGPoint(x: x, y: y)) {
                // Found the top of the surface at this X
                return y
            }
            samplesChecked += 1
        }
        // If no intersection found within bounds, return far below
        print("  ❌ No path intersection at x=\(x), checked \(samplesChecked) samples")
        return bounds.maxY + 1000
    }

    /// Add snow at the given x position (returns false if rejected)
    /// Uses probabilistic stacking: always allowed up to 5px, increasingly unlikely 5-15px, hard cap at 15px
    /// When rejected, attempts to spread to neighboring columns with lower height
    /// If current stack is 2x higher than neighbor, spreads to neighbor instead
    func addSnow(at x: CGFloat, amount: CGFloat = 1.0, depth: Int = 0) -> Bool {
        let ix = Int(x - offsetX)
        guard ix >= 0 && ix < width else { return false }

        let currentHeight = heights[ix]

        // Hard cap at maxHeight
        if currentHeight >= maxHeight {
            // Try spreading to neighbors
            return trySpreadToNeighbors(ix: ix, currentHeight: currentHeight, depth: depth)
        }

        // Check if current stack is 2x higher than any neighbor that can support snow
        // If so, add to the shorter neighbor instead (but only for initial call to prevent infinite recursion)
        if depth == 0, let neighborIx = findBalancedNeighbor(ix: ix, currentHeight: currentHeight) {
            let neighborX = offsetX + CGFloat(neighborIx)
            return addSnow(at: neighborX, amount: amount, depth: depth + 1)
        }

        // Always allow stacking below comfortable height
        if currentHeight < comfortableHeight {
            heights[ix] = min(heights[ix] + amount, maxHeight)
            return true
        }

        // Above comfortable height: probabilistic stacking
        // Exponentially decreasing probability from 5 to 15
        let excessHeight = currentHeight - comfortableHeight
        let maxExcess = maxHeight - comfortableHeight  // 10 pixels
        let probability = pow(1.0 - (excessHeight / maxExcess), 3.0)  // Cubic falloff

        if CGFloat.random(in: 0...1) < probability {
            heights[ix] = min(heights[ix] + amount, maxHeight)
            return true
        }

        // Rejected by probability - try spreading to neighbors
        return trySpreadToNeighbors(ix: ix, currentHeight: currentHeight, depth: depth)
    }

    /// Find a neighbor to balance with if current stack is 2x higher
    /// Returns neighbor index if current height >= 2 * neighbor height and neighbor can support snow
    private func findBalancedNeighbor(ix: Int, currentHeight: CGFloat) -> Int? {
        var candidates: [(index: Int, height: CGFloat)] = []

        // Check left neighbor
        if ix > 0 {
            let leftHeight = heights[ix - 1]
            let leftBaseline = baselineYs[ix - 1]
            // Can support snow if baseline is reasonable (not far out of bounds)
            if leftBaseline < 1000 && currentHeight >= 2.0 * leftHeight {
                candidates.append((ix - 1, leftHeight))
            }
        }

        // Check right neighbor
        if ix < width - 1 {
            let rightHeight = heights[ix + 1]
            let rightBaseline = baselineYs[ix + 1]
            // Can support snow if baseline is reasonable (not far out of bounds)
            if rightBaseline < 1000 && currentHeight >= 2.0 * rightHeight {
                candidates.append((ix + 1, rightHeight))
            }
        }

        // If we have candidates, return the one with the smallest height
        if !candidates.isEmpty {
            return candidates.min(by: { $0.height < $1.height })?.index
        }

        return nil
    }

    /// Try to spread snow to neighboring columns with lower height
    private func trySpreadToNeighbors(ix: Int, currentHeight: CGFloat, depth: Int) -> Bool {
        var lowerNeighbors: [Int] = []

        // Check left neighbor
        if ix > 0 && heights[ix - 1] < currentHeight {
            lowerNeighbors.append(ix - 1)
        }

        // Check right neighbor
        if ix < width - 1 && heights[ix + 1] < currentHeight {
            lowerNeighbors.append(ix + 1)
        }

        // Spread to a random lower neighbor
        if !lowerNeighbors.isEmpty {
            let neighborIx = lowerNeighbors.randomElement()!
            let neighborX = offsetX + CGFloat(neighborIx)
            return addSnow(at: neighborX, amount: 1.0, depth: depth + 1)  // Add 1 pixel to neighbor
        }

        return false  // No valid neighbors, snow discarded
    }

    /// Erode a random snow column by 1 pixel (for natural melting effect)
    func erodeRandom() {
        // Find all columns with snow
        let snowyColumns = heights.indices.filter { heights[$0] > 0 }
        guard !snowyColumns.isEmpty else { return }

        // Pick a random snowy column and reduce by 1
        let randomIndex = snowyColumns.randomElement()!
        heights[randomIndex] = max(0, heights[randomIndex] - 1.0)
    }

    /// Get the height of snow at the given x position
    func heightAt(x: CGFloat) -> CGFloat {
        let ix = Int(x - offsetX)
        guard ix >= 0 && ix < width else { return 0 }
        return heights[ix]
    }

    /// Get the baseline Y (where snow lands) at the given x position
    func baselineY(at x: CGFloat) -> CGFloat {
        let ix = Int(x - offsetX)
        guard ix >= 0 && ix < width else { return 0 }
        return baselineYs[ix]
    }

    /// Get the Y position of the top of snow at the given x position
    func topY(at x: CGFloat) -> CGFloat {
        return baselineY(at: x) - heightAt(x: x)
    }

    /// Check if a point would collide with fallen snow (within surface bounds)
    func collides(x: CGFloat, y: CGFloat) -> Bool {
        // Check if x is within this surface's bounds
        guard x >= offsetX && x < offsetX + CGFloat(width) else { return false }

        let baseline = baselineY(at: x)
        let snowTop = topY(at: x)

        // Only collide if the snowflake is close to this surface's baseline at this X
        // Allow a small buffer (3 pixels) below the surface for collision detection
        return y >= snowTop && y <= baseline + 3
    }

    /// Reset all fallen snow
    func reset() {
        heights = Array(repeating: 0, count: width)
    }

    /// Update width when bounds change
    func updateWidth(_ newWidth: Int, bounds: CGRect, path: CGPath?, offsetX: CGFloat) {
        self.offsetX = offsetX
        if newWidth != width {
            // Resize arrays
            if newWidth > width {
                heights.append(contentsOf: Array(repeating: 0, count: newWidth - width))
                baselineYs.append(contentsOf: Array(repeating: 0, count: newWidth - width))
            } else {
                heights = Array(heights.prefix(newWidth))
                baselineYs = Array(baselineYs.prefix(newWidth))
            }
            width = newWidth
        }

        // Resample the path for baseline Ys
        for i in 0..<width {
            let x = offsetX + CGFloat(i)
            if let path = path {
                baselineYs[i] = findTopOfPathAt(x: x, path: path, bounds: bounds)
            } else {
                baselineYs[i] = bounds.minY
            }
        }
    }

    /// Get all heights for rendering
    func getHeights() -> [(x: CGFloat, height: CGFloat, baselineY: CGFloat)] {
        return heights.enumerated().compactMap { index, height in
            guard height > 0 else { return nil }
            return (x: CGFloat(index) + offsetX, height: height, baselineY: baselineYs[index])
        }
    }
}
