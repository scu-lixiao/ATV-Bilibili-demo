//
//  BLContentEnhancementLayerTests.swift
//  BilibiliLive
//
//  Created by Aurora Premium Enhancement Team on 2024-12-19.
//  Copyright © 2024 Bilibili. All rights reserved.
//

@testable import BilibiliLive
import UIKit
import XCTest

class BLContentEnhancementLayerTests: XCTestCase {
    var contentLayer: BLContentEnhancementLayer!
    var containerView: UIView!

    override func setUp() {
        super.setUp()
        containerView = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        contentLayer = BLContentEnhancementLayer()
    }

    override func tearDown() {
        contentLayer?.cleanup()
        contentLayer = nil
        containerView = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertEqual(contentLayer.layerType, .contentEnhancement)
        XCTAssertFalse(contentLayer.isActive)
        XCTAssertFalse(contentLayer.isSetup)
        XCTAssertTrue(contentLayer.isEnabled)
    }

    func testLayerSetup() {
        contentLayer.setupLayer(in: containerView)

        XCTAssertTrue(contentLayer.isSetup)
        XCTAssertNotNil(contentLayer.mainLayer)
        XCTAssertEqual(contentLayer.containerView, containerView)
    }

    // MARK: - Blur Effect Tests

    func testBlurEffectViewCreation() {
        contentLayer.setupLayer(in: containerView)

        // Check if blur effect view was added to container
        let blurViews = containerView.subviews.compactMap { $0 as? UIVisualEffectView }
        XCTAssertEqual(blurViews.count, 1)

        let blurView = blurViews.first
        XCTAssertNotNil(blurView)
        XCTAssertEqual(blurView?.frame, containerView.bounds)
        XCTAssertEqual(blurView?.alpha, 0.0) // Initial state
    }

    func testBlurStyleConfiguration() {
        let config = BLLayerConfiguration(
            intensity: 0.8,
            duration: 0.3,
            timing: CAMediaTimingFunction(name: .linear),
            properties: ["blurStyle": "thin"]
        )

        contentLayer.setupLayer(in: containerView)
        contentLayer.activateWithConfiguration(config)

        let blurViews = containerView.subviews.compactMap { $0 as? UIVisualEffectView }
        XCTAssertEqual(blurViews.count, 1)

        let blurView = blurViews.first
        XCTAssertNotNil(blurView?.effect)
    }

    // MARK: - Configuration Tests

    func testDefaultConfiguration() {
        let config = BLLayerConfiguration.default
        contentLayer.setupLayer(in: containerView)
        contentLayer.activateWithConfiguration(config)

        XCTAssertTrue(contentLayer.isActive)
        XCTAssertEqual(contentLayer.currentConfiguration.intensity, config.intensity)
    }

    func testQualityOptimizations() {
        // Test reduced effects
        let lowQualityConfig = BLLayerConfiguration(
            intensity: 0.5,
            duration: 0.3,
            timing: CAMediaTimingFunction(name: .linear),
            properties: ["reducedEffects": true]
        )

        contentLayer.setupLayer(in: containerView)
        contentLayer.activateWithConfiguration(lowQualityConfig)

        XCTAssertTrue(contentLayer.isActive)

        // Test enhanced effects
        let highQualityConfig = BLLayerConfiguration(
            intensity: 0.8,
            duration: 0.6,
            timing: CAMediaTimingFunction(name: .easeInEaseOut),
            properties: ["enhancedEffects": true]
        )

        contentLayer.updateConfiguration(highQualityConfig)
        XCTAssertTrue(contentLayer.isActive)
    }

    func testBlurStyleUpdates() {
        contentLayer.setupLayer(in: containerView)
        contentLayer.activateWithConfiguration(.default)

        let styles = ["thin", "ultrathin", "thick", "chrome", "invalid"]

        for style in styles {
            let config = BLLayerConfiguration(
                intensity: 0.7,
                duration: 0.3,
                timing: CAMediaTimingFunction(name: .linear),
                properties: ["blurStyle": style]
            )

            contentLayer.updateConfiguration(config)
            XCTAssertTrue(contentLayer.isActive)
        }
    }

    // MARK: - Focus State Tests

    func testFocusStateUpdate() {
        let config = BLLayerConfiguration.default
        contentLayer.setupLayer(in: containerView)
        contentLayer.activateWithConfiguration(config)

        // Test focused state
        contentLayer.updateFocusState(isFocused: true, animated: false)
        XCTAssertTrue(contentLayer.isActive)

        // Test unfocused state
        contentLayer.updateFocusState(isFocused: false, animated: false)
        XCTAssertTrue(contentLayer.isActive)
    }

    func testAnimatedFocusTransition() {
        let config = BLLayerConfiguration(
            intensity: 0.7,
            duration: 0.5,
            timing: CAMediaTimingFunction(name: .easeInEaseOut),
            properties: [:]
        )

        contentLayer.setupLayer(in: containerView)
        contentLayer.activateWithConfiguration(config)

        let expectation = self.expectation(description: "Focus animation completion")

        contentLayer.updateFocusState(isFocused: true, animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + config.duration + 0.1) {
            XCTAssertTrue(self.contentLayer.isActive)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    // MARK: - Custom State Tests

    func testHighlightState() {
        contentLayer.setupLayer(in: containerView)
        contentLayer.activateWithConfiguration(.default)

        contentLayer.applyCustomState("highlight", configuration: .default)
        XCTAssertTrue(contentLayer.isActive)
    }

    func testErrorState() {
        contentLayer.setupLayer(in: containerView)
        contentLayer.activateWithConfiguration(.default)

        contentLayer.applyCustomState("error", configuration: .default)
        XCTAssertTrue(contentLayer.isActive)
    }

    func testSuccessState() {
        contentLayer.setupLayer(in: containerView)
        contentLayer.activateWithConfiguration(.default)

        contentLayer.applyCustomState("success", configuration: .default)
        XCTAssertTrue(contentLayer.isActive)
    }

    func testLoadingState() {
        contentLayer.setupLayer(in: containerView)
        contentLayer.activateWithConfiguration(.default)

        contentLayer.applyCustomState("loading", configuration: .default)
        XCTAssertTrue(contentLayer.isActive)
    }

    func testDisabledState() {
        contentLayer.setupLayer(in: containerView)
        contentLayer.activateWithConfiguration(.default)

        contentLayer.applyCustomState("disabled", configuration: .default)
        XCTAssertTrue(contentLayer.isActive)
    }

    func testReadingState() {
        contentLayer.setupLayer(in: containerView)
        contentLayer.activateWithConfiguration(.default)

        contentLayer.applyCustomState("reading", configuration: .default)
        XCTAssertTrue(contentLayer.isActive)
    }

    func testMediaState() {
        contentLayer.setupLayer(in: containerView)
        contentLayer.activateWithConfiguration(.default)

        contentLayer.applyCustomState("media", configuration: .default)
        XCTAssertTrue(contentLayer.isActive)
    }

    // MARK: - Content Analysis Tests

    func testContentAnalysisTrigger() {
        contentLayer.setupLayer(in: containerView)
        contentLayer.activateWithConfiguration(.default)

        // Enable content adaptive
        let adaptiveConfig = BLLayerConfiguration(
            intensity: 0.7,
            duration: 0.3,
            timing: CAMediaTimingFunction(name: .linear),
            properties: ["contentAdaptive": true]
        )

        contentLayer.updateConfiguration(adaptiveConfig)

        // Trigger content analysis through focus
        contentLayer.updateFocusState(isFocused: true, animated: false)

        XCTAssertTrue(contentLayer.isActive)
    }

    func testContentAnalysisThrottling() {
        contentLayer.setupLayer(in: containerView)
        contentLayer.activateWithConfiguration(.default)

        // Multiple rapid focus changes should be throttled
        for _ in 0..<5 {
            contentLayer.updateFocusState(isFocused: true, animated: false)
            contentLayer.updateFocusState(isFocused: false, animated: false)
        }

        XCTAssertTrue(contentLayer.isActive)
    }

    // MARK: - Layer Management Tests

    func testLayerFrameUpdates() {
        contentLayer.setupLayer(in: containerView)

        // Change container bounds
        containerView.frame = CGRect(x: 0, y: 0, width: 400, height: 300)
        contentLayer.performSpecificSetup()

        let blurViews = containerView.subviews.compactMap { $0 as? UIVisualEffectView }
        let blurView = blurViews.first

        XCTAssertEqual(blurView?.frame, containerView.bounds)
    }

    func testMemoryManagement() {
        contentLayer.setupLayer(in: containerView)
        contentLayer.activateWithConfiguration(.default)
        contentLayer.updateFocusState(isFocused: true, animated: false)

        // Test cleanup
        contentLayer.cleanup()

        XCTAssertFalse(contentLayer.isSetup)
        XCTAssertFalse(contentLayer.isActive)

        // Check if blur view was removed
        let blurViews = containerView.subviews.compactMap { $0 as? UIVisualEffectView }
        XCTAssertEqual(blurViews.count, 0)
    }

    // MARK: - Edge Case Tests

    func testSetupWithoutContainer() {
        // Should not crash
        contentLayer.setupLayer(in: UIView())
        XCTAssertTrue(contentLayer.isSetup)
    }

    func testMultipleSetupCalls() {
        contentLayer.setupLayer(in: containerView)
        let firstMainLayer = contentLayer.mainLayer

        contentLayer.setupLayer(in: containerView)
        let secondMainLayer = contentLayer.mainLayer

        XCTAssertEqual(firstMainLayer, secondMainLayer)
    }

    func testInvalidCustomState() {
        contentLayer.setupLayer(in: containerView)
        contentLayer.activateWithConfiguration(.default)

        // Should fall back to normal configuration
        contentLayer.applyCustomState("invalid_state", configuration: .default)

        // Should not crash and maintain normal state
        XCTAssertTrue(contentLayer.isActive)
    }

    func testConfigurationWithNilProperties() {
        let config = BLLayerConfiguration(
            intensity: 0.5,
            duration: 0.3,
            timing: CAMediaTimingFunction(name: .linear),
            properties: [:]
        )

        contentLayer.setupLayer(in: containerView)

        // Should not crash
        contentLayer.activateWithConfiguration(config)
        XCTAssertTrue(contentLayer.isActive)
    }

    // MARK: - Performance Tests

    func testPerformanceWithMultipleStateChanges() {
        contentLayer.setupLayer(in: containerView)
        contentLayer.activateWithConfiguration(.default)

        let startTime = CFAbsoluteTimeGetCurrent()

        // Simulate multiple rapid state changes
        for i in 0..<10 {
            contentLayer.updateFocusState(isFocused: i % 2 == 0, animated: true)
            contentLayer.applyCustomState(i % 2 == 0 ? "highlight" : "normal", configuration: .default)
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime

        // Should complete within reasonable time (< 100ms)
        XCTAssertLessThan(executionTime, 0.1)
    }

    func testBlurEffectPerformance() {
        contentLayer.setupLayer(in: containerView)

        let startTime = CFAbsoluteTimeGetCurrent()

        // Test multiple blur style changes
        let styles = ["thin", "ultrathin", "thick", "chrome"]
        for style in styles {
            let config = BLLayerConfiguration(
                intensity: 0.7,
                duration: 0.1,
                timing: CAMediaTimingFunction(name: .linear),
                properties: ["blurStyle": style]
            )
            contentLayer.activateWithConfiguration(config)
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime

        // Should complete within reasonable time (< 50ms)
        XCTAssertLessThan(executionTime, 0.05)
    }

    // MARK: - Integration Tests

    func testLayerCommunication() {
        class MockCommunicationDelegate: BLLayerCommunicationProtocol {
            var updateCallCount = 0
            var lastLayerType: BLVisualLayerType?
            var lastState: BLLayerState?

            func layerDidUpdate(_ layerType: BLVisualLayerType, state: BLLayerState) {
                updateCallCount += 1
                lastLayerType = layerType
                lastState = state
            }

            func requestLayerUpdate(_ layerType: BLVisualLayerType, configuration: BLLayerConfiguration) {
                // Mock implementation
            }
        }

        let delegate = MockCommunicationDelegate()
        contentLayer.setupLayer(in: containerView)
        contentLayer.communicationDelegate = delegate

        contentLayer.activateWithConfiguration(.default)

        XCTAssertEqual(delegate.updateCallCount, 2) // transitioning + active
        XCTAssertEqual(delegate.lastLayerType, .contentEnhancement)
        XCTAssertEqual(delegate.lastState, .active)
    }
}
