//
//  ContentView.swift
//  Flame
//
//  Main view for the macOS fire shader app
//

import SwiftUI

struct ContentView: View {
    @State private var speed: Float = 0.2
    @State private var intensity: Float = 1.5
    @State private var height: Float = 1.0
    @State private var turbulence: Float = 0.5
    @State private var detail: Float = 0.5
    @State private var colorShift: Float = 1.0
    @State private var baseWidth: Float = 1.0
    @State private var taper: Float = 0.3
    @State private var twist: Float = 0.0
    @State private var frequency: Float = 2.0
    @State private var showSliders = false
    @State private var showPresets = false
    @State private var showGrid = true  // Start with grid visible
    @State private var showPerformanceStats = false
    @State private var isCycling = false
    @State private var cycleTimer: Timer?

    // Lock states for each parameter
    @State private var speedLocked = false
    @State private var intensityLocked = false
    @State private var heightLocked = false
    @State private var turbulenceLocked = false
    @State private var detailLocked = false
    @State private var colorShiftLocked = false
    @State private var baseWidthLocked = false
    @State private var taperLocked = false
    @State private var twistLocked = false
    @State private var frequencyLocked = false

    // Remembered preset values
    @State private var rememberedSpeed: Float?
    @State private var rememberedIntensity: Float?
    @State private var rememberedHeight: Float?
    @State private var rememberedTurbulence: Float?
    @State private var rememberedDetail: Float?
    @State private var rememberedColorShift: Float?
    @State private var rememberedBaseWidth: Float?
    @State private var rememberedTaper: Float?
    @State private var rememberedTwist: Float?
    @State private var rememberedFrequency: Float?

    // Preset values - single source of truth
    private struct PresetValues {
        let speed: Float
        let intensity: Float
        let height: Float
        let turbulence: Float
        let detail: Float
        let colorShift: Float
        let baseWidth: Float
        let taper: Float
        let twist: Float
        let frequency: Float
    }

    private let idlePreset = PresetValues(
        speed: 0.22, intensity: 0.8, height: 0.5, turbulence: 0.8,
        detail: 0.8, colorShift: 0.7, baseWidth: 0.6, taper: 0.2,
        twist: 0.44, frequency: 1.5
    )

    private let easyPreset = PresetValues(
        speed: 0.52, intensity: 1.5, height: 0.93, turbulence: 0.71,
        detail: 0.8, colorShift: 1.0, baseWidth: 1.0, taper: 0.3,
        twist: 0.27, frequency: 1.5
    )

    private let mediumPreset = PresetValues(
        speed: 0.54, intensity: 2.06, height: 1.13, turbulence: 1.01,
        detail: 0.8, colorShift: 1.15, baseWidth: 1.23, taper: 0.26,
        twist: 0.96, frequency: 1.5
    )

    private let hardPreset = PresetValues(
        speed: 1.16, intensity: 2.36, height: 1.23, turbulence: 1.12,
        detail: 0.8, colorShift: 0.5, baseWidth: 1.12, taper: 0.87,
        twist: 0.0, frequency: 1.5
    )

    var body: some View {
        HStack(spacing: 0) {
            // Left panel - Presets
            if showPresets {
                presetsPanel
                    .transition(.move(edge: .leading))
            }

            // Center - Fire shader
            ZStack {
                FireShaderHostingView(
                    speed: $speed,
                    intensity: $intensity,
                    height: $height,
                    turbulence: $turbulence,
                    detail: $detail,
                    colorShift: $colorShift,
                    baseWidth: $baseWidth,
                    taper: $taper,
                    twist: $twist,
                    frequency: $frequency,
                    showPerformanceStats: $showPerformanceStats
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(
                    GeometryReader { geometry in
                        if showGrid {
                            CoordinateGridOverlay(height: geometry.size.height)
                        }
                    }
                )

                // Top left - Grid toggle and performance stats
                VStack {
                    HStack(spacing: 8) {
                        Button(action: {
                            withAnimation {
                                showGrid.toggle()
                            }
                        }) {
                            Image(systemName: showGrid ? "grid" : "grid.slash")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(12)
                                .background(.black.opacity(0.3))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .help("Toggle Grid")

                        Button(action: {
                            showPerformanceStats.toggle()
                        }) {
                            Image(systemName: showPerformanceStats ? "gauge.high" : "gauge.low")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(12)
                                .background(.black.opacity(0.3))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .help("Toggle Performance Stats (FPS, CPU, GPU timing)")
                        Spacer()
                    }
                    .padding(16)
                    Spacer()
                }

                // Left side - Presets toggle button
                VStack {
                    HStack {
                        VStack(spacing: 12) {
                            Spacer()
                            Button(action: { withAnimation { showPresets.toggle() } }) {
                                Image(systemName: showPresets ? "chevron.left" : "flame.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Toggle Presets")
                            Spacer()
                        }
                        .padding(.leading, showPresets ? 8 : 16)
                        Spacer()
                    }
                    Spacer()
                }

                // Right side - Sliders toggle button
                VStack {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Spacer()
                            Button(action: { withAnimation { showSliders.toggle() } }) {
                                Image(systemName: showSliders ? "chevron.right" : "slider.horizontal.3")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Toggle Controls")
                            Spacer()
                        }
                        .padding(.trailing, showSliders ? 8 : 16)
                    }
                    Spacer()
                }
            }

            // Right panel - Sliders
            if showSliders {
                slidersPanel
                    .transition(.move(edge: .trailing))
            }
        }
        .background(Color.black)
    }

    private var slidersPanel: some View {
        VStack(spacing: 0) {
            // Header
            Text("🎛️ Controls")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.top, 24)
                .padding(.bottom, 20)

            // Scrollable controls
            ScrollView {
                VStack(spacing: 18) {
                    SliderControl(
                        value: $speed,
                        locked: $speedLocked,
                        label: "Speed",
                        range: 0.1...2.0,
                        tooltip: "Controls how fast the fire animates"
                    )

                    SliderControl(
                        value: $intensity,
                        locked: $intensityLocked,
                        label: "Intensity",
                        range: 0.5...3.0,
                        tooltip: "Controls the brightness of the flames"
                    )

                    SliderControl(
                        value: $height,
                        locked: $heightLocked,
                        label: "Height",
                        range: 0.1...2.0,
                        tooltip: "Controls how tall the flames reach"
                    )

                    SliderControl(
                        value: $turbulence,
                        locked: $turbulenceLocked,
                        label: "Turbulence",
                        range: 0.5...2.0,
                        tooltip: "Controls the chaos and amplitude of flame motion"
                    )

                    SliderControl(
                        value: $detail,
                        locked: $detailLocked,
                        label: "Detail",
                        range: 0.5...2.0,
                        tooltip: "Controls amount of fine detail: low=smooth, high=intricate",
                        showWarning: true
                    )

                    SliderControl(
                        value: $colorShift,
                        locked: $colorShiftLocked,
                        label: "Temperature",
                        range: 0.5...2.0,
                        tooltip: "Flame temperature: red → orange → yellow → green → cyan → blue → white"
                    )

                    SliderControl(
                        value: $baseWidth,
                        locked: $baseWidthLocked,
                        label: "Base Width",
                        range: 0.3...2.0,
                        tooltip: "Controls the width of the flame at the base"
                    )

                    SliderControl(
                        value: $taper,
                        locked: $taperLocked,
                        label: "Taper",
                        range: 0.0...1.0,
                        tooltip: "Cone shape: 0=point at top, 0.5=cylinder, 1=wide top"
                    )

                    SliderControl(
                        value: $twist,
                        locked: $twistLocked,
                        label: "Twist",
                        range: 0.0...2.0,
                        tooltip: "Controls how much the flame spirals and twists"
                    )

                    SliderControl(
                        value: $frequency,
                        locked: $frequencyLocked,
                        label: "Frequency",
                        range: 0.5...4.0,
                        tooltip: "Controls vertical spacing of flame kinks and waves",
                        showWarning: true
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(width: 320)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.95),
                    Color(red: 0.05, green: 0.05, blue: 0.1).opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            Rectangle()
                .strokeBorder(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .cyan.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                ),
            alignment: .leading
        )
    }

    private var presetsPanel: some View {
        VStack(spacing: 0) {
            // Header
            Text("🔥 Presets")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.top, 24)
                .padding(.bottom, 20)

            Spacer()

            // Presets
            VStack(spacing: 12) {
                // Cycle button
                Button(action: { toggleCycle() }) {
                    HStack(spacing: 10) {
                        Image(systemName: isCycling ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 16))
                        Text(isCycling ? "Stop Cycle" : "Cycle Presets")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: isCycling ? [.green.opacity(0.6), .blue.opacity(0.6)] : [.purple.opacity(0.5), .pink.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                VStack(spacing: 10) {
                    PresetButton(title: "Idle", icon: "wind") {
                        setIdle()
                    }

                    PresetButton(title: "Easy", icon: "aqi.low") {
                        setEasy()
                    }

                    PresetButton(title: "Medium", icon: "flame") {
                        setMedium()
                    }

                    PresetButton(title: "Hard", icon: "flame.fill") {
                        setHard()
                    }

                    // Separator
                    Divider()
                        .background(Color.white.opacity(0.2))
                        .padding(.vertical, 5)

                    // Remember button - special styling
                    RememberButton(
                        hasMemory: rememberedSpeed != nil,
                        onSave: { saveCurrentSettings() },
                        onRecall: { recallSavedSettings() }
                    )

                    PresetButton(title: "Reset", icon: "arrow.counterclockwise") {
                        resetDefaults()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            Spacer()
        }
        .frame(width: 280)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.95),
                    Color(red: 0.1, green: 0.05, blue: 0.0).opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            Rectangle()
                .strokeBorder(
                    LinearGradient(
                        colors: [.orange.opacity(0.3), .red.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                ),
            alignment: .trailing
        )
    }

    private func applyPreset(_ preset: PresetValues) {
        withAnimation(.easeInOut(duration: 3.0)) {
            if !speedLocked { speed = preset.speed }
            if !intensityLocked { intensity = preset.intensity }
            if !heightLocked { height = preset.height }
            if !turbulenceLocked { turbulence = preset.turbulence }
            if !detailLocked { detail = preset.detail }
            if !colorShiftLocked { colorShift = preset.colorShift }
            if !baseWidthLocked { baseWidth = preset.baseWidth }
            if !taperLocked { taper = preset.taper }
            if !twistLocked { twist = preset.twist }
            if !frequencyLocked { frequency = preset.frequency }
        }
    }

    private func setIdle() {
        applyPreset(idlePreset)
    }

    private func setEasy() {
        applyPreset(easyPreset)
    }

    private func setMedium() {
        applyPreset(mediumPreset)
    }

    private func setHard() {
        applyPreset(hardPreset)
    }

    private func resetDefaults() {
        withAnimation(.easeInOut(duration: 3.0)) {
            if !speedLocked { speed = 1.0 }
            if !intensityLocked { intensity = 1.5 }
            if !heightLocked { height = 1.0 }
            if !turbulenceLocked { turbulence = 1.0 }
            if !detailLocked { detail = 1.0 }
            if !colorShiftLocked { colorShift = 1.0 }
            if !baseWidthLocked { baseWidth = 1.0 }
            if !taperLocked { taper = 0.3 }
            if !twistLocked { twist = 0.5 }
            if !frequencyLocked { frequency = 2.0 }
        }
    }

    private func saveCurrentSettings() {
        rememberedSpeed = speed
        rememberedIntensity = intensity
        rememberedHeight = height
        rememberedTurbulence = turbulence
        rememberedDetail = detail
        rememberedColorShift = colorShift
        rememberedBaseWidth = baseWidth
        rememberedTaper = taper
        rememberedTwist = twist
        rememberedFrequency = frequency
    }

    private func recallSavedSettings() {
        guard rememberedSpeed != nil else { return }
        withAnimation(.easeInOut(duration: 3.0)) {
            if !speedLocked, let value = rememberedSpeed { speed = value }
            if !intensityLocked, let value = rememberedIntensity { intensity = value }
            if !heightLocked, let value = rememberedHeight { height = value }
            if !turbulenceLocked, let value = rememberedTurbulence { turbulence = value }
            if !detailLocked, let value = rememberedDetail { detail = value }
            if !colorShiftLocked, let value = rememberedColorShift { colorShift = value }
            if !baseWidthLocked, let value = rememberedBaseWidth { baseWidth = value }
            if !taperLocked, let value = rememberedTaper { taper = value }
            if !twistLocked, let value = rememberedTwist { twist = value }
            if !frequencyLocked, let value = rememberedFrequency { frequency = value }
        }
    }

    private func toggleCycle() {
        if isCycling {
            // Stop cycling
            isCycling = false
            cycleTimer?.invalidate()
            cycleTimer = nil
        } else {
            // Start cycling with idle and perturbation phases
            isCycling = true

            // Timing: 3s transition + 10s idle = 13s per preset
            let transitionDuration: Float = 3.0  // seconds to blend to next preset
            let idleDuration: Float = 10.0       // seconds to idle at preset with perturbations
            let tickInterval: TimeInterval = 0.05 // 50ms ticks

            var currentPhase: Int = 0  // 0 = transition, 1 = idle
            var phaseTime: Float = 0.0
            var currentPresetIndex = 0

            // Use centralized preset values
            let presets: [PresetValues] = [
                idlePreset,
                easyPreset,
                mediumPreset,
                hardPreset,
                mediumPreset,
                easyPreset,
                idlePreset
            ]

            // Store base values for perturbation
            var baseSpeed: Float = idlePreset.speed
            var baseIntensity: Float = idlePreset.intensity
            var baseHeight: Float = idlePreset.height
            var baseTurbulence: Float = idlePreset.turbulence
            var baseColorShift: Float = idlePreset.colorShift
            var baseBaseWidth: Float = idlePreset.baseWidth
            var baseTaper: Float = idlePreset.taper
            var baseTwist: Float = idlePreset.twist

            cycleTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { timer in
                if !self.isCycling {
                    timer.invalidate()
                    return
                }

                phaseTime += Float(tickInterval)

                if currentPhase == 0 {
                    // Transition phase
                    if phaseTime >= transitionDuration {
                        // Transition complete, switch to idle
                        currentPhase = 1
                        phaseTime = 0.0

                        // Store base values for perturbation
                        let preset = presets[currentPresetIndex]
                        baseSpeed = preset.speed
                        baseIntensity = preset.intensity
                        baseHeight = preset.height
                        baseTurbulence = preset.turbulence
                        baseColorShift = preset.colorShift
                        baseBaseWidth = preset.baseWidth
                        baseTaper = preset.taper
                        baseTwist = preset.twist
                    } else {
                        // Interpolate between presets
                        let progress = phaseTime / transitionDuration
                        let fromIndex = currentPresetIndex == 0 ? presets.count - 1 : currentPresetIndex - 1
                        let current = presets[fromIndex]
                        let next = presets[currentPresetIndex]

                        if !self.speedLocked { self.speed = current.speed + (next.speed - current.speed) * progress }
                        if !self.intensityLocked { self.intensity = current.intensity + (next.intensity - current.intensity) * progress }
                        if !self.heightLocked { self.height = current.height + (next.height - current.height) * progress }
                        if !self.turbulenceLocked { self.turbulence = current.turbulence + (next.turbulence - current.turbulence) * progress }
                        if !self.detailLocked { self.detail = current.detail + (next.detail - current.detail) * progress }
                        if !self.colorShiftLocked { self.colorShift = current.colorShift + (next.colorShift - current.colorShift) * progress }
                        if !self.baseWidthLocked { self.baseWidth = current.baseWidth + (next.baseWidth - current.baseWidth) * progress }
                        if !self.taperLocked { self.taper = current.taper + (next.taper - current.taper) * progress }
                        if !self.twistLocked { self.twist = current.twist + (next.twist - current.twist) * progress }
                        if !self.frequencyLocked { self.frequency = current.frequency + (next.frequency - current.frequency) * progress }
                    }
                } else {
                    // Idle phase with perturbations
                    if phaseTime >= idleDuration {
                        // Idle complete, move to next preset
                        currentPresetIndex = (currentPresetIndex + 1) % presets.count
                        currentPhase = 0
                        phaseTime = 0.0
                    } else {
                        // Apply smooth perturbations using sine waves at different frequencies
                        let t = phaseTime
                        let perturbAmount: Float = 0.6  // ±60%

                        // Fade out perturbations in the last 2 seconds to return to base values
                        let fadeoutStart: Float = idleDuration - 2.0
                        let fadeMultiplier: Float = phaseTime > fadeoutStart
                            ? 1.0 - ((phaseTime - fadeoutStart) / 2.0)  // Linear fade from 1.0 to 0.0
                            : 1.0

                        // Use multiple sine waves for organic variation
                        let perturb1 = sin(t * 0.5) * 0.4
                        let perturb2 = sin(t * 0.7 + 1.0) * 0.3
                        let perturb3 = sin(t * 1.1 + 2.0) * 0.3

                        if !self.speedLocked {
                            let variation = (perturb1 + perturb2 * 0.5) * perturbAmount * fadeMultiplier
                            self.speed = baseSpeed * (1.0 + variation)
                        }
                        if !self.intensityLocked {
                            let variation = (perturb2 + perturb3 * 0.5) * perturbAmount * fadeMultiplier
                            self.intensity = baseIntensity * (1.0 + variation)
                        }
                        if !self.heightLocked {
                            let variation = (perturb3 + perturb1 * 0.5) * perturbAmount * fadeMultiplier
                            self.height = baseHeight * (1.0 + variation)
                        }
                        if !self.turbulenceLocked {
                            let variation = (perturb1 + perturb3) * 0.5 * perturbAmount * fadeMultiplier
                            self.turbulence = baseTurbulence * (1.0 + variation)
                        }
                        if !self.colorShiftLocked {
                            let variation = (perturb2 + perturb1) * 0.5 * perturbAmount * fadeMultiplier
                            self.colorShift = baseColorShift * (1.0 + variation)
                        }
                        if !self.baseWidthLocked {
                            let variation = (perturb3 + perturb2) * 0.5 * perturbAmount * fadeMultiplier
                            self.baseWidth = baseBaseWidth * (1.0 + variation)
                        }
                        if !self.taperLocked {
                            let variation = (perturb1 - perturb2) * 0.5 * perturbAmount * fadeMultiplier
                            self.taper = baseTaper * (1.0 + variation)
                        }
                        if !self.twistLocked {
                            let variation = (perturb2 - perturb3) * 0.5 * perturbAmount * fadeMultiplier
                            self.twist = baseTwist * (1.0 + variation)
                        }
                        // Note: detail and frequency are NOT perturbed as requested
                    }
                }
            }
        }
    }
}

struct SliderControl: View {
    @Binding var value: Float
    @Binding var locked: Bool
    let label: String
    let range: ClosedRange<Float>
    let tooltip: String
    var showWarning: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    if showWarning {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                            .help("Adjusting this parameter may cause brief animation discontinuity")
                    }
                    Text(label)
                        .foregroundColor(.white)
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                        .help(tooltip)  // Tooltip on hover
                }
                Spacer()
                Text(String(format: "%.2f", value))
                    .foregroundColor(.orange)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .frame(width: 45, alignment: .trailing)
                    .animation(nil, value: value)  // Update immediately without animation

                // Lock toggle button
                Button(action: {
                    locked.toggle()
                }) {
                    Image(systemName: locked ? "lock.fill" : "lock.open")
                        .font(.system(size: 12))
                        .foregroundColor(locked ? .orange : .white.opacity(0.5))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help(locked ? "Unlock (presets will change this value)" : "Lock (presets will not change this value)")
            }

            // Tooltip text displayed below label
            Text(tooltip)
                .foregroundColor(.white.opacity(0.6))
                .font(.system(size: 10))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Slider(value: Binding(
                get: { Double(value) },
                set: { value = Float($0) }
            ), in: Double(range.lowerBound)...Double(range.upperBound))
            .accentColor(.orange)
            .disabled(locked)
            .opacity(locked ? 0.5 : 1.0)
        }
        .padding(.horizontal, 4)
    }
}

struct PresetButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [.orange.opacity(0.5), .red.opacity(0.5)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct RememberButton: View {
    let hasMemory: Bool
    let onSave: () -> Void
    let onRecall: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Main button - always saves current settings
            Button(action: onSave) {
                HStack(spacing: 10) {
                    Image(systemName: hasMemory ? "star.fill" : "star")
                        .font(.system(size: 16))
                    Text("Remember")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                }
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: hasMemory
                            ? [Color(red: 1.0, green: 0.84, blue: 0.0), Color(red: 1.0, green: 0.65, blue: 0.0)]  // Gold to amber
                            : [Color(red: 0.8, green: 0.7, blue: 0.3), Color(red: 0.7, green: 0.6, blue: 0.2)],    // Dimmer gold
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            // Recall button - only shown when memory exists
            if hasMemory {
                Button(action: onRecall) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 12))
                        Text("Recall")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.84, blue: 0.0), Color(red: 1.0, green: 0.65, blue: 0.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help("Recall saved settings")
            }
        }
    }
}

// SwiftUI wrapper for the FireShaderView
struct FireShaderHostingView: NSViewRepresentable {
    @Binding var speed: Float
    @Binding var intensity: Float
    @Binding var height: Float
    @Binding var turbulence: Float
    @Binding var detail: Float
    @Binding var colorShift: Float
    @Binding var baseWidth: Float
    @Binding var taper: Float
    @Binding var twist: Float
    @Binding var frequency: Float
    @Binding var showPerformanceStats: Bool

    func makeNSView(context: Context) -> FireShaderView {
        let view = FireShaderView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: FireShaderView, context: Context) {
        nsView.speed = speed
        nsView.intensity = intensity
        nsView.height = height
        nsView.turbulence = turbulence
        nsView.detail = detail
        nsView.colorShift = colorShift
        nsView.baseWidth = baseWidth
        nsView.taper = taper
        nsView.twist = twist
        nsView.frequency = frequency
        nsView.showPerformanceStats = showPerformanceStats
    }
}

struct CoordinateGridOverlay: View {
    let height: CGFloat

    // Calculate which screen Y position has rays that sample a given p.y
    // Shader applies: p.y = z * (uv.y / sqrt(uv.y^2 + 1)) + (uv.y + 1.0)
    // For center column (uv.x=0) at z≈5 (actual flame convergence zone)
    func screenYForPY(_ py: Float, atZ z: Float = 5.0) -> CGFloat? {
        // We need to solve: py = z * uv.y / sqrt(uv.y^2 + 1) + uv.y + 1.0
        // This is complex, so let's sample different uv.y values and find closest match

        var bestUvY: Float = 0
        var bestError: Float = Float.infinity

        for uvYTest in stride(from: -1.0 as Float, through: 1.0, by: 0.01) {
            let dir_y = uvYTest / sqrt(uvYTest * uvYTest + 1.0)
            let sampled_py = z * dir_y + (uvYTest + 1.0)
            let error = abs(sampled_py - py)
            if error < bestError {
                bestError = error
                bestUvY = uvYTest
            }
        }

        if bestError > 0.1 { return nil }  // No good match found

        // After flip: uv.y = +1 at top, -1 at bottom
        // Screen Y: 0 (top) to height (bottom)
        let normalized = (1.0 - bestUvY) / 2.0  // 0.0 at top, 1.0 at bottom
        return CGFloat(normalized) * height
    }

    var body: some View {
        ZStack {
            // Draw horizontal lines showing where rays sample different p.y values
            // At z=5, screen range is -2.887 to 4.887
            ForEach([-3.0, -2.5, -2.0, -1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0], id: \.self) { py in
                if let screenY = screenYForPY(Float(py)) {
                    // Horizontal line
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: screenY))
                        path.addLine(to: CGPoint(x: 10000, y: screenY))
                    }
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)

                    // Label
                    Text(String(format: "p.y=%.1f", py))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                        .position(x: 60, y: screenY)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1000, height: 700)
    }
}
#endif
