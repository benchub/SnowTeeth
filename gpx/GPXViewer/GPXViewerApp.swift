import SwiftUI

@main
struct GPXViewerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open GPX File...") {
                    NotificationCenter.default.post(name: .openGPXFile, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let openGPXFile = Notification.Name("openGPXFile")
}
