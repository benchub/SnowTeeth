import SwiftUI

struct SpeedChartView: View {
    let gpxData: GPXData
    @ObservedObject var coordinator: HoverCoordinator
    let unitSystem: UnitSystem
    @State private var hoverLocation: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))

                // Chart
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Speed")
                            .font(.headline)

                        if let selection = coordinator.dragSelection {
                            Spacer()
                            Text(getMeasurementText(selection: selection))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.trailing, 4)
                        }
                    }
                    .padding([.top, .leading], 8)

                    Canvas { context, size in
                        drawChart(in: context, size: size)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .overlay(
                GeometryReader { geo in
                    Color.clear
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                if coordinator.dragSelection == nil {
                                    handleHover(at: location, size: geo.size)
                                }
                            case .ended:
                                coordinator.setHoveredPoint(nil)
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    handleDrag(at: value.location, size: geo.size, isStart: value.translation.width == 0 && value.translation.height == 0)
                                }
                                .onEnded { _ in
                                    coordinator.endDragSelection()
                                }
                        )
                }
            )
        }
    }

    private func drawChart(in context: GraphicsContext, size: CGSize) {
        guard !gpxData.points.isEmpty else { return }

        let padding: CGFloat = 40
        let bottomPadding: CGFloat = 50 // Extra space for time labels
        let chartWidth = size.width - padding * 2
        let chartHeight = size.height - padding - bottomPadding

        let speedRange = gpxData.speedRange
        let speedSpan = speedRange.upperBound - speedRange.lowerBound

        // Calculate time range in minutes
        let startTime = gpxData.points.first!.time
        let totalMinutes = gpxData.points.last!.time.timeIntervalSince(startTime) / 60.0

        // Draw axes
        var axisPath = Path()
        axisPath.move(to: CGPoint(x: padding, y: padding))
        axisPath.addLine(to: CGPoint(x: padding, y: size.height - bottomPadding))
        axisPath.addLine(to: CGPoint(x: size.width - padding, y: size.height - bottomPadding))
        context.stroke(axisPath, with: .color(.gray), lineWidth: 1)

        // Draw raw speed profile (light/transparent)
        var rawPath = Path()
        var firstRawPoint = true

        for (index, point) in gpxData.points.enumerated() {
            guard let speed = point.speed else { continue }

            let x = padding + (CGFloat(index) / CGFloat(gpxData.points.count - 1)) * chartWidth
            let normalizedSpeed = speedSpan > 0 ?
                (speed - speedRange.lowerBound) / speedSpan : 0.5
            let y = size.height - bottomPadding - CGFloat(normalizedSpeed) * chartHeight

            if firstRawPoint {
                rawPath.move(to: CGPoint(x: x, y: y))
                firstRawPoint = false
            } else {
                rawPath.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.stroke(rawPath, with: .color(.green.opacity(0.3)), lineWidth: 1)

        // Draw smoothed speed profile (main line)
        var smoothedPath = Path()
        var firstSmoothedPoint = true

        for (index, point) in gpxData.points.enumerated() {
            guard let speed = point.smoothedSpeed else { continue }

            let x = padding + (CGFloat(index) / CGFloat(gpxData.points.count - 1)) * chartWidth
            let normalizedSpeed = speedSpan > 0 ?
                (speed - speedRange.lowerBound) / speedSpan : 0.5
            let y = size.height - bottomPadding - CGFloat(normalizedSpeed) * chartHeight

            if firstSmoothedPoint {
                smoothedPath.move(to: CGPoint(x: x, y: y))
                firstSmoothedPoint = false
            } else {
                smoothedPath.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.stroke(smoothedPath, with: .color(.green), lineWidth: 2)

        // Draw drag selection highlight
        if let selection = coordinator.dragSelection {
            let range = selection.range
            let startX = padding + (CGFloat(range.lowerBound) / CGFloat(gpxData.points.count - 1)) * chartWidth
            let endX = padding + (CGFloat(range.upperBound) / CGFloat(gpxData.points.count - 1)) * chartWidth

            // Draw semi-transparent rectangle
            let selectionRect = CGRect(
                x: startX,
                y: padding,
                width: endX - startX,
                height: chartHeight
            )
            context.fill(Path(selectionRect), with: .color(.green.opacity(0.15)))

            // Draw vertical lines at start and end
            var startLine = Path()
            startLine.move(to: CGPoint(x: startX, y: padding))
            startLine.addLine(to: CGPoint(x: startX, y: size.height - bottomPadding))
            context.stroke(startLine, with: .color(.green), lineWidth: 2)

            var endLine = Path()
            endLine.move(to: CGPoint(x: endX, y: padding))
            endLine.addLine(to: CGPoint(x: endX, y: size.height - bottomPadding))
            context.stroke(endLine, with: .color(.green), lineWidth: 2)
        }

        // Draw time labels on horizontal axis
        let timeInterval: Double = determineTimeInterval(totalMinutes: totalMinutes)
        var currentTime: Double = 0

        while currentTime <= totalMinutes {
            let normalizedTime = currentTime / totalMinutes
            let x = padding + CGFloat(normalizedTime) * chartWidth

            // Draw tick mark
            var tickPath = Path()
            tickPath.move(to: CGPoint(x: x, y: size.height - bottomPadding))
            tickPath.addLine(to: CGPoint(x: x, y: size.height - bottomPadding + 5))
            context.stroke(tickPath, with: .color(.gray), lineWidth: 1)

            // Draw label
            let timeText = String(format: "%.0f min", currentTime)
            context.draw(
                Text(timeText).font(.caption).foregroundColor(.secondary),
                at: CGPoint(x: x, y: size.height - bottomPadding + 15),
                anchor: .top
            )

            currentTime += timeInterval
        }

        // Draw hover indicator
        if let hoveredIndex = coordinator.hoveredPointIndex,
           hoveredIndex < gpxData.points.count {
            let point = gpxData.points[hoveredIndex]

            // Use smoothed speed for position if available, otherwise raw
            if let smoothedSpeed = point.smoothedSpeed {
                let x = padding + (CGFloat(hoveredIndex) / CGFloat(gpxData.points.count - 1)) * chartWidth
                let normalizedSpeed = speedSpan > 0 ?
                    (smoothedSpeed - speedRange.lowerBound) / speedSpan : 0.5
                let y = size.height - bottomPadding - CGFloat(normalizedSpeed) * chartHeight

                // Draw vertical line
                var verticalLine = Path()
                verticalLine.move(to: CGPoint(x: x, y: padding))
                verticalLine.addLine(to: CGPoint(x: x, y: size.height - bottomPadding))
                context.stroke(verticalLine, with: .color(.red.opacity(0.5)), lineWidth: 1)

                // Draw point
                let circleRect = CGRect(x: x - 4, y: y - 4, width: 8, height: 8)
                context.fill(Path(ellipseIn: circleRect), with: .color(.red))

                // Draw label with both smoothed and raw speed
                let convertedSmoothed = unitSystem.convertSpeed(smoothedSpeed)
                var speedText = String(format: "%.1f %@", convertedSmoothed, unitSystem.speedUnit)

                if let rawSpeed = point.speed {
                    let convertedRaw = unitSystem.convertSpeed(rawSpeed)
                    speedText += String(format: " (raw: %.1f)", convertedRaw)
                }

                let textPosition = CGPoint(x: x + 10, y: y - 10)
                context.draw(
                    Text(speedText)
                        .font(.caption)
                        .foregroundColor(.primary),
                    at: textPosition,
                    anchor: .leading
                )
            }
        }

        // Draw speed labels on vertical axis
        let minSpeedConverted = unitSystem.convertSpeed(speedRange.lowerBound)
        let maxSpeedConverted = unitSystem.convertSpeed(speedRange.upperBound)

        context.draw(
            Text(String(format: "%.1f %@", minSpeedConverted, unitSystem.speedUnit)).font(.caption).foregroundColor(.secondary),
            at: CGPoint(x: padding - 5, y: size.height - bottomPadding),
            anchor: .trailing
        )

        context.draw(
            Text(String(format: "%.1f %@", maxSpeedConverted, unitSystem.speedUnit)).font(.caption).foregroundColor(.secondary),
            at: CGPoint(x: padding - 5, y: padding),
            anchor: .trailing
        )
    }

    private func determineTimeInterval(totalMinutes: Double) -> Double {
        // Choose appropriate interval based on total duration
        if totalMinutes <= 10 {
            return 2 // Every 2 minutes
        } else if totalMinutes <= 30 {
            return 5 // Every 5 minutes
        } else if totalMinutes <= 60 {
            return 10 // Every 10 minutes
        } else if totalMinutes <= 120 {
            return 15 // Every 15 minutes
        } else if totalMinutes <= 240 {
            return 30 // Every 30 minutes
        } else {
            return 60 // Every hour
        }
    }

    private func handleHover(at location: CGPoint, size: CGSize) {
        let padding: CGFloat = 40
        let chartWidth = size.width - padding * 2

        guard location.x >= padding && location.x <= size.width - padding else {
            coordinator.setHoveredPoint(nil)
            return
        }

        let normalizedX = (location.x - padding) / chartWidth
        let index = Int(normalizedX * CGFloat(gpxData.points.count - 1))
        let clampedIndex = max(0, min(gpxData.points.count - 1, index))

        coordinator.setHoveredPoint(clampedIndex)
    }

    private func handleDrag(at location: CGPoint, size: CGSize, isStart: Bool) {
        let padding: CGFloat = 40
        let chartWidth = size.width - padding * 2

        guard location.x >= padding && location.x <= size.width - padding else {
            return
        }

        let normalizedX = (location.x - padding) / chartWidth
        let index = Int(normalizedX * CGFloat(gpxData.points.count - 1))
        let clampedIndex = max(0, min(gpxData.points.count - 1, index))

        if isStart {
            coordinator.startDragSelection(at: clampedIndex)
        } else {
            coordinator.updateDragSelection(to: clampedIndex)
        }
    }

    private func getMeasurementText(selection: DragSelection) -> String {
        let range = selection.range
        guard range.lowerBound < gpxData.points.count && range.upperBound < gpxData.points.count else {
            return ""
        }

        let startPoint = gpxData.points[range.lowerBound]
        let endPoint = gpxData.points[range.upperBound]

        let timeDiff = endPoint.time.timeIntervalSince(startPoint.time)
        let minutes = timeDiff / 60.0

        // Calculate average smoothed speed in the selection
        var totalSpeed: Double = 0
        var speedCount = 0
        for i in range {
            if let speed = gpxData.points[i].smoothedSpeed {
                totalSpeed += speed
                speedCount += 1
            }
        }

        let avgSpeed = speedCount > 0 ? totalSpeed / Double(speedCount) : 0
        let convertedAvgSpeed = unitSystem.convertSpeed(avgSpeed)

        return String(format: "Δt: %.1f min, Smoothed avg: %.1f %@",
                     minutes,
                     convertedAvgSpeed,
                     unitSystem.speedUnit)
    }
}
