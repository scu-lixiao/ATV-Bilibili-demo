import QuartzCore
import UIKit

// MARK: - Spring Animation Configuration

/// 弹性动画配置结构体
/// 封装所有弹性动画相关的物理参数和时序控制
public struct BLSpringAnimationConfiguration {
    /// 动画时长 (秒)
    public let duration: TimeInterval
    /// 阻尼系数 (0.0-1.0, 越小越有弹性)
    public let damping: CGFloat
    /// 刚度系数 (0.0-1000.0, 越大越快速)
    public let stiffness: CGFloat
    /// 初始速度 (0.0-10.0)
    public let initialVelocity: CGFloat
    /// 动画延迟 (秒)
    public let delay: TimeInterval
    /// 自定义时序函数
    public let timingFunction: CAMediaTimingFunction?
    /// 动画完成回调
    public let completion: ((Bool) -> Void)?

    public init(
        duration: TimeInterval = 0.6,
        damping: CGFloat = 0.8,
        stiffness: CGFloat = 300.0,
        initialVelocity: CGFloat = 0.0,
        delay: TimeInterval = 0.0,
        timingFunction: CAMediaTimingFunction? = nil,
        completion: ((Bool) -> Void)? = nil
    ) {
        self.duration = max(0.1, min(duration, 3.0)) // 限制在合理范围
        self.damping = max(0.1, min(damping, 1.0))
        self.stiffness = max(10.0, min(stiffness, 1000.0))
        self.initialVelocity = max(0.0, min(initialVelocity, 10.0))
        self.delay = max(0.0, delay)
        self.timingFunction = timingFunction
        self.completion = completion
    }
}

// MARK: - Animation Presets

/// 预设的弹性动画配置
public enum BLSpringAnimationPreset {
    case gentle // 温和弹性
    case moderate // 中等弹性
    case bouncy // 强烈弹性
    case quick // 快速响应
    case smooth // 平滑过渡
    case dramatic // 戏剧性效果
    case custom(BLSpringAnimationConfiguration)

    /// 获取对应的配置
    public var configuration: BLSpringAnimationConfiguration {
        switch self {
        case .gentle:
            return BLSpringAnimationConfiguration(
                duration: 0.8,
                damping: 0.9,
                stiffness: 200.0,
                initialVelocity: 0.0
            )
        case .moderate:
            return BLSpringAnimationConfiguration(
                duration: 0.6,
                damping: 0.8,
                stiffness: 300.0,
                initialVelocity: 0.2
            )
        case .bouncy:
            return BLSpringAnimationConfiguration(
                duration: 0.7,
                damping: 0.6,
                stiffness: 400.0,
                initialVelocity: 0.5
            )
        case .quick:
            return BLSpringAnimationConfiguration(
                duration: 0.3,
                damping: 0.9,
                stiffness: 500.0,
                initialVelocity: 1.0
            )
        case .smooth:
            return BLSpringAnimationConfiguration(
                duration: 0.5,
                damping: 1.0,
                stiffness: 250.0,
                initialVelocity: 0.0
            )
        case .dramatic:
            return BLSpringAnimationConfiguration(
                duration: 1.0,
                damping: 0.5,
                stiffness: 350.0,
                initialVelocity: 0.8
            )
        case let .custom(config):
            return config
        }
    }
}

// MARK: - Animation Properties

/// 可动画的属性类型
public enum BLAnimatableProperty {
    case transform
    case scale
    case position
    case opacity
    case backgroundColor
    case cornerRadius
    case shadowOpacity
    case shadowRadius
    case shadowOffset
    case bounds
    case custom(String)

    /// 获取对应的 keyPath
    public var keyPath: String {
        switch self {
        case .transform:
            return "transform"
        case .scale:
            return "transform.scale"
        case .position:
            return "position"
        case .opacity:
            return "opacity"
        case .backgroundColor:
            return "backgroundColor"
        case .cornerRadius:
            return "cornerRadius"
        case .shadowOpacity:
            return "shadowOpacity"
        case .shadowRadius:
            return "shadowRadius"
        case .shadowOffset:
            return "shadowOffset"
        case .bounds:
            return "bounds"
        case let .custom(keyPath):
            return keyPath
        }
    }
}

// MARK: - Animation Manager Protocol

/// 弹性动画管理协议
public protocol BLSpringAnimationManaging: AnyObject {
    /// 创建弹性动画
    func createSpringAnimation(
        for property: BLAnimatableProperty,
        from fromValue: Any?,
        to toValue: Any,
        preset: BLSpringAnimationPreset
    ) -> CASpringAnimation

    /// 应用弹性动画到图层
    func applySpringAnimation(
        to layer: CALayer,
        for property: BLAnimatableProperty,
        from fromValue: Any?,
        to toValue: Any,
        preset: BLSpringAnimationPreset,
        completion: ((Bool) -> Void)?
    )

    /// 批量应用动画
    func applyBatchAnimations(
        to layer: CALayer,
        animations: [(property: BLAnimatableProperty, fromValue: Any?, toValue: Any, preset: BLSpringAnimationPreset)],
        completion: ((Bool) -> Void)?
    )

    /// 停止指定图层的所有动画
    func stopAnimations(for layer: CALayer)

    /// 停止指定图层的特定属性动画
    func stopAnimation(for layer: CALayer, property: BLAnimatableProperty)
}

// MARK: - Spring Animation Manager Implementation

/// BLSpringAnimationManager - 弹性动画管理器
/// 提供高级的弹性动画创建、管理和优化功能
public class BLSpringAnimationManager: BLSpringAnimationManaging {
    // MARK: - Properties

    /// 单例实例
    public static let shared = BLSpringAnimationManager()

    /// 动画池 - 复用动画对象以提高性能
    private var animationPool: [String: [CASpringAnimation]] = [:]

    /// 活跃动画追踪 - 用于内存管理和状态监控
    private var activeAnimations: [CALayer: Set<String>] = [:]

    /// 动画完成回调存储
    private var completionHandlers: [String: (Bool) -> Void] = [:]

    /// 性能监控
    private var performanceMetrics = BLAnimationPerformanceMetrics()

    /// 线程安全队列
    private let animationQueue = DispatchQueue(label: "com.bl.spring-animation", qos: .userInteractive)

    // MARK: - Initialization

    private init() {
        setupAnimationPool()
        setupPerformanceMonitoring()
    }

    deinit {
        cleanupResources()
    }

    // MARK: - Public Methods

    /// 创建弹性动画
    public func createSpringAnimation(
        for property: BLAnimatableProperty,
        from fromValue: Any?,
        to toValue: Any,
        preset: BLSpringAnimationPreset
    ) -> CASpringAnimation {
        let config = preset.configuration
        let animation = getPooledAnimation(for: property.keyPath) ?? CASpringAnimation(keyPath: property.keyPath)

        // {{CHENGQI:
        // Action: Added
        // Timestamp: 2025-06-09 09:24:14 +08:00
        // Reason: 实现弹性动画创建核心逻辑，支持P3-LD-009任务要求
        // Principle_Applied: KISS - 使用系统CASpringAnimation，避免复杂自定义实现
        // Optimization: 动画池复用减少对象创建开销
        // Architectural_Note (AR): 符合Aurora Premium架构中BLAnimationController设计
        // Documentation_Note (DW): 清晰的参数配置和性能优化策略
        // }}

        // 配置弹性动画参数
        animation.fromValue = fromValue
        animation.toValue = toValue
        animation.duration = config.duration
        animation.damping = config.damping
        animation.stiffness = config.stiffness
        animation.initialVelocity = config.initialVelocity
        animation.beginTime = CACurrentMediaTime() + config.delay

        // 设置时序函数
        if let timingFunction = config.timingFunction {
            animation.timingFunction = timingFunction
        } else {
            // 默认使用自然的缓动函数
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        }

        // 配置动画属性
        animation.fillMode = .both
        animation.isRemovedOnCompletion = false

        // 性能监控
        performanceMetrics.recordAnimationCreation(for: property.keyPath)

        return animation
    }

    /// 应用弹性动画到图层
    public func applySpringAnimation(
        to layer: CALayer,
        for property: BLAnimatableProperty,
        from fromValue: Any?,
        to toValue: Any,
        preset: BLSpringAnimationPreset,
        completion: ((Bool) -> Void)? = nil
    ) {
        animationQueue.async { [weak self] in
            guard let self = self else { return }

            let animation = self.createSpringAnimation(
                for: property,
                from: fromValue,
                to: toValue,
                preset: preset
            )

            let animationKey = self.generateAnimationKey(for: layer, property: property)

            // 存储完成回调
            if let completion = completion {
                self.completionHandlers[animationKey] = completion
            }

            // 设置动画代理
            animation.delegate = self

            DispatchQueue.main.async {
                // 停止现有的同属性动画
                self.stopAnimation(for: layer, property: property)

                // 记录活跃动画
                self.trackActiveAnimation(layer: layer, key: animationKey)

                // 应用动画
                layer.add(animation, forKey: animationKey)

                // 立即设置最终值以避免闪烁
                layer.setValue(toValue, forKeyPath: property.keyPath)
            }
        }
    }

    /// 批量应用动画
    public func applyBatchAnimations(
        to layer: CALayer,
        animations: [(property: BLAnimatableProperty, fromValue: Any?, toValue: Any, preset: BLSpringAnimationPreset)],
        completion: ((Bool) -> Void)? = nil
    ) {
        guard !animations.isEmpty else {
            completion?(true)
            return
        }

        let group = DispatchGroup()
        var allSucceeded = true

        // {{CHENGQI:
        // Action: Added
        // Timestamp: 2025-06-09 09:24:14 +08:00
        // Reason: 实现批量动画功能，提高多属性同时动画的性能
        // Principle_Applied: DRY - 复用单个动画逻辑，避免重复代码
        // Optimization: 使用DispatchGroup协调多个动画的完成状态
        // Architectural_Note (AR): 支持BLLayeredTimingController的批量动画需求
        // }}

        for animationInfo in animations {
            group.enter()

            applySpringAnimation(
                to: layer,
                for: animationInfo.property,
                from: animationInfo.fromValue,
                to: animationInfo.toValue,
                preset: animationInfo.preset
            ) { success in
                if !success {
                    allSucceeded = false
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion?(allSucceeded)
        }
    }

    /// 停止指定图层的所有动画
    public func stopAnimations(for layer: CALayer) {
        animationQueue.async { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                // 移除所有动画
                layer.removeAllAnimations()

                // 清理追踪记录
                if let activeKeys = self.activeAnimations[layer] {
                    for key in activeKeys {
                        self.completionHandlers.removeValue(forKey: key)
                    }
                }
                self.activeAnimations.removeValue(forKey: layer)
            }
        }
    }

    /// 停止指定图层的特定属性动画
    public func stopAnimation(for layer: CALayer, property: BLAnimatableProperty) {
        let animationKey = generateAnimationKey(for: layer, property: property)

        DispatchQueue.main.async { [weak self] in
            layer.removeAnimation(forKey: animationKey)
            self?.untrackActiveAnimation(layer: layer, key: animationKey)
        }
    }

    // MARK: - Private Methods

    /// 设置动画池
    private func setupAnimationPool() {
        // 为常用属性预创建动画对象
        let commonProperties = ["transform.scale", "opacity", "position", "backgroundColor"]
        for property in commonProperties {
            animationPool[property] = []
        }
    }

    /// 设置性能监控
    private func setupPerformanceMonitoring() {
        performanceMetrics.startMonitoring()
    }

    /// 从动画池获取动画对象
    private func getPooledAnimation(for keyPath: String) -> CASpringAnimation? {
        guard var pool = animationPool[keyPath], !pool.isEmpty else {
            return nil
        }

        let animation = pool.removeLast()
        animationPool[keyPath] = pool

        // 重置动画状态
        animation.fromValue = nil
        animation.toValue = nil
        animation.delegate = nil

        return animation
    }

    /// 回收动画对象到池中
    private func returnAnimationToPool(_ animation: CASpringAnimation, keyPath: String) {
        guard var pool = animationPool[keyPath] else { return }

        // 限制池大小以避免内存过度使用
        if pool.count < 5 {
            pool.append(animation)
            animationPool[keyPath] = pool
        }
    }

    /// 生成动画键
    private func generateAnimationKey(for layer: CALayer, property: BLAnimatableProperty) -> String {
        let layerHash = ObjectIdentifier(layer).hashValue
        return "BLSpring_\(layerHash)_\(property.keyPath)"
    }

    /// 追踪活跃动画
    private func trackActiveAnimation(layer: CALayer, key: String) {
        if activeAnimations[layer] == nil {
            activeAnimations[layer] = Set<String>()
        }
        activeAnimations[layer]?.insert(key)
    }

    /// 取消追踪活跃动画
    private func untrackActiveAnimation(layer: CALayer, key: String) {
        activeAnimations[layer]?.remove(key)
        if activeAnimations[layer]?.isEmpty == true {
            activeAnimations.removeValue(forKey: layer)
        }
        completionHandlers.removeValue(forKey: key)
    }

    /// 清理资源
    private func cleanupResources() {
        animationPool.removeAll()
        activeAnimations.removeAll()
        completionHandlers.removeAll()
        performanceMetrics.stopMonitoring()
    }
}

// MARK: - CAAnimationDelegate

extension BLSpringAnimationManager: CAAnimationDelegate {
    public func animationDidStart(_ anim: CAAnimation) {
        performanceMetrics.recordAnimationStart()
    }

    public func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        guard let springAnimation = anim as? CASpringAnimation,
              let keyPath = springAnimation.keyPath else { return }

        // 查找对应的动画键和完成回调
        for (layer, keys) in activeAnimations {
            for key in keys {
                if layer.animation(forKey: key) === anim {
                    // 执行完成回调
                    completionHandlers[key]?(flag)

                    // 清理追踪记录
                    untrackActiveAnimation(layer: layer, key: key)

                    // 回收动画对象
                    returnAnimationToPool(springAnimation, keyPath: keyPath)

                    // 性能监控
                    performanceMetrics.recordAnimationCompletion(success: flag)

                    return
                }
            }
        }
    }
}

// MARK: - Performance Metrics

/// 动画性能指标监控
private class BLAnimationPerformanceMetrics {
    private var creationCount: Int = 0
    private var startCount: Int = 0
    private var completionCount: Int = 0
    private var successCount: Int = 0
    private var startTime: CFTimeInterval = 0

    func startMonitoring() {
        startTime = CACurrentMediaTime()
        resetMetrics()
    }

    func stopMonitoring() {
        // 可以在这里输出性能报告
        let duration = CACurrentMediaTime() - startTime
        let successRate = completionCount > 0 ? Double(successCount) / Double(completionCount) : 0.0

        print("BLSpringAnimationManager Performance Report:")
        print("- Duration: \(String(format: "%.2f", duration))s")
        print("- Animations Created: \(creationCount)")
        print("- Animations Started: \(startCount)")
        print("- Animations Completed: \(completionCount)")
        print("- Success Rate: \(String(format: "%.1f", successRate * 100))%")
    }

    func recordAnimationCreation(for keyPath: String) {
        creationCount += 1
    }

    func recordAnimationStart() {
        startCount += 1
    }

    func recordAnimationCompletion(success: Bool) {
        completionCount += 1
        if success {
            successCount += 1
        }
    }

    private func resetMetrics() {
        creationCount = 0
        startCount = 0
        completionCount = 0
        successCount = 0
    }
}

// MARK: - Convenience Extensions

public extension BLSpringAnimationManager {
    /// 便捷方法：缩放动画
    func animateScale(
        layer: CALayer,
        to scale: CGFloat,
        preset: BLSpringAnimationPreset = .moderate,
        completion: ((Bool) -> Void)? = nil
    ) {
        let transform = CATransform3DMakeScale(scale, scale, 1.0)
        applySpringAnimation(
            to: layer,
            for: .transform,
            from: layer.transform,
            to: transform,
            preset: preset,
            completion: completion
        )
    }

    /// 便捷方法：透明度动画
    func animateOpacity(
        layer: CALayer,
        to opacity: Float,
        preset: BLSpringAnimationPreset = .smooth,
        completion: ((Bool) -> Void)? = nil
    ) {
        applySpringAnimation(
            to: layer,
            for: .opacity,
            from: layer.opacity,
            to: opacity,
            preset: preset,
            completion: completion
        )
    }

    /// 便捷方法：位置动画
    func animatePosition(
        layer: CALayer,
        to position: CGPoint,
        preset: BLSpringAnimationPreset = .moderate,
        completion: ((Bool) -> Void)? = nil
    ) {
        applySpringAnimation(
            to: layer,
            for: .position,
            from: layer.position,
            to: position,
            preset: preset,
            completion: completion
        )
    }

    /// 便捷方法：背景色动画
    func animateBackgroundColor(
        layer: CALayer,
        to color: UIColor,
        preset: BLSpringAnimationPreset = .smooth,
        completion: ((Bool) -> Void)? = nil
    ) {
        applySpringAnimation(
            to: layer,
            for: .backgroundColor,
            from: layer.backgroundColor,
            to: color.cgColor,
            preset: preset,
            completion: completion
        )
    }
}
