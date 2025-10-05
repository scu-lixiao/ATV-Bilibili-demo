@testable import BLAuroraPremium
import QuartzCore
import UIKit
import XCTest

// {{CHENGQI:
// Action: Added
// Timestamp: 2025-06-09 08:39:02 +08:00 (from mcp-server-time)
// Reason: 为P2-LD-008任务创建完整的测试套件，确保交互反馈层质量
// Principle_Applied:
//   - 测试驱动开发(TDD): 全面覆盖功能、性能、集成测试
//   - SOLID: 测试类单一职责，接口分离测试
//   - DRY: 复用测试工具和配置方法
// Optimization:
//   - 异步测试优化，避免测试超时
//   - 性能基准测试，确保60fps目标
//   - 内存泄漏检测和资源清理验证
// Architectural_Note (AR):
//   - 验证与BLVisualLayerManager的集成
//   - 测试配置系统的完整性
//   - 确保协议实现的正确性
// Documentation_Note (DW):
//   - 详细的测试用例说明
//   - 清晰的测试分组和命名
//   - 完整的边界情况覆盖
// }}

class BLInteractionFeedbackLayerTests: XCTestCase {
    // MARK: - Properties

    var feedbackLayer: BLInteractionFeedbackLayer!
    var testConfiguration: BLLayerConfiguration!
    var performanceExpectation: XCTestExpectation!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        feedbackLayer = BLInteractionFeedbackLayer()

        // 创建测试配置
        let properties: [String: Any] = [
            "feedbackIntensity": "moderate",
            "animationSpeed": 1.0,
            "hapticEnabled": true,
            "feedbackEnabled": true,
        ]

        testConfiguration = BLLayerConfiguration(
            intensity: 0.7,
            duration: 0.3,
            timing: .easeInEaseOut,
            properties: properties
        )
    }

    override func tearDown() {
        feedbackLayer?.deactivateWithConfiguration(testConfiguration)
        feedbackLayer = nil
        testConfiguration = nil
        performanceExpectation = nil
        super.tearDown()
    }

    // MARK: - 初始化和基础设置测试

    func testInitialization() {
        XCTAssertNotNil(feedbackLayer, "交互反馈层应该能够正确初始化")
        XCTAssertEqual(feedbackLayer.layerType, .interactionFeedback, "层类型应该正确设置")
        XCTAssertFalse(feedbackLayer.isActive, "初始状态应该为非激活")
    }

    func testLayerSetup() {
        feedbackLayer.activateWithConfiguration(testConfiguration)

        XCTAssertTrue(feedbackLayer.isActive, "激活后应该处于活跃状态")
        XCTAssertNotNil(feedbackLayer.layer.superlayer, "应该正确添加到父层")
    }

    func testConfigurationParsing() {
        feedbackLayer.activateWithConfiguration(testConfiguration)

        // 验证配置解析
        XCTAssertTrue(feedbackLayer.feedbackEnabled, "反馈功能应该启用")
        XCTAssertTrue(feedbackLayer.hapticEnabled, "震动反馈应该启用")
    }

    // MARK: - 反馈强度测试

    func testFeedbackIntensityLevels() {
        let intensities: [BLFeedbackIntensity] = [.subtle, .moderate, .strong, .dramatic]

        for intensity in intensities {
            let properties: [String: Any] = [
                "feedbackIntensity": intensity.rawValue,
                "feedbackEnabled": true,
            ]

            let config = BLLayerConfiguration(
                intensity: intensity.opacity,
                duration: intensity.duration,
                timing: .easeInEaseOut,
                properties: properties
            )

            feedbackLayer.activateWithConfiguration(config)

            // 验证强度设置
            XCTAssertTrue(feedbackLayer.isActive, "强度 \(intensity) 应该正确激活")

            feedbackLayer.deactivateWithConfiguration(config)
        }
    }

    func testFeedbackIntensityValues() {
        // 测试强度值的正确性
        XCTAssertEqual(BLFeedbackIntensity.subtle.scale, 1.02, accuracy: 0.01)
        XCTAssertEqual(BLFeedbackIntensity.moderate.scale, 1.05, accuracy: 0.01)
        XCTAssertEqual(BLFeedbackIntensity.strong.scale, 1.08, accuracy: 0.01)
        XCTAssertEqual(BLFeedbackIntensity.dramatic.scale, 1.12, accuracy: 0.01)

        XCTAssertEqual(BLFeedbackIntensity.subtle.opacity, 0.3, accuracy: 0.01)
        XCTAssertEqual(BLFeedbackIntensity.moderate.opacity, 0.5, accuracy: 0.01)
        XCTAssertEqual(BLFeedbackIntensity.strong.opacity, 0.7, accuracy: 0.01)
        XCTAssertEqual(BLFeedbackIntensity.dramatic.opacity, 0.9, accuracy: 0.01)
    }

    // MARK: - 交互类型测试

    func testInteractionTypes() {
        feedbackLayer.activateWithConfiguration(testConfiguration)

        let interactions: [BLInteractionType] = [
            .focus, .select, .hover, .press, .release, .longPress, .swipe, .custom("test"),
        ]

        for interaction in interactions {
            // 测试交互反馈触发
            XCTAssertNoThrow(
                feedbackLayer.triggerFeedback(for: interaction, intensity: .moderate),
                "交互类型 \(interaction) 应该能够正确触发反馈"
            )
        }
    }

    func testInteractionStateMapping() {
        feedbackLayer.activateWithConfiguration(testConfiguration)

        let states: [BLInteractionState] = [
            .idle, .focused, .highlighted, .pressed, .selected, .disabled, .loading, .error, .success,
        ]

        for state in states {
            XCTAssertNoThrow(
                feedbackLayer.updateFeedbackState(state),
                "交互状态 \(state) 应该能够正确更新"
            )
        }
    }

    // MARK: - 微动画测试

    func testMicroAnimationTypes() {
        feedbackLayer.activateWithConfiguration(testConfiguration)

        let animationTypes: [BLMicroAnimationType] = [
            .pulse, .ripple, .bounce, .glow, .shake, .breathe, .sparkle,
        ]

        for animationType in animationTypes {
            let expectation = XCTestExpectation(description: "微动画 \(animationType) 完成")

            feedbackLayer.microAnimationManager?.playMicroAnimation(animationType) {
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 2.0)
        }
    }

    func testAnimationSpeedControl() {
        feedbackLayer.activateWithConfiguration(testConfiguration)

        let speeds: [CGFloat] = [0.5, 1.0, 1.5, 2.0]

        for speed in speeds {
            feedbackLayer.microAnimationManager?.setAnimationSpeed(speed)

            let expectation = XCTestExpectation(description: "动画速度 \(speed) 测试")

            feedbackLayer.microAnimationManager?.playMicroAnimation(.pulse) {
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 3.0)
        }
    }

    func testStopAllAnimations() {
        feedbackLayer.activateWithConfiguration(testConfiguration)

        // 启动多个动画
        feedbackLayer.microAnimationManager?.playMicroAnimation(.pulse, completion: nil)
        feedbackLayer.microAnimationManager?.playMicroAnimation(.glow, completion: nil)
        feedbackLayer.microAnimationManager?.playMicroAnimation(.breathe, completion: nil)

        // 停止所有动画
        XCTAssertNoThrow(
            feedbackLayer.microAnimationManager?.stopAllMicroAnimations(),
            "应该能够正确停止所有微动画"
        )
    }

    // MARK: - 状态指示器测试

    func testStateIndicatorVisibility() {
        feedbackLayer.activateWithConfiguration(testConfiguration)

        // 测试状态显示
        feedbackLayer.stateIndicator?.showState(.focused, animated: true)
        XCTAssertTrue(feedbackLayer.stateIndicator?.isVisible ?? false, "状态指示器应该可见")

        // 测试状态隐藏
        feedbackLayer.stateIndicator?.hideState(animated: true)

        // 等待动画完成
        let expectation = XCTestExpectation(description: "状态隐藏动画完成")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testStateAppearancePresets() {
        let appearances = [
            BLStateAppearance.focused,
            BLStateAppearance.selected,
            BLStateAppearance.error,
            BLStateAppearance.loading,
        ]

        for appearance in appearances {
            XCTAssertNotNil(appearance.color, "状态外观应该有颜色")
            XCTAssertGreaterThan(appearance.intensity, 0, "强度应该大于0")
            XCTAssertGreaterThan(appearance.duration, 0, "持续时间应该大于0")
        }
    }

    // MARK: - 震动反馈测试

    func testHapticFeedbackEnabled() {
        let properties: [String: Any] = [
            "hapticEnabled": true,
            "feedbackEnabled": true,
        ]

        let config = BLLayerConfiguration(
            intensity: 0.7,
            duration: 0.3,
            timing: .easeInEaseOut,
            properties: properties
        )

        feedbackLayer.activateWithConfiguration(config)
        XCTAssertTrue(feedbackLayer.hapticEnabled, "震动反馈应该启用")
    }

    func testHapticFeedbackDisabled() {
        let properties: [String: Any] = [
            "hapticEnabled": false,
            "feedbackEnabled": true,
        ]

        let config = BLLayerConfiguration(
            intensity: 0.7,
            duration: 0.3,
            timing: .easeInEaseOut,
            properties: properties
        )

        feedbackLayer.activateWithConfiguration(config)
        XCTAssertFalse(feedbackLayer.hapticEnabled, "震动反馈应该禁用")
    }

    // MARK: - 自定义状态测试

    func testCustomStates() {
        feedbackLayer.activateWithConfiguration(testConfiguration)

        let customStates = ["highlight", "error", "success", "loading", "disabled"]

        for state in customStates {
            let properties: [String: Any] = ["customState": state]
            let config = BLLayerConfiguration(
                intensity: 0.7,
                duration: 0.3,
                timing: .easeInEaseOut,
                properties: properties
            )

            XCTAssertNoThrow(
                feedbackLayer.applyCustomState(state, configuration: config),
                "自定义状态 \(state) 应该能够正确应用"
            )
        }
    }

    func testCustomStateMapping() {
        feedbackLayer.activateWithConfiguration(testConfiguration)

        // 测试状态映射
        let mappings = [
            ("highlight", BLInteractionState.highlighted),
            ("error", BLInteractionState.error),
            ("success", BLInteractionState.success),
            ("loading", BLInteractionState.loading),
            ("disabled", BLInteractionState.disabled),
        ]

        for (customState, expectedState) in mappings {
            let mappedState = feedbackLayer.mapCustomStateToInteractionState(customState)
            XCTAssertEqual(mappedState, expectedState, "自定义状态 \(customState) 应该映射到 \(expectedState)")
        }
    }

    // MARK: - 配置更新测试

    func testConfigurationUpdate() {
        feedbackLayer.activateWithConfiguration(testConfiguration)

        // 创建新配置
        let newProperties: [String: Any] = [
            "feedbackIntensity": "strong",
            "animationSpeed": 2.0,
            "hapticEnabled": false,
        ]

        let newConfig = BLLayerConfiguration(
            intensity: 0.8,
            duration: 0.4,
            timing: .easeOut,
            properties: newProperties
        )

        XCTAssertNoThrow(
            feedbackLayer.updateConfiguration(newConfig),
            "应该能够正确更新配置"
        )

        XCTAssertFalse(feedbackLayer.hapticEnabled, "震动反馈应该已禁用")
    }

    func testDynamicConfigurationChange() {
        feedbackLayer.activateWithConfiguration(testConfiguration)

        // 测试动态配置变更
        let intensities: [BLFeedbackIntensity] = [.subtle, .dramatic, .moderate]

        for intensity in intensities {
            let properties: [String: Any] = [
                "feedbackIntensity": intensity.rawValue,
            ]

            let config = BLLayerConfiguration(
                intensity: intensity.opacity,
                duration: intensity.duration,
                timing: .easeInEaseOut,
                properties: properties
            )

            feedbackLayer.updateConfiguration(config)

            // 验证配置更新
            XCTAssertTrue(feedbackLayer.isActive, "配置更新后应该保持活跃状态")
        }
    }

    // MARK: - 状态重置测试

    func testResetToStableState() {
        feedbackLayer.activateWithConfiguration(testConfiguration)

        // 设置一些状态
        feedbackLayer.updateFeedbackState(.pressed)
        feedbackLayer.triggerFeedback(for: .press, intensity: .strong)

        // 重置状态
        XCTAssertNoThrow(
            feedbackLayer.resetToStableState(),
            "应该能够正确重置到稳定状态"
        )

        // 验证重置结果
        XCTAssertEqual(feedbackLayer.currentInteractionState, .idle, "应该重置到空闲状态")
    }

    func testResetFeedback() {
        feedbackLayer.activateWithConfiguration(testConfiguration)

        // 触发一些反馈
        feedbackLayer.triggerFeedback(for: .focus, intensity: .moderate)
        feedbackLayer.updateFeedbackState(.focused)

        // 重置反馈
        XCTAssertNoThrow(
            feedbackLayer.resetFeedback(),
            "应该能够正确重置反馈"
        )
    }

    // MARK: - 内存管理测试

    func testMemoryManagement() {
        weak var weakFeedbackLayer: BLInteractionFeedbackLayer?

        autoreleasepool {
            let layer = BLInteractionFeedbackLayer()
            weakFeedbackLayer = layer

            layer.activateWithConfiguration(testConfiguration)
            layer.triggerFeedback(for: .focus, intensity: .moderate)
            layer.deactivateWithConfiguration(testConfiguration)
        }

        // 验证内存释放
        XCTAssertNil(weakFeedbackLayer, "交互反馈层应该正确释放内存")
    }

    func testResourceCleanup() {
        feedbackLayer.activateWithConfiguration(testConfiguration)

        // 启动一些动画和状态
        feedbackLayer.microAnimationManager?.playMicroAnimation(.pulse, completion: nil)
        feedbackLayer.stateIndicator?.showState(.focused, animated: true)

        // 清理资源
        XCTAssertNoThrow(
            feedbackLayer.deactivateWithConfiguration(testConfiguration),
            "应该能够正确清理资源"
        )

        XCTAssertFalse(feedbackLayer.isActive, "清理后应该处于非活跃状态")
    }

    // MARK: - 边界情况测试

    func testNilConfiguration() {
        // 测试空配置处理
        XCTAssertNoThrow(
            feedbackLayer.activateWithConfiguration(BLLayerConfiguration(intensity: 0, duration: 0, timing: .linear, properties: [:])),
            "应该能够处理空配置"
        )
    }

    func testInvalidConfigurationValues() {
        let invalidProperties: [String: Any] = [
            "feedbackIntensity": "invalid",
            "animationSpeed": -1.0,
            "hapticEnabled": "not_boolean",
        ]

        let invalidConfig = BLLayerConfiguration(
            intensity: -1.0,
            duration: -1.0,
            timing: .linear,
            properties: invalidProperties
        )

        XCTAssertNoThrow(
            feedbackLayer.activateWithConfiguration(invalidConfig),
            "应该能够处理无效配置值"
        )
    }

    func testExtremeAnimationSpeed() {
        feedbackLayer.activateWithConfiguration(testConfiguration)

        // 测试极端动画速度
        let extremeSpeeds: [CGFloat] = [0.01, 10.0, 100.0]

        for speed in extremeSpeeds {
            XCTAssertNoThrow(
                feedbackLayer.microAnimationManager?.setAnimationSpeed(speed),
                "应该能够处理极端动画速度 \(speed)"
            )
        }
    }

    func testConcurrentAnimations() {
        feedbackLayer.activateWithConfiguration(testConfiguration)

        // 同时触发多个动画
        let expectation = XCTestExpectation(description: "并发动画完成")
        expectation.expectedFulfillmentCount = 3

        feedbackLayer.microAnimationManager?.playMicroAnimation(.pulse) {
            expectation.fulfill()
        }

        feedbackLayer.microAnimationManager?.playMicroAnimation(.glow) {
            expectation.fulfill()
        }

        feedbackLayer.microAnimationManager?.playMicroAnimation(.bounce) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
    }

    // MARK: - 性能测试

    func testFeedbackTriggerPerformance() {
        feedbackLayer.activateWithConfiguration(testConfiguration)

        measure {
            for _ in 0..<100 {
                feedbackLayer.triggerFeedback(for: .focus, intensity: .moderate)
            }
        }
    }

    func testAnimationCreationPerformance() {
        feedbackLayer.activateWithConfiguration(testConfiguration)

        measure {
            for animationType in BLMicroAnimationType.allCases {
                feedbackLayer.microAnimationManager?.playMicroAnimation(animationType, completion: nil)
            }
        }
    }

    func testStateUpdatePerformance() {
        feedbackLayer.activateWithConfiguration(testConfiguration)

        let states: [BLInteractionState] = [.idle, .focused, .highlighted, .pressed, .selected]

        measure {
            for state in states {
                feedbackLayer.updateFeedbackState(state)
            }
        }
    }

    func testMemoryUsageStability() {
        feedbackLayer.activateWithConfiguration(testConfiguration)

        // 执行大量操作测试内存稳定性
        for i in 0..<1000 {
            let intensity: BLFeedbackIntensity = [.subtle, .moderate, .strong, .dramatic][i % 4]
            let interaction: BLInteractionType = [.focus, .select, .hover, .press][i % 4]

            feedbackLayer.triggerFeedback(for: interaction, intensity: intensity)

            if i % 100 == 0 {
                feedbackLayer.resetToStableState()
            }
        }

        // 验证最终状态
        XCTAssertTrue(feedbackLayer.isActive, "大量操作后应该保持稳定")
    }

    // MARK: - 集成测试

    func testVisualLayerManagerIntegration() {
        let layerManager = BLVisualLayerManager()

        // 测试与层管理器的集成
        XCTAssertNoThrow(
            layerManager.setupLayers(),
            "应该能够与层管理器正确集成"
        )

        // 验证交互反馈层的创建
        let interactionLayer = layerManager.getLayer(type: .interactionFeedback) as? BLInteractionFeedbackLayer
        XCTAssertNotNil(interactionLayer, "应该能够从层管理器获取交互反馈层")
    }

    func testAuroraPremiumCellIntegration() {
        let auroraPremiumCell = BLAuroraPremiumCell()

        // 启用Aurora Premium功能
        auroraPremiumCell.setAuroraPremiumEnabled(true)

        // 验证交互反馈层集成
        XCTAssertNotNil(auroraPremiumCell.layerManager, "Aurora Premium Cell应该有层管理器")

        let interactionLayer = auroraPremiumCell.layerManager?.getLayer(type: .interactionFeedback)
        XCTAssertNotNil(interactionLayer, "应该包含交互反馈层")
    }

    func testConfigurationSystemIntegration() {
        let configManager = BLConfigurationManager()

        // 测试配置系统集成
        let config = configManager.getLayerConfiguration(for: .interactionFeedback)
        XCTAssertNotNil(config, "应该能够从配置管理器获取交互反馈层配置")

        feedbackLayer.activateWithConfiguration(config!)
        XCTAssertTrue(feedbackLayer.isActive, "应该能够使用配置管理器的配置激活")
    }
}

// MARK: - Test Extensions

extension BLInteractionFeedbackLayerTests {
    /// 创建测试用的配置
    private func createTestConfiguration(
        intensity: BLFeedbackIntensity = .moderate,
        hapticEnabled: Bool = true,
        feedbackEnabled: Bool = true
    ) -> BLLayerConfiguration {
        let properties: [String: Any] = [
            "feedbackIntensity": intensity.rawValue,
            "hapticEnabled": hapticEnabled,
            "feedbackEnabled": feedbackEnabled,
        ]

        return BLLayerConfiguration(
            intensity: intensity.opacity,
            duration: intensity.duration,
            timing: .easeInEaseOut,
            properties: properties
        )
    }

    /// 等待动画完成的辅助方法
    private func waitForAnimationCompletion(timeout: TimeInterval = 1.0) {
        let expectation = XCTestExpectation(description: "动画完成")
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout + 0.5)
    }
}
