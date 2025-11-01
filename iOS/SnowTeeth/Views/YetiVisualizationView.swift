//
//  YetiVisualizationView.swift
//  SnowTeeth
//
//  Created by SnowTeeth
//

import SwiftUI
import AVFoundation
import AVKit
import Combine

// MARK: - Yeti State Machine

class YetiStateMachine: ObservableObject {
    @Published var currentState: Int = 0

    // Bucket to state mapping (from shared/constants/yeti_state_mapping.json)
    private let bucketToState: [VelocityBucket: Int] = [
        .idle: 0,
        .downhillEasy: 1,
        .uphillEasy: 1,
        .downhillMedium: 2,
        .uphillMedium: 2,
        .downhillHard: 3,
        .uphillHard: 3
    ]

    // Video variants for same-state loops with weights
    // (from shared/constants/yeti_video_weights.json)
    private let sameStateVariants: [String: [(name: String, weight: Float)]] = [
        "0 to 0": [
            ("0 to 0 a", 2.0),
            ("0 to 0 b", 1.0),
            ("0 to 0 c", 1.5),
            ("0 to 0 d", 5.0),
            ("0 to 0 e", 3.0),
            ("0 to 0 f", 2.0),
            ("0 to 0 g", 3.0),
            ("0 to 0 h", 2.0),
            ("0 to 0 i", 2.0)
        ],
        "1 to 1": [
            ("1 to 1 a", 1.0),
            ("1 to 1 b", 1.0),
            ("1 to 1 c", 1.0),
            ("1 to 1 d", 3.0),
            ("1 to 1 e", 3.0)
        ],
        "2 to 2": [
            ("2 to 2 a", 1.0),
            ("2 to 2 b", 1.0),
            ("2 to 2 c", 1.0),
            ("2 to 2 e", 5.0),
            ("2 to 2 f", 1.0),
            ("2 to 2 g", 1.0)
        ],
        "3 to 3": [
            ("3 to 3 a", 2.0),
            ("3 to 3 b", 1.0),
            ("3 to 3 c", 1.0),
            ("3 to 3 d", 2.0)
        ]
    ]

    func getTargetState(for bucket: VelocityBucket) -> Int {
        return bucketToState[bucket] ?? 0
    }

    func getNextState(currentBucket: VelocityBucket) -> Int {
        let targetState = getTargetState(for: currentBucket)

        // Gradual transitions - move one state at a time
        if targetState > currentState {
            return currentState + 1
        } else if targetState < currentState {
            return currentState - 1
        } else {
            return currentState
        }
    }

    func getVideoFilename(from: Int, to: Int) -> String? {
        if from == to {
            // Same state - pick weighted random variant
            let key = "\(from) to \(to)"
            guard let variants = sameStateVariants[key], !variants.isEmpty else {
                print("WARNING: No variants found for \(key)")
                return nil
            }
            return weightedRandomSelection(variants: variants)
        } else {
            // State transition
            return "\(from) to \(to)"
        }
    }

    // Weighted random selection algorithm
    private func weightedRandomSelection(variants: [(name: String, weight: Float)]) -> String {
        let totalWeight = variants.reduce(0) { $0 + $1.weight }
        var random = Float.random(in: 0..<totalWeight)

        for variant in variants {
            random -= variant.weight
            if random < 0 {
                return variant.name
            }
        }

        // Fallback (should never happen)
        return variants.first?.name ?? ""
    }
}

// MARK: - Video Player View

class YetiPlayerCoordinator: NSObject {
    var player: AVQueuePlayer?
    var currentVideoName: String?
    var nextVideoName: String?
    var getNextVideo: (() -> String)?
    private var timeObserver: Any?
    private var hasQueuedNext = false

    func initialize(initialVideo: String) {
        guard let videoURL = Bundle.main.url(forResource: initialVideo, withExtension: "mp4") else {
            print("ERROR: Could not find initial video: \(initialVideo).mp4")
            return
        }

        let item = createPlayerItem(from: videoURL)
        currentVideoName = initialVideo

        player = AVQueuePlayer(playerItem: item)
        player?.automaticallyWaitsToMinimizeStalling = false

        // Observe when items finish to update tracking
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(itemDidFinish(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )

        // Add time observer to queue next video early
        addTimeObserver()

        player?.play()

        // Immediately queue the next video
        queueNextVideo()
    }

    private func addTimeObserver() {
        // Check playback progress every 0.5 seconds
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.checkQueueStatus(at: time)
        }
    }

    private func checkQueueStatus(at time: CMTime) {
        guard let currentItem = player?.currentItem,
              currentItem.status == .readyToPlay else { return }

        let currentTime = CMTimeGetSeconds(time)
        let duration = CMTimeGetSeconds(currentItem.duration)

        // If we're past 70% of the video and haven't queued the next one yet, queue it now
        if !hasQueuedNext && duration > 0 && currentTime / duration > 0.7 {
            queueNextVideo()
        }
    }

    @objc func itemDidFinish(_ notification: Notification) {
        // Current video finished, move to next
        currentVideoName = nextVideoName
        hasQueuedNext = false

        // Queue next video immediately as backup (in case time observer didn't fire)
        if let player = player, player.items().count < 2 {
            queueNextVideo()
        }
    }

    func queueNextVideo() {
        guard let getNextVideo = getNextVideo else { return }
        guard !hasQueuedNext else { return }

        let nextVideo = getNextVideo()
        nextVideoName = nextVideo

        guard let videoURL = Bundle.main.url(forResource: nextVideo, withExtension: "mp4") else {
            print("ERROR: Could not find next video: \(nextVideo).mp4")
            return
        }

        let item = createPlayerItem(from: videoURL)
        player?.insert(item, after: nil) // Add to end of queue
        hasQueuedNext = true

        debugLog("Queued next video: \(nextVideo)")
    }

    private func createPlayerItem(from url: URL) -> AVPlayerItem {
        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: true,
            AVURLAssetAllowsCellularAccessKey: true
        ])
        let item = AVPlayerItem(asset: asset)
        // Increase buffer duration for smoother transitions
        item.preferredForwardBufferDuration = 5.0
        return item
    }

    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        NotificationCenter.default.removeObserver(self)
    }
}

struct YetiVideoPlayerView: UIViewControllerRepresentable {
    let initialVideo: String
    let getNextVideo: () -> String

    func makeCoordinator() -> YetiPlayerCoordinator {
        let coordinator = YetiPlayerCoordinator()
        coordinator.getNextVideo = getNextVideo
        return coordinator
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill

        // Initialize with first video
        context.coordinator.initialize(initialVideo: initialVideo)
        controller.player = context.coordinator.player

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // No updates needed - coordinator manages everything
    }
}

// MARK: - Main Yeti Visualization View

struct YetiVisualization: View {
    @ObservedObject var locationService: LocationTrackingService
    @StateObject private var stateMachine = YetiStateMachine()

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            YetiVideoPlayerView(
                initialVideo: "0 to 0 a",
                getNextVideo: getNextVideo
            )
            .edgesIgnoringSafeArea(.all)
            .allowsHitTesting(false) // Allow taps to pass through to parent
        }
    }

    private func getNextVideo() -> String {
        // Get current velocity bucket
        let currentBucket = locationService.currentBucket

        // Determine next state
        let nextState = stateMachine.getNextState(currentBucket: currentBucket)

        // Get video filename for transition
        if let videoFilename = stateMachine.getVideoFilename(from: stateMachine.currentState, to: nextState) {
            stateMachine.currentState = nextState
            return videoFilename
        } else {
            print("ERROR: No video found for transition \(stateMachine.currentState) to \(nextState)")
            // Stay in current state and replay a same-state video
            if let fallbackVideo = stateMachine.getVideoFilename(from: stateMachine.currentState, to: stateMachine.currentState) {
                return fallbackVideo
            }
            return "0 to 0 a" // Ultimate fallback
        }
    }
}
