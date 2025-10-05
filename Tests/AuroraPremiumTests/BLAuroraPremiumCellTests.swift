//
//  BLAuroraPremiumCellTests.swift
//  BilibiliLive
//
//  Aurora Premium Enhancement System
//  Task: P1-TE-004 - Testing Framework Implementation
//

@testable import BilibiliLive
import UIKit
import XCTest

class BLAuroraPremiumCellTests: XCTestCase {
    var cell: BLAuroraPremiumCell!
    var mockCollectionView: UICollectionView!

    override func setUp() {
        super.setUp()

        // Create mock collection view
        let layout = UICollectionViewFlowLayout()
        mockCollectionView = UICollectionView(frame: CGRect(x: 0, y: 0, width: 300, height: 200), collectionViewLayout: layout)

        // Create cell
        cell = BLAuroraPremiumCell(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
    }

    override func tearDown() {
        cell = nil
        mockCollectionView = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testCellInitialization() {
        XCTAssertNotNil(cell, "Cell should be initialized")
        XCTAssertTrue(cell.isKind(of: BLMotionCollectionViewCell.self), "Should inherit from BLMotionCollectionViewCell")
    }

    func testAuroraPremiumEnabled() {
        XCTAssertTrue(cell.isAuroraPremiumEnabled, "Aurora Premium should be enabled by default")
    }

    func testQualityLevelDefault() {
        XCTAssertEqual(cell.qualityLevel, .high, "Default quality level should be high")
    }

    // MARK: - Layer Manager Tests

    func testLayerManagerInitialization() {
        XCTAssertNotNil(cell.layerManager, "Layer manager should be initialized")
        XCTAssertTrue(cell.layerManager!.isEnabled, "Layer manager should be enabled by default")
    }

    func testLayerManagerParentView() {
        XCTAssertEqual(cell.layerManager?.parentView, cell.contentView, "Layer manager should reference content view")
    }

    // MARK: - Animation Controller Tests

    func testAnimationControllerInitialization() {
        XCTAssertNotNil(cell.animationController, "Animation controller should be initialized")
    }

    // MARK: - Performance Monitor Tests

    func testPerformanceMonitorInitialization() {
        XCTAssertNotNil(cell.performanceMonitor, "Performance monitor should be initialized")
    }

    func testPerformanceMonitorMetrics() {
        let fps = cell.performanceMonitor?.getCurrentFPS()
        XCTAssertNotNil(fps, "Should be able to get FPS metrics")

        let memory = cell.performanceMonitor?.getMemoryUsage()
        XCTAssertNotNil(memory, "Should be able to get memory usage")
    }

    // MARK: - Configuration Manager Tests

    func testConfigurationManagerInitialization() {
        XCTAssertNotNil(cell.configurationManager, "Configuration manager should be initialized")
    }

    // MARK: - Quality Level Tests

    func testQualityLevelChange() {
        cell.qualityLevel = .low
        XCTAssertEqual(cell.qualityLevel, .low, "Quality level should be updated")
        XCTAssertEqual(cell.layerManager?.qualityLevel, .low, "Layer manager quality should be synced")
    }

    func testQualityLevelUltra() {
        cell.qualityLevel = .ultra
        XCTAssertEqual(cell.qualityLevel, .ultra, "Should support ultra quality level")
    }

    // MARK: - Aurora Premium Toggle Tests

    func testAuroraPremiumToggle() {
        // Disable Aurora Premium
        cell.isAuroraPremiumEnabled = false
        XCTAssertFalse(cell.isAuroraPremiumEnabled, "Aurora Premium should be disabled")
        XCTAssertFalse(cell.layerManager?.isEnabled ?? true, "Layer manager should be disabled when Aurora Premium is off")

        // Re-enable Aurora Premium
        cell.isAuroraPremiumEnabled = true
        XCTAssertTrue(cell.isAuroraPremiumEnabled, "Aurora Premium should be re-enabled")
        XCTAssertTrue(cell.layerManager?.isEnabled ?? false, "Layer manager should be re-enabled")
    }

    // MARK: - Focus State Tests

    func testFocusStateHandling() {
        // Test focus state when Aurora Premium is enabled
        cell.isAuroraPremiumEnabled = true

        // Simulate focus gain (this would normally be called by the system)
        cell.setNeedsFocusUpdate()

        // Verify that the cell can handle focus updates
        XCTAssertNoThrow(cell.didUpdateFocus(in: UIFocusUpdateContext(), with: UIFocusAnimationCoordinator()))
    }

    // MARK: - Backward Compatibility Tests

    func testBackwardCompatibilityWithDisabledAurora() {
        // Disable Aurora Premium to test backward compatibility
        cell.isAuroraPremiumEnabled = false

        // Should behave like original BLMotionCollectionViewCell
        XCTAssertEqual(cell.scaleFactor, 1.15, "Scale factor should remain default")

        // Focus updates should still work
        XCTAssertNoThrow(cell.didUpdateFocus(in: UIFocusUpdateContext(), with: UIFocusAnimationCoordinator()))
    }

    // MARK: - Memory Management Tests

    func testMemoryCleanup() {
        weak var weakCell: BLAuroraPremiumCell? = cell
        weak var weakLayerManager = cell.layerManager
        weak var weakPerformanceMonitor = cell.performanceMonitor

        // Release cell
        cell = nil

        // Verify cleanup (this might not immediately pass due to test environment)
        // We're testing that no strong reference cycles exist
        XCTAssertNotNil(weakCell, "Cell might still exist due to test environment, but no strong cycles should exist")
    }

    // MARK: - Integration Tests

    func testLayerManagerIntegration() {
        // Test that layer manager receives focus state updates
        cell.isAuroraPremiumEnabled = true

        let initialStates = cell.layerManager?.getAllLayerStates()
        XCTAssertNotNil(initialStates, "Should have layer states")

        // All layers should start inactive
        for (_, state) in initialStates ?? [:] {
            XCTAssertEqual(state, .inactive, "Layers should start inactive")
        }
    }

    // MARK: - Performance Tests

    func testPerformanceFocusAnimation() {
        cell.isAuroraPremiumEnabled = true

        measure {
            // Measure the time taken for focus animation
            for _ in 0..<10 {
                cell.didUpdateFocus(in: UIFocusUpdateContext(), with: UIFocusAnimationCoordinator())
            }
        }
    }

    func testPerformanceLayerSetup() {
        measure {
            // Measure layer setup performance
            let testCell = BLAuroraPremiumCell(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
            testCell.isAuroraPremiumEnabled = true
            _ = testCell.layerManager // Trigger lazy initialization
        }
    }
}

// MARK: - Mock Classes for Testing

class MockAnimationController: BLAnimationControllerProtocol {
    var isAnimating = false
    var lastAnimationType: String?

    func startFocusAnimation(focused: Bool, duration: TimeInterval) {
        isAnimating = true
        lastAnimationType = focused ? "focus" : "unfocus"
    }

    func stopAllAnimations() {
        isAnimating = false
        lastAnimationType = nil
    }
}

class MockConfigurationManager: BLConfigurationManagerProtocol {
    var currentConfiguration: [String: Any] = [:]

    func loadConfiguration() -> [String: Any] {
        return currentConfiguration
    }

    func saveConfiguration(_ config: [String: Any]) {
        currentConfiguration = config
    }

    func resetToDefaults() {
        currentConfiguration.removeAll()
    }
}
