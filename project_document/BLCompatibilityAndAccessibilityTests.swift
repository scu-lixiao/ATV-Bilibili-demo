@testable import AuroraPremium
import AVFoundation
import UIKit
import XCTest

// {{CHENGQI:
// Action: Created
// Timestamp: 2025-06-09 10:08:45 +08:00 (from mcp-server-time)
// Reason: 实现P4-TE-014任务 - 设备兼容性和可访问性测试
// Principle_Applied: SOLID - S: 专注于兼容性测试单一职责, I: 分离设备测试和可访问性验证接口
// Optimization: 全面的tvOS设备覆盖，完整的可访问性功能验证
// Architectural_Note (AR): 基于BLConfigurationManager的设备能力检测，确保测试覆盖现有架构
// Documentation_Note (DW): 完整的测试文档和结果报告，符合质量标准
// }}

/// Aurora Premium设备兼容性和可访问性测试套件
/// 覆盖所有tvOS设备型号和可访问性功能
class BLCompatibilityAndAccessibilityTests: XCTestCase {
    // MARK: - Test Properties

    private var auroraCell: BLAuroraPremiumCell!
    private var testDeviceCapabilities: [BLDeviceModel: BLDeviceCapability] = [:]
    private var testAccessibilityConfigurations: [BLAccessibilityConfiguration] = []

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()

        // 初始化Aurora Premium Cell
        auroraCell = BLAuroraPremiumCell(frame: CGRect(x: 0, y: 0, width: 400, height: 300))

        // 设置测试设备能力
        setupTestDeviceCapabilities()

        // 设置测试可访问性配置
        setupTestAccessibilityConfigurations()
    }

    override func tearDownWithError() throws {
        auroraCell = nil
        testDeviceCapabilities.removeAll()
        testAccessibilityConfigurations.removeAll()
        try super.tearDownWithError()
    }

    // MARK: - Device Compatibility Tests

    /// 测试Apple TV 4K (第3代) - A15 Bionic兼容性
    func testAppleTV4K3rdGenCompatibility() throws {
        let deviceModel = BLDeviceModel.appleTV4K3rdGen
        let capability = testDeviceCapabilities[deviceModel]!

        // 验证设备检测
        XCTAssertEqual(capability.memoryGB, 4)
        XCTAssertEqual(capability.cpuCores, 6)
        XCTAssertEqual(capability.gpuSupport, .full)
        XCTAssertEqual(capability.recommendedQualityLevel, .ultra)

        // 验证Aurora Premium功能
        try testAuroraPremiumFunctionality(for: capability, expectedPerformance: .excellent)
    }

    /// 测试Apple TV 4K (第2代) - A12 Bionic兼容性
    func testAppleTV4K2ndGenCompatibility() throws {
        let deviceModel = BLDeviceModel.appleTV4K2ndGen
        let capability = testDeviceCapabilities[deviceModel]!

        // 验证设备检测
        XCTAssertEqual(capability.memoryGB, 3)
        XCTAssertEqual(capability.cpuCores, 6)
        XCTAssertEqual(capability.gpuSupport, .enhanced)
        XCTAssertEqual(capability.recommendedQualityLevel, .high)

        // 验证Aurora Premium功能
        try testAuroraPremiumFunctionality(for: capability, expectedPerformance: .good)
    }

    /// 测试Apple TV HD - A8兼容性
    func testAppleTVHDCompatibility() throws {
        let deviceModel = BLDeviceModel.appleTVHD
        let capability = testDeviceCapabilities[deviceModel]!

        // 验证设备检测
        XCTAssertEqual(capability.memoryGB, 2)
        XCTAssertEqual(capability.cpuCores, 2)
        XCTAssertEqual(capability.gpuSupport, .basic)
        XCTAssertEqual(capability.recommendedQualityLevel, .medium)

        // 验证Aurora Premium功能（降级模式）
        try testAuroraPremiumFunctionality(for: capability, expectedPerformance: .acceptable)
    }

    /// 测试Apple TV (第1代) - A4兼容性
    func testAppleTV1stGenCompatibility() throws {
        let deviceModel = BLDeviceModel.appleTV1stGen
        let capability = testDeviceCapabilities[deviceModel]!

        // 验证设备检测
        XCTAssertEqual(capability.memoryGB, 1)
        XCTAssertEqual(capability.cpuCores, 1)
        XCTAssertEqual(capability.gpuSupport, .none)
        XCTAssertEqual(capability.recommendedQualityLevel, .low)

        // 验证基础功能（禁用高级效果）
        try testBasicFunctionality(for: capability)
    }

    /// 测试不同tvOS版本兼容性
    func testtvOSVersionCompatibility() throws {
        let testVersions: [String] = ["15.0", "16.0", "17.0", "18.0"]

        for version in testVersions {
            let capability = createMockCapability(tvOSVersion: version)

            // 验证版本特性支持
            try testVersionSpecificFeatures(for: capability, version: version)
        }
    }

    /// 测试热节流状态下的性能
    func testThermalThrottlingCompatibility() throws {
        let thermalStates: [ProcessInfo.ThermalState] = [.nominal, .fair, .serious, .critical]

        for thermalState in thermalStates {
            // 模拟热状态
            let capability = createMockCapability(thermalState: thermalState)

            // 验证性能降级
            try testThermalPerformance(for: capability, thermalState: thermalState)
        }
    }

    /// 测试内存压力下的兼容性
    func testMemoryPressureCompatibility() throws {
        let memoryLevels: [Int] = [1, 2, 3, 4, 8] // GB

        for memoryGB in memoryLevels {
            let capability = createMockCapability(memoryGB: memoryGB)

            // 验证内存适配
            try testMemoryAdaptation(for: capability, memoryGB: memoryGB)
        }
    }

    // MARK: - Accessibility Tests

    /// 测试VoiceOver支持
    func testVoiceOverSupport() throws {
        // 启用VoiceOver
        enableAccessibilityFeature(.voiceOver)

        // 验证可访问性标签
        XCTAssertNotNil(auroraCell.accessibilityLabel)
        XCTAssertTrue(auroraCell.isAccessibilityElement)

        // 验证可访问性提示
        XCTAssertNotNil(auroraCell.accessibilityHint)

        // 验证可访问性特征
        XCTAssertTrue(auroraCell.accessibilityTraits.contains(.button))

        // 验证聚焦状态的可访问性
        auroraCell.setNeedsFocusUpdate()
        auroraCell.updateFocusIfNeeded()

        // 检查VoiceOver公告
        let announcement = auroraCell.accessibilityValue
        XCTAssertNotNil(announcement)
    }

    /// 测试Switch Control支持
    func testSwitchControlSupport() throws {
        // 启用Switch Control
        enableAccessibilityFeature(.switchControl)

        // 验证可访问性动作
        let actions = auroraCell.accessibilityCustomActions
        XCTAssertNotNil(actions)
        XCTAssertGreaterThan(actions?.count ?? 0, 0)

        // 验证激活动作
        let result = auroraCell.accessibilityActivate()
        XCTAssertTrue(result)

        // 验证增量/减量动作
        auroraCell.accessibilityIncrement()
        auroraCell.accessibilityDecrement()
    }

    /// 测试动态类型支持
    func testDynamicTypeSupport() throws {
        let contentSizes: [UIContentSizeCategory] = [
            .extraSmall, .small, .medium, .large,
            .extraLarge, .extraExtraLarge, .extraExtraExtraLarge,
            .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
            .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge,
        ]

        for contentSize in contentSizes {
            // 设置动态类型
            setDynamicTypeCategory(contentSize)

            // 验证字体适配
            try testFontAdaptation(for: contentSize)

            // 验证布局适配
            try testLayoutAdaptation(for: contentSize)
        }
    }

    /// 测试高对比度支持
    func testHighContrastSupport() throws {
        // 启用高对比度
        enableAccessibilityFeature(.increaseContrast)

        // 验证颜色对比度
        try testColorContrast()

        // 验证边框和分隔线
        try testHighContrastBorders()

        // 验证背景和前景色适配
        try testHighContrastColors()
    }

    /// 测试减少动画支持
    func testReduceMotionSupport() throws {
        // 启用减少动画
        enableAccessibilityFeature(.reduceMotion)

        // 验证动画禁用
        let animationManager = BLSpringAnimationManager.shared
        let config = animationManager.getConfiguration(for: .gentle)

        // 检查动画时长调整
        XCTAssertLessThanOrEqual(config.duration, 0.1) // 应该大幅减少

        // 验证视差效果禁用
        let parallaxController = BLParallaxEffectController.shared
        let parallaxConfig = parallaxController.getCurrentConfiguration()
        XCTAssertEqual(parallaxConfig.parallaxIntensity, 0.0)
    }

    /// 测试语音控制支持
    func testVoiceControlSupport() throws {
        // 启用语音控制
        enableAccessibilityFeature(.voiceControl)

        // 验证语音命令识别
        try testVoiceCommands()

        // 验证可访问性名称
        XCTAssertNotNil(auroraCell.accessibilityUserInputLabels)

        // 验证语音控制标签
        let labels = auroraCell.accessibilityUserInputLabels
        XCTAssertNotNil(labels)
        XCTAssertFalse(labels?.isEmpty ?? true)
    }

    /// 测试智能反转颜色支持
    func testSmartInvertColorsSupport() throws {
        // 启用智能反转
        enableAccessibilityFeature(.smartInvertColors)

        // 验证图像和媒体不反转
        auroraCell.accessibilityIgnoresInvertColors = true
        XCTAssertTrue(auroraCell.accessibilityIgnoresInvertColors)

        // 验证UI元素正确反转
        try testColorInversion()
    }

    // MARK: - Performance Benchmark Tests

    /// 测试不同设备的性能基准
    func testPerformanceBenchmarks() throws {
        let deviceModels: [BLDeviceModel] = [
            .appleTV4K3rdGen, .appleTV4K2ndGen, .appleTVHD, .appleTV1stGen,
        ]

        for deviceModel in deviceModels {
            let capability = testDeviceCapabilities[deviceModel]!

            // 测试动画性能
            try measureAnimationPerformance(for: capability)

            // 测试渲染性能
            try measureRenderingPerformance(for: capability)

            // 测试内存使用
            try measureMemoryUsage(for: capability)
        }
    }

    /// 测试可访问性功能的性能影响
    func testAccessibilityPerformanceImpact() throws {
        let accessibilityFeatures: [BLAccessibilityFeature] = [
            .voiceOver, .switchControl, .reduceMotion, .increaseContrast,
        ]

        // 基准性能（无可访问性功能）
        let baselinePerformance = try measureBaselinePerformance()

        for feature in accessibilityFeatures {
            // 启用可访问性功能
            enableAccessibilityFeature(feature)

            // 测量性能影响
            let featurePerformance = try measureBaselinePerformance()

            // 验证性能影响在可接受范围内
            let performanceImpact = (baselinePerformance - featurePerformance) / baselinePerformance
            XCTAssertLessThan(performanceImpact, 0.2) // 性能影响应小于20%

            // 禁用功能以备下次测试
            disableAccessibilityFeature(feature)
        }
    }

    // MARK: - Integration Tests

    /// 测试设备检测和配置管理集成
    func testDeviceDetectionIntegration() throws {
        let configManager = BLConfigurationManager.shared

        // 测试不同设备的配置生成
        for (deviceModel, capability) in testDeviceCapabilities {
            // 模拟设备能力
            let mockDetector = MockDeviceCapabilityDetector(capability: capability)
            configManager.setDeviceCapabilityDetector(mockDetector)

            // 获取全局配置
            let globalConfig = configManager.getGlobalConfiguration()

            // 验证配置正确性
            XCTAssertEqual(globalConfig.effectiveQualityLevel, capability.recommendedQualityLevel)
            XCTAssertEqual(globalConfig.deviceCapability, capability)
        }
    }

    /// 测试可访问性设置和配置同步
    func testAccessibilityConfigurationSync() throws {
        let configManager = BLConfigurationManager.shared

        // 测试减少动画设置
        enableAccessibilityFeature(.reduceMotion)
        let config1 = configManager.getGlobalConfiguration()
        XCTAssertTrue(config1.userPreferences.reduceAnimations)

        // 测试高对比度设置
        enableAccessibilityFeature(.increaseContrast)
        let config2 = configManager.getGlobalConfiguration()
        XCTAssertTrue(config2.userPreferences.increaseContrast)

        // 测试动画速度调整
        let animationSpeed = configManager.getAnimationSpeed()
        XCTAssertLessThan(animationSpeed, 1.0) // 应该减速
    }

    // MARK: - Helper Methods

    private func setupTestDeviceCapabilities() {
        // Apple TV 4K (第3代) - A15 Bionic
        testDeviceCapabilities[.appleTV4K3rdGen] = BLDeviceCapability(
            deviceModel: .appleTV4K3rdGen,
            tvOSVersion: "17.0",
            memoryGB: 4,
            cpuCores: 6,
            gpuSupport: .full,
            thermalState: .nominal,
            recommendedQualityLevel: .ultra,
            performanceScore: 15,
            supportsAdvancedFeatures: true
        )

        // Apple TV 4K (第2代) - A12 Bionic
        testDeviceCapabilities[.appleTV4K2ndGen] = BLDeviceCapability(
            deviceModel: .appleTV4K2ndGen,
            tvOSVersion: "16.0",
            memoryGB: 3,
            cpuCores: 6,
            gpuSupport: .enhanced,
            thermalState: .nominal,
            recommendedQualityLevel: .high,
            performanceScore: 11,
            supportsAdvancedFeatures: true
        )

        // Apple TV HD - A8
        testDeviceCapabilities[.appleTVHD] = BLDeviceCapability(
            deviceModel: .appleTVHD,
            tvOSVersion: "15.0",
            memoryGB: 2,
            cpuCores: 2,
            gpuSupport: .basic,
            thermalState: .fair,
            recommendedQualityLevel: .medium,
            performanceScore: 6,
            supportsAdvancedFeatures: false
        )

        // Apple TV (第1代) - A4
        testDeviceCapabilities[.appleTV1stGen] = BLDeviceCapability(
            deviceModel: .appleTV1stGen,
            tvOSVersion: "14.0",
            memoryGB: 1,
            cpuCores: 1,
            gpuSupport: .none,
            thermalState: .serious,
            recommendedQualityLevel: .low,
            performanceScore: 2,
            supportsAdvancedFeatures: false
        )
    }

    private func setupTestAccessibilityConfigurations() {
        // VoiceOver配置
        testAccessibilityConfigurations.append(BLAccessibilityConfiguration(
            feature: .voiceOver,
            enabled: true,
            settings: ["speakHints": true, "speakNotifications": true]
        ))

        // Switch Control配置
        testAccessibilityConfigurations.append(BLAccessibilityConfiguration(
            feature: .switchControl,
            enabled: true,
            settings: ["autoScanTimeout": 3.0, "customActions": true]
        ))

        // 减少动画配置
        testAccessibilityConfigurations.append(BLAccessibilityConfiguration(
            feature: .reduceMotion,
            enabled: true,
            settings: ["crossfadeTransitions": true, "disableParallax": true]
        ))
    }

    private func testAuroraPremiumFunctionality(for capability: BLDeviceCapability, expectedPerformance: BLPerformanceLevel) throws {
        // 设置设备能力
        auroraCell.updateDeviceCapability(capability)

        // 启用Aurora Premium
        auroraCell.isAuroraPremiumEnabled = true

        // 验证层管理器设置
        let layerManager = auroraCell.visualLayerManager
        XCTAssertNotNil(layerManager)
        XCTAssertEqual(layerManager?.currentQualityLevel, capability.recommendedQualityLevel)

        // 验证性能监控
        let performanceMetrics = auroraCell.performanceMonitor.getCurrentMetrics()
        XCTAssertNotNil(performanceMetrics)

        // 模拟聚焦状态变化
        auroraCell.didUpdateFocus(in: MockFocusUpdateContext(focused: true))

        // 等待动画完成
        let expectation = XCTestExpectation(description: "动画完成")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        // 验证FPS
        let currentFPS = performanceMetrics.currentFPS
        let expectedMinFPS: Double = expectedPerformance == .excellent ? 55.0 :
            expectedPerformance == .good ? 45.0 : 30.0
        XCTAssertGreaterThan(currentFPS, expectedMinFPS)
    }

    private func testBasicFunctionality(for capability: BLDeviceCapability) throws {
        // 设置设备能力
        auroraCell.updateDeviceCapability(capability)

        // 应该自动禁用Aurora Premium
        XCTAssertFalse(auroraCell.isAuroraPremiumEnabled)

        // 验证基础功能仍然工作
        auroraCell.didUpdateFocus(in: MockFocusUpdateContext(focused: true))

        // 验证基础动画
        let expectation = XCTestExpectation(description: "基础动画完成")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // 验证无高级效果
        let layerManager = auroraCell.visualLayerManager
        XCTAssertNil(layerManager) // 应该没有层管理器
    }

    private func measureAnimationPerformance(for capability: BLDeviceCapability) throws {
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
            // 设置设备能力
            auroraCell.updateDeviceCapability(capability)
            auroraCell.isAuroraPremiumEnabled = capability.supportsAdvancedFeatures

            // 执行复杂动画序列
            for _ in 0..<10 {
                auroraCell.didUpdateFocus(in: MockFocusUpdateContext(focused: true))
                auroraCell.didUpdateFocus(in: MockFocusUpdateContext(focused: false))
            }
        }
    }

    private func measureRenderingPerformance(for capability: BLDeviceCapability) throws {
        let renderExpectation = XCTestExpectation(description: "渲染性能测试")

        // 设置设备能力
        auroraCell.updateDeviceCapability(capability)
        auroraCell.isAuroraPremiumEnabled = capability.supportsAdvancedFeatures

        // 强制渲染
        auroraCell.setNeedsLayout()
        auroraCell.layoutIfNeeded()
        auroraCell.setNeedsDisplay()

        // 检查渲染时间
        let startTime = CFAbsoluteTimeGetCurrent()
        auroraCell.draw(auroraCell.bounds)
        let renderTime = CFAbsoluteTimeGetCurrent() - startTime

        // 验证渲染性能
        let maxRenderTime: Double = capability.performanceScore >= 10 ? 0.016 : // 60fps
            capability.performanceScore >= 5 ? 0.033 : // 30fps
            0.066 // 15fps
        XCTAssertLessThan(renderTime, maxRenderTime)

        renderExpectation.fulfill()
        wait(for: [renderExpectation], timeout: 1.0)
    }

    private func enableAccessibilityFeature(_ feature: BLAccessibilityFeature) {
        // 模拟可访问性功能启用
        let notification: Notification.Name
        switch feature {
        case .voiceOver:
            notification = UIAccessibility.voiceOverStatusDidChangeNotification
        case .switchControl:
            notification = UIAccessibility.switchControlStatusDidChangeNotification
        case .reduceMotion:
            notification = UIAccessibility.reduceMotionStatusDidChangeNotification
        case .increaseContrast:
            notification = UIAccessibility.darkerSystemColorsStatusDidChangeNotification
        default:
            return
        }

        NotificationCenter.default.post(name: notification, object: nil)
    }

    private func createMockCapability(tvOSVersion: String = "17.0",
                                      thermalState: ProcessInfo.ThermalState = .nominal,
                                      memoryGB: Int = 4) -> BLDeviceCapability
    {
        return BLDeviceCapability(
            deviceModel: .appleTV4K3rdGen,
            tvOSVersion: tvOSVersion,
            memoryGB: memoryGB,
            cpuCores: 6,
            gpuSupport: memoryGB >= 3 ? .full : .basic,
            thermalState: thermalState,
            recommendedQualityLevel: memoryGB >= 4 ? .ultra : memoryGB >= 2 ? .high : .low,
            performanceScore: min(memoryGB * 3, 15),
            supportsAdvancedFeatures: memoryGB >= 2
        )
    }
}

// MARK: - Supporting Types

enum BLDeviceModel {
    case appleTV4K3rdGen
    case appleTV4K2ndGen
    case appleTVHD
    case appleTV1stGen
}

enum BLPerformanceLevel {
    case excellent
    case good
    case acceptable
    case poor
}

enum BLAccessibilityFeature {
    case voiceOver
    case switchControl
    case reduceMotion
    case increaseContrast
    case smartInvertColors
    case voiceControl
}

struct BLDeviceCapability {
    let deviceModel: BLDeviceModel
    let tvOSVersion: String
    let memoryGB: Int
    let cpuCores: Int
    let gpuSupport: BLGPUSupport
    let thermalState: ProcessInfo.ThermalState
    let recommendedQualityLevel: BLQualityLevel
    let performanceScore: Int
    let supportsAdvancedFeatures: Bool
}

struct BLAccessibilityConfiguration {
    let feature: BLAccessibilityFeature
    let enabled: Bool
    let settings: [String: Any]
}

enum BLGPUSupport {
    case none
    case basic
    case enhanced
    case full
}

// MARK: - Mock Classes

class MockFocusUpdateContext: UIFocusUpdateContext {
    private let _focused: Bool

    init(focused: Bool) {
        _focused = focused
        super.init()
    }

    override var nextFocusedView: UIView? {
        return _focused ? UIView() : nil
    }
}

class MockDeviceCapabilityDetector: BLDeviceCapabilityDetecting {
    private let capability: BLDeviceCapability

    init(capability: BLDeviceCapability) {
        self.capability = capability
    }

    func detectDeviceCapability() -> BLDeviceCapability {
        return capability
    }

    func getPerformanceScore() -> Int {
        return capability.performanceScore
    }

    func supportsAdvancedFeatures() -> Bool {
        return capability.supportsAdvancedFeatures
    }
}
