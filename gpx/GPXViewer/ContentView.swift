import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var coordinator = HoverCoordinator()
    @State private var gpxData: GPXData?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var unitSystem: UnitSystem = .metric

    var body: some View {
        VStack(spacing: 0) {
            if let gpxData = gpxData {
                // Toolbar with unit toggle and clear selection button
                HStack {
                    if coordinator.dragSelection != nil {
                        Button("Clear Selection") {
                            coordinator.clearDragSelection()
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    Text("Units:")
                        .foregroundColor(.secondary)
                    Picker("", selection: $unitSystem) {
                        Text("Metric").tag(UnitSystem.metric)
                        Text("Imperial").tag(UnitSystem.imperial)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

                // Three-pane layout
                GeometryReader { geometry in
                    VStack(spacing: 12) {
                        // Top row: Elevation and Speed charts side by side
                        HStack(spacing: 12) {
                            ElevationChartView(gpxData: gpxData, coordinator: coordinator, unitSystem: unitSystem)
                                .frame(height: geometry.size.height * 0.25)

                            SpeedChartView(gpxData: gpxData, coordinator: coordinator, unitSystem: unitSystem)
                                .frame(height: geometry.size.height * 0.25)
                        }

                        // Bottom row: Map
                        MapView(gpxData: gpxData, coordinator: coordinator, unitSystem: unitSystem)
                            .frame(height: geometry.size.height * 0.65)
                    }
                    .padding(12)
                }
            } else {
                // Welcome screen
                VStack(spacing: 20) {
                    Image(systemName: "map")
                        .font(.system(size: 72))
                        .foregroundColor(.secondary)

                    Text("GPX Viewer")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Open a GPX file to visualize elevation, speed, and route")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Open GPX File") {
                        openFile()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("o", modifiers: .command)

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .onReceive(NotificationCenter.default.publisher(for: .openGPXFile)) { _ in
            openFile()
        }
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType(filenameExtension: "gpx")!]

        if panel.runModal() == .OK, let url = panel.url {
            loadGPXFile(from: url)
        }
    }

    private func loadGPXFile(from url: URL) {
        isLoading = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try Data(contentsOf: url)
                let parser = GPXParser()

                if let parsedData = parser.parse(data: data) {
                    DispatchQueue.main.async {
                        self.coordinator.clearDragSelection()
                        self.gpxData = parsedData
                        self.isLoading = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to parse GPX file"
                        self.isLoading = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Error loading file: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

}
