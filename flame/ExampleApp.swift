//
//  ExampleApp.swift
//  Example iOS/macOS app demonstrating the fire shader
//
//  Copy this file to create a simple demo app
//

import SwiftUI

@main
struct FireShaderDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var speed: Float = 1.0
    @State private var intensity: Float = 1.5
    @State private var height: Float = 1.0
    @State private var turbulence: Float = 1.0
    @State private var colorShift: Float = 1.0
    @State private var showControls = false

    var body: some View {
        ZStack {
            // Fire shader background
            FireShaderSwiftUIView()
                .edgesIgnoringSafeArea(.all)

            // Controls overlay
            VStack {
                Spacer()

                if showControls {
                    VStack(spacing: 20) {
                        Text("Fire Controls")
                            .font(.headline)
                            .foregroundColor(.white)

                        ControlSlider(value: $speed, label: "Speed", range: 0.5...2.0)
                        ControlSlider(value: $intensity, label: "Intensity", range: 0.5...3.0)
                        ControlSlider(value: $height, label: "Height", range: 0.5...2.0)
                        ControlSlider(value: $turbulence, label: "Turbulence", range: 0.5...2.0)
                        ControlSlider(value: $colorShift, label: "Color Shift", range: 0.5...2.0)

                        HStack(spacing: 20) {
                            PresetButton(title: "Campfire") {
                                setCampfire()
                            }
                            PresetButton(title: "Inferno") {
                                setInferno()
                            }
                            PresetButton(title: "Reset") {
                                resetDefaults()
                            }
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(15)
                    .padding()
                }

                Button(action: { withAnimation { showControls.toggle() } }) {
                    Image(systemName: showControls ? "xmark.circle.fill" : "slider.horizontal.3")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .padding()
            }
        }
    }

    private func setCampfire() {
        speed = 0.6
        intensity = 1.0
        height = 0.7
        turbulence = 1.2
        colorShift = 1.0
    }

    private func setInferno() {
        speed = 2.0
        intensity = 3.0
        height = 1.5
        turbulence = 2.0
        colorShift = 1.5
    }

    private func resetDefaults() {
        speed = 1.0
        intensity = 1.5
        height = 1.0
        turbulence = 1.0
        colorShift = 1.0
    }
}

struct ControlSlider: View {
    @Binding var value: Float
    let label: String
    let range: ClosedRange<Float>

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .foregroundColor(.white)
                Spacer()
                Text(String(format: "%.2f", value))
                    .foregroundColor(.white.opacity(0.7))
            }
            Slider(value: $value, in: range)
                .accentColor(.orange)
        }
    }
}

struct PresetButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                .background(Color.orange)
                .cornerRadius(8)
        }
    }
}

// Note: Make sure to update FireShaderSwiftUIView to accept parameters
extension FireShaderSwiftUIView {
    init(speed: Float = 1.0,
         intensity: Float = 1.5,
         height: Float = 1.0,
         turbulence: Float = 1.0,
         colorShift: Float = 1.0) {
        self.init()
        // Parameters will be passed through the representable
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
