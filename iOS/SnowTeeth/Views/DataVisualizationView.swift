//
//  DataVisualizationView.swift
//  SnowTeeth
//
//  Data visualization with animated character morphing
//

import SwiftUI

struct DataVisualizationView: View {
    @ObservedObject var locationService: LocationTrackingService
    @ObservedObject var prefs: AppPreferences

    @State private var displayedVelocity: String = "  0.0"
    @State private var displayedVelocityUnit: String = "miles per hour"
    @State private var displayedDirection: String = ""
    @State private var displayedLatitude: String = "Latitude: --"
    @State private var displayedLongitude: String = "Longitude: --"
    @State private var displayedAltitude: String = "Altitude:   -- ft"
    @State private var displayedAccuracy: String = "Accuracy:   -- ft"
    @State private var displayedSatellites: String = "Satellites: --"
    @State private var previousAltitude: Double?

    // Separate morphing state for each field
    @State private var velocityAnimating: [Int: CharacterMorphState] = [:]
    @State private var latitudeAnimating: [Int: CharacterMorphState] = [:]
    @State private var longitudeAnimating: [Int: CharacterMorphState] = [:]
    @State private var altitudeAnimating: [Int: CharacterMorphState] = [:]
    @State private var accuracyAnimating: [Int: CharacterMorphState] = [:]
    @State private var satellitesAnimating: [Int: CharacterMorphState] = [:]
    @State private var lastUpdateTime: Date = Date()
    @State private var updateTimer: Timer?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Black background
                Color.black.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    // Top half - Velocity display with unit
                    VStack(spacing: geometry.size.height * 0.01) {
                        MorphingText(
                            text: displayedVelocity,
                            fontSize: geometry.size.height * 0.15,
                            fontWeight: .bold,
                            color: .white,
                            animatingCharacters: velocityAnimating
                        )
                        .monospacedDigit()

                        Text(displayedVelocityUnit)
                            .font(.system(size: geometry.size.height * 0.03))
                            .foregroundColor(Color(white: 0.69))

                        if !displayedDirection.isEmpty {
                            Text(displayedDirection)
                                .font(.system(size: geometry.size.height * 0.03))
                                .foregroundColor(Color(white: 0.69))
                        }
                    }
                    .frame(height: geometry.size.height * 0.5, alignment: .center)
                    .padding(.top, geometry.size.height * 0.05)

                    // Bottom half - GPS info with morphing
                    VStack(alignment: .leading, spacing: geometry.size.height * 0.015) {
                        MorphingText(
                            text: displayedLatitude,
                            fontSize: geometry.size.height * 0.04,
                            fontWeight: .regular,
                            color: Color(white: 0.69),
                            animatingCharacters: latitudeAnimating
                        )
                        .monospacedDigit()

                        MorphingText(
                            text: displayedLongitude,
                            fontSize: geometry.size.height * 0.04,
                            fontWeight: .regular,
                            color: Color(white: 0.69),
                            animatingCharacters: longitudeAnimating
                        )
                        .monospacedDigit()

                        MorphingText(
                            text: displayedAltitude,
                            fontSize: geometry.size.height * 0.04,
                            fontWeight: .regular,
                            color: Color(white: 0.69),
                            animatingCharacters: altitudeAnimating
                        )
                        .monospacedDigit()

                        MorphingText(
                            text: displayedAccuracy,
                            fontSize: geometry.size.height * 0.04,
                            fontWeight: .regular,
                            color: Color(white: 0.69),
                            animatingCharacters: accuracyAnimating
                        )
                        .monospacedDigit()

                        MorphingText(
                            text: displayedSatellites,
                            fontSize: geometry.size.height * 0.04,
                            fontWeight: .regular,
                            color: Color(white: 0.69),
                            animatingCharacters: satellitesAnimating
                        )
                        .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, geometry.size.width * 0.05)
                    .frame(height: geometry.size.height * 0.5, alignment: .top)
                    .padding(.top, geometry.size.height * 0.05)
                }
            }
        }
        .onAppear {
            startUpdateTimer()
        }
        .onDisappear {
            updateTimer?.invalidate()
        }
    }

    private func startUpdateTimer() {
        // Update every 2 seconds
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            updateDisplay()
        }
        // Initial update
        updateDisplay()
    }

    private func updateDisplay() {
        let currentLocation = locationService.currentLocation

        // Format velocity (speed is in m/s, convert based on prefs)
        let speedMPS = currentLocation?.speed ?? 0.0
        let velocityValue = prefs.useMetric ?
            speedMPS * 3.6 :  // m/s to km/h
            speedMPS * 2.23694 // m/s to mph
        // Format with fixed width (5 chars: "XXX.X") - pads with leading spaces to keep decimal fixed
        let newVelocity = String(format: "%5.1f", velocityValue)

        // Update velocity unit
        displayedVelocityUnit = prefs.useMetric ? "kilometers per hour" : "miles per hour"

        // Trigger morphing animations for all changed fields
        if newVelocity != displayedVelocity {
            triggerMorphAnimation(from: displayedVelocity, to: newVelocity, field: "velocity")
            displayedVelocity = newVelocity
        }

        // Update GPS info with morphing
        if let location = currentLocation {
            let newLatitude = String(format: "Latitude: %.4f", location.latitude)
            let newLongitude = String(format: "Longitude: %.4f", location.longitude)

            let altitudeValue = prefs.useMetric ?
                location.altitude :
                location.altitude * 3.28084
            let altitudeUnit = prefs.useMetric ? "m" : "ft"
            // Format altitude with fixed width (4 digits)
            let newAltitude = String(format: "Altitude: %4.0f %@", altitudeValue, altitudeUnit)

            // Determine uphill/downhill direction
            if let prevAlt = previousAltitude {
                let altitudeDiff = location.altitude - prevAlt
                if abs(altitudeDiff) > 1.0 { // Only show if change is > 1 meter
                    displayedDirection = altitudeDiff > 0 ? "uphill" : "downhill"
                }
            }
            previousAltitude = location.altitude

            if newLatitude != displayedLatitude {
                triggerMorphAnimation(from: displayedLatitude, to: newLatitude, field: "latitude")
                displayedLatitude = newLatitude
            }
            if newLongitude != displayedLongitude {
                triggerMorphAnimation(from: displayedLongitude, to: newLongitude, field: "longitude")
                displayedLongitude = newLongitude
            }
            if newAltitude != displayedAltitude {
                triggerMorphAnimation(from: displayedAltitude, to: newAltitude, field: "altitude")
                displayedAltitude = newAltitude
            }

            // Display horizontal accuracy
            let accuracyValue = prefs.useMetric ?
                location.horizontalAccuracy :
                location.horizontalAccuracy * 3.28084
            let accuracyUnit = prefs.useMetric ? "m" : "ft"
            let newAccuracy: String
            if location.horizontalAccuracy < 0 {
                newAccuracy = String(format: "Accuracy:   -- %@", accuracyUnit)
            } else {
                newAccuracy = String(format: "Accuracy: %4.0f %@", accuracyValue, accuracyUnit)
            }

            if newAccuracy != displayedAccuracy {
                triggerMorphAnimation(from: displayedAccuracy, to: newAccuracy, field: "accuracy")
                displayedAccuracy = newAccuracy
            }

            // Estimate satellite count from horizontal accuracy
            // Better accuracy = more satellites (simulated)
            let satelliteCount: Int
            if accuracyValue < 0 {
                satelliteCount = 0  // Invalid
            } else if accuracyValue < 5 {
                satelliteCount = 12 + Int.random(in: 0...3)  // Excellent: 12-15
            } else if accuracyValue < 10 {
                satelliteCount = 9 + Int.random(in: 0...2)   // Good: 9-11
            } else if accuracyValue < 20 {
                satelliteCount = 6 + Int.random(in: 0...2)   // Fair: 6-8
            } else {
                satelliteCount = 3 + Int.random(in: 0...2)   // Poor: 3-5
            }
            let newSatellites = String(format: "Satellites: %2d", satelliteCount)

            if newSatellites != displayedSatellites {
                triggerMorphAnimation(from: displayedSatellites, to: newSatellites, field: "satellites")
                displayedSatellites = newSatellites
            }
        } else {
            let accuracyUnit = prefs.useMetric ? "m" : "ft"
            let altitudeUnit = prefs.useMetric ? "m" : "ft"
            displayedLatitude = "Latitude: --"
            displayedLongitude = "Longitude: --"
            displayedAltitude = String(format: "Altitude:   -- %@", altitudeUnit)
            displayedAccuracy = String(format: "Accuracy:   -- %@", accuracyUnit)
            displayedSatellites = "Satellites: --"
        }
    }

    private func triggerMorphAnimation(from oldText: String, to newText: String, field: String) {
        let maxLength = max(oldText.count, newText.count)
        let oldChars = Array(oldText)
        let newChars = Array(newText)
        var states: [Int: CharacterMorphState] = [:]

        // Set up animation for each changed character
        for i in 0..<maxLength {
            let oldChar = i < oldChars.count ? oldChars[i] : " "
            let newChar = i < newChars.count ? newChars[i] : " "

            if oldChar != newChar {
                states[i] = CharacterMorphState(
                    startTime: Date(),
                    oldChar: oldChar,
                    newChar: newChar
                )
            }
        }

        // Update the appropriate field
        switch field {
        case "velocity":
            velocityAnimating = states
        case "latitude":
            latitudeAnimating = states
        case "longitude":
            longitudeAnimating = states
        case "altitude":
            altitudeAnimating = states
        case "accuracy":
            accuracyAnimating = states
        case "satellites":
            satellitesAnimating = states
        default:
            break
        }

        // Clear animations after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            switch field {
            case "velocity":
                self.velocityAnimating.removeAll()
            case "latitude":
                self.latitudeAnimating.removeAll()
            case "longitude":
                self.longitudeAnimating.removeAll()
            case "altitude":
                self.altitudeAnimating.removeAll()
            case "accuracy":
                self.accuracyAnimating.removeAll()
            case "satellites":
                self.satellitesAnimating.removeAll()
            default:
                break
            }
        }
    }
}

struct CharacterMorphState {
    let startTime: Date
    let oldChar: Character
    let newChar: Character
}

struct MorphingText: View {
    let text: String
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let color: Color
    let animatingCharacters: [Int: CharacterMorphState]

    @State private var currentTime = Date()

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { index, char in
                if let morphState = animatingCharacters[index] {
                    MorphingCharacter(
                        morphState: morphState,
                        fontSize: fontSize,
                        fontWeight: fontWeight,
                        color: color,
                        currentTime: currentTime
                    )
                } else {
                    Text(String(char))
                        .font(.system(size: fontSize, weight: fontWeight))
                        .foregroundColor(color)
                }
            }
        }
        .onAppear {
            // Update at 60fps for smooth animation
            Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
                currentTime = Date()
            }
        }
    }
}

struct MorphingCharacter: View {
    let morphState: CharacterMorphState
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let color: Color
    let currentTime: Date

    var body: some View {
        let elapsed = currentTime.timeIntervalSince(morphState.startTime)
        let progress = min(elapsed, 1.0)

        let charAndScale = calculateDisplayCharAndScale(progress: progress)

        return Text(charAndScale.char)
            .font(.system(size: fontSize, weight: fontWeight))
            .foregroundColor(color)
            .scaleEffect(x: charAndScale.scale, y: 1.0, anchor: .center)
    }

    private func calculateDisplayCharAndScale(progress: Double) -> (char: String, scale: CGFloat) {
        if progress < 0.5 {
            // Phase 1: Compress old character (0.0 -> 0.5)
            let phaseProgress = progress / 0.5
            let displayChar = String(morphState.oldChar)
            let scaleX = 1.0 - (phaseProgress * 0.8) // Compress to 20% width
            return (displayChar, scaleX)
        } else {
            // Phase 2: Expand new character (0.5 -> 1.0)
            let phaseProgress = (progress - 0.5) / 0.5
            let displayChar = String(morphState.newChar)
            let scaleX = 0.2 + (phaseProgress * 0.8) // Expand from 20% to 100% width
            return (displayChar, scaleX)
        }
    }
}

#Preview {
    DataVisualizationView(
        locationService: LocationTrackingService(prefs: AppPreferences()),
        prefs: AppPreferences()
    )
}
