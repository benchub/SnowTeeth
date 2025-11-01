//
//  SnowEffectTests.swift
//  SnowTeethTests
//
//  Unit tests for snow effect core logic
//

import XCTest
import CoreGraphics
import UIKit
@testable import SnowTeeth

class SnowEffectTests: XCTestCase {

    // MARK: - Collision Detection Tests

    func testSnowflakeCollidesWithLetterTop() {
        let detector = CollisionDetector()
        let targetBounds = CGRect(x: 100, y: 200, width: 50, height: 60)
        let targets = [("letter_0", targetBounds)]

        var snowflake = Snowflake(
            position: CGPoint(x: 120, y: 198), // Just above top
            velocity: CGVector(dx: 0, dy: 20),
            size: 4,
            opacity: 1.0
        )

        let collision = detector.checkCollision(snowflake: snowflake, targets: targets)
        XCTAssertNotNil(collision, "Snowflake should collide with letter top")
        XCTAssertEqual(collision, "letter_0")
    }

    func testSnowflakePassesThroughGap() {
        let detector = CollisionDetector()
        let target1 = ("letter_0", CGRect(x: 50, y: 200, width: 40, height: 60))
        let target2 = ("letter_1", CGRect(x: 100, y: 200, width: 40, height: 60))
        let targets = [target1, target2]

        var snowflake = Snowflake(
            position: CGPoint(x: 95, y: 198), // In the gap between letters
            velocity: CGVector(dx: 0, dy: 20),
            size: 4,
            opacity: 1.0
        )

        let collision = detector.checkCollision(snowflake: snowflake, targets: targets)
        XCTAssertNil(collision, "Snowflake should pass through gap between letters")
    }

    func testSnowflakeNotCollidingWhenAbove() {
        let detector = CollisionDetector()
        let targetBounds = CGRect(x: 100, y: 200, width: 50, height: 60)
        let targets = [("letter_0", targetBounds)]

        var snowflake = Snowflake(
            position: CGPoint(x: 120, y: 180), // Well above top
            velocity: CGVector(dx: 0, dy: 20),
            size: 4,
            opacity: 1.0
        )

        let collision = detector.checkCollision(snowflake: snowflake, targets: targets)
        XCTAssertNil(collision, "Snowflake should not collide when well above target")
    }

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

        XCTAssertEqual(stickPos.x, 120, "X position should remain the same")
        XCTAssertEqual(stickPos.y, 196, "Y should be top of target minus snowflake size (200 - 4)")
    }

    // MARK: - Letter Bounds Tests

    func testLetterBoundsCalculation() {
        let calculator = LetterBoundsCalculator()
        let font = UIFont.systemFont(ofSize: 34, weight: .bold)
        let position = CGPoint(x: 100, y: 100)

        let bounds = calculator.calculateBounds(text: "Hi", font: font, position: position)

        XCTAssertEqual(bounds.count, 2, "Should have bounds for 2 letters")
        XCTAssertEqual(bounds[0].id, "letter_0", "First letter should have ID letter_0")
        XCTAssertEqual(bounds[1].id, "letter_1", "Second letter should have ID letter_1")

        // First letter should start at position
        XCTAssertEqual(bounds[0].bounds.origin.x, 100)
        XCTAssertEqual(bounds[0].bounds.origin.y, 100)

        // Second letter should start after first letter
        XCTAssertGreaterThan(bounds[1].bounds.origin.x, bounds[0].bounds.maxX - 1)
    }

    func testSnowTeethLetterCount() {
        let calculator = LetterBoundsCalculator()
        let font = UIFont.systemFont(ofSize: 34, weight: .bold)
        let position = CGPoint(x: 0, y: 0)

        let bounds = calculator.calculateBounds(text: "SnowTeeth", font: font, position: position)

        XCTAssertEqual(bounds.count, 9, "SnowTeeth has 9 letters")
    }

    // MARK: - Gravity Calculator Tests

    func testGravityPortrait() {
        let calculator = GravityCalculator()
        let gravity = calculator.gravityVector(for: .portrait)

        XCTAssertEqual(gravity.dx, 0, "Portrait gravity should have no horizontal component")
        XCTAssertEqual(gravity.dy, 1, "Portrait gravity should point down")
    }

    func testGravityLandscapeLeft() {
        let calculator = GravityCalculator()
        let gravity = calculator.gravityVector(for: .landscapeLeft)

        XCTAssertEqual(gravity.dx, 1, "Landscape left gravity should point right")
        XCTAssertEqual(gravity.dy, 0, "Landscape left gravity should have no vertical component")
    }

    func testGravityLandscapeRight() {
        let calculator = GravityCalculator()
        let gravity = calculator.gravityVector(for: .landscapeRight)

        XCTAssertEqual(gravity.dx, -1, "Landscape right gravity should point left")
        XCTAssertEqual(gravity.dy, 0, "Landscape right gravity should have no vertical component")
    }

    func testGravityUpsideDown() {
        let calculator = GravityCalculator()
        let gravity = calculator.gravityVector(for: .portraitUpsideDown)

        XCTAssertEqual(gravity.dx, 0, "Upside down gravity should have no horizontal component")
        XCTAssertEqual(gravity.dy, -1, "Upside down gravity should point up")
    }

    func testSlideDirection() {
        let calculator = GravityCalculator()
        let oldGravity = CGVector(dx: 0, dy: 1) // Portrait
        let newGravity = CGVector(dx: 1, dy: 0) // Landscape left

        let slideDir = calculator.slideDirection(from: oldGravity, to: newGravity)

        XCTAssertEqual(slideDir.dx, 1, "Slide direction should match new gravity")
        XCTAssertEqual(slideDir.dy, 0)
    }

    // MARK: - Particle State Tests

    func testParticleInitialState() {
        let snowflake = Snowflake(
            position: CGPoint(x: 100, y: 100),
            velocity: CGVector(dx: 0, dy: 20),
            size: 4,
            opacity: 1.0
        )

        XCTAssertEqual(snowflake.state, .falling, "Particle should start in falling state")
    }

    func testParticleUpdatePosition() {
        var snowflake = Snowflake(
            position: CGPoint(x: 100, y: 100),
            velocity: CGVector(dx: 5, dy: 20),
            size: 4,
            opacity: 1.0
        )

        snowflake.update(deltaTime: 1.0) // 1 second

        XCTAssertEqual(snowflake.position.x, 105, "X should move by velocity.dx * deltaTime")
        XCTAssertEqual(snowflake.position.y, 120, "Y should move by velocity.dy * deltaTime")
    }

    func testParticleStuckDoesNotMove() {
        var snowflake = Snowflake(
            position: CGPoint(x: 100, y: 100),
            velocity: CGVector(dx: 5, dy: 20),
            size: 4,
            opacity: 1.0
        )
        snowflake.state = .stuck(to: "letter_0")

        snowflake.update(deltaTime: 1.0)

        XCTAssertEqual(snowflake.position.x, 100, "Stuck particle should not move")
        XCTAssertEqual(snowflake.position.y, 100, "Stuck particle should not move")
    }

    func testParticleSlidingMoves() {
        var snowflake = Snowflake(
            position: CGPoint(x: 100, y: 100),
            velocity: CGVector(dx: 5, dy: 20),
            size: 4,
            opacity: 1.0
        )
        snowflake.state = .sliding(direction: CGVector(dx: 1, dy: 0))

        snowflake.update(deltaTime: 1.0)

        XCTAssertEqual(snowflake.position.x, 200, "Sliding particle should move in slide direction (100 points/sec)")
        XCTAssertEqual(snowflake.position.y, 100, "Sliding should only move in slide direction")
    }

    func testParticleOffscreen() {
        var snowflake = Snowflake(
            position: CGPoint(x: 100, y: 900),
            velocity: CGVector(dx: 0, dy: 20),
            size: 4,
            opacity: 1.0
        )

        let isOffscreen = snowflake.isOffscreen(screenHeight: 800, screenWidth: 400)
        XCTAssertTrue(isOffscreen, "Particle below screen should be offscreen")
    }
}
