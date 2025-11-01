//
//  StatsView.swift
//  SnowTeeth
//
//  Created by SnowTeeth
//

import SwiftUI

struct StatsView: View {
    @ObservedObject var prefs: AppPreferences
    @ObservedObject var locationService: LocationTrackingService
    @Environment(\.dismiss) var dismiss

    @State private var stats: TrackStats?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var updateTimer: Timer?
    @State private var trackingStartTime: Date?
    @State private var pointCount: Int = 0
    @State private var durationString: String = ""
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass

    // Detect landscape using geometry instead of size classes for more reliable detection
    private var isLandscape: Bool {
        // Landscape when width > height
        UIScreen.main.bounds.width > UIScreen.main.bounds.height
    }

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading track data...")
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if let stats = stats {
                    let cardSpacing: CGFloat = isLandscape ? 8 : 12

                    ScrollView {
                        if isLandscape {
                            VStack(spacing: cardSpacing) {
                                // GPS point count and duration at the top
                                if !durationString.isEmpty {
                                    Text("\(formatNumber(pointCount)) distinct GPS points over the last \(durationString)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 5)
                                }

                                // 3-column grid layout for landscape
                                LazyVGrid(columns: [
                                    GridItem(.flexible(), spacing: 8),
                                    GridItem(.flexible(), spacing: 8),
                                    GridItem(.flexible(), spacing: 8)
                                ], spacing: 8) {
                                    StatCard(
                                    title: "Vertical Feet Up",
                                    value: String(format: "%.0f ft", stats.verticalFeetUp),
                                    icon: "ic_stat_vertical_up",
                                    isCompact: true
                                )

                                StatCard(
                                    title: "Vertical Feet Down",
                                    value: String(format: "%.0f ft", stats.verticalFeetDown),
                                    icon: "ic_stat_vertical_down",
                                    isCompact: true
                                )

                                StatCard(
                                    title: "Horizontal Distance",
                                    value: String(format: "%.2f %@", stats.horizontalDistance, prefs.useMetric ? "km" : "mi"),
                                    icon: "ic_stat_horizontal_distance",
                                    isCompact: true
                                )

                                StatCard(
                                    title: "Average Downhill Pace",
                                    value: String(format: "%.1f %@", stats.avgDownhillPace, prefs.useMetric ? "km/h" : "mph"),
                                    icon: "ic_stat_downhill",
                                    isCompact: true
                                )

                                StatCard(
                                    title: "Average Uphill Pace",
                                    value: String(format: "%.1f %@", stats.avgUphillPace, prefs.useMetric ? "km/h" : "mph"),
                                    icon: "ic_stat_uphill",
                                    isCompact: true
                                )

                                StatCard(
                                    title: "Moving Time",
                                    value: stats.formattedMovingTime(),
                                    icon: "ic_stat_clock",
                                    isCompact: true
                                )
                                }
                            }
                            .padding()
                        } else {
                            // Portrait mode - vertical stack
                            VStack(spacing: cardSpacing) {
                                if !durationString.isEmpty {
                                    Text("\(formatNumber(pointCount)) distinct GPS points over the last \(durationString)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 5)
                                }

                                StatCard(
                                    title: "Vertical Feet Up",
                                    value: String(format: "%.0f ft", stats.verticalFeetUp),
                                    icon: "ic_stat_vertical_up",
                                    isCompact: false
                                )

                                StatCard(
                                    title: "Vertical Feet Down",
                                    value: String(format: "%.0f ft", stats.verticalFeetDown),
                                    icon: "ic_stat_vertical_down",
                                    isCompact: false
                                )

                                StatCard(
                                    title: "Horizontal Distance",
                                    value: String(format: "%.2f %@", stats.horizontalDistance, prefs.useMetric ? "km" : "mi"),
                                    icon: "ic_stat_horizontal_distance",
                                    isCompact: false
                                )

                                StatCard(
                                    title: "Average Downhill Pace",
                                    value: String(format: "%.1f %@", stats.avgDownhillPace, prefs.useMetric ? "km/h" : "mph"),
                                    icon: "ic_stat_downhill",
                                    isCompact: false
                                )

                                StatCard(
                                    title: "Average Uphill Pace",
                                    value: String(format: "%.1f %@", stats.avgUphillPace, prefs.useMetric ? "km/h" : "mph"),
                                    icon: "ic_stat_uphill",
                                    isCompact: false
                                )

                                StatCard(
                                    title: "Moving Time",
                                    value: stats.formattedMovingTime(),
                                    icon: "ic_stat_clock",
                                    isCompact: false
                                )
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Track Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadStats()
                // Start auto-refresh timer (1 second updates)
                updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    loadStats(showLoading: false)
                    updateDurationString()
                }
            }
            .onDisappear {
                // Stop auto-refresh timer
                updateTimer?.invalidate()
                updateTimer = nil
            }
        }
    }

    private func loadStats(showLoading: Bool = true) {
        if showLoading {
            isLoading = true
        }
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fileURL = locationService.getGpxFileURL()

                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    DispatchQueue.main.async {
                        if showLoading {
                            isLoading = false
                            if locationService.isTracking {
                                errorMessage = "Still gathering initial set of GPS data; will refresh when we have some."
                            } else {
                                errorMessage = "You need tracking enabled to see stats."
                            }
                        }
                    }
                    return
                }

                let gpxContent = try String(contentsOf: fileURL, encoding: .utf8)
                let calculator = StatsCalculator()
                let points = calculator.parseGpxFile(gpxContent: gpxContent)

                guard !points.isEmpty else {
                    DispatchQueue.main.async {
                        if showLoading {
                            isLoading = false
                            if locationService.isTracking {
                                errorMessage = "Still gathering initial set of GPS data; will refresh when we have some."
                            } else {
                                errorMessage = "You need tracking enabled to see stats."
                            }
                        }
                    }
                    return
                }

                let calculatedStats = calculator.calculateStats(points: points, useMetric: prefs.useMetric)

                // Extract start time from first point (timestamp is in milliseconds)
                let startTime = points.first.map { Date(timeIntervalSince1970: Double($0.timestamp) / 1000.0) }

                // Calculate optimized point count
                // When stationary, the last point is temporary and will be removed when the next arrives
                // Check if last 3 points have same lat/lon (stationary)
                var optimizedCount = points.count
                if points.count >= 3 {
                    let last = points[points.count - 1]
                    let secondLast = points[points.count - 2]
                    let thirdLast = points[points.count - 3]

                    if last.latitude == secondLast.latitude &&
                       last.longitude == secondLast.longitude &&
                       secondLast.latitude == thirdLast.latitude &&
                       secondLast.longitude == thirdLast.longitude {
                        // Stationary: current count includes temporary middle point that will be removed
                        optimizedCount = points.count - 1
                    }
                }

                DispatchQueue.main.async {
                    self.stats = calculatedStats
                    self.trackingStartTime = startTime
                    self.pointCount = optimizedCount
                    if let startTime = startTime {
                        self.durationString = self.formatDuration(from: startTime)
                    }
                    if showLoading {
                        isLoading = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    if showLoading {
                        isLoading = false
                        errorMessage = "Error loading track: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func formatDuration(from startTime: Date) -> String {
        let interval = Date().timeIntervalSince(startTime)
        let totalSeconds = Int(interval)

        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    private func updateDurationString() {
        if let startTime = trackingStartTime {
            durationString = formatDuration(from: startTime)
        }
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    var isCompact: Bool = false

    var body: some View {
        let iconSize: CGFloat = isCompact ? 45 : 60
        let hSpacing: CGFloat = isCompact ? 12 : 15
        let vSpacing: CGFloat = isCompact ? 3 : 5
        let padding: CGFloat = isCompact ? 12 : 16

        HStack(spacing: hSpacing) {
            Image(icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)

            VStack(alignment: .leading, spacing: vSpacing) {
                Text(title)
                    .font(isCompact ? .caption : .subheadline)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(isCompact ? .title3 : .title2)
                    .fontWeight(.bold)
            }

            Spacer()
        }
        .padding(padding)
        .background(Color(.systemGray6))
        .cornerRadius(15)
    }
}

#Preview {
    StatsView(
        prefs: AppPreferences(),
        locationService: LocationTrackingService(prefs: AppPreferences())
    )
}
