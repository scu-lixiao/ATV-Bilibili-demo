//
//  BLPerformanceMetrics.swift
//  BilibiliLive
//
//  Aurora Premium Enhancement System
//  Task: P1-LD-002 - Performance Metrics System
//

import QuartzCore
import UIKit

// MARK: - Performance Data Structures

struct BLAnimationMetrics {
    let identifier: String
    let startTime: CFTimeInterval
    let endTime: CFTimeInterval?
    let targetLayers: [BLVisualLayerType]

    var duration: CFTimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime - startTime
    }
}

struct BLLayerMetrics {
    let type: BLVisualLayerType
    var activationCount: Int = 0
    var totalActiveTime: CFTimeInterval = 0
    var errorCount: Int = 0
    var lastActivationTime: CFTimeInterval?
    var averageActivationDuration: CFTimeInterval {
        return activationCount > 0 ? totalActiveTime / CFTimeInterval(activationCount) : 0
    }
}

struct BLSystemMetrics {
    var frameRate: Double = 60.0
    var memoryUsage: Double = 0.0
    var cpuUsage: Double = 0.0
    var gpuUsage: Double = 0.0
    var batteryImpact: Double = 0.0
    var thermalState: ProcessInfo.ThermalState = .nominal

    var isPerformanceCritical: Bool {
        return frameRate < 30 || memoryUsage > 80 || cpuUsage > 80 || thermalState != .nominal
    }
}

// MARK: - Performance Metrics Manager

class BLPerformanceMetrics {
    // MARK: - Properties

    private var animationMetrics: [String: BLAnimationMetrics] = [:]
    private var layerMetrics: [BLVisualLayerType: BLLayerMetrics] = [:]
    private var systemMetrics: BLSystemMetrics = .init()

    private var displayLink: CADisplayLink?
    private var frameCount: Int = 0
    private var lastTimestamp: CFTimeInterval = 0

    // Performance thresholds
    private let targetFrameRate: Double = 60.0
    private let warningFrameRate: Double = 45.0
    private let criticalFrameRate: Double = 30.0

    private let maxMemoryUsage: Double = 50.0 // MB
    private let warningMemoryUsage: Double = 40.0 // MB

    // MARK: - Initialization

    init() {
        setupDisplayLink()
        setupSystemMonitoring()
        initializeLayerMetrics()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Setup Methods

    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateFrameRate))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func setupSystemMonitoring() {
        // Start system metrics monitoring
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateSystemMetrics()
        }
    }

    private func initializeLayerMetrics() {
        for layerType in [BLVisualLayerType.background, .contentEnhancement, .lightingEffect, .interactionFeedback] {
            layerMetrics[layerType] = BLLayerMetrics(type: layerType)
        }
    }

    private func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
    }

    // MARK: - Frame Rate Monitoring

    @objc private func updateFrameRate(_ displayLink: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = displayLink.timestamp
            return
        }

        frameCount += 1
        let currentTime = displayLink.timestamp
        let elapsed = currentTime - lastTimestamp

        if elapsed >= 1.0 {
            systemMetrics.frameRate = Double(frameCount) / elapsed
            frameCount = 0
            lastTimestamp = currentTime
        }
    }

    // MARK: - System Metrics Updates

    private func updateSystemMetrics() {
        // Update memory usage
        systemMetrics.memoryUsage = getCurrentMemoryUsage()

        // Update thermal state
        systemMetrics.thermalState = ProcessInfo.processInfo.thermalState

        // Update CPU usage (simplified estimation)
        systemMetrics.cpuUsage = getCurrentCPUUsage()

        // Estimate battery impact based on activity
        systemMetrics.batteryImpact = estimateBatteryImpact()
    }

    private func getCurrentMemoryUsage() -> Double {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            return Double(taskInfo.resident_size) / (1024 * 1024) // Convert to MB
        }

        return 0.0
    }

    private func getCurrentCPUUsage() -> Double {
        // Simplified CPU usage estimation based on animation activity
        let activeAnimations = animationMetrics.filter { $0.value.endTime == nil }.count
        let maxConcurrentAnimations = 4

        return min(Double(activeAnimations) / Double(maxConcurrentAnimations) * 100, 100)
    }

    private func estimateBatteryImpact() -> Double {
        // Estimate based on active layers and frame rate deviation
        let activeLayerCount = layerMetrics.filter {
            $0.value.lastActivationTime != nil &&
                CACurrentMediaTime() - $0.value.lastActivationTime! < 1.0
        }.count

        let frameRateImpact = max(0, (targetFrameRate - systemMetrics.frameRate) / targetFrameRate * 100)
        let layerImpact = Double(activeLayerCount) * 5.0 // 5% per active layer

        return min(frameRateImpact + layerImpact, 100)
    }

    // MARK: - Animation Metrics

    func recordAnimationStart(_ identifier: String, targetLayers: [BLVisualLayerType] = []) {
        let metrics = BLAnimationMetrics(
            identifier: identifier,
            startTime: CACurrentMediaTime(),
            endTime: nil,
            targetLayers: targetLayers
        )

        animationMetrics[identifier] = metrics
    }

    func recordAnimationEnd(_ identifier: String) {
        guard var metrics = animationMetrics[identifier] else { return }

        let endTime = CACurrentMediaTime()
        let updatedMetrics = BLAnimationMetrics(
            identifier: metrics.identifier,
            startTime: metrics.startTime,
            endTime: endTime,
            targetLayers: metrics.targetLayers
        )

        animationMetrics[identifier] = updatedMetrics

        // Clean up old completed animations
        cleanupOldAnimationMetrics()
    }

    private func cleanupOldAnimationMetrics() {
        let currentTime = CACurrentMediaTime()
        let cleanupThreshold: CFTimeInterval = 30.0 // Keep metrics for 30 seconds

        animationMetrics = animationMetrics.filter { key, metrics in
            if let endTime = metrics.endTime {
                return currentTime - endTime < cleanupThreshold
            }
            return true // Keep ongoing animations
        }
    }

    // MARK: - Layer Metrics

    func recordLayerActivation(_ layer: BLVisualLayerType) {
        guard var metrics = layerMetrics[layer] else { return }

        metrics.activationCount += 1
        metrics.lastActivationTime = CACurrentMediaTime()
        layerMetrics[layer] = metrics
    }

    func recordLayerDeactivation(_ layer: BLVisualLayerType) {
        guard var metrics = layerMetrics[layer],
              let activationTime = metrics.lastActivationTime else { return }

        let duration = CACurrentMediaTime() - activationTime
        metrics.totalActiveTime += duration
        metrics.lastActivationTime = nil
        layerMetrics[layer] = metrics
    }

    func recordLayerError(_ layer: BLVisualLayerType, message: String) {
        guard var metrics = layerMetrics[layer] else { return }

        metrics.errorCount += 1
        layerMetrics[layer] = metrics

        // Log error for debugging
        print("Aurora Premium - Layer Error [\(layer)]: \(message)")
    }

    // MARK: - Public Interface

    func getCurrentFPS() -> Double {
        return systemMetrics.frameRate
    }

    func getMemoryUsage() -> Double {
        return systemMetrics.memoryUsage
    }

    func getCPUUsage() -> Double {
        return systemMetrics.cpuUsage
    }

    func getBatteryImpact() -> Double {
        return systemMetrics.batteryImpact
    }

    func getThermalState() -> ProcessInfo.ThermalState {
        return systemMetrics.thermalState
    }

    func getSystemMetrics() -> BLSystemMetrics {
        return systemMetrics
    }

    func getLayerMetrics(_ layer: BLVisualLayerType) -> BLLayerMetrics? {
        return layerMetrics[layer]
    }

    func getAllLayerMetrics() -> [BLVisualLayerType: BLLayerMetrics] {
        return layerMetrics
    }

    func getActiveAnimations() -> [BLAnimationMetrics] {
        return animationMetrics.values.filter { $0.endTime == nil }
    }

    func getCompletedAnimations() -> [BLAnimationMetrics] {
        return animationMetrics.values.filter { $0.endTime != nil }
    }

    // MARK: - Performance Analysis

    func getPerformanceStatus() -> BLPerformanceStatus {
        if systemMetrics.isPerformanceCritical {
            return .critical
        } else if systemMetrics.frameRate < warningFrameRate ||
            systemMetrics.memoryUsage > warningMemoryUsage
        {
            return .warning
        } else {
            return .good
        }
    }

    func getPerformanceReport() -> BLPerformanceReport {
        return BLPerformanceReport(
            frameRate: systemMetrics.frameRate,
            memoryUsage: systemMetrics.memoryUsage,
            cpuUsage: systemMetrics.cpuUsage,
            batteryImpact: systemMetrics.batteryImpact,
            thermalState: systemMetrics.thermalState,
            activeAnimations: getActiveAnimations().count,
            layerMetrics: layerMetrics,
            recommendations: generatePerformanceRecommendations()
        )
    }

    private func generatePerformanceRecommendations() -> [String] {
        var recommendations: [String] = []

        if systemMetrics.frameRate < warningFrameRate {
            recommendations.append("Consider reducing animation complexity or quality level")
        }

        if systemMetrics.memoryUsage > warningMemoryUsage {
            recommendations.append("Memory usage is high, consider disabling some visual effects")
        }

        if systemMetrics.thermalState != .nominal {
            recommendations.append("Device thermal state elevated, reducing quality automatically")
        }

        let errorLayers = layerMetrics.filter { $0.value.errorCount > 0 }
        if !errorLayers.isEmpty {
            recommendations.append("Some layers have errors, check system compatibility")
        }

        return recommendations
    }
}

// MARK: - Performance Status & Report

enum BLPerformanceStatus {
    case good
    case warning
    case critical

    var description: String {
        switch self {
        case .good:
            return "Performance is optimal"
        case .warning:
            return "Performance impact detected"
        case .critical:
            return "Performance critically impacted"
        }
    }
}

struct BLPerformanceReport {
    let frameRate: Double
    let memoryUsage: Double
    let cpuUsage: Double
    let batteryImpact: Double
    let thermalState: ProcessInfo.ThermalState
    let activeAnimations: Int
    let layerMetrics: [BLVisualLayerType: BLLayerMetrics]
    let recommendations: [String]

    var summary: String {
        return """
        Aurora Premium Performance Report:
        - Frame Rate: \(String(format: "%.1f", frameRate)) FPS
        - Memory Usage: \(String(format: "%.1f", memoryUsage)) MB
        - CPU Usage: \(String(format: "%.1f", cpuUsage))%
        - Battery Impact: \(String(format: "%.1f", batteryImpact))%
        - Thermal State: \(thermalState)
        - Active Animations: \(activeAnimations)
        - Recommendations: \(recommendations.count)
        """
    }
}
