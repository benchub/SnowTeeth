//
//  FireShaderView.swift
//  3D Fire Shader View for iOS/macOS
//
//  Metal-based fire effect renderer
//

import Metal
import MetalKit

#if os(iOS)
import UIKit
typealias PlatformView = UIView
#elseif os(macOS)
import AppKit
typealias PlatformView = NSView
#endif

struct FireUniforms {
    var time: Float
    var speed: Float
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
    private var startTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()

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
            print("Metal is not supported on this device")
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

        // Load shader library
        guard let library = device.makeDefaultLibrary(),
              let kernelFunction = library.makeFunction(name: "fireShader") else {
            print("Failed to load shader library")
            return
        }

        // Create compute pipeline state
        do {
            computePipelineState = try device.makeComputePipelineState(function: kernelFunction)
        } catch {
            print("Failed to create compute pipeline state: \(error)")
        }

        self.delegate = self
    }

    func resetAnimation() {
        startTime = CFAbsoluteTimeGetCurrent()
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

        // Calculate elapsed time and delta time
        let currentTime = CFAbsoluteTimeGetCurrent()
        let elapsedTime = Float(currentTime - startTime)
        let deltaTime = Float(currentTime - lastFrameTime)
        lastFrameTime = currentTime

        // Smooth speed to prevent jerky animation
        // Interpolation factor: higher = faster response, lower = smoother
        // 0.3 provides good balance: smooth enough to prevent jerks, fast enough to follow 3s preset animations
        let smoothingFactor: Float = 0.3
        smoothedSpeed += (speed - smoothedSpeed) * smoothingFactor

        // Integrate speed to maintain phase continuity
        // This prevents jumps when speed changes
        timeOffset += smoothedSpeed * deltaTime

        // Prepare uniforms
        var uniforms = FireUniforms(
            time: elapsedTime,
            speed: smoothedSpeed,
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

        // Set up compute encoder
        commandEncoder.setComputePipelineState(computePipelineState)
        commandEncoder.setTexture(drawable.texture, index: 0)
        commandEncoder.setBytes(&uniforms, length: MemoryLayout<FireUniforms>.stride, index: 0)

        // Calculate thread groups
        let threadGroupSize = MTLSize(width: 8, height: 8, depth: 1)
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
