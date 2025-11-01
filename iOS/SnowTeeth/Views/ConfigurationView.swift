//
//  ConfigurationView.swift
//  SnowTeeth
//
//  Created by SnowTeeth
//

import SwiftUI

struct ConfigurationView: View {
    @ObservedObject var prefs: AppPreferences
    @Environment(\.dismiss) var dismiss
    @State private var previousUseMetric: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Units")) {
                    Picker("Unit System", selection: $prefs.useMetric) {
                        Text("Empire!").tag(false)
                        Text("Science!").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: prefs.useMetric) { oldValue, newValue in
                        convertThresholds(from: previousUseMetric, to: newValue)
                        previousUseMetric = newValue
                    }
                }

                Section(header: Text("Visualization Style")) {
                    Picker("Style", selection: $prefs.visualizationStyle) {
                        Text("Flame").tag(VisualizationStyle.flame)
                        Text("Data").tag(VisualizationStyle.data)
                        Text("Yeti").tag(VisualizationStyle.yeti)
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("Downhill Thresholds (\(prefs.useMetric ? "km/h" : "mph"))")) {
                    DualSliderThresholdView(
                        title: "Downhill",
                        easyThreshold: $prefs.downhillEasyThreshold,
                        mediumThreshold: $prefs.downhillMediumThreshold,
                        hardThreshold: $prefs.downhillHardThreshold,
                        minValue: 0.0,
                        maxValue: prefs.useMetric ? 48.3 : 30.0  // 30 mph = 48.3 km/h
                    )
                }

                Section(header: Text("Uphill Thresholds (\(prefs.useMetric ? "km/h" : "mph"))")) {
                    Toggle("I don't always go uphill, but when I do, I use Chairlifts", isOn: $prefs.useAlternateAscentVisualization)
                        .font(.caption)

                    DualSliderThresholdView(
                        title: "Uphill",
                        easyThreshold: $prefs.uphillEasyThreshold,
                        mediumThreshold: $prefs.uphillMediumThreshold,
                        hardThreshold: $prefs.uphillHardThreshold,
                        minValue: 0.0,
                        maxValue: prefs.useMetric ? 24.1 : 15.0  // 15 mph = 24.1 km/h
                    )
                }

                Section {
                    Button("Reset to Defaults") {
                        resetDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                previousUseMetric = prefs.useMetric
            }
        }
    }

    private func convertThresholds(from: Bool, to: Bool) {
        guard from != to else { return }

        let conversionFactor: Float = to ? 1.60934 : (1.0 / 1.60934)  // mph to km/h or vice versa

        // Convert downhill thresholds
        prefs.downhillEasyThreshold *= conversionFactor
        prefs.downhillMediumThreshold *= conversionFactor
        prefs.downhillHardThreshold *= conversionFactor

        // Convert uphill thresholds
        prefs.uphillEasyThreshold *= conversionFactor
        prefs.uphillMediumThreshold *= conversionFactor
        prefs.uphillHardThreshold *= conversionFactor
    }

    private func resetDefaults() {
        prefs.downhillHardThreshold = AppPreferences.defaultDownhillHard
        prefs.downhillMediumThreshold = AppPreferences.defaultDownhillMedium
        prefs.downhillEasyThreshold = AppPreferences.defaultDownhillEasy
        prefs.uphillEasyThreshold = AppPreferences.defaultUphillEasy
        prefs.uphillMediumThreshold = AppPreferences.defaultUphillMedium
        prefs.uphillHardThreshold = AppPreferences.defaultUphillHard
        prefs.useMetric = false
        prefs.visualizationStyle = .flame
        prefs.useAlternateAscentVisualization = false
    }
}

struct DualSliderThresholdView: View {
    let title: String
    @Binding var easyThreshold: Float
    @Binding var mediumThreshold: Float
    @Binding var hardThreshold: Float
    let minValue: Float
    let maxValue: Float

    @State private var draggingSlider: DraggingSlider? = nil

    enum DraggingSlider {
        case easy, medium, hard
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Threshold labels and values
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Easy: \(String(format: "%.1f", easyThreshold))")
                        .font(.caption)
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 8, height: 8)
                    Text("Med:")
                        .font(.caption)
                    Text(String(format: "%.1f", mediumThreshold))
                        .font(.caption)
                        .frame(minWidth: 30, alignment: .leading)
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("Hard:")
                        .font(.caption)
                    Text(String(format: "%.1f", hardThreshold))
                        .font(.caption)
                        .frame(minWidth: 30, alignment: .leading)
                }
            }

            // Combined bar with three sliders
            GeometryReader { geometry in
                let width = geometry.size.width
                let range = CGFloat(maxValue - minValue)

                // Calculate positions
                let easyPosition = CGFloat((easyThreshold - minValue)) / range * width
                let mediumPosition = CGFloat((mediumThreshold - minValue)) / range * width
                let hardPosition = CGFloat((hardThreshold - minValue)) / range * width

                ZStack(alignment: .leading) {
                    // Background bar with four colored sections
                    HStack(spacing: 0) {
                        // Idle section (grey) - from start to easy threshold
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: max(0, easyPosition))

                        // Easy section (green) - from easy to medium threshold
                        Rectangle()
                            .fill(Color.green.opacity(0.3))
                            .frame(width: max(0, mediumPosition - easyPosition))

                        // Medium section (yellow) - from medium to hard threshold
                        Rectangle()
                            .fill(Color.yellow.opacity(0.3))
                            .frame(width: max(0, hardPosition - mediumPosition))

                        // Hard section (red) - from hard to end
                        Rectangle()
                            .fill(Color.red.opacity(0.3))
                            .frame(width: max(0, width - hardPosition))
                    }
                    .frame(height: 40)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )

                    // Easy threshold slider (green handle)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .shadow(radius: 2)
                        .position(x: easyPosition, y: 20)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    draggingSlider = .easy
                                    let minGap: CGFloat = 0.5 * width / range
                                    let newPosition = max(0, min(value.location.x, mediumPosition - minGap))
                                    let newValue = Float((newPosition / width) * range + CGFloat(minValue))
                                    easyThreshold = max(minValue, round(newValue * 2) / 2) // Round to nearest 0.5
                                }
                                .onEnded { _ in
                                    draggingSlider = nil
                                }
                        )

                    // Medium threshold slider (yellow handle)
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .shadow(radius: 2)
                        .position(x: mediumPosition, y: 20)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    draggingSlider = .medium
                                    let minGap: CGFloat = 0.5 * width / range
                                    let newPosition = max(easyPosition + minGap, min(value.location.x, hardPosition - minGap))
                                    let newValue = Float((newPosition / width) * range + CGFloat(minValue))
                                    mediumThreshold = round(newValue * 2) / 2 // Round to nearest 0.5
                                }
                                .onEnded { _ in
                                    draggingSlider = nil
                                }
                        )

                    // Hard threshold slider (red handle)
                    Circle()
                        .fill(Color.red)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .shadow(radius: 2)
                        .position(x: hardPosition, y: 20)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    draggingSlider = .hard
                                    let minGap: CGFloat = 0.5 * width / range
                                    let newPosition = max(mediumPosition + minGap, min(value.location.x, width))
                                    let newValue = Float((newPosition / width) * range + CGFloat(minValue))
                                    hardThreshold = min(round(newValue * 2) / 2, maxValue) // Round to nearest 0.5
                                }
                                .onEnded { _ in
                                    draggingSlider = nil
                                }
                        )
                }
            }
            .frame(height: 40)

            // Min/Max labels
            HStack {
                Text(String(format: "%.1f", minValue))
                    .font(.caption2)
                    .foregroundColor(.gray)
                Spacer()
                Text(String(format: "%.1f", maxValue))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ConfigurationView(prefs: AppPreferences())
}
