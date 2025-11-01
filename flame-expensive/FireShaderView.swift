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
    var turbulence: Float
    var detail: Float
    var colorShift: Float
    var baseWidth: Float
    var taper: Float
    var twist: Float
    var frequency: Float
    var timeOffset: Float
    var resolution: SIMD2<Float>
}

class FireShaderView: MTKView {

    // Shader parameters - can be adjusted in real-time
    var speed: Float = 1.0
    var intensity: Float = 1.5
    var height: Float = 1.0
    var turbulence: Float = 1.0
    var detail: Float = 1.0
    var colorShift: Float = 1.0
    var baseWidth: Float = 1.0
    var taper: Float = 1.0
    var twist: Float = 0.5
    var frequency: Float = 2.0

    // Smoothed version of speed to prevent jerky animation
    private var smoothedSpeed: Float = 1.0

    // Phase tracking for continuity
    private var timeOffset: Float = 0.0
    private var lastFrameTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()

    private var commandQueue: MTLCommandQueue?
    private var computePipelineState: MTLComputePipelineState?

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
            turbulence: turbulence,
            detail: detail,
            colorShift: colorShift,
            baseWidth: baseWidth,
            taper: taper,
            twist: twist,
            frequency: frequency,
            timeOffset: timeOffset,
            resolution: SIMD2<Float>(Float(drawableSize.width), Float(drawableSize.height))
        )

        let encoderStartTime = CFAbsoluteTimeGetCurrent()

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
    @State private var turbulence: Float = 1.0
    @State private var detail: Float = 1.0
    @State private var colorShift: Float = 1.0

    var body: some View {
        FireShaderRepresentable(
            speed: speed,
            intensity: intensity,
            height: height,
            turbulence: turbulence,
            detail: detail,
            colorShift: colorShift
        )
    }
}

@available(iOS 13.0, macOS 10.15, *)
struct FireShaderRepresentable {
    var speed: Float
    var intensity: Float
    var height: Float
    var turbulence: Float
    var detail: Float
    var colorShift: Float
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
        uiView.turbulence = turbulence
        uiView.detail = detail
        uiView.colorShift = colorShift
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
        nsView.turbulence = turbulence
        nsView.detail = detail
        nsView.colorShift = colorShift
    }
}
#endif

#endif
