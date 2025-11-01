//
//  AppPreferences.swift
//  SnowTeeth
//
//  Created by SnowTeeth
//

import Foundation
import Combine

class AppPreferences: ObservableObject {
    private let defaults = UserDefaults.standard

    // Keys
    private enum Keys {
        static let downhillHard = "downhill_hard"
        static let downhillMedium = "downhill_medium"
        static let downhillEasy = "downhill_easy"
        static let uphillEasy = "uphill_easy"
        static let uphillMedium = "uphill_medium"
        static let uphillHard = "uphill_hard"
        static let useMetric = "use_metric"
        static let visualizationStyle = "visualization_style"
        static let isTracking = "is_tracking"
        static let useAlternateAscentVisualization = "use_alternate_ascent_visualization"
    }

    // Default values (in mph)
    static let defaultDownhillHard: Float = 10.0
    static let defaultDownhillMedium: Float = 6.0
    static let defaultDownhillEasy: Float = 2.0
    static let defaultUphillEasy: Float = 1.0
    static let defaultUphillMedium: Float = 3.0
    static let defaultUphillHard: Float = 5.0

    // Threshold properties
    @Published var downhillHardThreshold: Float {
        didSet { defaults.set(downhillHardThreshold, forKey: Keys.downhillHard) }
    }

    @Published var downhillMediumThreshold: Float {
        didSet { defaults.set(downhillMediumThreshold, forKey: Keys.downhillMedium) }
    }

    @Published var downhillEasyThreshold: Float {
        didSet { defaults.set(downhillEasyThreshold, forKey: Keys.downhillEasy) }
    }

    @Published var uphillEasyThreshold: Float {
        didSet { defaults.set(uphillEasyThreshold, forKey: Keys.uphillEasy) }
    }

    @Published var uphillMediumThreshold: Float {
        didSet { defaults.set(uphillMediumThreshold, forKey: Keys.uphillMedium) }
    }

    @Published var uphillHardThreshold: Float {
        didSet { defaults.set(uphillHardThreshold, forKey: Keys.uphillHard) }
    }

    // Settings properties
    @Published var useMetric: Bool {
        didSet { defaults.set(useMetric, forKey: Keys.useMetric) }
    }

    @Published var visualizationStyle: VisualizationStyle {
        didSet { defaults.set(visualizationStyle.rawValue, forKey: Keys.visualizationStyle) }
    }

    @Published var isTracking: Bool {
        didSet { defaults.set(isTracking, forKey: Keys.isTracking) }
    }

    @Published var useAlternateAscentVisualization: Bool {
        didSet { defaults.set(useAlternateAscentVisualization, forKey: Keys.useAlternateAscentVisualization) }
    }

    init() {
        // Load saved values or use defaults
        self.downhillHardThreshold = defaults.object(forKey: Keys.downhillHard) as? Float ?? Self.defaultDownhillHard
        self.downhillMediumThreshold = defaults.object(forKey: Keys.downhillMedium) as? Float ?? Self.defaultDownhillMedium
        self.downhillEasyThreshold = defaults.object(forKey: Keys.downhillEasy) as? Float ?? Self.defaultDownhillEasy
        self.uphillEasyThreshold = defaults.object(forKey: Keys.uphillEasy) as? Float ?? Self.defaultUphillEasy
        self.uphillMediumThreshold = defaults.object(forKey: Keys.uphillMedium) as? Float ?? Self.defaultUphillMedium
        self.uphillHardThreshold = defaults.object(forKey: Keys.uphillHard) as? Float ?? Self.defaultUphillHard
        self.useMetric = defaults.bool(forKey: Keys.useMetric)

        let styleString = defaults.string(forKey: Keys.visualizationStyle) ?? VisualizationStyle.flame.rawValue
        self.visualizationStyle = VisualizationStyle(rawValue: styleString) ?? .flame

        self.isTracking = defaults.bool(forKey: Keys.isTracking)
        self.useAlternateAscentVisualization = defaults.bool(forKey: Keys.useAlternateAscentVisualization)
    }
}
