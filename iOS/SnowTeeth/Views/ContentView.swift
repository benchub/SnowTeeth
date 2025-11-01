//
//  ContentView.swift
//  SnowTeeth
//
//  Created by SnowTeeth
//

import SwiftUI

struct ContentView: View {
    @StateObject private var prefs = AppPreferences()
    @StateObject private var locationService: LocationTrackingService
    @StateObject private var snowEffect = SnowEffect()

    @State private var showConfiguration = false
    @State private var showVisualization = false
    @State private var showStats = false
    @State private var showShareSheet = false
    @State private var showResetConfirmation = false
    @State private var showStartTrackingConfirmation = false
    @State private var pendingVisualization = false
    @State private var capturedLetters: [Int: (char: Character, frame: CGRect)] = [:]

    init() {
        let preferences = AppPreferences()
        _prefs = StateObject(wrappedValue: preferences)
        _locationService = StateObject(wrappedValue: LocationTrackingService(prefs: preferences))
    }

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Dark grey background
                    Color(red: 0.17, green: 0.17, blue: 0.17) // #2C2C2C
                        .ignoresSafeArea()

                    // Determine if we're in landscape
                    let isLandscape = geometry.size.width > geometry.size.height

                    if isLandscape {
                        landscapeLayout(geometry: geometry)
                    } else {
                        portraitLayout(geometry: geometry)
                    }

                    // Snow effect overlay
                    SnowEffectView(snowEffect: snowEffect)

                    // Santa flying animation - randomizes position each flight
                    SantaView(
                        screenWidth: geometry.size.width,
                        screenHeight: geometry.size.height
                    )
                    .id("\(geometry.size.width)-\(geometry.size.height)")
                }
                .coordinateSpace(name: "snowCoordinateSpace")
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showConfiguration) {
                ConfigurationView(prefs: prefs)
            }
            .fullScreenCover(isPresented: $showVisualization) {
                VisualizationView(prefs: prefs, locationService: locationService)
            }
            .sheet(isPresented: $showStats) {
                StatsView(prefs: prefs, locationService: locationService)
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(
                    fileURL: locationService.getGpxFileURL(),
                    statisticsText: locationService.getGpxStatisticsSummary()
                )
            }
            .alert("Reset GPS Tracking Data", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetGPXData()
                }
            } message: {
                Text("This will reset your GPS tracking location and speed history. This action cannot be undone.")
            }
            .alert("Reset GPS Stats?", isPresented: $showStartTrackingConfirmation) {
                Button("Keep Existing", role: .cancel) {
                    startTrackingWithoutReset()
                }
                Button("Reset", role: .destructive) {
                    resetAndStartTracking()
                }
            } message: {
                Text("You have existing GPS data. Do you want to reset it and start fresh, or keep adding to the existing data?")
            }
            .onChange(of: showConfiguration) { _, newValue in
                if newValue {
                    // Pause animations when leaving home screen
                    snowEffect.pause()
                } else {
                    // Reset and resume when returning from configuration
                    snowEffect.reset()
                    snowEffect.resume()
                }
            }
            .onChange(of: showVisualization) { _, newValue in
                if newValue {
                    // Pause animations when leaving home screen
                    snowEffect.pause()
                } else {
                    // Reset and resume when returning from visualization
                    snowEffect.reset()
                    snowEffect.resume()
                }
            }
            .onChange(of: showStats) { _, newValue in
                if newValue {
                    // Pause animations when leaving home screen
                    snowEffect.pause()
                } else {
                    // Reset and resume when returning from stats
                    snowEffect.reset()
                    snowEffect.resume()
                }
            }
            .onAppear {
                locationService.requestLocationPermission()
            }
        }
    }

    @ViewBuilder
    private func portraitLayout(geometry: GeometryProxy) -> some View {
        VStack(spacing: 30) {
            Spacer()

            // Title
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

            // Buttons
            VStack(spacing: 20) {
                configurationButton()
                visualizationButton()
                statsButton()
                shareButton()
                resetButton()
                trackingButton()
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    @ViewBuilder
    private func landscapeLayout(geometry: GeometryProxy) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // Row 1: Title
            HStack(spacing: 0) {
                ForEach(Array("SnowTeeth".enumerated()), id: \.offset) { index, char in
                    Text(String(char))
                        .font(.title)
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

            // Row 2: Three blue buttons
            HStack(spacing: 32) {
                configurationButton()
                    .frame(width: 216)
                visualizationButton()
                    .frame(width: 216)
                statsButton()
                    .frame(width: 216)
            }

            // Row 3: Share, Reset, and Tracking buttons
            HStack(spacing: 32) {
                shareButton()
                    .frame(width: 216)
                resetButton()
                    .frame(width: 216)
                trackingButton()
                    .frame(width: 216)
            }

            Spacer()
        }
        .padding(16)
    }

    @ViewBuilder
    private func configurationButton() -> some View {
        Button(action: {
            showConfiguration = true
        }) {
            HomeButtonView(title: "Configuration", icon: "ic_btn_configuration")
                .overlay(
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    captureButtonBounds(id: "button_config", geometry: geometry)
                                }
                            }
                    }
                )
        }
    }

    @ViewBuilder
    private func visualizationButton() -> some View {
        Button(action: {
            // If tracking is off and there's existing data, prompt before enabling
            if !locationService.isTracking && hasTrackingData() {
                pendingVisualization = true
                showStartTrackingConfirmation = true
            } else {
                showVisualization = true
            }
        }) {
            HomeButtonView(title: "Visualization", icon: "ic_btn_visualization")
                .overlay(
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    captureButtonBounds(id: "button_viz", geometry: geometry)
                                }
                            }
                    }
                )
        }
    }

    @ViewBuilder
    private func statsButton() -> some View {
        Button(action: {
            showStats = true
        }) {
            HomeButtonView(title: "Stats", icon: "ic_btn_stats")
                .overlay(
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    captureButtonBounds(id: "button_stats", geometry: geometry)
                                }
                            }
                    }
                )
        }
    }

    @ViewBuilder
    private func shareButton() -> some View {
        Button(action: {
            shareGPXFile()
        }) {
            HomeButtonView(title: "Share GPX", icon: "ic_btn_share", backgroundColor: .purple)
                .overlay(
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    captureButtonBounds(id: "button_share", geometry: geometry)
                                }
                            }
                    }
                )
        }
        .disabled(!hasTrackingData())
    }

    @ViewBuilder
    private func resetButton() -> some View {
        Button(action: {
            showResetConfirmation = true
        }) {
            HomeButtonView(title: "Reset GPX", icon: "ic_btn_reset", backgroundColor: .orange)
                .overlay(
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    captureButtonBounds(id: "button_reset", geometry: geometry)
                                }
                            }
                    }
                )
        }
        .disabled(!hasTrackingData())
    }

    @ViewBuilder
    private func trackingButton() -> some View {
        Button(action: {
            // If trying to start tracking and there's existing data, prompt
            if !locationService.isTracking && hasTrackingData() {
                pendingVisualization = false
                showStartTrackingConfirmation = true
            } else {
                locationService.toggleTracking()
            }
        }) {
            HomeButtonView(
                title: locationService.isTracking ? "Stop Tracking" : "Start Tracking",
                icon: locationService.isTracking ? "ic_btn_stop" : "ic_btn_play",
                backgroundColor: locationService.isTracking ? .red : .green
            )
            .overlay(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                captureButtonBounds(id: "button_tracking", geometry: geometry)
                            }
                        }
                }
            )
        }
    }

    private func hasTrackingData() -> Bool {
        let fileURL = locationService.getGpxFileURL()
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    private func shareGPXFile() {
        if hasTrackingData() {
            showShareSheet = true
        }
    }

    private func resetGPXData() {
        do {
            try locationService.resetGpxTrack()
        } catch {
            errorLog("Error resetting GPX track: \(error)")
        }
    }

    private func startTrackingWithoutReset() {
        locationService.startTracking(resetData: false)
        if pendingVisualization {
            showVisualization = true
        }
    }

    private func resetAndStartTracking() {
        resetGPXData()
        locationService.startTracking(resetData: true)
        if pendingVisualization {
            showVisualization = true
        }
    }

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

            debugLog("📝 Captured \(letterBounds.count) letter bounds from SwiftUI frames")
            updateSnowEffectBounds(letterBounds: letterBounds, buttonBounds: [])
        }
    }

    private func captureButtonBounds(id: String, geometry: GeometryProxy) {
        // Use local coordinates relative to the ContentView's ZStack
        let localFrame = geometry.frame(in: .named("snowCoordinateSpace"))
        let bounds = (id: id, bounds: localFrame, path: nil as CGPath?)

        updateSnowEffectBounds(letterBounds: [], buttonBounds: [bounds])
    }

    @State private var allLetterBounds: [(id: String, bounds: CGRect, path: CGPath?)] = []
    @State private var allButtonBounds: [(id: String, bounds: CGRect, path: CGPath?)] = []

    private func updateSnowEffectBounds(letterBounds: [(id: String, bounds: CGRect, path: CGPath?)], buttonBounds: [(id: String, bounds: CGRect, path: CGPath?)]) {
        if !letterBounds.isEmpty {
            allLetterBounds = letterBounds
        }
        if !buttonBounds.isEmpty {
            // Update or add button bounds
            for newBound in buttonBounds {
                if let index = allButtonBounds.firstIndex(where: { $0.id == newBound.id }) {
                    allButtonBounds[index] = newBound
                } else {
                    allButtonBounds.append(newBound)
                }
            }
        }

        // Combine all bounds and pass to snow effect
        let allBounds = allLetterBounds + allButtonBounds
        snowEffect.setTargetBounds(allBounds)
    }
}

struct HomeButtonView: View {
    let title: String
    let icon: String
    var backgroundColor: Color = .blue

    var body: some View {
        ZStack {
            // Centered text
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            // Left-aligned icon
            HStack {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 20)
                    .foregroundColor(.white)
                    .padding(.leading, 20)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(backgroundColor)
        .cornerRadius(15)
    }
}

#Preview {
    ContentView()
}
