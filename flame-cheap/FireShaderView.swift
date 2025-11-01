//
//  FireShaderView.swift
//  3D Fire Shader View for iOS/macOS
//
//  Metal-based fire effect renderer
//

import Metal
import MetalKit
import os.log

#if os(iOS)
import UIKit
typealias PlatformView = UIView
#elseif os(macOS)
import AppKit
typealias PlatformView = NSView
#endif

private let performanceLog = OSLog(subsystem: "com.example.flame", category: "Performance")

struct FireUniforms {
    var intensity: Float
    var height: Float
    var colorShift: Float
    var baseWidth: Float
    var timeOffset: Float
    var resolution: SIMD2<Float>
    var colorBlend: Float
}

class FireShaderView: MTKView {

    // Shader parameters - can be adjusted in real-time
    var speed: Float = 1.0
    var intensity: Float = 1.5
    var height: Float = 1.0
    var colorShift: Float = 1.0
    var baseWidth: Float = 1.0
    var colorBlend: Float = 0.8
    var noisePattern: Int = 0  // 0-19 for selecting pattern (grids, lines, circles, noise)

    // Smoothed version of speed to prevent jerky animation
    private var smoothedSpeed: Float = 1.0

    // Phase tracking for continuity
    private var timeOffset: Float = 0.0
    private var lastFrameTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()

    private var commandQueue: MTLCommandQueue?
    private var computePipelineState: MTLComputePipelineState?
    private var noiseTextures: [MTLTexture] = []

    // Performance profiling
    var showPerformanceStats: Bool = false
    private var frameCount: Int = 0
    private var fpsUpdateTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    private var currentFPS: Double = 0.0
    private var avgFrameTime: Double = 0.0
    private var avgGPUTime: Double = 0.0
    private var frameTimeSamples: [Double] = []
    private var gpuTimeSamples: [Double] = []
    private let maxSamples = 60

    override init(frame: CGRect, device: MTLDevice?) {
        super.init(frame: frame, device: device ?? MTLCreateSystemDefaultDevice())
        setupMetal()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        self.device = MTLCreateSystemDefaultDevice()
        setupMetal()
    }

    private func generateHardcodedPattern(device: MTLDevice, patternIndex: Int) -> MTLTexture? {
        guard patternIndex >= 0 && patternIndex < 20 else {
            return nil
        }

        // Determine size based on pattern
        let size: Int
        switch patternIndex {
        case 0: size = 8
        case 1: size = 16
        case 2: size = 32
        case 3, 5: size = 64
        case 4, 6, 7, 8, 11: size = 128
        case 9, 10, 12, 15, 18: size = 256
        case 16, 19: size = 512
        case 17: size = 1024
        case 13: size = 64
        case 14: size = 128
        default: size = 256
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Unorm,
            width: size,
            height: size,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }

        var noiseData = [UInt8](repeating: 0, count: size * size)

        // Generate pattern based on index
        for y in 0..<size {
            for x in 0..<size {
                let value: UInt8
                switch patternIndex {
                case 0: value = ((x / 4 + y / 4) % 2 == 0) ? 255 : 0  // 8x8 checkerboard
                case 1: value = ((x / 8 + y / 8) % 2 == 0) ? 255 : 0  // 16x16 checkerboard
                case 2: value = ((x / 16 + y / 16) % 2 == 0) ? 255 : 0  // 32x32 checkerboard
                case 3: value = (y % 8 < 2) ? 255 : 0  // Horizontal lines (thin)
                case 4: value = (y % 16 < 4) ? 255 : 0  // Horizontal lines (thick)
                case 5: value = (x % 8 < 2) ? 255 : 0  // Vertical lines (thin)
                case 6: value = (x % 16 < 4) ? 255 : 0  // Vertical lines (thick)
                case 7: value = ((x + y) % 16 < 4) ? 255 : 0  // Diagonal (45°)
                case 8: value = ((x - y + size) % 16 < 4) ? 255 : 0  // Diagonal (-45°)
                case 9:  // Concentric circles (tight)
                    let cx = Float(x - size/2), cy = Float(y - size/2)
                    let dist = sqrt(cx * cx + cy * cy)
                    value = (Int(dist) % 16 < 4) ? 255 : 0
                case 10:  // Concentric circles (wide)
                    let cx = Float(x - size/2), cy = Float(y - size/2)
                    let dist = sqrt(cx * cx + cy * cy)
                    value = (Int(dist) % 32 < 8) ? 255 : 0
                case 11: value = ((x % 8 == 0) && (y % 8 == 0)) ? 255 : 0  // Dots (small)
                case 12:  // Dots (large)
                    let dx = x % 16 - 8, dy = y % 16 - 8
                    value = (dx * dx + dy * dy < 16) ? 255 : 0
                case 13...17:  // Random noise at various resolutions
                    let hash = sin(Float(x) * 12.9898 + Float(y) * 78.233) * 43758.5453
                    value = UInt8((hash - floor(hash)) * 255.0)
                case 18:  // Perlin-like noise (medium frequency)
                    let fx = Float(x) / Float(size), fy = Float(y) / Float(size)
                    var noise: Float = 0.0
                    var amp: Float = 1.0, freq: Float = 4.0
                    for _ in 0..<3 {
                        let hash = sin(fx * freq * 12.9898 + fy * freq * 78.233) * 43758.5453
                        noise += (hash - floor(hash)) * amp
                        amp *= 0.5; freq *= 2.0
                    }
                    value = UInt8(max(0.0, min(255.0, noise * 255.0)))
                case 19:  // Perlin-like noise (high frequency)
                    let fx = Float(x) / Float(size), fy = Float(y) / Float(size)
                    var noise: Float = 0.0
                    var amp: Float = 1.0, freq: Float = 8.0
                    for _ in 0..<4 {
                        let hash = sin(fx * freq * 12.9898 + fy * freq * 78.233) * 43758.5453
                        noise += (hash - floor(hash)) * amp
                        amp *= 0.5; freq *= 2.0
                    }
                    value = UInt8(max(0.0, min(255.0, noise * 255.0)))
                default: value = 128
                }
                noiseData[y * size + x] = value
            }
        }

        let region = MTLRegionMake2D(0, 0, size, size)
        texture.replace(region: region, mipmapLevel: 0, withBytes: noiseData, bytesPerRow: size)

        return texture
    }

    private func clamp(_ value: Float, _ minValue: Float, _ maxValue: Float) -> Float {
        return max(minValue, min(maxValue, value))
    }

    private func setupMetal() {
        guard let device = self.device else {
            showError("Metal is not supported on this device")
            return
        }

        // Set up Metal view properties
        self.framebufferOnly = false
        self.enableSetNeedsDisplay = false
        self.isPaused = false
        self.preferredFramesPerSecond = 60

        #if os(iOS)
        self.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        #elseif os(macOS)
        self.wantsLayer = true
        self.layer?.isOpaque = true
        self.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        #endif

        // Create command queue
        commandQueue = device.makeCommandQueue()

        // Generate 20 different hardcoded patterns
        for patternIndex in 0..<20 {
            guard let texture = generateHardcodedPattern(device: device, patternIndex: patternIndex) else {
                showError("Failed to generate pattern \(patternIndex)")
                return
            }
            noiseTextures.append(texture)
        }

        // Load shader library from Resources bundle
        let library: MTLLibrary
        if let defaultLib = device.makeDefaultLibrary() {
            library = defaultLib
        } else {
            // Try loading explicitly from Resources
            guard let libraryURL = Bundle.main.url(forResource: "default", withExtension: "metallib") else {
                showError("Failed to find default.metallib in app bundle.\n\nThe Metal shader library is missing from:\n\(Bundle.main.resourcePath ?? "unknown path")")
                return
            }

            do {
                library = try device.makeLibrary(URL: libraryURL)
            } catch {
                showError("Failed to load Metal library from \(libraryURL.path):\n\(error.localizedDescription)")
                return
            }
        }

        guard let kernelFunction = library.makeFunction(name: "fireShader") else {
            showError("Failed to find 'fireShader' function in Metal library")
            return
        }

        // Create compute pipeline state
        do {
            computePipelineState = try device.makeComputePipelineState(function: kernelFunction)
        } catch {
            showError("Failed to create compute pipeline state: \(error.localizedDescription)")
            return
        }

        self.delegate = self
    }

    private func showError(_ message: String) {
        print("ERROR: \(message)")
        #if os(macOS)
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Flame Shader Error"
            alert.informativeText = message
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        #endif
    }
}

extension FireShaderView: MTKViewDelegate {

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle size changes if needed
    }

    func draw(in view: MTKView) {
        let frameStartTime = CFAbsoluteTimeGetCurrent()

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

        // Smooth speed (factor 0.3 balances responsiveness with smoothness)
        let smoothingFactor: Float = 0.3
        smoothedSpeed += (speed - smoothedSpeed) * smoothingFactor

        // Integrate speed to maintain phase continuity
        timeOffset += smoothedSpeed * deltaTime

        // Prepare uniforms
        var uniforms = FireUniforms(
            intensity: intensity,
            height: height,
            colorShift: colorShift,
            baseWidth: baseWidth,
            timeOffset: timeOffset,
            resolution: SIMD2<Float>(Float(drawableSize.width), Float(drawableSize.height)),
            colorBlend: colorBlend
        )

        let encoderStartTime = CFAbsoluteTimeGetCurrent()

        // Set up compute encoder
        commandEncoder.setComputePipelineState(computePipelineState)
        commandEncoder.setTexture(drawable.texture, index: 0)

        // Select noise texture based on noisePattern parameter (clamped to 0-19)
        let selectedPattern = max(0, min(19, noisePattern))
        commandEncoder.setTexture(noiseTextures[selectedPattern], index: 1)

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

        let encoderEndTime = CFAbsoluteTimeGetCurrent()

        commandBuffer.present(drawable)

        // Measure GPU time
        commandBuffer.addCompletedHandler { [weak self] _ in
            let gpuTime = (CFAbsoluteTimeGetCurrent() - frameStartTime) * 1000.0
            self?.updateGPUStats(gpuTime)
        }

        commandBuffer.commit()

        let frameEndTime = CFAbsoluteTimeGetCurrent()
        let cpuFrameTime = (frameEndTime - frameStartTime) * 1000.0
        let encoderTime = (encoderEndTime - encoderStartTime) * 1000.0

        updateFrameStats(cpuFrameTime)

        // Update FPS counter
        frameCount += 1
        if currentTime - fpsUpdateTime >= 1.0 {
            currentFPS = Double(frameCount) / (currentTime - fpsUpdateTime)
            frameCount = 0
            fpsUpdateTime = currentTime

            if showPerformanceStats {
                os_log("FPS: %.1f | CPU: %.2fms | GPU: %.2fms | Encoder: %.2fms",
                       log: performanceLog, type: .info,
                       currentFPS, avgFrameTime, avgGPUTime, encoderTime)
            }
        }
    }

    private func updateFrameStats(_ frameTime: Double) {
        frameTimeSamples.append(frameTime)
        if frameTimeSamples.count > maxSamples {
            frameTimeSamples.removeFirst()
        }
        avgFrameTime = frameTimeSamples.reduce(0.0, +) / Double(frameTimeSamples.count)
    }

    private func updateGPUStats(_ gpuTime: Double) {
        gpuTimeSamples.append(gpuTime)
        if gpuTimeSamples.count > maxSamples {
            gpuTimeSamples.removeFirst()
        }
        avgGPUTime = gpuTimeSamples.reduce(0.0, +) / Double(gpuTimeSamples.count)
    }
}

// MARK: - SwiftUI Integration (Optional)

#if canImport(SwiftUI)
import SwiftUI

@available(iOS 13.0, macOS 10.15, *)
struct FireShaderSwiftUIView: View {
    @State private var speed: Float = 1.0
    @State private var intensity: Float = 1.5
    @State private var height: Float = 1.0
    @State private var colorShift: Float = 1.0
    @State private var baseWidth: Float = 1.0

    var body: some View {
        FireShaderRepresentable(
            speed: speed,
            intensity: intensity,
            height: height,
            colorShift: colorShift,
            baseWidth: baseWidth
        )
    }
}

@available(iOS 13.0, macOS 10.15, *)
struct FireShaderRepresentable {
    var speed: Float
    var intensity: Float
    var height: Float
    var colorShift: Float
    var baseWidth: Float
}

#if os(iOS)
@available(iOS 13.0, *)
extension FireShaderRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> FireShaderView {
        let view = FireShaderView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        return view
    }

    func updateUIView(_ uiView: FireShaderView, context: Context) {
        uiView.speed = speed
        uiView.intensity = intensity
        uiView.height = height
        uiView.colorShift = colorShift
        uiView.baseWidth = baseWidth
    }
}
#elseif os(macOS)
@available(macOS 10.15, *)
extension FireShaderRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> FireShaderView {
        let view = FireShaderView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        return view
    }

    func updateNSView(_ nsView: FireShaderView, context: Context) {
        nsView.speed = speed
        nsView.intensity = intensity
        nsView.height = height
        nsView.colorShift = colorShift
        nsView.baseWidth = baseWidth
    }
}
#endif

#endif
