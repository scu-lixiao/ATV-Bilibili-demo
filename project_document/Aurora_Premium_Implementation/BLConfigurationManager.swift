import Foundation
import UIKit

// MARK: - 配置管理协议

/// 配置管理核心协议
protocol BLConfigurationManaging {
    /// 检测设备能力
    func detectDeviceCapabilities() -> BLDeviceCapabilities

    /// 加载用户偏好
    func loadUserPreferences() -> BLUserPreferences

    /// 保存用户偏好
    func saveUserPreferences(_ preferences: BLUserPreferences)

    /// 获取A/B测试配置
    func getABTestConfiguration(for feature: String) -> BLABTestConfiguration?

    /// 更新配置
    func updateConfiguration()

    /// 配置变更通知
    var configurationDidChange: ((BLGlobalConfiguration) -> Void)? { get set }
}

/// 设备能力检测协议
protocol BLDeviceCapabilityDetecting {
    func detectTVOSVersion() -> String
    func detectDeviceModel() -> String
    func detectMemoryCapacity() -> Int64
    func detectCPUCores() -> Int
    func detectGPUSupport() -> BLGPUSupport
    func detectThermalState() -> ProcessInfo.ThermalState
    func determinePerformanceLevel() -> BLPerformanceLevel
}

/// 偏好管理协议
protocol BLUserPreferenceManaging {
    func loadPreferences() -> BLUserPreferences
    func savePreferences(_ preferences: BLUserPreferences)
    func resetToDefaults() -> BLUserPreferences
    func migrateFromOldVersion() -> Bool
}

// MARK: - 数据结构

/// 设备能力信息
struct BLDeviceCapabilities: Codable {
    let tvosVersion: String
    let deviceModel: String
    let memoryCapacity: Int64 // bytes
    let cpuCores: Int
    let gpuSupport: BLGPUSupport
    let thermalState: ProcessInfo.ThermalState
    let performanceLevel: BLPerformanceLevel
    let detectionTime: Date

    /// 获取推荐质量等级
    var recommendedQualityLevel: BLQualityLevel {
        switch performanceLevel {
        case .low:
            return .low
        case .medium:
            return .medium
        case .high:
            return .high
        case .ultra:
            return .ultra
        }
    }

    /// 检查是否支持高级特性
    var supportsAdvancedFeatures: Bool {
        return performanceLevel.rawValue >= BLPerformanceLevel.high.rawValue &&
            gpuSupport == .full &&
            memoryCapacity >= 2 * 1024 * 1024 * 1024 // 2GB+
    }
}

/// GPU支持级别
enum BLGPUSupport: String, Codable, CaseIterable {
    case none
    case basic
    case enhanced
    case full

    var description: String {
        switch self {
        case .none: return "无GPU加速支持"
        case .basic: return "基础GPU支持"
        case .enhanced: return "增强GPU支持"
        case .full: return "完整GPU加速"
        }
    }
}

/// 性能等级
enum BLPerformanceLevel: Int, Codable, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
    case ultra = 4

    var description: String {
        switch self {
        case .low: return "低性能"
        case .medium: return "中等性能"
        case .high: return "高性能"
        case .ultra: return "超高性能"
        }
    }
}

/// 用户偏好设置
struct BLUserPreferences: Codable {
    var auroraEnabled: Bool
    var qualityLevel: BLQualityLevel
    var animationSpeed: Double // 0.1 - 3.0
    var parallaxIntensity: Double // 0.0 - 1.0
    var lightingEffectsEnabled: Bool
    var interactionFeedbackEnabled: Bool
    var reducedMotion: Bool
    var batteryOptimization: Bool
    var customColorScheme: String?
    var lastUpdated: Date

    /// 默认偏好设置
    static var defaultPreferences: BLUserPreferences {
        return BLUserPreferences(
            auroraEnabled: true,
            qualityLevel: .medium,
            animationSpeed: 1.0,
            parallaxIntensity: 0.6,
            lightingEffectsEnabled: true,
            interactionFeedbackEnabled: true,
            reducedMotion: false,
            batteryOptimization: false,
            customColorScheme: nil,
            lastUpdated: Date()
        )
    }

    /// 验证偏好设置的有效性
    mutating func validate() {
        animationSpeed = max(0.1, min(3.0, animationSpeed))
        parallaxIntensity = max(0.0, min(1.0, parallaxIntensity))
        lastUpdated = Date()
    }
}

/// A/B测试配置
struct BLABTestConfiguration: Codable {
    let feature: String
    let variant: String // "A", "B", "control"
    let enabled: Bool
    let parameters: [String: Any]
    let expirationDate: Date?

    enum CodingKeys: String, CodingKey {
        case feature, variant, enabled, expirationDate
    }

    init(feature: String, variant: String, enabled: Bool, parameters: [String: Any] = [:], expirationDate: Date? = nil) {
        self.feature = feature
        self.variant = variant
        self.enabled = enabled
        self.parameters = parameters
        self.expirationDate = expirationDate
    }

    // 自定义编解码，处理Any类型
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        feature = try container.decode(String.self, forKey: .feature)
        variant = try container.decode(String.self, forKey: .variant)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        expirationDate = try container.decodeIfPresent(Date.self, forKey: .expirationDate)
        parameters = [:] // 简化处理，实际项目中可实现更复杂的编解码
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(feature, forKey: .feature)
        try container.encode(variant, forKey: .variant)
        try container.encode(enabled, forKey: .enabled)
        try container.encodeIfPresent(expirationDate, forKey: .expirationDate)
    }

    /// 检查是否已过期
    var isExpired: Bool {
        guard let expiration = expirationDate else { return false }
        return Date() > expiration
    }
}

/// 全局配置
struct BLGlobalConfiguration {
    let deviceCapabilities: BLDeviceCapabilities
    let userPreferences: BLUserPreferences
    let abTestConfigurations: [String: BLABTestConfiguration]
    let configurationVersion: String
    let lastUpdated: Date

    /// 获取最终质量等级（设备能力和用户偏好的结合）
    var effectiveQualityLevel: BLQualityLevel {
        // 用户偏好和设备推荐的最小值
        let deviceRecommended = deviceCapabilities.recommendedQualityLevel
        let userPreferred = userPreferences.qualityLevel

        return BLQualityLevel(rawValue: min(deviceRecommended.rawValue, userPreferred.rawValue)) ?? .medium
    }

    /// 检查功能是否启用
    func isFeatureEnabled(_ feature: String) -> Bool {
        // 检查A/B测试配置
        if let abConfig = abTestConfigurations[feature], !abConfig.isExpired {
            return abConfig.enabled
        }

        // 默认启用状态
        switch feature {
        case "aurora_premium":
            return userPreferences.auroraEnabled
        case "lighting_effects":
            return userPreferences.lightingEffectsEnabled
        case "interaction_feedback":
            return userPreferences.interactionFeedbackEnabled
        default:
            return true
        }
    }
}

// MARK: - 设备能力检测器

/// 设备能力检测实现
class BLDeviceCapabilityDetector: BLDeviceCapabilityDetecting {
    func detectTVOSVersion() -> String {
        return ProcessInfo.processInfo.operatingSystemVersionString
    }

    func detectDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value))!)
        }
        return identifier.isEmpty ? "Unknown" : identifier
    }

    func detectMemoryCapacity() -> Int64 {
        return ProcessInfo.processInfo.physicalMemory
    }

    func detectCPUCores() -> Int {
        return ProcessInfo.processInfo.processorCount
    }

    func detectGPUSupport() -> BLGPUSupport {
        // 基于设备型号和系统版本判断GPU支持
        let deviceModel = detectDeviceModel()
        let osVersion = detectTVOSVersion()

        // 简化的GPU检测逻辑
        if deviceModel.contains("AppleTV11") || deviceModel.contains("AppleTV12") {
            return .full
        } else if deviceModel.contains("AppleTV6") {
            return .enhanced
        } else if deviceModel.contains("AppleTV5") {
            return .basic
        } else {
            return .none
        }
    }

    func detectThermalState() -> ProcessInfo.ThermalState {
        return ProcessInfo.processInfo.thermalState
    }

    func determinePerformanceLevel() -> BLPerformanceLevel {
        let memory = detectMemoryCapacity()
        let cpuCores = detectCPUCores()
        let gpuSupport = detectGPUSupport()
        let thermalState = detectThermalState()

        // 综合评分算法
        var score = 0

        // 内存评分
        if memory >= 4 * 1024 * 1024 * 1024 { score += 4 } // 4GB+
        else if memory >= 2 * 1024 * 1024 * 1024 { score += 3 } // 2GB+
        else if memory >= 1024 * 1024 * 1024 { score += 2 } // 1GB+
        else { score += 1 }

        // CPU评分
        if cpuCores >= 8 { score += 4 }
        else if cpuCores >= 6 { score += 3 }
        else if cpuCores >= 4 { score += 2 }
        else { score += 1 }

        // GPU评分
        score += gpuSupport.rawValue.count // 简化评分

        // 热状态惩罚
        switch thermalState {
        case .critical: score -= 2
        case .serious: score -= 1
        default: break
        }

        // 映射到性能等级
        switch score {
        case 12...: return .ultra
        case 8..<12: return .high
        case 5..<8: return .medium
        default: return .low
        }
    }
}

// MARK: - 偏好管理器

/// 用户偏好管理实现
class BLUserPreferenceManager: BLUserPreferenceManaging {
    private let userDefaults = UserDefaults.standard
    private let preferencesKey = "BLAuroraPremium.UserPreferences"
    private let migrationKey = "BLAuroraPremium.PreferencesMigration"

    func loadPreferences() -> BLUserPreferences {
        // 检查是否需要迁移
        if !userDefaults.bool(forKey: migrationKey) {
            _ = migrateFromOldVersion()
        }

        guard let data = userDefaults.data(forKey: preferencesKey),
              let preferences = try? JSONDecoder().decode(BLUserPreferences.self, from: data)
        else {
            return BLUserPreferences.defaultPreferences
        }

        var validatedPreferences = preferences
        validatedPreferences.validate()
        return validatedPreferences
    }

    func savePreferences(_ preferences: BLUserPreferences) {
        var validatedPreferences = preferences
        validatedPreferences.validate()

        guard let data = try? JSONEncoder().encode(validatedPreferences) else { return }
        userDefaults.set(data, forKey: preferencesKey)
        userDefaults.synchronize()
    }

    func resetToDefaults() -> BLUserPreferences {
        let defaultPrefs = BLUserPreferences.defaultPreferences
        savePreferences(defaultPrefs)
        return defaultPrefs
    }

    func migrateFromOldVersion() -> Bool {
        // 模拟从旧版本迁移偏好设置
        // 实际项目中这里会有复杂的迁移逻辑

        var preferences = BLUserPreferences.defaultPreferences

        // 尝试从旧的UserDefaults键读取设置
        if let oldAuroraEnabled = userDefaults.object(forKey: "OldAuroraEnabled") as? Bool {
            preferences.auroraEnabled = oldAuroraEnabled
        }

        if let oldQualityRaw = userDefaults.object(forKey: "OldQualityLevel") as? Int,
           let oldQuality = BLQualityLevel(rawValue: oldQualityRaw)
        {
            preferences.qualityLevel = oldQuality
        }

        // 保存迁移后的偏好
        savePreferences(preferences)

        // 标记迁移完成
        userDefaults.set(true, forKey: migrationKey)
        userDefaults.synchronize()

        return true
    }
}

// MARK: - 主配置管理器

/// 主配置管理器实现
class BLConfigurationManager: BLConfigurationManaging {
    // MARK: - 单例

    static let shared = BLConfigurationManager()

    // MARK: - 私有属性

    private let deviceDetector: BLDeviceCapabilityDetecting
    private let preferenceManager: BLUserPreferenceManaging
    private let syncQueue = DispatchQueue(label: "com.bl.configuration", qos: .userInteractive)

    // MARK: - 公共属性

    private(set) var currentConfiguration: BLGlobalConfiguration?
    var configurationDidChange: ((BLGlobalConfiguration) -> Void)?

    // MARK: - A/B测试配置存储

    private var abTestConfigurations: [String: BLABTestConfiguration] = [:]

    // MARK: - 初始化

    init(deviceDetector: BLDeviceCapabilityDetecting = BLDeviceCapabilityDetector(),
         preferenceManager: BLUserPreferenceManaging = BLUserPreferenceManager())
    {
        self.deviceDetector = deviceDetector
        self.preferenceManager = preferenceManager

        // 初始化A/B测试配置
        setupDefaultABTestConfigurations()

        // 初始加载配置
        updateConfiguration()
    }

    // MARK: - 配置管理协议实现

    func detectDeviceCapabilities() -> BLDeviceCapabilities {
        return BLDeviceCapabilities(
            tvosVersion: deviceDetector.detectTVOSVersion(),
            deviceModel: deviceDetector.detectDeviceModel(),
            memoryCapacity: deviceDetector.detectMemoryCapacity(),
            cpuCores: deviceDetector.detectCPUCores(),
            gpuSupport: deviceDetector.detectGPUSupport(),
            thermalState: deviceDetector.detectThermalState(),
            performanceLevel: deviceDetector.determinePerformanceLevel(),
            detectionTime: Date()
        )
    }

    func loadUserPreferences() -> BLUserPreferences {
        return preferenceManager.loadPreferences()
    }

    func saveUserPreferences(_ preferences: BLUserPreferences) {
        preferenceManager.savePreferences(preferences)

        // 异步更新配置
        syncQueue.async { [weak self] in
            self?.updateConfiguration()
        }
    }

    func getABTestConfiguration(for feature: String) -> BLABTestConfiguration? {
        return abTestConfigurations[feature]
    }

    func updateConfiguration() {
        syncQueue.async { [weak self] in
            guard let self = self else { return }

            let capabilities = self.detectDeviceCapabilities()
            let preferences = self.loadUserPreferences()

            let newConfiguration = BLGlobalConfiguration(
                deviceCapabilities: capabilities,
                userPreferences: preferences,
                abTestConfigurations: self.abTestConfigurations,
                configurationVersion: "1.0.0",
                lastUpdated: Date()
            )

            self.currentConfiguration = newConfiguration

            // 主线程通知配置变更
            DispatchQueue.main.async {
                self.configurationDidChange?(newConfiguration)
            }
        }
    }

    // MARK: - A/B测试管理

    func setABTestConfiguration(_ configuration: BLABTestConfiguration) {
        syncQueue.async { [weak self] in
            self?.abTestConfigurations[configuration.feature] = configuration
            self?.updateConfiguration()
        }
    }

    func removeABTestConfiguration(for feature: String) {
        syncQueue.async { [weak self] in
            self?.abTestConfigurations.removeValue(forKey: feature)
            self?.updateConfiguration()
        }
    }

    // MARK: - 便捷方法

    /// 获取当前有效的质量等级
    func getCurrentQualityLevel() -> BLQualityLevel {
        return currentConfiguration?.effectiveQualityLevel ?? .medium
    }

    /// 检查功能是否启用
    func isFeatureEnabled(_ feature: String) -> Bool {
        return currentConfiguration?.isFeatureEnabled(feature) ?? true
    }

    /// 获取动画速度倍数
    func getAnimationSpeedMultiplier() -> Double {
        guard let config = currentConfiguration else { return 1.0 }

        // 考虑减少动画偏好
        if config.userPreferences.reducedMotion {
            return 0.5
        }

        // 考虑电池优化
        if config.userPreferences.batteryOptimization {
            return min(1.0, config.userPreferences.animationSpeed)
        }

        return config.userPreferences.animationSpeed
    }

    /// 获取视差强度
    func getParallaxIntensity() -> Double {
        guard let config = currentConfiguration else { return 0.6 }

        // 减少动画时禁用视差
        if config.userPreferences.reducedMotion {
            return 0.0
        }

        return config.userPreferences.parallaxIntensity
    }

    /// 重置所有配置
    func resetToDefaults() {
        syncQueue.async { [weak self] in
            guard let self = self else { return }

            // 重置用户偏好
            _ = self.preferenceManager.resetToDefaults()

            // 清除A/B测试配置
            self.abTestConfigurations.removeAll()
            self.setupDefaultABTestConfigurations()

            // 更新配置
            self.updateConfiguration()
        }
    }

    // MARK: - 私有方法

    private func setupDefaultABTestConfigurations() {
        // 设置默认的A/B测试配置
        abTestConfigurations["aurora_premium"] = BLABTestConfiguration(
            feature: "aurora_premium",
            variant: "enabled",
            enabled: true,
            parameters: ["quality": "auto"],
            expirationDate: nil
        )

        abTestConfigurations["parallax_effects"] = BLABTestConfiguration(
            feature: "parallax_effects",
            variant: "enhanced",
            enabled: true,
            parameters: ["intensity": 0.6],
            expirationDate: Calendar.current.date(byAdding: .month, value: 3, to: Date())
        )
    }
}

// MARK: - 扩展：配置监听

extension BLConfigurationManager {
    /// 添加配置变更监听器
    func addConfigurationObserver(_ observer: @escaping (BLGlobalConfiguration) -> Void) {
        let previousObserver = configurationDidChange

        configurationDidChange = { configuration in
            previousObserver?(configuration)
            observer(configuration)
        }
    }

    /// 监听特定功能的启用状态变化
    func observeFeature(_ feature: String, handler: @escaping (Bool) -> Void) {
        addConfigurationObserver { configuration in
            let isEnabled = configuration.isFeatureEnabled(feature)
            handler(isEnabled)
        }
    }

    /// 监听质量等级变化
    func observeQualityLevel(_ handler: @escaping (BLQualityLevel) -> Void) {
        addConfigurationObserver { configuration in
            handler(configuration.effectiveQualityLevel)
        }
    }
}

// MARK: - 扩展：调试和诊断

extension BLConfigurationManager {
    /// 生成配置诊断报告
    func generateDiagnosticReport() -> String {
        guard let config = currentConfiguration else {
            return "配置未初始化"
        }

        var report = """
        === BL Aurora Premium 配置诊断报告 ===

        设备信息:
        - 系统版本: \(config.deviceCapabilities.tvosVersion)
        - 设备型号: \(config.deviceCapabilities.deviceModel)
        - 内存容量: \(ByteCountFormatter.string(fromByteCount: config.deviceCapabilities.memoryCapacity, countStyle: .memory))
        - CPU核心: \(config.deviceCapabilities.cpuCores)
        - GPU支持: \(config.deviceCapabilities.gpuSupport.description)
        - 性能等级: \(config.deviceCapabilities.performanceLevel.description)
        - 热状态: \(config.deviceCapabilities.thermalState)

        用户偏好:
        - Aurora启用: \(config.userPreferences.auroraEnabled)
        - 质量等级: \(config.userPreferences.qualityLevel)
        - 动画速度: \(config.userPreferences.animationSpeed)x
        - 视差强度: \(Int(config.userPreferences.parallaxIntensity * 100))%
        - 光效启用: \(config.userPreferences.lightingEffectsEnabled)
        - 交互反馈: \(config.userPreferences.interactionFeedbackEnabled)
        - 减少动画: \(config.userPreferences.reducedMotion)
        - 电池优化: \(config.userPreferences.batteryOptimization)

        最终配置:
        - 有效质量等级: \(config.effectiveQualityLevel)
        - 支持高级特性: \(config.deviceCapabilities.supportsAdvancedFeatures)
        - 配置版本: \(config.configurationVersion)
        - 最后更新: \(DateFormatter.localizedString(from: config.lastUpdated, dateStyle: .short, timeStyle: .medium))

        A/B测试配置:
        """

        for (feature, abConfig) in config.abTestConfigurations {
            report += "\n- \(feature): \(abConfig.variant) (\(abConfig.enabled ? "启用" : "禁用"))"
            if abConfig.isExpired {
                report += " [已过期]"
            }
        }

        return report
    }

    /// 验证配置一致性
    func validateConfiguration() -> [String] {
        var issues: [String] = []

        guard let config = currentConfiguration else {
            issues.append("配置未初始化")
            return issues
        }

        // 检查用户偏好和设备能力的兼容性
        if config.userPreferences.qualityLevel.rawValue > config.deviceCapabilities.recommendedQualityLevel.rawValue {
            issues.append("用户选择的质量等级超出设备推荐等级")
        }

        // 检查动画速度范围
        if config.userPreferences.animationSpeed < 0.1 || config.userPreferences.animationSpeed > 3.0 {
            issues.append("动画速度超出有效范围 (0.1-3.0)")
        }

        // 检查视差强度范围
        if config.userPreferences.parallaxIntensity < 0.0 || config.userPreferences.parallaxIntensity > 1.0 {
            issues.append("视差强度超出有效范围 (0.0-1.0)")
        }

        // 检查A/B测试配置过期
        for (feature, abConfig) in config.abTestConfigurations {
            if abConfig.isExpired {
                issues.append("A/B测试配置 '\(feature)' 已过期")
            }
        }

        return issues
    }
}
