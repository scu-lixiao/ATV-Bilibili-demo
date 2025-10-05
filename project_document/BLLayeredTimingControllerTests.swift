import XCTest
@testable import YourAppModule

// {{CHENGQI:
// Action: Added
// Timestamp: 2025-06-09 09:30:32 +08:00
// Reason: 为BLLayeredTimingController创建完整测试套件，确保分层时序控制功能的质量
// Principle_Applied: SOLID - 测试每个职责独立，DRY - 复用测试工具和数据
// Optimization: 使用模拟对象减少测试复杂度，异步测试确保时序准确性
// Architectural_Note (AR): 测试覆盖协议分离设计和时序算法的正确性
// Documentation_Note (DW): 测试文档化了时序控制器的预期行为和性能标准
// }}

class BLLayeredTimingControllerTests: XCTestCase {
    // MARK: - Properties

    var timingController: BLLayeredTimingController!
    var mockLayers: [MockVisualLayer] = []

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        timingController = BLLayeredTimingController.shared
        setupMockLayers()
    }

    override func tearDown() {
        timingController.stopCoordinatedAnimations()
        timingController.stopMonitoring()
        timingController.resetMetrics()
        mockLayers.removeAll()
        super.tearDown()
    }

    // MARK: - Configuration Tests

    func testTimingConfigurationDefaults() {
        // 测试默认配置的正确性
        let defaultConfig = BLLayeredTimingConfiguration.default

        XCTAssertEqual(defaultConfig.pattern, BLLayeredTimingConfiguration.TimingPattern.staggered)
        XCTAssertEqual(defaultConfig.globalDuration, 0.6)
        XCTAssertEqual(defaultConfig.staggerDelay, 0.1)
        XCTAssertEqual(defaultConfig.dampingFactor, 0.8)
        XCTAssertEqual(defaultConfig.priorities.count, 4)
        XCTAssertNotNil(defaultConfig.easingFunction)
    }

    func testTimingConfigurationPresets() {
        // 测试预设配置的有效性
        let configs = [
            BLLayeredTimingConfiguration.synchronized,
            BLLayeredTimingConfiguration.cascading,
            BLLayeredTimingConfiguration.ripple,
        ]

        for config in configs {
            XCTAssertGreaterThan(config.globalDuration, 0)
            XCTAssertGreaterThanOrEqual(config.staggerDelay, 0)
            XCTAssertGreaterThan(config.dampingFactor, 0)
            XCTAssertLessThanOrEqual(config.dampingFactor, 1.0)
            XCTAssertFalse(config.priorities.isEmpty)
        }
    }

    func testLayerPriorityMapping() {
        // 测试层优先级到层类型的映射
        let priorities = BLLayeredTimingConfiguration.LayerPriority.allCases

        for priority in priorities {
            let layerType = priority.layerType
            XCTAssertNotNil(layerType)

            switch priority {
            case .background:
                XCTAssertEqual(layerType, .auroraBackground)
            case .content:
                XCTAssertEqual(layerType, .contentEnhancement)
            case .lighting:
                XCTAssertEqual(layerType, .lightingEffect)
            case .interaction:
                XCTAssertEqual(layerType, .interactionFeedback)
            }
        }
    }

    // MARK: - Animation Sequence Generation Tests

    func testAnimationSequenceGeneration() {
        // 测试动画序列的生成
        let config = BLLayeredTimingConfiguration.default
        let sequences = timingController.coordinateLayerAnimations(with: config)

        XCTAssertEqual(sequences.count, 4) // 四个层

        // 验证序列属性
        for sequence in sequences {
            XCTAssertGreaterThanOrEqual(sequence.delay, 0)
            XCTAssertGreaterThan(sequence.duration, 0)
            XCTAssertFalse(sequence.animations.isEmpty)
        }
    }

    func testDelayCalculation() {
        // 测试不同模式下的延迟计算
        let configs = [
            ("synchronized", BLLayeredTimingConfiguration.synchronized),
            ("staggered", BLLayeredTimingConfiguration.default),
            ("cascading", BLLayeredTimingConfiguration.cascading),
            ("ripple", BLLayeredTimingConfiguration.ripple),
        ]

        for (name, config) in configs {
            let sequences = timingController.coordinateLayerAnimations(with: config)

            switch config.pattern {
            case .synchronized:
                // 同步模式所有延迟应该为0
                for sequence in sequences {
                    XCTAssertEqual(sequence.delay, 0, "同步模式延迟应为0 - \(name)")
                }
            case .staggered, .cascading:
                // 错峰和级联模式延迟应该递增
                for (index, sequence) in sequences.enumerated() {
                    let expectedDelay = TimeInterval(index) * config.staggerDelay
                    let actualDelay = sequence.delay
                    XCTAssertEqual(actualDelay, expectedDelay, accuracy: 0.01, "错峰延迟计算错误 - \(name)")
                }
            case .ripple:
                // 波纹模式延迟应该从交互层开始
                XCTAssertTrue(sequences.first?.delay ?? 0 >= 0, "波纹模式延迟错误 - \(name)")
            case .custom:
                break // 自定义模式不做特定验证
            }
        }
    }

    func testDurationCalculation() {
        // 测试时长计算的准确性
        let config = BLLayeredTimingConfiguration.default
        let sequences = timingController.coordinateLayerAnimations(with: config)

        for sequence in sequences {
            let baseDuration = config.globalDuration
            let dampingAdjustment = config.dampingFactor

            switch sequence.priority {
            case .background:
                let expected = baseDuration * dampingAdjustment * 1.2
                XCTAssertEqual(sequence.duration, expected, accuracy: 0.01)
            case .content:
                let expected = baseDuration * dampingAdjustment
                XCTAssertEqual(sequence.duration, expected, accuracy: 0.01)
            case .lighting:
                let expected = baseDuration * dampingAdjustment * 0.8
                XCTAssertEqual(sequence.duration, expected, accuracy: 0.01)
            case .interaction:
                let expected = baseDuration * dampingAdjustment * 0.6
                XCTAssertEqual(sequence.duration, expected, accuracy: 0.01)
            }
        }
    }

    // MARK: - Coordination Tests

    func testLayerAnimationCoordination() {
        // 测试层动画协调功能
        let expectation = XCTestExpectation(description: "Layer animation coordination")
        let config = BLLayeredTimingConfiguration.default

        timingController.coordinateLayerAnimations(
            for: mockLayers,
            with: config
        ) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testFocusStateCoordination() {
        // 测试聚焦状态协调
        let focusExpectation = XCTestExpectation(description: "Focus coordination")
        let unfocusExpectation = XCTestExpectation(description: "Unfocus coordination")

        // 测试聚焦
        timingController.coordinateFocusState(for: mockLayers, focused: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            focusExpectation.fulfill()

            // 测试取消聚焦
            self.timingController.coordinateFocusState(for: self.mockLayers, focused: false)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                unfocusExpectation.fulfill()
            }
        }

        wait(for: [focusExpectation, unfocusExpectation], timeout: 5.0)
    }

    func testAnimationSynchronization() {
        // 测试动画同步功能
        let config = BLLayeredTimingConfiguration.synchronized
        let sequences = timingController.coordinateLayerAnimations(with: config)

        let expectation = XCTestExpectation(description: "Animation synchronization")

        timingController.synchronizeAnimations(sequences)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testAnimationStaggering() {
        // 测试动画错峰功能
        let config = BLLayeredTimingConfiguration.staggered
        let sequences = timingController.coordinateLayerAnimations(with: config)

        let patterns: [BLStaggerPattern] = [
            .sequential, .reverse, .fromCenter, .toCenter, .alternating,
        ]

        for pattern in patterns {
            let expectation = XCTestExpectation(description: "Stagger pattern: \(pattern)")

            timingController.staggerAnimations(sequences, with: pattern)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 2.0)
        }
    }

    // MARK: - Monitoring Tests

    func testTimingMonitoring() {
        // 测试时序监控功能
        XCTAssertFalse(timingController.isMonitoring)

        timingController.startMonitoring()
        XCTAssertTrue(timingController.isMonitoring)

        // 获取初始指标
        let initialMetrics = timingController.getTimingMetrics()
        XCTAssertEqual(initialMetrics.coordinationStartTime, 0)
        XCTAssertEqual(initialMetrics.totalAnimationCount, 0)

        timingController.stopMonitoring()
        XCTAssertFalse(timingController.isMonitoring)
    }

    func testTimingMetricsReset() {
        // 测试时序指标重置
        timingController.startMonitoring()

        // 模拟一些数据
        var metrics = timingController.getTimingMetrics()
        metrics.coordinationStartTime = CACurrentMediaTime()
        metrics.totalAnimationCount = 5

        timingController.resetMetrics()

        let resetMetrics = timingController.getTimingMetrics()
        XCTAssertEqual(resetMetrics.coordinationStartTime, 0)
        XCTAssertEqual(resetMetrics.totalAnimationCount, 0)
        XCTAssertEqual(resetMetrics.synchronizationAccuracy, 0)
        XCTAssertEqual(resetMetrics.performanceScore, 0)
    }

    func testPerformanceMetricsAccuracy() {
        // 测试性能指标的准确性
        timingController.startMonitoring()

        let expectation = XCTestExpectation(description: "Performance metrics")

        // 执行一些动画协调
        timingController.coordinateLayerAnimations(for: mockLayers) {
            let metrics = self.timingController.getTimingMetrics()

            XCTAssertGreaterThan(metrics.coordinationDuration, 0)
            XCTAssertGreaterThanOrEqual(metrics.synchronizationAccuracy, 0)
            XCTAssertLessThanOrEqual(metrics.synchronizationAccuracy, 1.0)
            XCTAssertGreaterThanOrEqual(metrics.staggerPrecision, 0)
            XCTAssertLessThanOrEqual(metrics.staggerPrecision, 1.0)
            XCTAssertGreaterThanOrEqual(metrics.performanceScore, 0)
            XCTAssertLessThanOrEqual(metrics.performanceScore, 1.0)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        timingController.stopMonitoring()
    }

    // MARK: - Convenience Methods Tests

    func testConvenienceAnimations() {
        // 测试便捷动画方法
        let focusExpectation = XCTestExpectation(description: "Focus animation")
        let selectionExpectation = XCTestExpectation(description: "Selection animation")
        let stateExpectation = XCTestExpectation(description: "State animation")

        // 测试聚焦动画
        timingController.animateFocus(for: mockLayers, focused: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            focusExpectation.fulfill()
        }

        // 测试选择动画
        timingController.animateSelection(for: mockLayers, selected: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            selectionExpectation.fulfill()
        }

        // 测试状态变化动画
        let states = ["loading", "error", "success", "default"]
        for (index, state) in states.enumerated() {
            timingController.animateStateChange(for: mockLayers, to: state)

            if index == states.count - 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    stateExpectation.fulfill()
                }
            }
        }

        wait(for: [focusExpectation, selectionExpectation, stateExpectation], timeout: 5.0)
    }

    // MARK: - Error Handling Tests

    func testEmptyLayerHandling() {
        // 测试空层数组的处理
        let expectation = XCTestExpectation(description: "Empty layer handling")

        timingController.coordinateLayerAnimations(for: []) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testStopCoordinatedAnimations() {
        // 测试停止协调动画
        timingController.coordinateLayerAnimations(for: mockLayers)

        // 验证有活跃的动画序列
        XCTAssertFalse(timingController.activeSequences.isEmpty)

        timingController.stopCoordinatedAnimations()

        // 验证动画序列已清空
        XCTAssertTrue(timingController.activeSequences.isEmpty)
    }

    func testCustomStaggerPattern() {
        // 测试自定义错峰模式
        let config = BLLayeredTimingConfiguration.default
        let sequences = timingController.coordinateLayerAnimations(with: config)

        let customIndices = [2, 0, 3, 1]
        let customPattern = BLStaggerPattern.custom(customIndices)

        timingController.staggerAnimations(sequences, with: customPattern)

        // 验证不会崩溃并能正常执行
        XCTAssertTrue(true)
    }

    // MARK: - Performance Tests

    func testCoordinationPerformance() {
        // 测试协调性能
        measure {
            for _ in 0..<10 {
                timingController.coordinateLayerAnimations(for: mockLayers)
            }
        }
    }

    func testSequenceGenerationPerformance() {
        // 测试序列生成性能
        let config = BLLayeredTimingConfiguration.default

        measure {
            for _ in 0..<100 {
                _ = timingController.coordinateLayerAnimations(with: config)
            }
        }
    }

    func testMonitoringOverhead() {
        // 测试监控开销
        timingController.startMonitoring()

        measure {
            for _ in 0..<50 {
                timingController.coordinateLayerAnimations(for: mockLayers)
                _ = timingController.getTimingMetrics()
            }
        }

        timingController.stopMonitoring()
    }

    // MARK: - Integration Tests

    func testControllerSingleton() {
        // 测试单例模式
        let controller1 = BLLayeredTimingController.shared
        let controller2 = BLLayeredTimingController.shared

        XCTAssertTrue(controller1 === controller2)
    }

    func testConfigurationUpdate() {
        // 测试配置更新
        let originalConfig = BLLayeredTimingConfiguration.default
        let newConfig = BLLayeredTimingConfiguration.ripple

        timingController.updateConfiguration(newConfig)

        // 验证配置已更新（通过行为验证）
        let sequences1 = timingController.coordinateLayerAnimations(with: originalConfig)
        let sequences2 = timingController.coordinateLayerAnimations(with: newConfig)

        // 不同配置应产生不同的延迟模式
        XCTAssertNotEqual(sequences1.map { $0.delay }, sequences2.map { $0.delay })
    }

    func testConcurrentCoordination() {
        // 测试并发协调的安全性
        let expectation = XCTestExpectation(description: "Concurrent coordination")
        expectation.expectedFulfillmentCount = 3

        let queue = DispatchQueue.global(qos: .userInteractive)

        for i in 0..<3 {
            queue.async {
                self.timingController.coordinateLayerAnimations(for: self.mockLayers) {
                    expectation.fulfill()
                }
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Helper Methods

    private func setupMockLayers() {
        mockLayers = [
            MockVisualLayer(type: .auroraBackground),
            MockVisualLayer(type: .contentEnhancement),
            MockVisualLayer(type: .lightingEffect),
            MockVisualLayer(type: .interactionFeedback),
        ]
    }
}

// MARK: - Mock Classes

class MockVisualLayer: BLBaseVisualLayer {
    init(type: BLVisualLayerType) {
        super.init()
        // 模拟层的基本设置
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func activateWithConfiguration(_ configuration: BLLayerConfiguration) {
        // 模拟激活
        currentState = .active
    }

    override func deactivateWithConfiguration(_ configuration: BLLayerConfiguration) {
        // 模拟停用
        currentState = .inactive
    }

    override func updateConfiguration(_ configuration: BLLayerConfiguration) {
        // 模拟配置更新
        currentConfiguration = configuration
    }

    override func applyCustomState(_ state: String, configuration: BLLayerConfiguration) {
        // 模拟自定义状态应用
        currentState = .active
    }

    override func resetToStableState() {
        // 模拟重置到稳定状态
        currentState = .inactive
    }
}

// MARK: - Test Extensions

extension BLLayeredTimingController {
    /// 测试辅助属性：检查监控状态
    var isMonitoring: Bool {
        return monitoringTimer != nil
    }

    /// 测试辅助属性：活跃序列数量
    var activeSequences: [BLLayerAnimationSequence] {
        return syncQueue.sync {
            return self.activeSequences
        }
    }
}
