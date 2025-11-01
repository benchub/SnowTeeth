//
//  SantaView.swift
//  SnowTeeth
//
//  Santa flying animation
//

import SwiftUI

struct SantaView: View {
    @State private var santaPosition: CGFloat = -150  // Start off-screen left
    @State private var currentFrame: Int = 0
    @State private var isFlying: Bool = false
    @State private var lastFlyTime: Date = Date().addingTimeInterval(-8)  // Start with 8 second offset for 2 second delay
    @State private var flyingLeftToRight: Bool = true  // Randomized for each flight
    @State private var yPosition: CGFloat = 0  // Randomized for each flight (top 10% or bottom 10%)
    @State private var timer: Timer?

    let screenWidth: CGFloat
    let screenHeight: CGFloat

    private let santaFrames = ["MediumSantaRudolf1", "MediumSantaRudolf2", "MediumSantaRudolf3", "MediumSantaRudolf4"]

    var body: some View {
        Image(santaFrames[currentFrame])
            .resizable()
            .scaledToFit()
            .frame(width: 100, height: 100)
            .scaleEffect(x: flyingLeftToRight ? 1 : -1, y: 1)  // Flip horizontally if flying right-to-left
            .position(x: santaPosition, y: yPosition)
            .opacity(isFlying ? 1.0 : 0.0)
            .onAppear {
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }
    }

    private func startTimer() {
        stopTimer()  // Clean up any existing timer

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateAnimation()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateAnimation() {
        // Skip updates if screen dimensions are invalid (e.g., during rotation)
        guard screenWidth > 0, screenHeight > 0 else { return }

        if isFlying {
            // Cycle through sprite frames
            currentFrame = (currentFrame + 1) % santaFrames.count

            // Check if Santa is off-screen and animation time has elapsed
            let isOffScreen = flyingLeftToRight ? (santaPosition >= screenWidth + 150) : (santaPosition <= -150)
            if isOffScreen && Date().timeIntervalSince(lastFlyTime) > 8.0 {
                isFlying = false
            }
        }

        // Trigger flight every 42 seconds
        if !isFlying && Date().timeIntervalSince(lastFlyTime) >= 42.0 {
            startFlying()
        }
    }

    private func startFlying() {
        guard !isFlying, screenWidth > 0, screenHeight > 0 else {
            return
        }

        lastFlyTime = Date()
        isFlying = true
        currentFrame = 0

        // Randomize direction (left-to-right or right-to-left)
        flyingLeftToRight = Bool.random()

        // Randomize vertical position (top 10% or bottom 10%)
        yPosition = Bool.random()
            ? screenHeight * 0.05  // Top 10% (center at 5%)
            : screenHeight * 0.95  // Bottom 10% (center at 95%)

        // Set start and end positions based on direction
        let (startX, targetX): (CGFloat, CGFloat) = flyingLeftToRight
            ? (-150, screenWidth + 150)
            : (screenWidth + 150, -150)

        santaPosition = startX

        // Animate across screen
        withAnimation(.linear(duration: 8.0)) {
            santaPosition = targetX
        }
    }
}
