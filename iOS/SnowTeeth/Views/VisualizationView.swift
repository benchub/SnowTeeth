//
//  VisualizationView.swift
//  SnowTeeth
//
//  Created by SnowTeeth
//

import SwiftUI
import Metal
import MetalKit
import AVFoundation
import AVKit
import Combine

// MARK: - Fire Shader Support

struct FireUniforms {
    var intensity: Float
    var height: Float
    var colorShift: Float
    var baseWidth: Float
    var colorBlend: Float
    var timeOffset: Float
    var resolution: SIMD2<Float>
}

class FireShaderView: MTKView {

    // Target shader parameters (set from outside)
    var targetSpeed: Float = 0.47
    var targetIntensity: Float = 1.98
    var targetHeight: Float = 0.44
    var targetColorShift: Float = 0.72
    var targetBaseWidth: Float = 0.3
    var targetColorBlend: Float = 0.67

    // Smoothed versions to prevent jerky animation
    private var smoothedSpeed: Float = 0.47
    private var smoothedIntensity: Float = 1.98
    private var smoothedHeight: Float = 0.44
    private var smoothedColorShift: Float = 0.72
    private var smoothedBaseWidth: Float = 0.3
    private var smoothedColorBlend: Float = 0.67

    // Phase tracking for continuity
    private var timeOffset: Float = 0.0
    private var lastFrameTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()

    private var commandQueue: MTLCommandQueue?
    private var computePipelineState: MTLComputePipelineState?

    var isShaderReady: Bool {
        return computePipelineState != nil && commandQueue != nil
    }

    override init(frame: CGRect, device: MTLDevice?) {
        super.init(frame: frame, device: device ?? MTLCreateSystemDefaultDevice())
        setupMetal()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        self.device = MTLCreateSystemDefaultDevice()
        setupMetal()
    }

    private func setupMetal() {
        guard let device = self.device else {
            print("ERROR: Metal is not supported on this device")
            return
        }

        // Set up Metal view properties
        self.framebufferOnly = false
        self.enableSetNeedsDisplay = false
        self.isPaused = false
        self.preferredFramesPerSecond = 60
        self.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        // Create command queue
        commandQueue = device.makeCommandQueue()

        // Load shader library
        guard let library = device.makeDefaultLibrary(),
              let kernelFunction = library.makeFunction(name: "fireShader") else {
            print("ERROR: Failed to find 'fireShader' function in Metal library")
            return
        }

        // Create compute pipeline state
        do {
            computePipelineState = try device.makeComputePipelineState(function: kernelFunction)
        } catch {
            print("ERROR: Failed to create compute pipeline state: \(error.localizedDescription)")
            return
        }

        self.delegate = self
    }

    // Apply a preset configuration (sets target values for smooth transition)
    func applyPreset(speed: Float, intensity: Float, height: Float,
                     colorShift: Float, baseWidth: Float, colorBlend: Float) {
        self.targetSpeed = speed
        self.targetIntensity = intensity
        self.targetHeight = height
        self.targetColorShift = colorShift
        self.targetBaseWidth = baseWidth
        self.targetColorBlend = colorBlend
    }
}

extension FireShaderView: MTKViewDelegate {

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle size changes if needed
    }

    func draw(in view: MTKView) {
        guard let commandQueue = commandQueue,
              let computePipelineState = computePipelineState,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let drawable = currentDrawable,
              let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }

        // Calculate delta time for frame-to-frame integration
        let currentTime = CFAbsoluteTimeGetCurrent()
        let deltaTime = Float(currentTime - lastFrameTime)
        lastFrameTime = currentTime

        // Smooth all parameters (factor 0.15 gives smooth, gradual transitions)
        let smoothingFactor: Float = 0.15
        smoothedSpeed += (targetSpeed - smoothedSpeed) * smoothingFactor
        smoothedIntensity += (targetIntensity - smoothedIntensity) * smoothingFactor
        smoothedHeight += (targetHeight - smoothedHeight) * smoothingFactor
        smoothedColorShift += (targetColorShift - smoothedColorShift) * smoothingFactor
        smoothedBaseWidth += (targetBaseWidth - smoothedBaseWidth) * smoothingFactor
        smoothedColorBlend += (targetColorBlend - smoothedColorBlend) * smoothingFactor

        // Integrate speed to maintain phase continuity
        timeOffset += smoothedSpeed * deltaTime

        // Prepare uniforms using smoothed values
        var uniforms = FireUniforms(
            intensity: smoothedIntensity,
            height: smoothedHeight,
            colorShift: smoothedColorShift,
            baseWidth: smoothedBaseWidth,
            colorBlend: smoothedColorBlend,
            timeOffset: timeOffset,
            resolution: SIMD2<Float>(Float(drawableSize.width), Float(drawableSize.height))
        )

        // Set up compute encoder
        commandEncoder.setComputePipelineState(computePipelineState)
        commandEncoder.setTexture(drawable.texture, index: 0)
        commandEncoder.setBytes(&uniforms, length: MemoryLayout<FireUniforms>.stride, index: 0)

        // Calculate thread groups (16x16 for better GPU utilization)
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (Int(drawableSize.width) + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (Int(drawableSize.height) + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )

        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// MARK: - Main Views

struct VisualizationView: View {
    @ObservedObject var prefs: AppPreferences
    @ObservedObject var locationService: LocationTrackingService
    @Environment(\.dismiss) var dismiss

    @State private var lastGpsUpdateTime: Date?
    @State private var currentTime = Date()

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            if prefs.visualizationStyle == .flame {
                FlameVisualization(
                    bucket: locationService.currentBucket,
                    locationService: locationService,
                    prefs: prefs
                )
            } else if prefs.visualizationStyle == .yeti {
                YetiVisualization(locationService: locationService)
            } else if prefs.visualizationStyle == .data {
                DataVisualizationView(locationService: locationService, prefs: prefs)
            } else {
                ColorVisualization(
                    bucket: locationService.currentBucket,
                    currentLocation: locationService.currentLocation,
                    prefs: prefs
                )
            }

            // GPS update indicator overlay (only shown for data visualization)
            if prefs.visualizationStyle == .data {
                VStack {
                    HStack {
                        Spacer()
                        Text(gpsIndicatorText)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(gpsIndicatorColor)
                            .padding(8)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                            .padding()
                    }
                    Spacer()
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .statusBar(hidden: true)
        .onTapGesture {
            dismiss()
        }
        .onAppear {
            // Keep screen on
            UIApplication.shared.isIdleTimerDisabled = true

            // Start tracking if not already (no prompt here - handled by ContentView)
            // Visualization assumes tracking will be enabled when it opens
            if !locationService.isTracking {
                locationService.startTracking()
            }
        }
        .onDisappear {
            // Allow screen to turn off
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .onChange(of: locationService.currentLocation) { _ in
            lastGpsUpdateTime = Date()
        }
    }

    private var gpsIndicatorText: String {
        guard let lastUpdate = lastGpsUpdateTime else {
            return "GPS: --"
        }

        let elapsed = currentTime.timeIntervalSince(lastUpdate)

        if elapsed < 1.0 {
            return "GPS: now"
        } else {
            return String(format: "GPS: %.1fs", elapsed)
        }
    }

    private var gpsIndicatorColor: Color {
        guard let lastUpdate = lastGpsUpdateTime else {
            return Color.gray
        }

        let elapsed = currentTime.timeIntervalSince(lastUpdate)

        switch elapsed {
        case ..<2.0:
            return Color.green  // Fresh
        case 2.0..<5.0:
            return Color.yellow  // Aging
        case 5.0..<10.0:
            return Color.orange  // Stale
        default:
            return Color.red  // Very stale
        }
    }
}

struct FlameVisualization: View {
    let bucket: VelocityBucket
    @ObservedObject var locationService: LocationTrackingService
    @ObservedObject var prefs: AppPreferences

    var body: some View {
        FlameShaderRepresentable(
            bucket: bucket,
            currentLocation: locationService.currentLocation,
            previousLocation: locationService.previousLocation,
            prefs: prefs
        )
        .edgesIgnoringSafeArea(.all)
    }
}

// Flame shader presets (from shared/constants/flame_presets.json)
// Updated for new 2D fire shader algorithm
struct FlamePreset {
    let speed: Float
    let intensity: Float
    let height: Float
    let colorShift: Float
    let baseWidth: Float
    let colorBlend: Float

    static let idle = FlamePreset(
        speed: 0.2, intensity: 0.5, height: 0.33,
        colorShift: 0.5, baseWidth: 0.3, colorBlend: 1.77
    )

    static let easy = FlamePreset(
        speed: 0.47, intensity: 1.98, height: 0.44,
        colorShift: 0.72, baseWidth: 0.3, colorBlend: 0.67
    )

    static let medium = FlamePreset(
        speed: 0.81, intensity: 0.67, height: 0.74,
        colorShift: 1.13, baseWidth: 0.51, colorBlend: 1.42
    )

    static let hard = FlamePreset(
        speed: 1.36, intensity: 2.02, height: 0.58,
        colorShift: 1.73, baseWidth: 0.82, colorBlend: 1.13
    )

    static let alternateAscent = FlamePreset(
        speed: 0.88, intensity: 0.5, height: 0.1,
        colorShift: 1.36, baseWidth: 0.3, colorBlend: 1.62
    )

    static func forBucket(_ bucket: VelocityBucket) -> FlamePreset {
        switch bucket {
        case .idle:
            return .idle
        case .downhillEasy, .uphillEasy:
            return .easy
        case .downhillMedium, .uphillMedium:
            return .medium
        case .downhillHard, .uphillHard:
            return .hard
        }
    }

    // Interpolate between two presets based on factor (0.0 to 1.0)
    static func interpolate(from presetA: FlamePreset, to presetB: FlamePreset, factor: Float) -> FlamePreset {
        let clampedFactor = max(0.0, min(1.0, factor))

        return FlamePreset(
            speed: presetA.speed + (presetB.speed - presetA.speed) * clampedFactor,
            intensity: presetA.intensity + (presetB.intensity - presetA.intensity) * clampedFactor,
            height: presetA.height + (presetB.height - presetA.height) * clampedFactor,
            colorShift: presetA.colorShift + (presetB.colorShift - presetA.colorShift) * clampedFactor,
            baseWidth: presetA.baseWidth + (presetB.baseWidth - presetA.baseWidth) * clampedFactor,
            colorBlend: presetA.colorBlend + (presetB.colorBlend - presetA.colorBlend) * clampedFactor
        )
    }
}

struct FlameShaderRepresentable: UIViewRepresentable {
    let bucket: VelocityBucket
    let currentLocation: LocationData?
    let previousLocation: LocationData?
    let prefs: AppPreferences

    func makeUIView(context: Context) -> FireShaderView {
        let view = FireShaderView(frame: .zero, device: MTLCreateSystemDefaultDevice())

        // Log if Metal shader failed to load
        if !view.isShaderReady {
            print("WARNING: Metal shader failed to initialize")
        }

        return view
    }

    func updateUIView(_ uiView: FireShaderView, context: Context) {
        guard uiView.isShaderReady else { return }

        let preset = calculateInterpolatedPreset()
        uiView.applyPreset(
            speed: preset.speed,
            intensity: preset.intensity,
            height: preset.height,
            colorShift: preset.colorShift,
            baseWidth: preset.baseWidth,
            colorBlend: preset.colorBlend
        )
    }

    private func calculateInterpolatedPreset() -> FlamePreset {
        // Check if alternate ascent mode is enabled and we're in an uphill bucket
        let isUphillBucket = [VelocityBucket.uphillEasy, .uphillMedium, .uphillHard].contains(bucket)
        if prefs.useAlternateAscentVisualization && isUphillBucket {
            return FlamePreset.alternateAscent
        }

        guard let currentLocation = currentLocation, let previousLocation = previousLocation else {
            // Return preset for bucket if no location data
            return FlamePreset.forBucket(bucket)
        }

        // Get speed in mph
        let speedMps = currentLocation.speed
        let speedMph = speedMps / 0.44704

        // Determine direction
        let elevationChange = currentLocation.altitude - previousLocation.altitude
        let isDownhill = elevationChange < 0

        // Get bucket thresholds and presets
        let lowerThreshold: Float
        let upperThreshold: Float
        let lowerPreset: FlamePreset
        let centerPreset: FlamePreset
        let upperPreset: FlamePreset

        switch bucket {
        case .idle:
            return FlamePreset.idle

        case .downhillEasy, .uphillEasy:
            lowerThreshold = isDownhill ? prefs.downhillEasyThreshold : prefs.uphillEasyThreshold
            upperThreshold = isDownhill ? prefs.downhillMediumThreshold : prefs.uphillMediumThreshold
            lowerPreset = FlamePreset.idle
            centerPreset = FlamePreset.easy
            upperPreset = FlamePreset.medium

        case .downhillMedium, .uphillMedium:
            lowerThreshold = isDownhill ? prefs.downhillMediumThreshold : prefs.uphillMediumThreshold
            upperThreshold = isDownhill ? prefs.downhillHardThreshold : prefs.uphillHardThreshold
            lowerPreset = FlamePreset.easy
            centerPreset = FlamePreset.medium
            upperPreset = FlamePreset.hard

        case .downhillHard, .uphillHard:
            return FlamePreset.hard
        }

        // Calculate bucket center (this is where the preset is most accurate)
        let center = (lowerThreshold + upperThreshold) / 2.0

        if speedMph < center {
            // Lower half of bucket: interpolate from previous preset to current preset
            // At lower boundary: 50% blend, At center: 100% current preset
            let factor = 0.5 + (speedMph - lowerThreshold) / (center - lowerThreshold) * 0.5
            let clampedFactor = max(0.5, min(1.0, factor))
            return FlamePreset.interpolate(from: lowerPreset, to: centerPreset, factor: clampedFactor)
        } else {
            // Upper half of bucket: interpolate from current preset to next preset
            // At center: 100% current preset, At upper boundary: 50% blend
            let factor = (speedMph - center) / (upperThreshold - center) * 0.5
            let clampedFactor = max(0.0, min(0.5, factor))
            return FlamePreset.interpolate(from: centerPreset, to: upperPreset, factor: clampedFactor)
        }
    }
}

struct ColorVisualization: View {
    let bucket: VelocityBucket
    let currentLocation: LocationData?
    @ObservedObject var prefs: AppPreferences

    var body: some View {
        interpolatedColor
            .edgesIgnoringSafeArea(.all)
    }

    private var interpolatedColor: Color {
        // For now, use simple bucket colors
        // TODO: Implement interpolation based on velocity
        switch bucket {
        case .downhillHard, .uphillHard:
            return .red
        case .downhillMedium, .uphillMedium:
            return .yellow
        case .downhillEasy, .uphillEasy:
            return .green
        case .idle:
            return .purple
        }
    }
}

#Preview {
    VisualizationView(
        prefs: AppPreferences(),
        locationService: LocationTrackingService(prefs: AppPreferences())
    )
}
