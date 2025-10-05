//
//  BLScrollingStateDetector.swift
//  BilibiliLive
//
//  Created by Claude-4-Sonnet on 2025/10/06.
//  Performance Optimization: Detect scrolling velocity to adapt UI quality
//

import Foundation
import UIKit

/// Scrolling state based on velocity
enum BLScrollingState {
    case idle // Stopped
    case slow // <2 cells/sec
    case fast // 2-4 cells/sec
    case veryFast // >4 cells/sec

    /// Recommended quality level for this scrolling state
    var recommendedQualityLevel: BLPerformanceQualityLevel {
        switch self {
        case .idle:
            return .ultra
        case .slow:
            return .high
        case .fast:
            return .medium
        case .veryFast:
            return .low
        }
    }
}

/// Detects scrolling velocity by tracking focus changes
class BLScrollingStateDetector {
    // MARK: - Properties

    /// History of recent focus changes (timestamp, index)
    private var focusHistory: [(timestamp: CFTimeInterval, index: Int)] = []

    /// Maximum history length (sliding window size)
    private let historyLimit: Int = 5

    /// Threshold for considering scrolling as stopped (seconds)
    private let idleThreshold: CFTimeInterval = 0.3

    /// Current scrolling state
    private(set) var currentState: BLScrollingState = .idle

    /// Stability counter for state changes
    private var stateStabilityCounter: Int = 0

    /// Required stable frames before changing state
    private let stabilityThreshold: Int = 2

    // MARK: - Public Methods

    /// Record a focus change event
    /// - Parameter indexPath: Index path of focused cell
    func recordFocusChange(indexPath: IndexPath) {
        let now = CACurrentMediaTime()
        let linearIndex = indexPath.row

        focusHistory.append((timestamp: now, index: linearIndex))

        // Keep only recent history
        if focusHistory.count > historyLimit {
            focusHistory.removeFirst()
        }

        // Update current state
        updateCurrentState()
    }

    /// Get current scrolling state
    /// - Returns: Current scrolling state
    func getCurrentState() -> BLScrollingState {
        return currentState
    }

    /// Reset detector state
    func reset() {
        focusHistory.removeAll()
        currentState = .idle
        stateStabilityCounter = 0
    }

    // MARK: - Private Methods

    /// Update current scrolling state based on history
    private func updateCurrentState() {
        guard focusHistory.count >= 2 else {
            // Not enough data, assume idle
            transitionToState(.idle)
            return
        }

        let now = CACurrentMediaTime()
        let lastEvent = focusHistory.last!

        // Check if scrolling stopped
        if now - lastEvent.timestamp > idleThreshold {
            transitionToState(.idle)
            return
        }

        // Calculate velocity (cells per second)
        let velocity = calculateVelocity()

        // Determine state based on velocity
        let newState: BLScrollingState
        if velocity < 2.0 {
            newState = .slow
        } else if velocity < 4.0 {
            newState = .fast
        } else {
            newState = .veryFast
        }

        transitionToState(newState)
    }

    /// Calculate scrolling velocity in cells/second
    /// - Returns: Velocity in cells per second
    private func calculateVelocity() -> Double {
        guard focusHistory.count >= 2 else { return 0.0 }

        let first = focusHistory.first!
        let last = focusHistory.last!

        let timeDelta = last.timestamp - first.timestamp
        guard timeDelta > 0 else { return 0.0 }

        let indexDelta = abs(last.index - first.index)
        let velocity = Double(indexDelta) / timeDelta

        return velocity
    }

    /// Transition to new state with stability check
    /// - Parameter newState: Target state
    private func transitionToState(_ newState: BLScrollingState) {
        if newState == currentState {
            // State is stable, reset counter
            stateStabilityCounter = 0
        } else {
            // State changed, increment counter
            stateStabilityCounter += 1

            // Only transition if stable for threshold
            if stateStabilityCounter >= stabilityThreshold {
                currentState = newState
                stateStabilityCounter = 0
            }
        }
    }
}
