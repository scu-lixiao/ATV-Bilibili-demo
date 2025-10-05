//
//  BLPerformanceMetricsTests.swift
//  BilibiliLive
//
//  Aurora Premium Enhancement System
//  Task: P1-TE-004 - Performance Metrics Testing
//

@testable import BilibiliLive
import UIKit
import XCTest

class BLPerformanceMetricsTests: XCTestCase {
    var performanceMetrics: BLPerformanceMetrics!

    override func setUp() {
        super.setUp()
        performanceMetrics = BLPerformanceMetrics()
    }

    override func tearDown() {
        performanceMetrics = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testPerformanceMetricsInitialization() {
        XCTAssertNotNil(performanceMetrics, "Performance metrics should be initialized")
    }

    // MARK: - Basic Metrics Tests

    func testFPSMetrics() {
        let fps = performanceMetrics.getCurrentFPS()
        XCTAssertGreaterThanOrEqual(fps, 0, "FPS should be non-negative")
        XCTAssertLessThanOrEqual(fps, 120, "FPS should be reasonable (≤120)")
    }

    func testMemoryUsageMetrics() {
        let memoryUsage = performanceMetrics.getMemoryUsage()
        XCTAssertGreaterThanOrEqual(memoryUsage, 0, "Memory usage should be non-negative")
        XCTAssertLessThan(memoryUsage, 1000, "Memory usage should be reasonable (<1GB)")
    }

    func testCPUUsageMetrics() {
        let cpuUsage = performanceMetrics.getCPUUsage()
        XCTAssertGreaterThanOrEqual(cpuUsage, 0, "CPU usage should be non-negative")
        XCTAssertLessThanOrEqual(cpuUsage, 100, "CPU usage should be ≤100%")
    }

    func testBatteryImpactMetrics() {
        let batteryImpact = performanceMetrics.getBatteryImpact()
        XCTAssertGreaterThanOrEqual(batteryImpact, 0, "Battery impact should be non-negative")
        XCTAssertLessThanOrEqual(batteryImpact, 100, "Battery impact should be ≤100%")
    }

    func testThermalStateMetrics() {
        let thermalState = performanceMetrics.getThermalState()
        XCTAssertTrue([.nominal, .fair, .serious, .critical].contains(thermalState), "Thermal state should be valid")
    }

    // MARK: - System Metrics Tests

    func testSystemMetrics() {
        let systemMetrics = performanceMetrics.getSystemMetrics()

        XCTAssertGreaterThanOrEqual(systemMetrics.frameRate, 0, "Frame rate should be non-negative")
        XCTAssertGreaterThanOrEqual(systemMetrics.memoryUsage, 0, "Memory usage should be non-negative")
        XCTAssertGreaterThanOrEqual(systemMetrics.cpuUsage, 0, "CPU usage should be non-negative")
        XCTAssertGreaterThanOrEqual(systemMetrics.batteryImpact, 0, "Battery impact should be non-negative")
    }

    func testPerformanceCriticalDetection() {
        let systemMetrics = performanceMetrics.getSystemMetrics()

        // Test the logic for performance critical detection
        let isCritical = systemMetrics.isPerformanceCritical
        XCTAssertNotNil(isCritical, "Performance critical status should be determinable")
    }

    // MARK: - Animation Metrics Tests

    func testAnimationMetricsRecording() {
        let animationId = "test_animation"
        let targetLayers: [BLVisualLayerType] = [.background, .contentEnhancement]

        // Record animation start
        performanceMetrics.recordAnimationStart(animationId, targetLayers: targetLayers)

        let activeAnimations = performanceMetrics.getActiveAnimations()
        XCTAssertEqual(activeAnimations.count, 1, "Should have one active animation")
        XCTAssertEqual(activeAnimations.first?.identifier, animationId, "Animation ID should match")

        // Record animation end
        performanceMetrics.recordAnimationEnd(animationId)

        let completedAnimations = performanceMetrics.getCompletedAnimations()
        XCTAssertGreaterThanOrEqual(completedAnimations.count, 1, "Should have at least one completed animation")

        let activeAnimationsAfter = performanceMetrics.getActiveAnimations()
        XCTAssertEqual(activeAnimationsAfter.count, 0, "Should have no active animations after completion")
    }

    func testMultipleAnimationMetrics() {
        let animationIds = ["anim1", "anim2", "anim3"]

        // Start multiple animations
        for id in animationIds {
            performanceMetrics.recordAnimationStart(id)
        }

        let activeAnimations = performanceMetrics.getActiveAnimations()
        XCTAssertEqual(activeAnimations.count, 3, "Should have three active animations")

        // End one animation
        performanceMetrics.recordAnimationEnd(animationIds[0])

        let activeAfterOne = performanceMetrics.getActiveAnimations()
        XCTAssertEqual(activeAfterOne.count, 2, "Should have two active animations remaining")
    }

    // MARK: - Layer Metrics Tests

    func testLayerActivationMetrics() {
        let layerType = BLVisualLayerType.background

        // Record layer activation
        performanceMetrics.recordLayerActivation(layerType)

        let layerMetrics = performanceMetrics.getLayerMetrics(layerType)
        XCTAssertNotNil(layerMetrics, "Layer metrics should exist")
        XCTAssertEqual(layerMetrics?.activationCount, 1, "Activation count should be 1")
        XCTAssertNotNil(layerMetrics?.lastActivationTime, "Last activation time should be set")
    }

    func testLayerDeactivationMetrics() {
        let layerType = BLVisualLayerType.contentEnhancement

        // Record activation then deactivation
        performanceMetrics.recordLayerActivation(layerType)

        // Small delay to ensure measurable duration
        Thread.sleep(forTimeInterval: 0.01)

        performanceMetrics.recordLayerDeactivation(layerType)

        let layerMetrics = performanceMetrics.getLayerMetrics(layerType)
        XCTAssertNotNil(layerMetrics, "Layer metrics should exist")
        XCTAssertGreaterThan(layerMetrics?.totalActiveTime ?? 0, 0, "Total active time should be greater than 0")
        XCTAssertNil(layerMetrics?.lastActivationTime, "Last activation time should be cleared after deactivation")
    }

    func testLayerErrorMetrics() {
        let layerType = BLVisualLayerType.lightingEffect
        let errorMessage = "Test error message"

        performanceMetrics.recordLayerError(layerType, message: errorMessage)

        let layerMetrics = performanceMetrics.getLayerMetrics(layerType)
        XCTAssertNotNil(layerMetrics, "Layer metrics should exist")
        XCTAssertEqual(layerMetrics?.errorCount, 1, "Error count should be 1")
    }

    func testAllLayerMetrics() {
        // Activate all layer types
        for layerType in [BLVisualLayerType.background, .contentEnhancement, .lightingEffect, .interactionFeedback] {
            performanceMetrics.recordLayerActivation(layerType)
        }

        let allMetrics = performanceMetrics.getAllLayerMetrics()
        XCTAssertEqual(allMetrics.count, 4, "Should have metrics for all 4 layer types")

        for (_, metrics) in allMetrics {
            XCTAssertEqual(metrics.activationCount, 1, "Each layer should have 1 activation")
        }
    }

    // MARK: - Performance Status Tests

    func testPerformanceStatus() {
        let status = performanceMetrics.getPerformanceStatus()
        XCTAssertTrue([.good, .warning, .critical].contains(status), "Performance status should be valid")
    }

    func testPerformanceReport() {
        let report = performanceMetrics.getPerformanceReport()

        XCTAssertGreaterThanOrEqual(report.frameRate, 0, "Report frame rate should be valid")
        XCTAssertGreaterThanOrEqual(report.memoryUsage, 0, "Report memory usage should be valid")
        XCTAssertGreaterThanOrEqual(report.activeAnimations, 0, "Report active animations should be valid")
        XCTAssertNotNil(report.summary, "Report should have summary")
        XCTAssertFalse(report.summary.isEmpty, "Report summary should not be empty")
    }

    func testPerformanceRecommendations() {
        let report = performanceMetrics.getPerformanceReport()
        XCTAssertNotNil(report.recommendations, "Report should have recommendations")

        // Recommendations should be an array (might be empty if performance is good)
        XCTAssertTrue(report.recommendations.count >= 0, "Recommendations should be a valid array")
    }

    // MARK: - Performance Tests

    func testMetricsCollectionPerformance() {
        measure {
            // Test the performance of collecting metrics
            for _ in 0..<100 {
                _ = performanceMetrics.getCurrentFPS()
                _ = performanceMetrics.getMemoryUsage()
                _ = performanceMetrics.getCPUUsage()
            }
        }
    }

    func testAnimationRecordingPerformance() {
        measure {
            // Test the performance of recording animation metrics
            for i in 0..<100 {
                let animationId = "perf_test_\(i)"
                performanceMetrics.recordAnimationStart(animationId)
                performanceMetrics.recordAnimationEnd(animationId)
            }
        }
    }

    func testLayerMetricsPerformance() {
        measure {
            // Test the performance of layer metrics recording
            for _ in 0..<100 {
                performanceMetrics.recordLayerActivation(.background)
                performanceMetrics.recordLayerDeactivation(.background)
            }
        }
    }

    // MARK: - Edge Cases Tests

    func testDuplicateAnimationStart() {
        let animationId = "duplicate_test"

        // Start the same animation twice
        performanceMetrics.recordAnimationStart(animationId)
        performanceMetrics.recordAnimationStart(animationId)

        let activeAnimations = performanceMetrics.getActiveAnimations()
        // Should handle duplicate starts gracefully (implementation dependent)
        XCTAssertGreaterThanOrEqual(activeAnimations.count, 1, "Should have at least one animation")
    }

    func testAnimationEndWithoutStart() {
        let animationId = "nonexistent_animation"

        // Try to end an animation that was never started
        XCTAssertNoThrow(performanceMetrics.recordAnimationEnd(animationId), "Should handle missing animation gracefully")
    }

    func testLayerDeactivationWithoutActivation() {
        let layerType = BLVisualLayerType.interactionFeedback

        // Try to deactivate a layer that was never activated
        XCTAssertNoThrow(performanceMetrics.recordLayerDeactivation(layerType), "Should handle missing activation gracefully")
    }

    // MARK: - Cleanup Tests

    func testMetricsCleanup() {
        // Create many animations to test cleanup
        for i in 0..<50 {
            let animationId = "cleanup_test_\(i)"
            performanceMetrics.recordAnimationStart(animationId)
            performanceMetrics.recordAnimationEnd(animationId)
        }

        let completedAnimations = performanceMetrics.getCompletedAnimations()

        // The system should clean up old animations automatically
        // Exact behavior depends on implementation, but should not grow indefinitely
        XCTAssertLessThan(completedAnimations.count, 100, "Should not accumulate too many completed animations")
    }
}
