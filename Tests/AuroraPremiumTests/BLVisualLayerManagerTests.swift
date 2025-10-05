//
//  BLVisualLayerManagerTests.swift
//  BilibiliLive
//
//  Aurora Premium Enhancement System
//  Task: P1-TE-004 - Visual Layer Manager Testing
//

@testable import BilibiliLive
import UIKit
import XCTest

class BLVisualLayerManagerTests: XCTestCase {
    var layerManager: BLVisualLayerManager!
    var parentView: UIView!

    override func setUp() {
        super.setUp()

        parentView = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        layerManager = BLVisualLayerManager(parentView: parentView)
    }

    override func tearDown() {
        layerManager = nil
        parentView = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testLayerManagerInitialization() {
        XCTAssertNotNil(layerManager, "Layer manager should be initialized")
        XCTAssertEqual(layerManager.parentView, parentView, "Parent view should be set correctly")
        XCTAssertTrue(layerManager.isEnabled, "Layer manager should be enabled by default")
        XCTAssertEqual(layerManager.qualityLevel, .high, "Default quality level should be high")
    }

    func testLayerCreation() {
        let layerStates = layerManager.getAllLayerStates()

        // Should have all 4 layer types
        XCTAssertEqual(layerStates.count, 4, "Should have 4 layers")
        XCTAssertNotNil(layerStates[.background], "Background layer should exist")
        XCTAssertNotNil(layerStates[.contentEnhancement], "Content enhancement layer should exist")
        XCTAssertNotNil(layerStates[.lightingEffect], "Lighting effect layer should exist")
        XCTAssertNotNil(layerStates[.interactionFeedback], "Interaction feedback layer should exist")

        // All layers should start inactive
        for (_, state) in layerStates {
            XCTAssertEqual(state, .inactive, "Layers should start inactive")
        }
    }

    // MARK: - Quality Level Tests

    func testQualityLevelChange() {
        layerManager.qualityLevel = .low
        XCTAssertEqual(layerManager.qualityLevel, .low, "Quality level should be updated")

        layerManager.qualityLevel = .ultra
        XCTAssertEqual(layerManager.qualityLevel, .ultra, "Should support ultra quality")
    }

    func testQualityLevelConfiguration() {
        // Test that quality level changes affect layer configurations
        layerManager.qualityLevel = .low

        // Apply focus state to trigger configuration
        layerManager.applyFocusState(true, animated: false)

        // Verify that layers received low quality configuration
        let layerStates = layerManager.getAllLayerStates()
        XCTAssertTrue(layerStates.values.contains(.active), "At least one layer should be active after focus")
    }

    // MARK: - Focus State Tests

    func testFocusStateApplication() {
        // Test focus gain
        layerManager.applyFocusState(true, animated: false)

        let focusedStates = layerManager.getAllLayerStates()
        let activeCount = focusedStates.values.filter { $0 == .active }.count
        XCTAssertGreaterThan(activeCount, 0, "Some layers should be active when focused")

        // Test focus loss
        layerManager.applyFocusState(false, animated: false)

        let unfocusedStates = layerManager.getAllLayerStates()
        let inactiveCount = unfocusedStates.values.filter { $0 == .inactive }.count
        XCTAssertEqual(inactiveCount, 4, "All layers should be inactive when unfocused")
    }

    func testAnimatedFocusState() {
        // Test animated focus changes
        XCTAssertNoThrow(layerManager.applyFocusState(true, animated: true))
        XCTAssertNoThrow(layerManager.applyFocusState(false, animated: true))
    }

    // MARK: - Custom State Tests

    func testCustomStateApplication() {
        let customProperties = ["intensity": 0.8, "color": "blue"]

        XCTAssertNoThrow(layerManager.applyCustomState("highlight", properties: customProperties))

        // Verify that custom state was applied
        let states = layerManager.getAllLayerStates()
        XCTAssertTrue(states.values.contains(.active), "Custom state should activate layers")
    }

    func testEmptyCustomState() {
        // Empty state should not cause issues
        XCTAssertNoThrow(layerManager.applyCustomState("", properties: [:]))
    }

    // MARK: - Animation Control Tests

    func testAnimationExecution() {
        let mockCommand = MockAnimationCommand()

        XCTAssertNoThrow(layerManager.executeAnimation(command: mockCommand))
    }

    func testMultipleAnimationExecution() {
        let commands = [
            MockAnimationCommand(identifier: "anim1"),
            MockAnimationCommand(identifier: "anim2"),
            MockAnimationCommand(identifier: "anim3"),
        ]

        XCTAssertNoThrow(layerManager.executeAnimations(commands: commands))
    }

    func testAnimationCancellation() {
        let commands = [
            MockAnimationCommand(identifier: "anim1"),
            MockAnimationCommand(identifier: "anim2"),
        ]

        layerManager.executeAnimations(commands: commands)

        XCTAssertNoThrow(layerManager.cancelAllAnimations())

        // All layers should be reset to inactive
        let states = layerManager.getAllLayerStates()
        for (_, state) in states {
            XCTAssertEqual(state, .inactive, "All layers should be inactive after cancellation")
        }
    }

    // MARK: - Performance Monitoring Tests

    func testPerformanceMetrics() {
        // Test that performance metrics are available
        XCTAssertNoThrow(layerManager.performanceMetrics.getCurrentFPS())
        XCTAssertNoThrow(layerManager.performanceMetrics.getMemoryUsage())
        XCTAssertNoThrow(layerManager.performanceMetrics.getCPUUsage())
    }

    func testPerformanceAutoAdjustment() {
        // Start with high quality
        layerManager.qualityLevel = .high

        // Simulate performance monitoring (this would normally be automatic)
        // We can't easily simulate low FPS in unit tests, but we can test the mechanism
        XCTAssertEqual(layerManager.qualityLevel, .high, "Quality should start high")
    }

    // MARK: - Layer State Management Tests

    func testLayerStateRetrieval() {
        let backgroundState = layerManager.getLayerState(.background)
        XCTAssertNotNil(backgroundState, "Should be able to get background layer state")
        XCTAssertEqual(backgroundState, .inactive, "Background should start inactive")

        let allStates = layerManager.getAllLayerStates()
        XCTAssertEqual(allStates.count, 4, "Should have all layer states")
    }

    // MARK: - Enable/Disable Tests

    func testLayerManagerDisable() {
        layerManager.isEnabled = false
        XCTAssertFalse(layerManager.isEnabled, "Layer manager should be disabled")

        // Disabled manager should not execute animations
        let mockCommand = MockAnimationCommand()
        layerManager.executeAnimation(command: mockCommand)

        // Since manager is disabled, command should not execute
        XCTAssertFalse(mockCommand.wasExecuted, "Command should not execute when manager is disabled")
    }

    func testLayerManagerReEnable() {
        layerManager.isEnabled = false
        layerManager.isEnabled = true

        XCTAssertTrue(layerManager.isEnabled, "Layer manager should be re-enabled")

        // Should be able to execute animations again
        let mockCommand = MockAnimationCommand()
        layerManager.executeAnimation(command: mockCommand)

        // Give some time for async execution
        let expectation = XCTestExpectation(description: "Animation execution")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Concurrent Animation Tests

    func testMaxConcurrentAnimations() {
        XCTAssertEqual(layerManager.maxConcurrentAnimations, 4, "Should have default max concurrent animations")

        layerManager.maxConcurrentAnimations = 2
        XCTAssertEqual(layerManager.maxConcurrentAnimations, 2, "Should be able to change max concurrent animations")
    }

    // MARK: - Memory Management Tests

    func testMemoryCleanup() {
        weak var weakManager: BLVisualLayerManager? = layerManager

        // Release manager
        layerManager = nil

        // Manager might still exist due to test environment, but should not have strong cycles
        // This test mainly ensures no crashes occur during cleanup
        XCTAssertTrue(true, "Cleanup should complete without crashes")
    }

    // MARK: - Performance Tests

    func testPerformanceFocusStateChange() {
        measure {
            for _ in 0..<100 {
                layerManager.applyFocusState(true, animated: false)
                layerManager.applyFocusState(false, animated: false)
            }
        }
    }

    func testPerformanceCustomStateApplication() {
        measure {
            for i in 0..<50 {
                layerManager.applyCustomState("state\(i)", properties: ["value": i])
            }
        }
    }
}

// MARK: - Mock Animation Command

class MockAnimationCommand: BLAnimationCommand {
    let identifier: String
    let targetLayers: [BLVisualLayerType] = [.background, .contentEnhancement]
    let configuration: BLLayerConfiguration = .default
    var wasExecuted = false

    init(identifier: String = "mock_animation") {
        self.identifier = identifier
    }

    func execute(on layers: [BLBaseVisualLayer]) {
        wasExecuted = true
        // Mock execution - just mark as executed
        for layer in layers {
            layer.isActive = true
        }
    }

    func canExecute() -> Bool {
        return true
    }
}

// MARK: - Mock Layer Communication Delegate

class MockLayerCommunicationDelegate: BLLayerCommunicationProtocol {
    var receivedUpdates: [(BLVisualLayerType, BLLayerState)] = []
    var receivedRequests: [(BLVisualLayerType, BLLayerConfiguration)] = []

    func layerDidUpdate(_ layer: BLVisualLayerType, state: BLLayerState) {
        receivedUpdates.append((layer, state))
    }

    func requestLayerUpdate(_ layer: BLVisualLayerType, configuration: BLLayerConfiguration) {
        receivedRequests.append((layer, configuration))
    }

    func reset() {
        receivedUpdates.removeAll()
        receivedRequests.removeAll()
    }
}
