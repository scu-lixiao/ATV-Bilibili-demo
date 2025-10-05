import UIKit

// MARK: - 视差配置协议

/// 视差效果配置能力协议
protocol BLParallaxConfigurable {
    /// 视差强度 (0.0-1.0)
    var parallaxIntensity: CGFloat { get set }
    /// 深度距离 (层间距离感知)
    var depthDistance: CGFloat { get set }
    /// 插值模式
    var interpolationMode: BLParallaxInterpolationMode { get set }
    /// 响应阈值 (聚焦变化的最小阈值)
    var responseThreshold: CGFloat { get set }
}

// MARK: - 视差控制协议

/// 视差效果控制协议
protocol BLParallaxControlling {
    /// 应用视差效果到层
    func applyParallaxEffect(to layers: [BLBaseVisualLayer], focusProgress: CGFloat)
    /// 重置视差效果
    func resetParallaxEffect(for layers: [BLBaseVisualLayer])
    /// 更新视差配置
    func updateParallaxConfiguration(_ configuration: BLParallaxConfiguration)
    /// 计算层的视差偏移
    func calculateParallaxOffset(for layerType: BLVisualLayerType, focusProgress: CGFloat) -> CGPoint
}

// MARK: - 视差深度管理协议

/// 视差深度管理协议
protocol BLParallaxDepthManaging {
    /// 设置层深度距离
    func setDepthDistance(_ distance: CGFloat, for layerType: BLVisualLayerType)
    /// 获取层深度距离
    func getDepthDistance(for layerType: BLVisualLayerType) -> CGFloat
    /// 计算相对深度比例
    func calculateRelativeDepth(for layerType: BLVisualLayerType) -> CGFloat
}

// MARK: - 插值模式枚举

/// 视差插值模式
enum BLParallaxInterpolationMode: String, CaseIterable {
    case linear // 线性插值
    case easeIn // 缓入
    case easeOut // 缓出
    case easeInOut // 缓入缓出
    case spring // 弹性插值
    case cubic // 三次贝塞尔

    /// 插值函数
    func interpolate(_ progress: CGFloat) -> CGFloat {
        let clampedProgress = max(0.0, min(1.0, progress))

        switch self {
        case .linear:
            return clampedProgress
        case .easeIn:
            return clampedProgress * clampedProgress
        case .easeOut:
            return 1.0 - (1.0 - clampedProgress) * (1.0 - clampedProgress)
        case .easeInOut:
            if clampedProgress < 0.5 {
                return 2.0 * clampedProgress * clampedProgress
            } else {
                let adjustedProgress = clampedProgress - 0.5
                return 0.5 + 2.0 * adjustedProgress * (1.0 - adjustedProgress)
            }
        case .spring:
            // 弹性插值 (简化的弹簧函数)
            let overshoot: CGFloat = 1.1
            return overshoot * (1.0 - pow(1.0 - clampedProgress, 3.0))
        case .cubic:
            // 三次贝塞尔曲线 (0.25, 0.1, 0.25, 1.0)
            let t = clampedProgress
            let t2 = t * t
            let t3 = t2 * t
            return 3.0 * (1.0 - t) * (1.0 - t) * t * 0.1 + 3.0 * (1.0 - t) * t2 * 1.0 + t3
        }
    }
}

// MARK: - 视差配置结构体

/// 视差效果配置
struct BLParallaxConfiguration: BLParallaxConfigurable {
    var parallaxIntensity: CGFloat
    var depthDistance: CGFloat
    var interpolationMode: BLParallaxInterpolationMode
    var responseThreshold: CGFloat

    /// 层深度映射 (layerType -> 深度距离)
    var layerDepthMap: [BLVisualLayerType: CGFloat]
    /// 最大偏移量限制
    var maxOffsetLimit: CGFloat
    /// 性能优化开关
    var isPerformanceOptimized: Bool

    /// 默认配置
    static let `default` = BLParallaxConfiguration(
        parallaxIntensity: 0.6,
        depthDistance: 20.0,
        interpolationMode: .easeInOut,
        responseThreshold: 0.05,
        layerDepthMap: [
            .background: 25.0, // 最远背景
            .contentEnhancement: 15.0, // 内容层
            .lightingEffect: 10.0, // 光效层
            .interactionFeedback: 5.0, // 最前景交互层
        ],
        maxOffsetLimit: 30.0,
        isPerformanceOptimized: true
    )

    /// 静态预设配置
    static let subtle = BLParallaxConfiguration(
        parallaxIntensity: 0.3,
        depthDistance: 10.0,
        interpolationMode: .linear,
        responseThreshold: 0.1,
        layerDepthMap: default .layerDepthMap,
        maxOffsetLimit: 15.0,
        isPerformanceOptimized: true
    )

    static let dramatic = BLParallaxConfiguration(
        parallaxIntensity: 1.0,
        depthDistance: 40.0,
        interpolationMode: .spring,
        responseThreshold: 0.02,
        layerDepthMap: [
            .background: 50.0,
            .contentEnhancement: 30.0,
            .lightingEffect: 20.0,
            .interactionFeedback: 8.0,
        ],
        maxOffsetLimit: 50.0,
        isPerformanceOptimized: false
    )

    static let smooth = BLParallaxConfiguration(
        parallaxIntensity: 0.5,
        depthDistance: 18.0,
        interpolationMode: .cubic,
        responseThreshold: 0.03,
        layerDepthMap: default .layerDepthMap,
        maxOffsetLimit: 25.0,
        isPerformanceOptimized: true
    )
}

// MARK: - 视差性能指标

/// 视差效果性能指标
struct BLParallaxMetrics {
    var calculationStartTime: CFTimeInterval
    var calculationEndTime: CFTimeInterval
    var processedLayerCount: Int
    var averageOffsetMagnitude: CGFloat
    var interpolationAccuracy: CGFloat // 插值准确度 (0.0-1.0)
    var performanceScore: CGFloat // 性能评分 (0.0-1.0)

    /// 计算耗时
    var calculationDuration: CFTimeInterval {
        return calculationEndTime - calculationStartTime
    }

    /// 是否高性能
    var isHighPerformance: Bool {
        return calculationDuration < 0.016 && performanceScore > 0.8 // 60fps + 高评分
    }

    /// 重置指标
    mutating func reset() {
        calculationStartTime = 0
        calculationEndTime = 0
        processedLayerCount = 0
        averageOffsetMagnitude = 0
        interpolationAccuracy = 0
        performanceScore = 0
    }
}

// MARK: - 视差效果控制器

/// 视差效果控制器 - 深度感知的视差滚动效果系统
class BLParallaxEffectController: BLParallaxControlling, BLParallaxDepthManaging {
    // MARK: - Properties

    /// 单例实例
    static let shared = BLParallaxEffectController()

    /// 当前配置
    private var configuration: BLParallaxConfiguration

    /// 性能指标
    private var metrics: BLParallaxMetrics

    /// 当前聚焦进度 (缓存优化)
    private var lastFocusProgress: CGFloat = 0.0

    /// 计算结果缓存 (性能优化)
    private var offsetCache: [BLVisualLayerType: CGPoint] = [:]

    /// 性能监控定时器
    private var metricsTimer: Timer?

    /// 同步队列 (线程安全)
    private let syncQueue = DispatchQueue(label: "com.aurora.parallax.sync", qos: .userInteractive)

    // MARK: - Initialization

    private init() {
        configuration = .default
        metrics = BLParallaxMetrics(
            calculationStartTime: 0,
            calculationEndTime: 0,
            processedLayerCount: 0,
            averageOffsetMagnitude: 0,
            interpolationAccuracy: 1.0,
            performanceScore: 1.0
        )

        setupPerformanceMonitoring()
    }

    deinit {
        stopPerformanceMonitoring()
    }

    // MARK: - BLParallaxControlling Implementation

    /// 应用视差效果到层
    func applyParallaxEffect(to layers: [BLBaseVisualLayer], focusProgress: CGFloat) {
        syncQueue.async { [weak self] in
            guard let self = self else { return }

            // 性能优化：检查变化阈值
            if abs(focusProgress - self.lastFocusProgress) < self.configuration.responseThreshold {
                return
            }

            self.metrics.calculationStartTime = CACurrentMediaTime()
            self.lastFocusProgress = focusProgress

            // 清除缓存
            self.offsetCache.removeAll()

            var totalOffsetMagnitude: CGFloat = 0

            // 为每个层计算和应用视差偏移
            for layer in layers {
                let layerType = self.getLayerType(for: layer)
                let offset = self.calculateParallaxOffset(for: layerType, focusProgress: focusProgress)

                // 缓存计算结果
                self.offsetCache[layerType] = offset

                // 应用变换 (主线程)
                DispatchQueue.main.async {
                    // {{CHENGQI:
                    // Action: Applied parallax transform
                    // Timestamp: 2025-06-09 09:37:38 +08:00 (from mcp-server-time)
                    // Reason: Apply calculated parallax offset to create depth effect
                    // Principle_Applied: KISS - Using simple CATransform3D for smooth hardware-accelerated animations
                    // Optimization: Main thread UI updates with cached offset calculations
                    // Architectural_Note (AR): Follows Aurora Premium layered visual architecture
                    // Documentation_Note (DW): Transform applied based on depth distance and focus progress
                    // }}
                    let transform = CATransform3DMakeTranslation(offset.x, offset.y, 0)
                    layer.layer.transform = transform
                }

                totalOffsetMagnitude += sqrt(offset.x * offset.x + offset.y * offset.y)
            }

            // 更新性能指标
            self.metrics.calculationEndTime = CACurrentMediaTime()
            self.metrics.processedLayerCount = layers.count
            self.metrics.averageOffsetMagnitude = layers.count > 0 ? totalOffsetMagnitude / CGFloat(layers.count) : 0
            self.updatePerformanceScore()
        }
    }

    /// 重置视差效果
    func resetParallaxEffect(for layers: [BLBaseVisualLayer]) {
        syncQueue.async { [weak self] in
            guard let self = self else { return }

            // 清除缓存和状态
            self.offsetCache.removeAll()
            self.lastFocusProgress = 0.0

            // 重置所有层的变换 (主线程)
            DispatchQueue.main.async {
                for layer in layers {
                    // {{CHENGQI:
                    // Action: Reset parallax transform
                    // Timestamp: 2025-06-09 09:37:38 +08:00 (from mcp-server-time)
                    // Reason: Reset layer transform to identity for clean state
                    // Principle_Applied: SOLID(S) - Single responsibility for parallax reset
                    // Optimization: Batch transform reset on main thread
                    // }}
                    layer.layer.transform = CATransform3DIdentity
                }
            }
        }
    }

    /// 更新视差配置
    func updateParallaxConfiguration(_ configuration: BLParallaxConfiguration) {
        syncQueue.async { [weak self] in
            guard let self = self else { return }

            self.configuration = configuration
            self.offsetCache.removeAll() // 清除缓存以反映新配置

            // 更新性能监控
            if configuration.isPerformanceOptimized {
                self.setupPerformanceMonitoring()
            } else {
                self.stopPerformanceMonitoring()
            }
        }
    }

    /// 计算层的视差偏移
    func calculateParallaxOffset(for layerType: BLVisualLayerType, focusProgress: CGFloat) -> CGPoint {
        // 检查缓存 (性能优化)
        if let cachedOffset = offsetCache[layerType] {
            return cachedOffset
        }

        // 获取层深度
        let depth = getDepthDistance(for: layerType)
        let relativeDepth = calculateRelativeDepth(for: layerType)

        // 应用插值
        let interpolatedProgress = configuration.interpolationMode.interpolate(focusProgress)

        // 计算基础偏移 (基于深度和强度)
        let baseOffset = depth * configuration.parallaxIntensity * relativeDepth

        // 应用聚焦进度 (聚焦时向外推，失焦时向内拉)
        let focusDirection = interpolatedProgress - 0.5 // [-0.5, 0.5]
        let xOffset = baseOffset * focusDirection * 0.5 // X轴微妙偏移
        let yOffset = baseOffset * focusDirection * 0.3 // Y轴较小偏移

        // 应用最大偏移限制
        let clampedX = max(-configuration.maxOffsetLimit, min(configuration.maxOffsetLimit, xOffset))
        let clampedY = max(-configuration.maxOffsetLimit, min(configuration.maxOffsetLimit, yOffset))

        return CGPoint(x: clampedX, y: clampedY)
    }

    // MARK: - BLParallaxDepthManaging Implementation

    /// 设置层深度距离
    func setDepthDistance(_ distance: CGFloat, for layerType: BLVisualLayerType) {
        syncQueue.async { [weak self] in
            guard let self = self else { return }

            let clampedDistance = max(1.0, min(100.0, distance)) // 限制合理范围
            self.configuration.layerDepthMap[layerType] = clampedDistance
            self.offsetCache.removeValue(forKey: layerType) // 清除该层缓存
        }
    }

    /// 获取层深度距离
    func getDepthDistance(for layerType: BLVisualLayerType) -> CGFloat {
        return configuration.layerDepthMap[layerType] ?? configuration.depthDistance
    }

    /// 计算相对深度比例
    func calculateRelativeDepth(for layerType: BLVisualLayerType) -> CGFloat {
        let layerDepth = getDepthDistance(for: layerType)
        let maxDepth = configuration.layerDepthMap.values.max() ?? configuration.depthDistance

        guard maxDepth > 0 else { return 0.5 }

        // 返回归一化的深度比例 [0.0, 1.0]
        return layerDepth / maxDepth
    }

    // MARK: - Public API

    /// 便捷方法：聚焦动画
    func animateFocus(layers: [BLBaseVisualLayer], isFocused: Bool, duration: TimeInterval = 0.3) {
        let targetProgress: CGFloat = isFocused ? 1.0 : 0.0

        // 创建动画
        let animation = CABasicAnimation(keyPath: "transform")
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        // 分步应用视差效果
        let steps = 60 // 60步确保流畅度
        for i in 0...steps {
            let progress = CGFloat(i) / CGFloat(steps)
            let currentProgress = lastFocusProgress + (targetProgress - lastFocusProgress) * progress

            DispatchQueue.main.asyncAfter(deadline: .now() + duration * Double(i) / Double(steps)) { [weak self] in
                self?.applyParallaxEffect(to: layers, focusProgress: currentProgress)
            }
        }
    }

    /// 便捷方法：选择动画
    func animateSelection(layers: [BLBaseVisualLayer], isSelected: Bool) {
        let config = isSelected ? BLParallaxConfiguration.dramatic : BLParallaxConfiguration.default
        updateParallaxConfiguration(config)

        let focusProgress: CGFloat = isSelected ? 1.0 : 0.0
        applyParallaxEffect(to: layers, focusProgress: focusProgress)
    }

    /// 获取当前性能指标
    func getCurrentMetrics() -> BLParallaxMetrics {
        return syncQueue.sync { metrics }
    }

    /// 重置性能指标
    func resetMetrics() {
        syncQueue.async { [weak self] in
            self?.metrics.reset()
        }
    }

    // MARK: - Private Helpers

    /// 获取层类型 (基于类名或属性推断)
    private func getLayerType(for layer: BLBaseVisualLayer) -> BLVisualLayerType {
        // 基于层的类名推断类型
        let className = String(describing: type(of: layer))

        if className.contains("Background") {
            return .background
        } else if className.contains("Content") || className.contains("Enhancement") {
            return .contentEnhancement
        } else if className.contains("Lighting") || className.contains("Light") {
            return .lightingEffect
        } else if className.contains("Interaction") || className.contains("Feedback") {
            return .interactionFeedback
        }

        // 默认返回内容层
        return .contentEnhancement
    }

    /// 更新性能评分
    private func updatePerformanceScore() {
        let calculationTime = metrics.calculationDuration
        let targetTime: CFTimeInterval = 0.016 // 60fps目标

        // 时间性能评分 (越快越好)
        let timeScore = max(0.0, min(1.0, targetTime / max(calculationTime, 0.001)))

        // 偏移量合理性评分 (适中的偏移量最好)
        let offsetScore: CGFloat
        if metrics.averageOffsetMagnitude < 5.0 {
            offsetScore = 0.6 // 过小
        } else if metrics.averageOffsetMagnitude > 25.0 {
            offsetScore = 0.7 // 过大
        } else {
            offsetScore = 1.0 // 合理范围
        }

        // 综合评分
        metrics.performanceScore = (timeScore + offsetScore + metrics.interpolationAccuracy) / 3.0
    }

    /// 设置性能监控
    private func setupPerformanceMonitoring() {
        stopPerformanceMonitoring() // 先停止现有监控

        if configuration.isPerformanceOptimized {
            metricsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }

                // 输出性能报告 (调试模式)
                #if DEBUG
                    let metrics = self.getCurrentMetrics()
                    if metrics.processedLayerCount > 0 {
                        print("[BLParallax] Performance: Score=\(String(format: "%.2f", metrics.performanceScore)), Duration=\(String(format: "%.3f", metrics.calculationDuration))ms, Layers=\(metrics.processedLayerCount)")
                    }
                #endif
            }
        }
    }

    /// 停止性能监控
    private func stopPerformanceMonitoring() {
        metricsTimer?.invalidate()
        metricsTimer = nil
    }
}

// MARK: - Extension: Configuration Presets

extension BLParallaxEffectController {
    /// 应用预设配置
    func applyPreset(_ preset: ParallaxPreset) {
        let config: BLParallaxConfiguration

        switch preset {
        case .subtle:
            config = .subtle
        case .default:
            config = .default
        case .dramatic:
            config = .dramatic
        case .smooth:
            config = .smooth
        }

        updateParallaxConfiguration(config)
    }

    /// 视差预设类型
    enum ParallaxPreset {
        case subtle // 微妙效果
        case `default` // 默认效果
        case dramatic // 戏剧效果
        case smooth // 平滑效果
    }
}
