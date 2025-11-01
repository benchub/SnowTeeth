//
//  Snowflake.swift
//  SnowTeeth
//
//  Snow particle model
//

import Foundation
import CoreGraphics

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
            // Particles don't move when stuck
            break

        case .sliding(let direction):
            position.x += direction.dx * deltaTime * 100 // slide speed
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
