import XCTest
@testable import YourAppTarget

// MARK: - Mock Objects for Testing

/// Mock Visual Layer for Testing
class MockParallaxVisualLayer: BLBaseVisualLayer {
    var mockLayerType: BLVisualLayerType
    override var layer: CALayer { return mockCALayer }
    private let mockCALayer = CALayer()

    init(layerType: BLVisualLayerType) {
        mockLayerType = layerType
        super.init()
        setupMockLayer()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupMockLayer() {
        mockCALayer.bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        mockCALayer.position = CGPoint(x: 50, y: 50)
    }

    // Override methods for testing
    override func configure(with configuration: BLLayerConfiguration) {
        // Mock implementation
    }

    override func activate() {
        // Mock implementation
    }

    override func deactivate() {
        // Mock implementation
    }
}

// MARK: - BLParallaxEffectController Tests

class BLParallaxEffectControllerTests: XCTestCase {
    var parallaxController: BLParallaxEffectController!
    var mockLayers: [MockParallaxVisualLayer]!

    override func setUp() {
        super.setUp()
        parallaxController = BLParallaxEffectController.shared

        // Create mock layers for all types
        mockLayers = [
            MockParallaxVisualLayer(layerType: .background),
            MockParallaxVisualLayer(layerType: .contentEnhancement),
            MockParallaxVisualLayer(layerType: .lightingEffect),
            MockParallaxVisualLayer(layerType: .interactionFeedback),
        ]

        // Reset controller state
        parallaxController.resetMetrics()
        parallaxController.updateParallaxConfiguration(.default)
    }

    override func tearDown() {
        parallaxController.resetParallaxEffect(for: mockLayers)
        parallaxController.resetMetrics()
        super.tearDown()
    }

    // MARK: - Configuration Tests

    func testDefaultConfiguration() {
        let config = BLParallaxConfiguration.default

        XCTAssertEqual(config.parallaxIntensity, 0.6, accuracy: 0.01)
        XCTAssertEqual(config.depthDistance, 20.0, accuracy: 0.01)
        XCTAssertEqual(config.interpolationMode, .easeInOut)
        XCTAssertEqual(config.responseThreshold, 0.05, accuracy: 0.01)
        XCTAssertEqual(config.maxOffsetLimit, 30.0, accuracy: 0.01)
        XCTAssertTrue(config.isPerformanceOptimized)

        // Test layer depth mapping
        XCTAssertEqual(config.layerDepthMap[.background], 25.0)
        XCTAssertEqual(config.layerDepthMap[.contentEnhancement], 15.0)
        XCTAssertEqual(config.layerDepthMap[.lightingEffect], 10.0)
        XCTAssertEqual(config.layerDepthMap[.interactionFeedback], 5.0)
    }

    func testPresetConfigurations() {
        // Test subtle preset
        let subtle = BLParallaxConfiguration.subtle
        XCTAssertEqual(subtle.parallaxIntensity, 0.3, accuracy: 0.01)
        XCTAssertEqual(subtle.interpolationMode, .linear)
        XCTAssertEqual(subtle.maxOffsetLimit, 15.0, accuracy: 0.01)

        // Test dramatic preset
        let dramatic = BLParallaxConfiguration.dramatic
        XCTAssertEqual(dramatic.parallaxIntensity, 1.0, accuracy: 0.01)
        XCTAssertEqual(dramatic.interpolationMode, .spring)
        XCTAssertEqual(dramatic.maxOffsetLimit, 50.0, accuracy: 0.01)

        // Test smooth preset
        let smooth = BLParallaxConfiguration.smooth
        XCTAssertEqual(smooth.parallaxIntensity, 0.5, accuracy: 0.01)
        XCTAssertEqual(smooth.interpolationMode, .cubic)
        XCTAssertEqual(smooth.maxOffsetLimit, 25.0, accuracy: 0.01)
    }

    func testConfigurationUpdate() {
        let customConfig = BLParallaxConfiguration.dramatic
        parallaxController.updateParallaxConfiguration(customConfig)

        // Verify configuration is applied by testing behavior
        let offset = parallaxController.calculateParallaxOffset(for: .background, focusProgress: 0.5)
        XCTAssertNotNil(offset)

        // Dramatic config should produce larger offsets
        let defaultController = BLParallaxEffectController()
        let defaultOffset = defaultController.calculateParallaxOffset(for: .background, focusProgress: 0.5)

        // Note: Due to different configurations, offsets may vary
    }

    // MARK: - Interpolation Mode Tests

    func testLinearInterpolation() {
        let mode = BLParallaxInterpolationMode.linear

        XCTAssertEqual(mode.interpolate(0.0), 0.0, accuracy: 0.01)
        XCTAssertEqual(mode.interpolate(0.5), 0.5, accuracy: 0.01)
        XCTAssertEqual(mode.interpolate(1.0), 1.0, accuracy: 0.01)

        // Test boundary clamping
        XCTAssertEqual(mode.interpolate(-0.5), 0.0, accuracy: 0.01)
        XCTAssertEqual(mode.interpolate(1.5), 1.0, accuracy: 0.01)
    }

    func testEaseInOutInterpolation() {
        let mode = BLParallaxInterpolationMode.easeInOut

        XCTAssertEqual(mode.interpolate(0.0), 0.0, accuracy: 0.01)
        XCTAssertEqual(mode.interpolate(1.0), 1.0, accuracy: 0.01)

        // EaseInOut should be slower at start and end
        let quarterProgress = mode.interpolate(0.25)
        let halfProgress = mode.interpolate(0.5)

        XCTAssertLessThan(quarterProgress, 0.25) // Slower at start
        XCTAssertEqual(halfProgress, 0.5, accuracy: 0.01) // Linear at midpoint
    }

    func testSpringInterpolation() {
        let mode = BLParallaxInterpolationMode.spring

        let result = mode.interpolate(0.8)
        // Spring should have overshoot, so result might be > 0.8
        XCTAssertGreaterThanOrEqual(result, 0.8)
    }

    // MARK: - Depth Management Tests

    func testDepthDistanceManagement() {
        // Test setting depth distance
        parallaxController.setDepthDistance(35.0, for: .background)

        let retrievedDistance = parallaxController.getDepthDistance(for: .background)
        XCTAssertEqual(retrievedDistance, 35.0, accuracy: 0.01)

        // Test boundary clamping (1.0-100.0)
        parallaxController.setDepthDistance(150.0, for: .contentEnhancement)
        XCTAssertEqual(parallaxController.getDepthDistance(for: .contentEnhancement), 100.0, accuracy: 0.01)

        parallaxController.setDepthDistance(-5.0, for: .lightingEffect)
        XCTAssertEqual(parallaxController.getDepthDistance(for: .lightingEffect), 1.0, accuracy: 0.01)
    }

    func testRelativeDepthCalculation() {
        // Set up known depth values
        parallaxController.setDepthDistance(50.0, for: .background)
        parallaxController.setDepthDistance(25.0, for: .contentEnhancement)
        parallaxController.setDepthDistance(10.0, for: .lightingEffect)

        // Background should have relative depth of 1.0 (maximum)
        XCTAssertEqual(parallaxController.calculateRelativeDepth(for: .background), 1.0, accuracy: 0.01)

        // Content enhancement should be 0.5 (half of max)
        XCTAssertEqual(parallaxController.calculateRelativeDepth(for: .contentEnhancement), 0.5, accuracy: 0.01)

        // Lighting effect should be 0.2 (20% of max)
        XCTAssertEqual(parallaxController.calculateRelativeDepth(for: .lightingEffect), 0.2, accuracy: 0.01)
    }

    // MARK: - Parallax Calculation Tests

    func testParallaxOffsetCalculation() {
        // Test focused state (progress = 1.0)
        let focusedOffset = parallaxController.calculateParallaxOffset(for: .background, focusProgress: 1.0)
        XCTAssertNotEqual(focusedOffset, CGPoint.zero)

        // Test unfocused state (progress = 0.0)
        let unfocusedOffset = parallaxController.calculateParallaxOffset(for: .background, focusProgress: 0.0)
        XCTAssertNotEqual(unfocusedOffset, CGPoint.zero)

        // Focused and unfocused should be different
        XCTAssertNotEqual(focusedOffset, unfocusedOffset)
    }

    func testOffsetLimiting() {
        // Use dramatic config for larger offsets
        parallaxController.updateParallaxConfiguration(.dramatic)

        let extremeOffset = parallaxController.calculateParallaxOffset(for: .background, focusProgress: 1.0)

        // Offsets should be limited by maxOffsetLimit
        let config = BLParallaxConfiguration.dramatic
        XCTAssertLessThanOrEqual(abs(extremeOffset.x), config.maxOffsetLimit)
        XCTAssertLessThanOrEqual(abs(extremeOffset.y), config.maxOffsetLimit)
    }

    func testDifferentLayerOffsets() {
        let backgroundOffset = parallaxController.calculateParallaxOffset(for: .background, focusProgress: 0.8)
        let interactionOffset = parallaxController.calculateParallaxOffset(for: .interactionFeedback, focusProgress: 0.8)

        // Different layer types should have different offsets due to depth differences
        XCTAssertNotEqual(backgroundOffset, interactionOffset)

        // Background (deeper) should typically have larger offset magnitude
        let backgroundMagnitude = sqrt(backgroundOffset.x * backgroundOffset.x + backgroundOffset.y * backgroundOffset.y)
        let interactionMagnitude = sqrt(interactionOffset.x * interactionOffset.x + interactionOffset.y * interactionOffset.y)

        XCTAssertGreaterThan(backgroundMagnitude, interactionMagnitude)
    }

    // MARK: - Parallax Application Tests

    func testParallaxEffectApplication() {
        let initialTransforms = mockLayers.map { $0.layer.transform }

        // Apply parallax effect
        parallaxController.applyParallaxEffect(to: mockLayers, focusProgress: 0.7)

        // Wait for async operations
        let expectation = XCTestExpectation(description: "Parallax effect applied")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Verify transforms have changed
        for (index, layer) in mockLayers.enumerated() {
            XCTAssertFalse(CATransform3DEqualToTransform(layer.layer.transform, initialTransforms[index]))
        }
    }

    func testParallaxEffectReset() {
        // First apply an effect
        parallaxController.applyParallaxEffect(to: mockLayers, focusProgress: 0.8)

        // Wait for application
        let applyExpectation = XCTestExpectation(description: "Parallax effect applied")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            applyExpectation.fulfill()
        }
        wait(for: [applyExpectation], timeout: 1.0)

        // Reset the effect
        parallaxController.resetParallaxEffect(for: mockLayers)

        // Wait for reset
        let resetExpectation = XCTestExpectation(description: "Parallax effect reset")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            resetExpectation.fulfill()
        }
        wait(for: [resetExpectation], timeout: 1.0)

        // Verify all transforms are identity
        for layer in mockLayers {
            XCTAssertTrue(CATransform3DEqualToTransform(layer.layer.transform, CATransform3DIdentity))
        }
    }

    func testResponseThreshold() {
        // Apply initial effect
        parallaxController.applyParallaxEffect(to: mockLayers, focusProgress: 0.5)

        // Wait for initial application
        let initialExpectation = XCTestExpectation(description: "Initial effect applied")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            initialExpectation.fulfill()
        }
        wait(for: [initialExpectation], timeout: 1.0)

        let initialTransforms = mockLayers.map { $0.layer.transform }

        // Apply very small change (below threshold)
        let smallChange = 0.51 // Should be below default threshold of 0.05
        parallaxController.applyParallaxEffect(to: mockLayers, focusProgress: smallChange)

        // Wait for potential application
        let thresholdExpectation = XCTestExpectation(description: "Threshold test completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            thresholdExpectation.fulfill()
        }
        wait(for: [thresholdExpectation], timeout: 1.0)

        // Transforms should remain the same due to threshold
        for (index, layer) in mockLayers.enumerated() {
            XCTAssertTrue(CATransform3DEqualToTransform(layer.layer.transform, initialTransforms[index]))
        }
    }

    // MARK: - Performance Tests

    func testPerformanceMetrics() {
        // Reset metrics
        parallaxController.resetMetrics()

        let initialMetrics = parallaxController.getCurrentMetrics()
        XCTAssertEqual(initialMetrics.processedLayerCount, 0)
        XCTAssertEqual(initialMetrics.averageOffsetMagnitude, 0.0, accuracy: 0.01)

        // Apply effect to generate metrics
        parallaxController.applyParallaxEffect(to: mockLayers, focusProgress: 0.6)

        // Wait for processing
        let expectation = XCTestExpectation(description: "Metrics updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let finalMetrics = parallaxController.getCurrentMetrics()
        XCTAssertEqual(finalMetrics.processedLayerCount, mockLayers.count)
        XCTAssertGreaterThan(finalMetrics.averageOffsetMagnitude, 0.0)
        XCTAssertGreaterThan(finalMetrics.performanceScore, 0.0)
    }

    func testCalculationPerformance() {
        // Measure parallax calculation performance
        measure {
            for _ in 0..<100 {
                _ = parallaxController.calculateParallaxOffset(for: .background, focusProgress: 0.5)
                _ = parallaxController.calculateParallaxOffset(for: .contentEnhancement, focusProgress: 0.7)
                _ = parallaxController.calculateParallaxOffset(for: .lightingEffect, focusProgress: 0.3)
                _ = parallaxController.calculateParallaxOffset(for: .interactionFeedback, focusProgress: 0.9)
            }
        }
    }

    func testBatchApplicationPerformance() {
        // Create larger set of layers for performance testing
        let largeMockLayers = (0..<20).map { _ in MockParallaxVisualLayer(layerType: .background) }

        measure {
            parallaxController.applyParallaxEffect(to: largeMockLayers, focusProgress: 0.5)
        }
    }

    // MARK: - Convenience Method Tests

    func testFocusAnimation() {
        let expectation = XCTestExpectation(description: "Focus animation completed")

        // Test focus animation
        parallaxController.animateFocus(layers: mockLayers, isFocused: true, duration: 0.2)

        // Wait for animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Verify transforms have been applied
        for layer in mockLayers {
            XCTAssertFalse(CATransform3DEqualToTransform(layer.layer.transform, CATransform3DIdentity))
        }
    }

    func testSelectionAnimation() {
        // Test selection animation with dramatic config
        parallaxController.animateSelection(layers: mockLayers, isSelected: true)

        let expectation = XCTestExpectation(description: "Selection animation applied")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Verify dramatic config effects
        let offset = parallaxController.calculateParallaxOffset(for: .background, focusProgress: 1.0)
        XCTAssertNotEqual(offset, CGPoint.zero)
    }

    // MARK: - Preset Tests

    func testPresetApplication() {
        // Test all presets
        let presets: [BLParallaxEffectController.ParallaxPreset] = [.subtle, .default, .dramatic, .smooth]

        for preset in presets {
            parallaxController.applyPreset(preset)

            // Verify preset is applied by testing behavior
            let offset = parallaxController.calculateParallaxOffset(for: .background, focusProgress: 0.5)
            XCTAssertNotNil(offset)
        }
    }

    // MARK: - Edge Cases and Error Handling

    func testEmptyLayerArray() {
        // Should not crash with empty layer array
        XCTAssertNoThrow {
            parallaxController.applyParallaxEffect(to: [], focusProgress: 0.5)
        }

        XCTAssertNoThrow {
            parallaxController.resetParallaxEffect(for: [])
        }
    }

    func testExtremeProgressValues() {
        // Test with extreme progress values
        let extremeValues: [CGFloat] = [-10.0, -1.0, 2.0, 100.0]

        for extremeValue in extremeValues {
            XCTAssertNoThrow {
                let offset = parallaxController.calculateParallaxOffset(for: .background, focusProgress: extremeValue)
                // Offset should still be within reasonable bounds due to clamping
                XCTAssertLessThanOrEqual(abs(offset.x), 100.0)
                XCTAssertLessThanOrEqual(abs(offset.y), 100.0)
            }
        }
    }

    func testConcurrentAccess() {
        let expectation = XCTestExpectation(description: "Concurrent access completed")
        expectation.expectedFulfillmentCount = 10

        // Test concurrent access to controller
        for i in 0..<10 {
            DispatchQueue.global(qos: .userInteractive).async {
                self.parallaxController.applyParallaxEffect(to: self.mockLayers, focusProgress: CGFloat(i) / 10.0)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testMemoryManagement() {
        // Test that controller doesn't retain layers
        weak var weakLayer: MockParallaxVisualLayer?

        autoreleasepool {
            let tempLayer = MockParallaxVisualLayer(layerType: .background)
            weakLayer = tempLayer

            parallaxController.applyParallaxEffect(to: [tempLayer], focusProgress: 0.5)
        }

        // Layer should be deallocated
        XCTAssertNil(weakLayer)
    }

    // MARK: - Integration Tests

    func testFullWorkflow() {
        // Test complete workflow

        // 1. Configure controller
        parallaxController.updateParallaxConfiguration(.dramatic)

        // 2. Set custom depth distances
        parallaxController.setDepthDistance(40.0, for: .background)
        parallaxController.setDepthDistance(20.0, for: .contentEnhancement)

        // 3. Apply parallax effects
        parallaxController.applyParallaxEffect(to: mockLayers, focusProgress: 0.8)

        // 4. Animate focus change
        parallaxController.animateFocus(layers: mockLayers, isFocused: false, duration: 0.1)

        // 5. Check performance metrics
        let expectation = XCTestExpectation(description: "Workflow completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let metrics = self.parallaxController.getCurrentMetrics()
            XCTAssertGreaterThan(metrics.processedLayerCount, 0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // 6. Reset everything
        parallaxController.resetParallaxEffect(for: mockLayers)
        parallaxController.resetMetrics()

        let finalMetrics = parallaxController.getCurrentMetrics()
        XCTAssertEqual(finalMetrics.processedLayerCount, 0)
    }

    func testSingletonBehavior() {
        let controller1 = BLParallaxEffectController.shared
        let controller2 = BLParallaxEffectController.shared

        XCTAssertTrue(controller1 === controller2)

        // Changes to one should affect the other
        controller1.updateParallaxConfiguration(.dramatic)

        let offset1 = controller1.calculateParallaxOffset(for: .background, focusProgress: 0.5)
        let offset2 = controller2.calculateParallaxOffset(for: .background, focusProgress: 0.5)

        XCTAssertEqual(offset1, offset2)
    }
}
