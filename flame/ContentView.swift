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
    @State private var showControls = true
    @State private var showGrid = true  // Start with grid visible
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

    var body: some View {
        HStack(spacing: 0) {
            // Fire shader - full screen
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
                frequency: $frequency
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                GeometryReader { geometry in
                    if showGrid {
                        CoordinateGridOverlay(height: geometry.size.height)
                    }
                }
            )
            .overlay(alignment: .topLeading) {
                // Grid toggle button in upper left corner
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
                .padding(16)
            }

            // Side panel for controls
            if showControls {
                sidePanel
                    .transition(.move(edge: .trailing))
            }
        }
        .overlay(alignment: .topTrailing) {
            VStack(spacing: 12) {
                // Toggle controls button
                Button(action: { withAnimation { showControls.toggle() } }) {
                    Image(systemName: showControls ? "sidebar.right" : "slider.horizontal.3")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .background(Color.black)
    }

    private var sidePanel: some View {
        VStack(spacing: 0) {
            // Header
            Text("🔥 Fire Controls")
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
                        tooltip: "Controls amount of fine detail: low=smooth, high=intricate"
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
                        tooltip: "Controls vertical spacing of flame kinks and waves"
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.vertical, 16)

            // Presets
            VStack(spacing: 12) {
                Text("Presets")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.7))

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
                    PresetButton(title: "Gentle", icon: "wind") {
                        setGentle()
                    }

                    PresetButton(title: "Medium", icon: "flame") {
                        setMedium()
                    }

                    PresetButton(title: "Hard", icon: "flame.fill") {
                        setHard()
                    }

                    PresetButton(title: "Reset", icon: "arrow.counterclockwise") {
                        resetDefaults()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(width: 300)
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
            alignment: .leading
        )
    }

    private func setGentle() {
        withAnimation(.easeInOut(duration: 3.0)) {
            if !speedLocked { speed = 0.22 }
            if !intensityLocked { intensity = 0.8 }
            if !heightLocked { height = 0.5 }
            if !turbulenceLocked { turbulence = 0.8 }
            if !detailLocked { detail = 0.8 }
            if !colorShiftLocked { colorShift = 0.7 }
            if !baseWidthLocked { baseWidth = 0.6 }
            if !taperLocked { taper = 0.2 }
            if !twistLocked { twist = 0.44 }
            if !frequencyLocked { frequency = 1.5 }
        }
    }

    private func setMedium() {
        withAnimation(.easeInOut(duration: 3.0)) {
            if !speedLocked { speed = 1.1 }
            if !intensityLocked { intensity = 2.21 }
            if !heightLocked { height = 0.9 }
            if !turbulenceLocked { turbulence = 1.0 }
            if !detailLocked { detail = 0.8 }
            if !colorShiftLocked { colorShift = 0.55 }
            if !baseWidthLocked { baseWidth = 1.67 }
            if !taperLocked { taper = 0.38 }
            if !twistLocked { twist = 0.31 }
            if !frequencyLocked { frequency = 0.89 }
        }
    }

    private func setHard() {
        withAnimation(.easeInOut(duration: 3.0)) {
            if !speedLocked { speed = 1.4 }
            if !intensityLocked { intensity = 2.2 }
            if !heightLocked { height = 1.37 }
            if !turbulenceLocked { turbulence = 1.63 }
            if !detailLocked { detail = 2.0 }
            if !colorShiftLocked { colorShift = 1.24 }
            if !baseWidthLocked { baseWidth = 1.45 }
            if !taperLocked { taper = 1.0 }
            if !twistLocked { twist = 0.46 }
            if !frequencyLocked { frequency = 1.21 }
        }
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

    private func toggleCycle() {
        if isCycling {
            // Stop cycling
            isCycling = false
            cycleTimer?.invalidate()
            cycleTimer = nil
        } else {
            // Start cycling: gentle -> medium -> hard -> medium -> gentle (10 seconds total)
            isCycling = true
            let cycleSteps = 200  // 200 steps over 10 seconds = 50ms per step
            var currentStep = 0

            // Define preset values
            let presets: [(speed: Float, intensity: Float, height: Float, turbulence: Float,
                          detail: Float, colorShift: Float, baseWidth: Float, taper: Float,
                          twist: Float, frequency: Float)] = [
                // Gentle
                (0.22, 0.8, 0.5, 0.8, 0.8, 0.7, 0.6, 0.2, 0.44, 1.5),
                // Medium
                (1.1, 2.21, 0.9, 1.0, 0.8, 0.55, 1.67, 0.38, 0.31, 0.89),
                // Hard
                (1.4, 2.2, 1.37, 1.63, 2.0, 1.24, 1.45, 1.0, 0.46, 1.21),
                // Medium (return)
                (1.1, 2.21, 0.9, 1.0, 0.8, 0.55, 1.67, 0.38, 0.31, 0.89),
                // Gentle (return to start)
                (0.22, 0.8, 0.5, 0.8, 0.8, 0.7, 0.6, 0.2, 0.44, 1.5)
            ]

            cycleTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
                if !self.isCycling {
                    timer.invalidate()
                    return
                }

                // Calculate position in cycle (0.0 to 4.0, representing transitions between 5 presets)
                let progress = Float(currentStep) / Float(cycleSteps) * 4.0
                let segmentIndex = Int(progress)
                let segmentProgress = progress - Float(segmentIndex)

                if segmentIndex >= 4 {
                    // Cycle complete, restart
                    currentStep = 0
                } else {
                    // Interpolate between current and next preset
                    let current = presets[segmentIndex]
                    let next = presets[segmentIndex + 1]

                    if !self.speedLocked { self.speed = current.speed + (next.speed - current.speed) * segmentProgress }
                    if !self.intensityLocked { self.intensity = current.intensity + (next.intensity - current.intensity) * segmentProgress }
                    if !self.heightLocked { self.height = current.height + (next.height - current.height) * segmentProgress }
                    if !self.turbulenceLocked { self.turbulence = current.turbulence + (next.turbulence - current.turbulence) * segmentProgress }
                    if !self.detailLocked { self.detail = current.detail + (next.detail - current.detail) * segmentProgress }
                    if !self.colorShiftLocked { self.colorShift = current.colorShift + (next.colorShift - current.colorShift) * segmentProgress }
                    if !self.baseWidthLocked { self.baseWidth = current.baseWidth + (next.baseWidth - current.baseWidth) * segmentProgress }
                    if !self.taperLocked { self.taper = current.taper + (next.taper - current.taper) * segmentProgress }
                    if !self.twistLocked { self.twist = current.twist + (next.twist - current.twist) * segmentProgress }
                    if !self.frequencyLocked { self.frequency = current.frequency + (next.frequency - current.frequency) * segmentProgress }

                    currentStep += 1
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 4) {
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
