//
//  BLPerformanceMetrics.swift
//  BilibiliLive
//
//  Created by Aurora Premium Enhancement on 2025/06/09.
//  Premium 2025: Enhanced performance monitoring and adaptive quality system
//

import Foundation
import QuartzCore
import UIKit

// MARK: - Premium 2025: Performance Monitoring System

/// Performance quality level for adaptive degradation
public enum BLPerformanceQualityLevel: Int, Comparable {
    case ultra = 4 // 60fps, all effects enabled
    case high = 3 // 50-60fps, full effects
    case medium = 2 // 40-50fps, reduced particles
    case low = 1 // 30-40fps, minimal effects
    case minimal = 0 // <30fps, essential only

    public static func < (lhs: BLPerformanceQualityLevel, rhs: BLPerformanceQualityLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    var qualityMultiplier: CGFloat {
        switch self {
        case .ultra: return 1.0
        case .high: return 0.85
        case .medium: return 0.65
        case .low: return 0.45
        case .minimal: return 0.25
        }
    }
}

/// Premium 2025: Enhanced performance metrics with automatic quality adaptation
public class BLPremiumPerformanceMonitor {
    // MARK: - Properties

    /// Singleton instance
    public static let shared = BLPremiumPerformanceMonitor()

    /// Current FPS
    public private(set) var currentFPS: Double = 60.0

    /// Current memory usage in MB
    public private(set) var memoryUsage: Double = 0.0

    /// Current quality level
    public private(set) var currentQualityLevel: BLPerformanceQualityLevel = .ultra

    /// FPS threshold for quality degradation
    private let fpsThresholds: [BLPerformanceQualityLevel: Double] = [
        .ultra: 55.0,
        .high: 50.0,
        .medium: 40.0,
        .low: 30.0,
        .minimal: 0.0,
    ]

    /// Display link for FPS monitoring
    private var displayLink: CADisplayLink?

    /// FPS calculation
    private var lastFrameTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var accumulatedFrameTime: CFTimeInterval = 0

    /// Quality change callback
    public var onQualityLevelChanged: ((BLPerformanceQualityLevel) -> Void)?

    /// Performance degradation callback
    public var onPerformanceDegraded: ((Double) -> Void)?

    /// Is monitoring active
    private var isMonitoring: Bool = false

    /// Stability counter for quality changes
    private var stabilityCounter: Int = 0
    private let stabilityThreshold: Int = 30 // 30 frames of stability required

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Start performance monitoring
    public func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        lastFrameTimestamp = CACurrentMediaTime()

        // Create display link
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        displayLink?.add(to: .main, forMode: .common)

        print("[Aurora Premium] Performance monitoring started")
    }

    /// Stop performance monitoring
    public func stopMonitoring() {
        guard isMonitoring else { return }

        isMonitoring = false
        displayLink?.invalidate()
        displayLink = nil

        print("[Aurora Premium] Performance monitoring stopped")
    }

    /// Manually set quality level
    public func setQualityLevel(_ level: BLPerformanceQualityLevel) {
        guard level != currentQualityLevel else { return }

        let oldLevel = currentQualityLevel
        currentQualityLevel = level

        print("[Aurora Premium] Quality level changed: \(oldLevel) → \(level)")
        onQualityLevelChanged?(level)
    }

    /// Get recommended quality level for current performance
    public func getRecommendedQualityLevel() -> BLPerformanceQualityLevel {
        // Determine quality based on current FPS
        if currentFPS >= 55.0 {
            return .ultra
        } else if currentFPS >= 50.0 {
            return .high
        } else if currentFPS >= 40.0 {
            return .medium
        } else if currentFPS >= 30.0 {
            return .low
        } else {
            return .minimal
        }
    }

    // MARK: - Private Methods

    @objc private func displayLinkTick() {
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastFrameTimestamp

        guard deltaTime > 0 else { return }

        // Calculate instantaneous FPS
        let instantFPS = 1.0 / deltaTime

        // Accumulate for smoothed FPS
        frameCount += 1
        accumulatedFrameTime += deltaTime

        // Update FPS every 30 frames for stability
        if frameCount >= 30 {
            currentFPS = Double(frameCount) / accumulatedFrameTime

            // Update memory usage
            updateMemoryUsage()

            // Check for quality adaptation
            checkQualityAdaptation()

            // Reset accumulators
            frameCount = 0
            accumulatedFrameTime = 0
        }

        lastFrameTimestamp = currentTime
    }

    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            memoryUsage = Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        }
    }

    private func checkQualityAdaptation() {
        let recommendedLevel = getRecommendedQualityLevel()

        // Only change quality if stable for threshold frames
        if recommendedLevel != currentQualityLevel {
            stabilityCounter += 1

            if stabilityCounter >= stabilityThreshold {
                // Quality level change confirmed
                setQualityLevel(recommendedLevel)
                stabilityCounter = 0

                // Notify performance degradation if quality dropped
                if recommendedLevel < currentQualityLevel {
                    onPerformanceDegraded?(currentFPS)
                }
            }
        } else {
            // Reset stability counter if performance is stable
            stabilityCounter = max(0, stabilityCounter - 1)
        }
    }
}

// MARK: - Performance-Aware Configuration Extension

public extension BLLayerConfiguration {
    /// Create configuration adapted to current performance level
    static func adaptive(for qualityLevel: BLPerformanceQualityLevel) -> BLLayerConfiguration {
        let multiplier = qualityLevel.qualityMultiplier

        return BLLayerConfiguration(
            intensity: multiplier,
            duration: 0.3 + (0.3 * Double(multiplier)), // Slower animations on lower quality
            isAnimated: qualityLevel >= .medium, // Disable animations on low quality
            properties: [
                "reducedEffects": qualityLevel < .medium,
                "enhancedEffects": qualityLevel == .ultra,
                "particleCount": Int(50.0 * multiplier),
                "blurQuality": qualityLevel.rawValue,
            ],
            timing: CAMediaTimingFunction(name: .easeInEaseOut)
        )
    }
}
