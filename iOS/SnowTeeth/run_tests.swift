#!/usr/bin/env swift

// Standalone test runner for snow effect logic
// Run with: swift run_tests.swift

import Foundation
import CoreGraphics

// MARK: - Copy of implementation code

enum ParticleState: Equatable {
    case falling
    case stuck(to: String)
    case sliding(direction: CGVector)
    case gone
}

struct Snowflake {
    var position: CGPoint
    var velocity: CGVector
    var size: CGFloat
    var opacity: Float
    var state: ParticleState

    init(position: CGPoint, velocity: CGVector, size: CGFloat, opacity: Float) {
        self.position = position
        self.velocity = velocity
        self.size = size
        self.opacity = opacity
        self.state = .falling
    }

    mutating func update(deltaTime: TimeInterval) {
        switch state {
        case .falling:
            position.x += velocity.dx * deltaTime
            position.y += velocity.dy * deltaTime

        case .stuck:
            break

        case .sliding(let direction):
            position.x += direction.dx * deltaTime * 100
            position.y += direction.dy * deltaTime * 100

        case .gone:
            break
        }
    }

    func isOffscreen(screenHeight: CGFloat, screenWidth: CGFloat) -> Bool {
        return position.y > screenHeight + size ||
               position.x < -size ||
               position.x > screenWidth + size
    }
}

class CollisionDetector {

    private let stickThreshold: CGFloat

    init(stickThreshold: CGFloat = 2.0) {
        self.stickThreshold = stickThreshold
    }

    func checkCollision(
        snowflake: Snowflake,
        targets: [(id: String, bounds: CGRect)]
    ) -> String? {
        guard snowflake.state == .falling else {
            return nil
        }

        let snowBottom = snowflake.position.y + snowflake.size

        for target in targets {
            let bounds = target.bounds

            if snowBottom >= bounds.minY - stickThreshold {
                if snowflake.position.x >= bounds.minX &&
                   snowflake.position.x <= bounds.maxX {
                    return target.id
                }
            }
        }

        return nil
    }

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

// MARK: - Test Assertions

var testsPassed = 0
var testsFailed = 0

func assert(_ condition: Bool, _ message: String) {
    if !condition {
        print("❌ FAIL: \(message)")
        testsFailed += 1
    } else {
        print("✅ PASS: \(message)")
        testsPassed += 1
    }
}

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
    if actual != expected {
        print("❌ FAIL: \(message)")
        print("   Expected: \(expected)")
        print("   Actual: \(actual)")
        testsFailed += 1
    } else {
        print("✅ PASS: \(message)")
        testsPassed += 1
    }
}

func assertNil<T>(_ value: T?, _ message: String) {
    if value != nil {
        print("❌ FAIL: \(message)")
        print("   Expected: nil")
        print("   Actual: \(String(describing: value))")
        testsFailed += 1
    } else {
        print("✅ PASS: \(message)")
        testsPassed += 1
    }
}

func assertNotNil<T>(_ value: T?, _ message: String) {
    if value == nil {
        print("❌ FAIL: \(message)")
        print("   Expected: not nil")
        print("   Actual: nil")
        testsFailed += 1
    } else {
        print("✅ PASS: \(message)")
        testsPassed += 1
    }
}

// MARK: - Run Tests

print("Running Snow Effect Tests...")
print(String(repeating: "=", count: 50))
print()

// Test 1: Snowflake collides with letter top
func testSnowflakeCollidesWithLetterTop() {
    let detector = CollisionDetector()
    let targetBounds = CGRect(x: 100, y: 200, width: 50, height: 60)
    let targets = [("letter_0", targetBounds)]

    let snowflake = Snowflake(
        position: CGPoint(x: 120, y: 198),
        velocity: CGVector(dx: 0, dy: 20),
        size: 4,
        opacity: 1.0
    )

    let collision = detector.checkCollision(snowflake: snowflake, targets: targets)
    assertNotNil(collision, "Snowflake should collide with letter top")
    if let collision = collision {
        assertEqual(collision, "letter_0", "Should collide with letter_0")
    }
}

// Test 2: Snowflake passes through gap
func testSnowflakePassesThroughGap() {
    let detector = CollisionDetector()
    let target1 = ("letter_0", CGRect(x: 50, y: 200, width: 40, height: 60))
    let target2 = ("letter_1", CGRect(x: 100, y: 200, width: 40, height: 60))
    let targets = [target1, target2]

    let snowflake = Snowflake(
        position: CGPoint(x: 95, y: 198),
        velocity: CGVector(dx: 0, dy: 20),
        size: 4,
        opacity: 1.0
    )

    let collision = detector.checkCollision(snowflake: snowflake, targets: targets)
    assertNil(collision, "Snowflake should pass through gap between letters")
}

// Test 3: Snowflake not colliding when above
func testSnowflakeNotCollidingWhenAbove() {
    let detector = CollisionDetector()
    let targetBounds = CGRect(x: 100, y: 200, width: 50, height: 60)
    let targets = [("letter_0", targetBounds)]

    let snowflake = Snowflake(
        position: CGPoint(x: 120, y: 180),
        velocity: CGVector(dx: 0, dy: 20),
        size: 4,
        opacity: 1.0
    )

    let collision = detector.checkCollision(snowflake: snowflake, targets: targets)
    assertNil(collision, "Snowflake should not collide when well above target")
}

// Test 4: Stick position calculation
func testStickPositionCalculation() {
    let detector = CollisionDetector()
    let targetBounds = CGRect(x: 100, y: 200, width: 50, height: 60)

    let snowflake = Snowflake(
        position: CGPoint(x: 120, y: 198),
        velocity: CGVector(dx: 0, dy: 20),
        size: 4,
        opacity: 1.0
    )

    let stickPos = detector.calculateStickPosition(snowflake: snowflake, targetBounds: targetBounds)

    assertEqual(stickPos.x, 120, "X position should remain the same")
    assertEqual(stickPos.y, 196, "Y should be top of target minus snowflake size (200 - 4)")
}

// Test 5: Particle initial state
func testParticleInitialState() {
    let snowflake = Snowflake(
        position: CGPoint(x: 100, y: 100),
        velocity: CGVector(dx: 0, dy: 20),
        size: 4,
        opacity: 1.0
    )

    assertEqual(snowflake.state, .falling, "Particle should start in falling state")
}

// Test 6: Particle update position
func testParticleUpdatePosition() {
    var snowflake = Snowflake(
        position: CGPoint(x: 100, y: 100),
        velocity: CGVector(dx: 5, dy: 20),
        size: 4,
        opacity: 1.0
    )

    snowflake.update(deltaTime: 1.0)

    assertEqual(snowflake.position.x, 105, "X should move by velocity.dx * deltaTime")
    assertEqual(snowflake.position.y, 120, "Y should move by velocity.dy * deltaTime")
}

// Test 7: Stuck particle doesn't move
func testParticleStuckDoesNotMove() {
    var snowflake = Snowflake(
        position: CGPoint(x: 100, y: 100),
        velocity: CGVector(dx: 5, dy: 20),
        size: 4,
        opacity: 1.0
    )
    snowflake.state = .stuck(to: "letter_0")

    snowflake.update(deltaTime: 1.0)

    assertEqual(snowflake.position.x, 100, "Stuck particle should not move")
    assertEqual(snowflake.position.y, 100, "Stuck particle should not move")
}

// Test 8: Sliding particle moves
func testParticleSlidingMoves() {
    var snowflake = Snowflake(
        position: CGPoint(x: 100, y: 100),
        velocity: CGVector(dx: 5, dy: 20),
        size: 4,
        opacity: 1.0
    )
    snowflake.state = .sliding(direction: CGVector(dx: 1, dy: 0))

    snowflake.update(deltaTime: 1.0)

    assertEqual(snowflake.position.x, 200, "Sliding particle should move in slide direction (100 points/sec)")
    assertEqual(snowflake.position.y, 100, "Sliding should only move in slide direction")
}

// Test 9: Particle offscreen detection
func testParticleOffscreen() {
    let snowflake = Snowflake(
        position: CGPoint(x: 100, y: 900),
        velocity: CGVector(dx: 0, dy: 20),
        size: 4,
        opacity: 1.0
    )

    let isOffscreen = snowflake.isOffscreen(screenHeight: 800, screenWidth: 400)
    assert(isOffscreen, "Particle below screen should be offscreen")
}

// Run all tests
print("Collision Detection Tests:")
print(String(repeating: "-", count: 50))
testSnowflakeCollidesWithLetterTop()
testSnowflakePassesThroughGap()
testSnowflakeNotCollidingWhenAbove()
testStickPositionCalculation()

print()
print("Particle State Tests:")
print(String(repeating: "-", count: 50))
testParticleInitialState()
testParticleUpdatePosition()
testParticleStuckDoesNotMove()
testParticleSlidingMoves()
testParticleOffscreen()

// Summary
print()
print(String(repeating: "=", count: 50))
print("Test Results:")
print("  ✅ Passed: \(testsPassed)")
print("  ❌ Failed: \(testsFailed)")
print("  Total: \(testsPassed + testsFailed)")
print()

if testsFailed == 0 {
    print("🎉 All tests passed!")
    exit(0)
} else {
    print("💥 Some tests failed!")
    exit(1)
}
