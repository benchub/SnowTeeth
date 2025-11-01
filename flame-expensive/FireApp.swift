//
//  FireApp.swift
//  Flame
//
//  Main entry point for the macOS fire shader app
//

import SwiftUI

@main
struct FireApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // Remove some default menu items for a cleaner experience
            CommandGroup(replacing: .newItem) { }
        }
    }
}
