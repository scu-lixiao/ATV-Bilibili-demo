//
//  BLAuroraBackgroundLayerTests.swift
//  BilibiliLive
//
//  Created by Aurora Premium Enhancement Team on 2024-12-19.
//  Copyright © 2024 Bilibili. All rights reserved.
//

@testable import BilibiliLive
import UIKit
import XCTest

class BLAuroraBackgroundLayerTests: XCTestCase {
    var backgroundLayer: BLAuroraBackgroundLayer!
    var containerView: UIView!

    override func setUp() {
        super.setUp()
        containerView = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        backgroundLayer = BLAuroraBackgroundLayer()
    }

    override func tearDown() {
        backgroundLayer?.cleanup()
        backgroundLayer = nil
        containerView = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertEqual(backgroundLayer.layerType, .background)
        XCTAssertFalse(backgroundLayer.isActive)
        XCTAssertFalse(backgroundLayer.isSetup)
        XCTAssertTrue(backgroundLayer.isEnabled)
    }

    func testLayerSetup() {
        backgroundLayer.setupLayer(in: containerView)

        XCTAssertTrue(backgroundLayer.isSetup)
        XCTAssertNotNil(backgroundLayer.mainLayer)
        XCTAssertEqual(backgroundLayer.containerView, containerView)
    }

    // MARK: - Configuration Tests

    func testDefaultConfiguration() {
        let config = BLLayerConfiguration.default
        backgroundLayer.setupLayer(in: containerView)
        backgroundLayer.activateWithConfiguration(config)

        XCTAssertTrue(backgroundLayer.isActive)
        XCTAssertEqual(backgroundLayer.currentConfiguration.intensity, config.intensity)
    }

    func testHighIntensityConfiguration() {
        let config = BLLayerConfiguration(
            intensity: 1.0,
            duration: 0.5,
            timing: CAMediaTimingFunction(name: .easeInEaseOut),
            properties: [:]
        )

        backgroundLayer.setupLayer(in: containerView)
        backgroundLayer.activateWithConfiguration(config)

        XCTAssertTrue(backgroundLayer.isActive)
        XCTAssertEqual(backgroundLayer.currentConfiguration.intensity, 1.0)
    }

    // MARK: - Focus State Tests

    func testFocusStateUpdate() {
        let config = BLLayerConfiguration.default
        backgroundLayer.setupLayer(in: containerView)
        backgroundLayer.activateWithConfiguration(config)

        // Test focused state
        backgroundLayer.updateFocusState(isFocused: true, animated: false)
        XCTAssertTrue(backgroundLayer.isActive)

        // Test unfocused state
        backgroundLayer.updateFocusState(isFocused: false, animated: false)
        XCTAssertTrue(backgroundLayer.isActive)
    }

    // MARK: - Custom State Tests

    func testHighlightState() {
        backgroundLayer.setupLayer(in: containerView)
        backgroundLayer.activateWithConfiguration(.default)

        backgroundLayer.applyCustomState("highlight", configuration: .default)
        XCTAssertTrue(backgroundLayer.isActive)
    }

    func testErrorState() {
        backgroundLayer.setupLayer(in: containerView)
        backgroundLayer.activateWithConfiguration(.default)

        backgroundLayer.applyCustomState("error", configuration: .default)
        XCTAssertTrue(backgroundLayer.isActive)
    }

    func testSuccessState() {
        backgroundLayer.setupLayer(in: containerView)
        backgroundLayer.activateWithConfiguration(.default)

        backgroundLayer.applyCustomState("success", configuration: .default)
        XCTAssertTrue(backgroundLayer.isActive)
    }

    func testLoadingState() {
        backgroundLayer.setupLayer(in: containerView)
        backgroundLayer.activateWithConfiguration(.default)

        backgroundLayer.applyCustomState("loading", configuration: .default)
        XCTAssertTrue(backgroundLayer.isActive)
    }

    func testDisabledState() {
        backgroundLayer.setupLayer(in: containerView)
        backgroundLayer.activateWithConfiguration(.default)

        backgroundLayer.applyCustomState("disabled", configuration: .default)
        XCTAssertTrue(backgroundLayer.isActive)
    }

    // MARK: - Memory Management Tests

    func testMemoryManagement() {
        backgroundLayer.setupLayer(in: containerView)
        backgroundLayer.activateWithConfiguration(.default)
        backgroundLayer.updateFocusState(isFocused: true, animated: false)

        // Test cleanup
        backgroundLayer.cleanup()

        XCTAssertFalse(backgroundLayer.isSetup)
        XCTAssertFalse(backgroundLayer.isActive)
    }

    // MARK: - Edge Case Tests

    func testSetupWithoutContainer() {
        // Should not crash
        backgroundLayer.setupLayer(in: UIView())
        XCTAssertTrue(backgroundLayer.isSetup)
    }

    func testMultipleSetupCalls() {
        backgroundLayer.setupLayer(in: containerView)
        let firstMainLayer = backgroundLayer.mainLayer

        backgroundLayer.setupLayer(in: containerView)
        let secondMainLayer = backgroundLayer.mainLayer

        XCTAssertEqual(firstMainLayer, secondMainLayer)
    }

    func testInvalidCustomState() {
        backgroundLayer.setupLayer(in: containerView)
        backgroundLayer.activateWithConfiguration(.default)

        // Should fall back to normal configuration
        backgroundLayer.applyCustomState("invalid_state", configuration: .default)

        // Should not crash and maintain normal state
        XCTAssertTrue(backgroundLayer.isActive)
    }
}
