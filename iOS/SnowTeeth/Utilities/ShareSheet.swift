//
//  ShareSheet.swift
//  SnowTeeth
//
//  UIActivityViewController wrapper for sharing files
//

import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let fileURL: URL
    let statisticsText: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(
            activityItems: [statisticsText, fileURL],
            applicationActivities: nil
        )
        return activityVC
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
    }
}
