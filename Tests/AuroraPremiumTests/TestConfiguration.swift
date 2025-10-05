//
//  TestConfiguration.swift
//  BilibiliLive
//
//  Aurora Premium Enhancement System
//  Task: P1-TE-004 - Test Configuration and Utilities
//

@testable import BilibiliLive
import UIKit
import XCTest

// MARK: - Test Configuration

enum AuroraPremiumTestConfiguration {
    // MARK: - Test Environment Settings

    static let defaultTestFrame = CGRect(x: 0, y: 0, width: 300, height: 200)
    static let largeTestFrame = CGRect(x: 0, y: 0, width: 600, height: 400)
    static let smallTestFrame = CGRect(x: 0, y: 0, width: 150, height: 100)

    // MARK: - Performance Test Thresholds

    static let maxAcceptableAnimationTime: TimeInterval = 0.5
    static let maxAcceptableSetupTime: TimeInterval = 0.1
    static let maxAcceptableMemoryUsage: Double = 100.0 // MB
    static let minAcceptableFPS: Double = 30.0

    // MARK: - Quality Level Test Settings

    static let testQualityLevels: [BLQualityLevel] = [.low, .medium, .high, .ultra]

    // MARK: - Animation Test Settings

    static let testAnimationDuration: TimeInterval = 0.3
    static let testAnimationIterations = 10

    // MARK: - Layer Test Settings

    static let allLayerTypes: [BLVisualLayerType] = [
        .background,
        .contentEnhancement,
        .lightingEffect,
        .interactionFeedback,
    ]
}

// MARK: - Test Utilities

class AuroraPremiumTestUtilities {
    // MARK: - View Creation Helpers

    static func createTestCollectionView() -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = AuroraPremiumTestConfiguration.defaultTestFrame.size

        return UICollectionView(
            frame: AuroraPremiumTestConfiguration.defaultTestFrame,
            collectionViewLayout: layout
        )
    }

    static func createTestCell() -> BLAuroraPremiumCell {
        return BLAuroraPremiumCell(frame: AuroraPremiumTestConfiguration.defaultTestFrame)
    }

    static func createTestParentView() -> UIView {
        return UIView(frame: AuroraPremiumTestConfiguration.defaultTestFrame)
    }

    // MARK: - Performance Measurement Helpers

    static func measureExecutionTime<T>(operation: () throws -> T) rethrows -> (result: T, time: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let endTime = CFAbsoluteTimeGetCurrent()

        return (result: result, time: endTime - startTime)
    }

    static func measureMemoryUsage<T>(operation: () throws -> T) rethrows -> (result: T, memoryDelta: Double) {
        let initialMemory = getCurrentMemoryUsage()
        let result = try operation()
        let finalMemory = getCurrentMemoryUsage()

        return (result: result, memoryDelta: finalMemory - initialMemory)
    }

    private static func getCurrentMemoryUsage() -> Double {
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

    // MARK: - Animation Test Helpers

    static func waitForAnimationCompletion(timeout: TimeInterval = 1.0) {
        let expectation = XCTestExpectation(description: "Animation completion")

        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            expectation.fulfill()
        }

        _ = XCTWaiter.wait(for: [expectation], timeout: timeout + 0.5)
    }

    static func simulateFocusChange(on cell: BLAuroraPremiumCell, focused: Bool, animated: Bool = true) {
        // Simulate focus change by calling the focus update method
        let context = UIFocusUpdateContext()
        let coordinator = UIFocusAnimationCoordinator()

        cell.didUpdateFocus(in: context, with: coordinator)
    }

    // MARK: - Layer State Verification Helpers

    static func verifyLayerStates(
        _ states: [BLVisualLayerType: BLLayerState],
        expectedState: BLLayerState,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        for (layerType, state) in states {
            XCTAssertEqual(
                state,
                expectedState,
                "Layer \(layerType) should be in \(expectedState) state",
                file: file,
                line: line
            )
        }
    }

    static func verifyLayerExists(
        _ states: [BLVisualLayerType: BLLayerState],
        layerType: BLVisualLayerType,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertNotNil(
            states[layerType],
            "Layer \(layerType) should exist",
            file: file,
            line: line
        )
    }

    // MARK: - Performance Assertion Helpers

    static func assertPerformanceWithinThreshold(
        _ time: TimeInterval,
        threshold: TimeInterval,
        operation: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertLessThanOrEqual(
            time,
            threshold,
            "\(operation) took \(time)s, which exceeds threshold of \(threshold)s",
            file: file,
            line: line
        )
    }

    static func assertMemoryUsageWithinThreshold(
        _ memoryDelta: Double,
        threshold: Double,
        operation: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertLessThanOrEqual(
            memoryDelta,
            threshold,
            "\(operation) used \(memoryDelta)MB, which exceeds threshold of \(threshold)MB",
            file: file,
            line: line
        )
    }

    // MARK: - Quality Level Test Helpers

    static func testAllQualityLevels(
        on cell: BLAuroraPremiumCell,
        testBlock: (BLQualityLevel) -> Void
    ) {
        for qualityLevel in AuroraPremiumTestConfiguration.testQualityLevels {
            cell.qualityLevel = qualityLevel
            testBlock(qualityLevel)
        }
    }

    // MARK: - Error Simulation Helpers

    static func simulateMemoryPressure() {
        // Simulate memory pressure by creating temporary objects
        var tempObjects: [Data] = []

        for _ in 0..<100 {
            tempObjects.append(Data(count: 1024 * 1024)) // 1MB each
        }

        // Release immediately to simulate pressure spike
        tempObjects.removeAll()
    }

    static func simulateThermalPressure() {
        // Simulate thermal pressure by performing intensive calculations
        var result = 0.0

        for i in 0..<100000 {
            result += sin(Double(i)) * cos(Double(i))
        }

        // Use result to prevent optimization
        _ = result
    }
}

// MARK: - Test Data Providers

class AuroraPremiumTestDataProvider {
    // MARK: - Animation Test Data

    static func animationTestConfigurations() -> [BLLayerConfiguration] {
        return [
            BLLayerConfiguration(
                intensity: 0.5,
                duration: 0.2,
                timing: CAMediaTimingFunction(name: .easeIn),
                properties: ["test": "low_intensity"]
            ),
            BLLayerConfiguration(
                intensity: 1.0,
                duration: 0.3,
                timing: CAMediaTimingFunction(name: .easeInEaseOut),
                properties: ["test": "normal_intensity"]
            ),
            BLLayerConfiguration(
                intensity: 1.5,
                duration: 0.5,
                timing: CAMediaTimingFunction(name: .easeOut),
                properties: ["test": "high_intensity"]
            ),
        ]
    }

    // MARK: - Custom State Test Data

    static func customStateTestData() -> [(String, [String: Any])] {
        return [
            ("highlight", ["color": "blue", "intensity": 0.8]),
            ("error", ["color": "red", "shake": true]),
            ("success", ["color": "green", "glow": true]),
            ("loading", ["animation": "pulse", "duration": 1.0]),
            ("disabled", ["opacity": 0.5, "interactive": false]),
        ]
    }

    // MARK: - Performance Test Scenarios

    static func performanceTestScenarios() -> [(String, () -> Void)] {
        return [
            ("rapid_focus_changes", {
                // Simulate rapid focus changes
                for _ in 0..<50 {
                    // Simulate focus state changes
                }
            }),
            ("multiple_animations", {
                // Simulate multiple concurrent animations
                for _ in 0..<10 {
                    // Simulate animation start
                }
            }),
            ("quality_level_changes", {
                // Simulate rapid quality level changes
                for _ in AuroraPremiumTestConfiguration.testQualityLevels {
                    // Simulate quality change
                }
            }),
        ]
    }
}

// MARK: - Test Assertions Extensions

extension XCTestCase {
    func assertAuroraPremiumCellValid(
        _ cell: BLAuroraPremiumCell,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertNotNil(cell.layerManager, "Layer manager should be initialized", file: file, line: line)
        XCTAssertNotNil(cell.animationController, "Animation controller should be initialized", file: file, line: line)
        XCTAssertNotNil(cell.performanceMonitor, "Performance monitor should be initialized", file: file, line: line)
        XCTAssertNotNil(cell.configurationManager, "Configuration manager should be initialized", file: file, line: line)
    }

    func assertLayerManagerValid(
        _ manager: BLVisualLayerManager,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertNotNil(manager.parentView, "Parent view should be set", file: file, line: line)
        XCTAssertTrue(manager.isEnabled, "Manager should be enabled by default", file: file, line: line)

        let states = manager.getAllLayerStates()
        XCTAssertEqual(states.count, 4, "Should have all 4 layer types", file: file, line: line)
    }

    func assertPerformanceMetricsValid(
        _ metrics: BLPerformanceMetrics,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let fps = metrics.getCurrentFPS()
        let memory = metrics.getMemoryUsage()
        let cpu = metrics.getCPUUsage()

        XCTAssertGreaterThanOrEqual(fps, 0, "FPS should be non-negative", file: file, line: line)
        XCTAssertGreaterThanOrEqual(memory, 0, "Memory usage should be non-negative", file: file, line: line)
        XCTAssertGreaterThanOrEqual(cpu, 0, "CPU usage should be non-negative", file: file, line: line)
        XCTAssertLessThanOrEqual(cpu, 100, "CPU usage should not exceed 100%", file: file, line: line)
    }
}
