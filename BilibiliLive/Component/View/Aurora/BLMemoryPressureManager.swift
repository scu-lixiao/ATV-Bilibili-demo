//
//  BLMemoryPressureManager.swift
//  BilibiliLive
//
//  Created by Claude-4-Sonnet on 2025-10-17.
//  Phase 3: Proactive memory pressure monitoring and cleanup
//

import Foundation
import Kingfisher
import UIKit

/// Memory pressure levels for proactive cleanup
public enum BLMemoryPressureLevel: Int, Comparable {
    case normal = 0 // < 150MB
    case moderate = 1 // 150-180MB
    case high = 2 // 180-200MB
    case critical = 3 // > 200MB

    public static func < (lhs: BLMemoryPressureLevel, rhs: BLMemoryPressureLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// {{CHENGQI:
/// Action: Created
/// Timestamp: 2025-10-17 08:08:30 +08:00
/// Reason: Phase 3 内存优化 - 主动监控内存并执行分级清理
/// Principle_Applied: Proactive Resource Management - 在系统 warning 前主动清理
/// Optimization: 三级清理策略 (150MB/180MB/200MB 阈值)
/// Architectural_Note (AR): 与 BLPremiumPerformanceMonitor 集成，统一内存管理
/// }}
/// Proactive memory pressure manager with tiered cleanup strategies
public class BLMemoryPressureManager {
    // MARK: - Singleton

    public static let shared = BLMemoryPressureManager()

    // MARK: - Properties

    /// Current memory pressure level
    public private(set) var currentPressureLevel: BLMemoryPressureLevel = .normal

    /// Memory monitoring timer
    private var monitoringTimer: Timer?

    /// Is monitoring active
    private var isMonitoring: Bool = false

    /// Memory thresholds (in MB)
    private let moderateThreshold: Double = 150.0
    private let highThreshold: Double = 180.0
    private let criticalThreshold: Double = 200.0

    /// Last cleanup timestamp for each level (prevent excessive cleanup)
    private var lastCleanupTime: [BLMemoryPressureLevel: Date] = [:]

    /// Minimum interval between cleanups (in seconds)
    private let cleanupCooldown: TimeInterval = 5.0

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Start memory pressure monitoring
    public func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true

        // Check memory every 3 seconds
        monitoringTimer = Timer.scheduledTimer(
            withTimeInterval: 3.0,
            repeats: true
        ) { [weak self] _ in
            self?.checkMemoryPressure()
        }

        Logger.debug("[MemoryPressure] Monitoring started (check interval: 3s)")
    }

    /// Stop memory pressure monitoring
    public func stopMonitoring() {
        guard isMonitoring else { return }

        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil

        Logger.debug("[MemoryPressure] Monitoring stopped")
    }

    /// Manually trigger emergency cleanup
    public func triggerEmergencyCleanup() {
        Logger.warn("[MemoryPressure] ⚠️ Emergency cleanup triggered manually!")
        performCleanup(for: .critical, forced: true)
    }

    // MARK: - Private Methods

    private func checkMemoryPressure() {
        let currentMemory = BLPremiumPerformanceMonitor.shared.memoryUsage
        let newPressureLevel = determinePressureLevel(for: currentMemory)

        // Update pressure level
        if newPressureLevel != currentPressureLevel {
            let oldLevel = currentPressureLevel
            currentPressureLevel = newPressureLevel

            Logger.debug("[MemoryPressure] Level changed: \(oldLevel) → \(newPressureLevel) (Memory: \(currentMemory)MB)")
        }

        // Perform cleanup if needed
        if newPressureLevel > .normal {
            performCleanupIfNeeded(for: newPressureLevel, currentMemory: currentMemory)
        }
    }

    private func determinePressureLevel(for memory: Double) -> BLMemoryPressureLevel {
        if memory > criticalThreshold {
            return .critical
        } else if memory > highThreshold {
            return .high
        } else if memory > moderateThreshold {
            return .moderate
        } else {
            return .normal
        }
    }

    private func performCleanupIfNeeded(for level: BLMemoryPressureLevel, currentMemory _: Double) {
        // Check cooldown
        if let lastCleanup = lastCleanupTime[level] {
            let elapsed = Date().timeIntervalSince(lastCleanup)
            if elapsed < cleanupCooldown {
                return // Still in cooldown period
            }
        }

        performCleanup(for: level, forced: false)
        lastCleanupTime[level] = Date()
    }

    private func performCleanup(for level: BLMemoryPressureLevel, forced _: Bool) {
        let beforeMemory = BLPremiumPerformanceMonitor.shared.memoryUsage

        switch level {
        case .normal:
            break // No cleanup needed

        case .moderate:
            // Level 1: Clean expired disk cache only
            Logger.warn("[MemoryPressure] Level 1 cleanup (Moderate: >150MB)")
            ImageCache.default.cleanExpiredDiskCache {
                Logger.debug("[MemoryPressure] Expired disk cache cleared")
            }

        case .high:
            // Level 2: Clear memory cache + degrade quality
            Logger.warn("[MemoryPressure] ⚠️ Level 2 cleanup (High: >180MB)")
            ImageCache.default.clearMemoryCache()
            // Note: BLShadowRenderer only has clearAllCaches(), skip here to avoid disk cache clearing
            BLPremiumPerformanceMonitor.shared.setQualityLevel(.low)
            Logger.warn("[MemoryPressure] Memory cache cleared, quality → low")

        case .critical:
            // Level 3: Emergency cleanup - clear everything
            Logger.warn("[MemoryPressure] 🚨 Level 3 EMERGENCY cleanup (Critical: >200MB)")
            ImageCache.default.clearMemoryCache()
            BLShadowRenderer.clearAllCaches() // Clear all shadow caches
            BLPremiumPerformanceMonitor.shared.setQualityLevel(.minimal)

            // Force expire disk cache entries older than 1 day
            ImageCache.default.cleanExpiredDiskCache()

            Logger.warn("[MemoryPressure] 🚨 Emergency cleanup completed, quality → minimal")
        }

        // Log cleanup effect (async to avoid blocking)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let afterMemory = BLPremiumPerformanceMonitor.shared.memoryUsage
            let saved = beforeMemory - afterMemory
            Logger.debug("[MemoryPressure] Cleanup saved: \(saved)MB (Before: \(beforeMemory)MB, After: \(afterMemory)MB)")
        }
    }

    deinit {
        stopMonitoring()
    }
}
