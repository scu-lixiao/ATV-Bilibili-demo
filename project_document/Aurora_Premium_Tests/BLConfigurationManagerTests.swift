@testable import BLAuroraPremium
import XCTest

// MARK: - Mock 类

/// Mock设备能力检测器
class MockDeviceCapabilityDetector: BLDeviceCapabilityDetecting {
    var mockTVOSVersion = "tvOS 17.0"
    var mockDeviceModel = "AppleTV11,1"
    var mockMemoryCapacity: Int64 = 3 * 1024 * 1024 * 1024 // 3GB
    var mockCPUCores = 6
    var mockGPUSupport = BLGPUSupport.full
    var mockThermalState = ProcessInfo.ThermalState.nominal
    var mockPerformanceLevel = BLPerformanceLevel.high

    func detectTVOSVersion() -> String { return mockTVOSVersion }
    func detectDeviceModel() -> String { return mockDeviceModel }
    func detectMemoryCapacity() -> Int64 { return mockMemoryCapacity }
    func detectCPUCores() -> Int { return mockCPUCores }
    func detectGPUSupport() -> BLGPUSupport { return mockGPUSupport }
    func detectThermalState() -> ProcessInfo.ThermalState { return mockThermalState }
    func determinePerformanceLevel() -> BLPerformanceLevel { return mockPerformanceLevel }
}

/// Mock偏好管理器
class MockUserPreferenceManager: BLUserPreferenceManaging {
    private var storedPreferences = BLUserPreferences.defaultPreferences
    var migrationCalled = false
    var resetCalled = false

    func loadPreferences() -> BLUserPreferences {
        return storedPreferences
    }

    func savePreferences(_ preferences: BLUserPreferences) {
        storedPreferences = preferences
    }

    func resetToDefaults() -> BLUserPreferences {
        resetCalled = true
        storedPreferences = BLUserPreferences.defaultPreferences
        return storedPreferences
    }

    func migrateFromOldVersion() -> Bool {
        migrationCalled = true
        return true
    }

    // 测试辅助方法
    func setMockPreferences(_ preferences: BLUserPreferences) {
        storedPreferences = preferences
    }
}

// MARK: - 主测试类

class BLConfigurationManagerTests: XCTestCase {
    var configurationManager: BLConfigurationManager!
    var mockDeviceDetector: MockDeviceCapabilityDetector!
    var mockPreferenceManager: MockUserPreferenceManager!

    override func setUp() {
        super.setUp()
        mockDeviceDetector = MockDeviceCapabilityDetector()
        mockPreferenceManager = MockUserPreferenceManager()
        configurationManager = BLConfigurationManager(
            deviceDetector: mockDeviceDetector,
            preferenceManager: mockPreferenceManager
        )
    }

    override func tearDown() {
        configurationManager = nil
        mockDeviceDetector = nil
        mockPreferenceManager = nil
        super.tearDown()
    }

    // MARK: - 设备能力检测测试

    func testDeviceCapabilityDetection() {
        // 测试设备能力检测
        let capabilities = configurationManager.detectDeviceCapabilities()

        XCTAssertEqual(capabilities.tvosVersion, "tvOS 17.0")
        XCTAssertEqual(capabilities.deviceModel, "AppleTV11,1")
        XCTAssertEqual(capabilities.memoryCapacity, 3 * 1024 * 1024 * 1024)
        XCTAssertEqual(capabilities.cpuCores, 6)
        XCTAssertEqual(capabilities.gpuSupport, .full)
        XCTAssertEqual(capabilities.performanceLevel, .high)
        XCTAssertEqual(capabilities.recommendedQualityLevel, .high)
        XCTAssertTrue(capabilities.supportsAdvancedFeatures)
    }

    func testDeviceCapabilityDetection_LowPerformance() {
        // 测试低性能设备
        mockDeviceDetector.mockMemoryCapacity = 1024 * 1024 * 1024 // 1GB
        mockDeviceDetector.mockCPUCores = 2
        mockDeviceDetector.mockGPUSupport = .basic
        mockDeviceDetector.mockPerformanceLevel = .low

        let capabilities = configurationManager.detectDeviceCapabilities()

        XCTAssertEqual(capabilities.performanceLevel, .low)
        XCTAssertEqual(capabilities.recommendedQualityLevel, .low)
        XCTAssertFalse(capabilities.supportsAdvancedFeatures)
    }

    func testDeviceCapabilityDetection_ThermalThrottling() {
        // 测试热节流状态
        mockDeviceDetector.mockThermalState = .critical

        let capabilities = configurationManager.detectDeviceCapabilities()

        XCTAssertEqual(capabilities.thermalState, .critical)
    }

    // MARK: - 用户偏好测试

    func testUserPreferencesLoading() {
        // 测试偏好加载
        let preferences = configurationManager.loadUserPreferences()

        XCTAssertEqual(preferences.auroraEnabled, true)
        XCTAssertEqual(preferences.qualityLevel, .medium)
        XCTAssertEqual(preferences.animationSpeed, 1.0)
        XCTAssertEqual(preferences.parallaxIntensity, 0.6)
    }

    func testUserPreferencesSaving() {
        // 测试偏好保存
        var customPreferences = BLUserPreferences.defaultPreferences
        customPreferences.auroraEnabled = false
        customPreferences.qualityLevel = .ultra
        customPreferences.animationSpeed = 2.0

        configurationManager.saveUserPreferences(customPreferences)

        let loadedPreferences = configurationManager.loadUserPreferences()
        XCTAssertEqual(loadedPreferences.auroraEnabled, false)
        XCTAssertEqual(loadedPreferences.qualityLevel, .ultra)
        XCTAssertEqual(loadedPreferences.animationSpeed, 2.0)
    }

    func testUserPreferencesValidation() {
        // 测试偏好验证
        var invalidPreferences = BLUserPreferences.defaultPreferences
        invalidPreferences.animationSpeed = 5.0 // 超出范围
        invalidPreferences.parallaxIntensity = 1.5 // 超出范围

        configurationManager.saveUserPreferences(invalidPreferences)

        let validatedPreferences = configurationManager.loadUserPreferences()
        XCTAssertEqual(validatedPreferences.animationSpeed, 3.0) // 被限制到最大值
        XCTAssertEqual(validatedPreferences.parallaxIntensity, 1.0) // 被限制到最大值
    }

    // MARK: - A/B测试配置测试

    func testABTestConfiguration() {
        // 测试A/B测试配置
        let abConfig = BLABTestConfiguration(
            feature: "test_feature",
            variant: "B",
            enabled: true,
            parameters: ["param1": "value1"],
            expirationDate: Date().addingTimeInterval(86400) // 1天后过期
        )

        configurationManager.setABTestConfiguration(abConfig)

        let retrievedConfig = configurationManager.getABTestConfiguration(for: "test_feature")
        XCTAssertNotNil(retrievedConfig)
        XCTAssertEqual(retrievedConfig?.variant, "B")
        XCTAssertEqual(retrievedConfig?.enabled, true)
        XCTAssertFalse(retrievedConfig?.isExpired ?? true)
    }

    func testABTestConfiguration_Expired() {
        // 测试过期的A/B测试配置
        let expiredConfig = BLABTestConfiguration(
            feature: "expired_feature",
            variant: "A",
            enabled: true,
            expirationDate: Date().addingTimeInterval(-86400) // 1天前过期
        )

        configurationManager.setABTestConfiguration(expiredConfig)

        let retrievedConfig = configurationManager.getABTestConfiguration(for: "expired_feature")
        XCTAssertNotNil(retrievedConfig)
        XCTAssertTrue(retrievedConfig?.isExpired ?? false)
    }

    func testRemoveABTestConfiguration() {
        // 测试移除A/B测试配置
        let abConfig = BLABTestConfiguration(feature: "remove_test", variant: "A", enabled: true)
        configurationManager.setABTestConfiguration(abConfig)

        XCTAssertNotNil(configurationManager.getABTestConfiguration(for: "remove_test"))

        configurationManager.removeABTestConfiguration(for: "remove_test")

        XCTAssertNil(configurationManager.getABTestConfiguration(for: "remove_test"))
    }

    // MARK: - 全局配置测试

    func testGlobalConfigurationGeneration() {
        // 测试全局配置生成
        let expectation = self.expectation(description: "Configuration updated")

        configurationManager.configurationDidChange = { configuration in
            XCTAssertNotNil(configuration.deviceCapabilities)
            XCTAssertNotNil(configuration.userPreferences)
            XCTAssertEqual(configuration.configurationVersion, "1.0.0")
            expectation.fulfill()
        }

        configurationManager.updateConfiguration()

        waitForExpectations(timeout: 2.0, handler: nil)
    }

    func testEffectiveQualityLevel() {
        // 测试有效质量等级计算
        mockPreferenceManager.setMockPreferences({
            var prefs = BLUserPreferences.defaultPreferences
            prefs.qualityLevel = .ultra // 用户选择超高质量
            return prefs
        }())

        mockDeviceDetector.mockPerformanceLevel = .medium // 设备只支持中等性能

        configurationManager.updateConfiguration()

        let effectiveLevel = configurationManager.getCurrentQualityLevel()
        XCTAssertEqual(effectiveLevel, .medium) // 应该取设备和用户偏好的最小值
    }

    func testFeatureEnabledCheck() {
        // 测试功能启用检查
        XCTAssertTrue(configurationManager.isFeatureEnabled("aurora_premium"))
        XCTAssertTrue(configurationManager.isFeatureEnabled("lighting_effects"))
        XCTAssertTrue(configurationManager.isFeatureEnabled("interaction_feedback"))

        // 通过用户偏好禁用功能
        var customPreferences = BLUserPreferences.defaultPreferences
        customPreferences.auroraEnabled = false
        customPreferences.lightingEffectsEnabled = false

        configurationManager.saveUserPreferences(customPreferences)

        XCTAssertFalse(configurationManager.isFeatureEnabled("aurora_premium"))
        XCTAssertFalse(configurationManager.isFeatureEnabled("lighting_effects"))
    }

    // MARK: - 便捷方法测试

    func testAnimationSpeedMultiplier() {
        // 测试动画速度倍数计算
        var preferences = BLUserPreferences.defaultPreferences
        preferences.animationSpeed = 2.0
        mockPreferenceManager.setMockPreferences(preferences)
        configurationManager.updateConfiguration()

        XCTAssertEqual(configurationManager.getAnimationSpeedMultiplier(), 2.0)

        // 测试减少动画模式
        preferences.reducedMotion = true
        mockPreferenceManager.setMockPreferences(preferences)
        configurationManager.updateConfiguration()

        XCTAssertEqual(configurationManager.getAnimationSpeedMultiplier(), 0.5)

        // 测试电池优化模式
        preferences.reducedMotion = false
        preferences.batteryOptimization = true
        preferences.animationSpeed = 2.0 // 会被限制到1.0
        mockPreferenceManager.setMockPreferences(preferences)
        configurationManager.updateConfiguration()

        XCTAssertEqual(configurationManager.getAnimationSpeedMultiplier(), 1.0)
    }

    func testParallaxIntensity() {
        // 测试视差强度计算
        var preferences = BLUserPreferences.defaultPreferences
        preferences.parallaxIntensity = 0.8
        mockPreferenceManager.setMockPreferences(preferences)
        configurationManager.updateConfiguration()

        XCTAssertEqual(configurationManager.getParallaxIntensity(), 0.8)

        // 测试减少动画模式下的视差
        preferences.reducedMotion = true
        mockPreferenceManager.setMockPreferences(preferences)
        configurationManager.updateConfiguration()

        XCTAssertEqual(configurationManager.getParallaxIntensity(), 0.0)
    }

    // MARK: - 配置监听测试

    func testConfigurationObserver() {
        // 测试配置变更监听
        let expectation = self.expectation(description: "Observer called")

        configurationManager.addConfigurationObserver { configuration in
            XCTAssertEqual(configuration.configurationVersion, "1.0.0")
            expectation.fulfill()
        }

        configurationManager.updateConfiguration()

        waitForExpectations(timeout: 2.0, handler: nil)
    }

    func testFeatureObserver() {
        // 测试功能状态监听
        let expectation = self.expectation(description: "Feature observer called")

        configurationManager.observeFeature("aurora_premium") { isEnabled in
            XCTAssertTrue(isEnabled)
            expectation.fulfill()
        }

        configurationManager.updateConfiguration()

        waitForExpectations(timeout: 2.0, handler: nil)
    }

    func testQualityLevelObserver() {
        // 测试质量等级监听
        let expectation = self.expectation(description: "Quality level observer called")

        configurationManager.observeQualityLevel { level in
            XCTAssertEqual(level, .high) // 基于mock的高性能设备
            expectation.fulfill()
        }

        configurationManager.updateConfiguration()

        waitForExpectations(timeout: 2.0, handler: nil)
    }

    // MARK: - 重置和迁移测试

    func testResetToDefaults() {
        // 测试重置到默认配置
        // 先设置自定义配置
        var customPreferences = BLUserPreferences.defaultPreferences
        customPreferences.auroraEnabled = false
        customPreferences.qualityLevel = .ultra
        configurationManager.saveUserPreferences(customPreferences)

        let customABConfig = BLABTestConfiguration(feature: "custom_feature", variant: "test", enabled: false)
        configurationManager.setABTestConfiguration(customABConfig)

        // 重置
        configurationManager.resetToDefaults()

        // 验证重置
        XCTAssertTrue(mockPreferenceManager.resetCalled)

        let resetPreferences = configurationManager.loadUserPreferences()
        XCTAssertEqual(resetPreferences.auroraEnabled, true)
        XCTAssertEqual(resetPreferences.qualityLevel, .medium)

        XCTAssertNil(configurationManager.getABTestConfiguration(for: "custom_feature"))
    }

    // MARK: - 诊断和验证测试

    func testDiagnosticReport() {
        // 测试诊断报告生成
        configurationManager.updateConfiguration()

        let report = configurationManager.generateDiagnosticReport()

        XCTAssertTrue(report.contains("=== BL Aurora Premium 配置诊断报告 ==="))
        XCTAssertTrue(report.contains("tvOS 17.0"))
        XCTAssertTrue(report.contains("AppleTV11,1"))
        XCTAssertTrue(report.contains("高性能"))
        XCTAssertTrue(report.contains("完整GPU加速"))
    }

    func testConfigurationValidation() {
        // 测试配置验证
        // 设置有问题的配置
        var problematicPreferences = BLUserPreferences.defaultPreferences
        problematicPreferences.qualityLevel = .ultra // 超出设备推荐
        problematicPreferences.animationSpeed = 5.0 // 超出范围
        problematicPreferences.parallaxIntensity = 1.5 // 超出范围

        mockDeviceDetector.mockPerformanceLevel = .medium // 设备推荐medium
        mockPreferenceManager.setMockPreferences(problematicPreferences)
        configurationManager.updateConfiguration()

        let issues = configurationManager.validateConfiguration()

        XCTAssertTrue(issues.contains("用户选择的质量等级超出设备推荐等级"))
        XCTAssertTrue(issues.contains("动画速度超出有效范围 (0.1-3.0)"))
        XCTAssertTrue(issues.contains("视差强度超出有效范围 (0.0-1.0)"))
    }

    func testValidConfiguration() {
        // 测试正常配置验证
        configurationManager.updateConfiguration()

        let issues = configurationManager.validateConfiguration()

        XCTAssertTrue(issues.isEmpty, "正常配置不应该有问题: \(issues)")
    }

    // MARK: - 性能测试

    func testConfigurationUpdatePerformance() {
        // 测试配置更新性能
        measure {
            for _ in 0..<100 {
                configurationManager.updateConfiguration()
            }
        }
    }

    func testDeviceDetectionPerformance() {
        // 测试设备检测性能
        measure {
            for _ in 0..<1000 {
                _ = configurationManager.detectDeviceCapabilities()
            }
        }
    }

    func testPreferencesLoadSavePerformance() {
        // 测试偏好加载保存性能
        let preferences = BLUserPreferences.defaultPreferences

        measure {
            for _ in 0..<500 {
                configurationManager.saveUserPreferences(preferences)
                _ = configurationManager.loadUserPreferences()
            }
        }
    }

    // MARK: - 边界情况测试

    func testNilConfiguration() {
        // 测试配置为nil的情况
        let newManager = BLConfigurationManager(
            deviceDetector: mockDeviceDetector,
            preferenceManager: mockPreferenceManager
        )

        // 在配置更新前调用方法
        XCTAssertEqual(newManager.getCurrentQualityLevel(), .medium) // 默认值
        XCTAssertTrue(newManager.isFeatureEnabled("unknown_feature")) // 默认启用
        XCTAssertEqual(newManager.getAnimationSpeedMultiplier(), 1.0) // 默认速度
        XCTAssertEqual(newManager.getParallaxIntensity(), 0.6) // 默认强度
    }

    func testConcurrentAccess() {
        // 测试并发访问安全性
        let expectation = self.expectation(description: "Concurrent operations completed")
        expectation.expectedFulfillmentCount = 10

        for i in 0..<10 {
            DispatchQueue.global().async {
                var preferences = BLUserPreferences.defaultPreferences
                preferences.qualityLevel = BLQualityLevel(rawValue: (i % 4) + 1) ?? .medium

                self.configurationManager.saveUserPreferences(preferences)
                _ = self.configurationManager.loadUserPreferences()
                _ = self.configurationManager.getCurrentQualityLevel()

                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 5.0, handler: nil)
    }

    // MARK: - 集成测试

    func testCompleteWorkflow() {
        // 测试完整工作流程
        let configUpdateExpectation = expectation(description: "Configuration updated")

        // 1. 设置监听器
        configurationManager.configurationDidChange = { configuration in
            XCTAssertEqual(configuration.deviceCapabilities.deviceModel, "AppleTV11,1")
            XCTAssertEqual(configuration.userPreferences.qualityLevel, .ultra)
            XCTAssertEqual(configuration.effectiveQualityLevel, .high) // 受设备能力限制
            configUpdateExpectation.fulfill()
        }

        // 2. 修改用户偏好
        var preferences = BLUserPreferences.defaultPreferences
        preferences.qualityLevel = .ultra
        preferences.animationSpeed = 1.5
        preferences.parallaxIntensity = 0.8

        // 3. 添加A/B测试配置
        let abConfig = BLABTestConfiguration(
            feature: "new_feature",
            variant: "experimental",
            enabled: true
        )
        configurationManager.setABTestConfiguration(abConfig)

        // 4. 保存偏好（会触发配置更新）
        configurationManager.saveUserPreferences(preferences)

        // 5. 验证结果
        waitForExpectations(timeout: 3.0) { _ in
            XCTAssertEqual(self.configurationManager.getCurrentQualityLevel(), .high)
            XCTAssertEqual(self.configurationManager.getAnimationSpeedMultiplier(), 1.5)
            XCTAssertEqual(self.configurationManager.getParallaxIntensity(), 0.8)
            XCTAssertNotNil(self.configurationManager.getABTestConfiguration(for: "new_feature"))
        }
    }
}
