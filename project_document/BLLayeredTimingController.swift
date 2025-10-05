import QuartzCore
import UIKit

// MARK: - Timing Configuration Protocols

/// 时序配置协议
protocol BLTimingConfigurable {
    var delay: TimeInterval { get set }
    var duration: TimeInterval { get set }
    var timingFunction: CAMediaTimingFunction { get set }
    var repeatCount: Int { get set }
}

/// 层时序协调协议
protocol BLLayerTimingCoordinating {
    func coordinateLayerAnimations(with configuration: BLLayeredTimingConfiguration) -> [BLLayerAnimationSequence]
    func synchronizeAnimations(_ sequences: [BLLayerAnimationSequence])
    func staggerAnimations(_ sequences: [BLLayerAnimationSequence], with pattern: BLStaggerPattern)
    func stopCoordinatedAnimations()
}

/// 时序监控协议
protocol BLTimingMonitoring {
    func startMonitoring()
    func stopMonitoring()
    func getTimingMetrics() -> BLTimingMetrics
    func resetMetrics()
}

// MARK: - Data Structures

/// 分层时序配置
struct BLLayeredTimingConfiguration {
    // {{CHENGQI:
    // Action: Added
    // Timestamp: 2025-06-09 09:30:32 +08:00
    // Reason: 实现分层时序配置结构，支持错峰动画和协调效果
    // Principle_Applied: KISS - 使用简洁的配置结构，DRY - 复用时序参数
    // Optimization: 使用值类型避免引用开销
    // }}

    /// 时序模式
    enum TimingPattern {
        case synchronized // 同步执行
        case staggered // 错峰执行
        case cascading // 级联执行
        case ripple // 波纹扩散
        case custom(String) // 自定义模式
    }

    /// 层优先级
    enum LayerPriority: Int, CaseIterable {
        case background = 0 // Aurora背景层
        case content = 1 // 内容增强层
        case lighting = 2 // 光效层
        case interaction = 3 // 交互反馈层

        var layerType: BLVisualLayerType {
            switch self {
            case .background: return .auroraBackground
            case .content: return .contentEnhancement
            case .lighting: return .lightingEffect
            case .interaction: return .interactionFeedback
            }
        }
    }

    let pattern: TimingPattern
    let globalDuration: TimeInterval
    let staggerDelay: TimeInterval // 错峰延迟
    let dampingFactor: Double // 阻尼系数
    let priorities: [LayerPriority] // 层优先级顺序
    let easingFunction: CAMediaTimingFunction

    /// 默认配置
    static let `default` = BLLayeredTimingConfiguration(
        pattern: .staggered,
        globalDuration: 0.6,
        staggerDelay: 0.1,
        dampingFactor: 0.8,
        priorities: LayerPriority.allCases,
        easingFunction: CAMediaTimingFunction(name: .easeInEaseOut)
    )

    /// 同步配置
    static let synchronized = BLLayeredTimingConfiguration(
        pattern: .synchronized,
        globalDuration: 0.4,
        staggerDelay: 0.0,
        dampingFactor: 1.0,
        priorities: LayerPriority.allCases,
        easingFunction: CAMediaTimingFunction(name: .easeOut)
    )

    /// 级联配置
    static let cascading = BLLayeredTimingConfiguration(
        pattern: .cascading,
        globalDuration: 1.0,
        staggerDelay: 0.15,
        dampingFactor: 0.6,
        priorities: LayerPriority.allCases,
        easingFunction: CAMediaTimingFunction(name: .easeInEaseOut)
    )

    /// 波纹配置
    static let ripple = BLLayeredTimingConfiguration(
        pattern: .ripple,
        globalDuration: 0.8,
        staggerDelay: 0.08,
        dampingFactor: 0.7,
        priorities: [.interaction, .lighting, .content, .background],
        easingFunction: CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1.0)
    )
}

/// 错峰模式
enum BLStaggerPattern {
    case sequential // 顺序执行
    case reverse // 逆序执行
    case fromCenter // 从中心扩散
    case toCenter // 向中心收缩
    case alternating // 交替执行
    case custom([Int]) // 自定义索引顺序
}

/// 层动画序列
struct BLLayerAnimationSequence {
    let layerType: BLVisualLayerType
    let priority: BLLayeredTimingConfiguration.LayerPriority
    let delay: TimeInterval
    let duration: TimeInterval
    let animations: [BLTimingAnimationInfo]
    let completion: (() -> Void)?

    struct BLTimingAnimationInfo {
        let keyPath: String
        let fromValue: Any?
        let toValue: Any?
        let timingFunction: CAMediaTimingFunction
    }
}

/// 时序性能指标
struct BLTimingMetrics {
    var coordinationStartTime: TimeInterval
    var coordinationEndTime: TimeInterval
    var totalAnimationCount: Int
    var synchronizationAccuracy: Double // 同步准确度 (0.0-1.0)
    var staggerPrecision: Double // 错峰精度 (0.0-1.0)
    var performanceScore: Double // 性能评分 (0.0-1.0)

    var coordinationDuration: TimeInterval {
        return coordinationEndTime - coordinationStartTime
    }

    mutating func reset() {
        coordinationStartTime = 0
        coordinationEndTime = 0
        totalAnimationCount = 0
        synchronizationAccuracy = 0
        staggerPrecision = 0
        performanceScore = 0
    }
}

// MARK: - Main Controller

/// 分层时序控制器
class BLLayeredTimingController: NSObject {
    // {{CHENGQI:
    // Action: Added
    // Timestamp: 2025-06-09 09:30:32 +08:00
    // Reason: 实现核心时序控制器，管理多层动画协调
    // Principle_Applied: SOLID(S,O,D) - 单一职责，开放扩展，依赖倒置
    // Optimization: 使用弱引用避免循环引用，线程安全设计
    // }}

    // MARK: - Properties

    /// 单例实例
    static let shared = BLLayeredTimingController()

    /// 当前配置
    private var currentConfiguration: BLLayeredTimingConfiguration = .default

    /// 活跃的动画序列
    private var activeSequences: [BLLayerAnimationSequence] = []

    /// 时序监控
    private var timingMetrics = BLTimingMetrics()

    /// 监控定时器
    private var monitoringTimer: Timer?

    /// 是否正在监控
    private var isMonitoring = false

    /// 操作队列
    private let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "BLLayeredTimingController"
        queue.maxConcurrentOperationCount = 1 // 串行执行确保时序准确
        queue.qualityOfService = .userInteractive
        return queue
    }()

    /// 同步队列
    private let syncQueue = DispatchQueue(label: "BLLayeredTimingController.sync", qos: .userInteractive)

    // MARK: - Lifecycle

    override private init() {
        super.init()
        setupMonitoring()
    }

    deinit {
        stopMonitoring()
        stopCoordinatedAnimations()
    }

    // MARK: - Public Interface

    /// 更新配置
    func updateConfiguration(_ configuration: BLLayeredTimingConfiguration) {
        syncQueue.async { [weak self] in
            self?.currentConfiguration = configuration
        }
    }

    /// 协调层动画
    func coordinateLayerAnimations(
        for layers: [BLBaseVisualLayer],
        with configuration: BLLayeredTimingConfiguration? = nil,
        completion: (() -> Void)? = nil
    ) {
        let config = configuration ?? currentConfiguration

        operationQueue.addOperation { [weak self] in
            guard let self = self else { return }

            self.timingMetrics.coordinationStartTime = CACurrentMediaTime()

            // 生成动画序列
            let sequences = self.generateAnimationSequences(for: layers, with: config)

            DispatchQueue.main.async {
                // 应用动画序列
                self.applyAnimationSequences(sequences, with: config) {
                    self.timingMetrics.coordinationEndTime = CACurrentMediaTime()
                    completion?()
                }
            }
        }
    }

    /// 应用聚焦状态协调
    func coordinateFocusState(
        for layers: [BLBaseVisualLayer],
        focused: Bool,
        configuration: BLLayeredTimingConfiguration? = nil
    ) {
        let config = configuration ?? (focused ? .ripple : .cascading)

        // 为聚焦状态创建特殊的动画序列
        var modifiedLayers: [BLBaseVisualLayer] = []

        for layer in layers {
            // 创建聚焦状态的临时配置
            let focusConfig = BLLayerConfiguration(
                intensity: focused ? 1.0 : 0.3,
                duration: config.globalDuration,
                timing: .custom(config.easingFunction),
                properties: ["focused": focused]
            )

            // 应用配置到层
            layer.updateConfiguration(focusConfig)
            modifiedLayers.append(layer)
        }

        coordinateLayerAnimations(for: modifiedLayers, with: config)
    }

    /// 停止所有协调动画
    func stopCoordinatedAnimations() {
        syncQueue.async { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                for sequence in self.activeSequences {
                    // 停止对应层的动画
                    // 注意：这里需要与实际的层实例协调
                }
                self.activeSequences.removeAll()
            }
        }
    }
}

// MARK: - BLLayerTimingCoordinating

extension BLLayeredTimingController: BLLayerTimingCoordinating {
    func coordinateLayerAnimations(with configuration: BLLayeredTimingConfiguration) -> [BLLayerAnimationSequence] {
        return generateAnimationSequences(for: [], with: configuration)
    }

    func synchronizeAnimations(_ sequences: [BLLayerAnimationSequence]) {
        // 同步执行所有动画
        let group = DispatchGroup()

        for sequence in sequences {
            group.enter()
            DispatchQueue.main.asyncAfter(deadline: .now() + sequence.delay) {
                // 执行动画
                self.executeAnimationSequence(sequence) {
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            print("所有动画已同步完成")
        }
    }

    func staggerAnimations(_ sequences: [BLLayerAnimationSequence], with pattern: BLStaggerPattern) {
        let orderedSequences = reorderSequences(sequences, with: pattern)

        for (index, sequence) in orderedSequences.enumerated() {
            let additionalDelay = TimeInterval(index) * currentConfiguration.staggerDelay
            let delayedSequence = BLLayerAnimationSequence(
                layerType: sequence.layerType,
                priority: sequence.priority,
                delay: sequence.delay + additionalDelay,
                duration: sequence.duration,
                animations: sequence.animations,
                completion: sequence.completion
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + delayedSequence.delay) {
                self.executeAnimationSequence(delayedSequence)
            }
        }
    }
}

// MARK: - BLTimingMonitoring

extension BLLayeredTimingController: BLTimingMonitoring {
    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        timingMetrics.reset()

        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateTimingMetrics()
        }
    }

    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        isMonitoring = false
    }

    func getTimingMetrics() -> BLTimingMetrics {
        return timingMetrics
    }

    func resetMetrics() {
        timingMetrics.reset()
    }

    private func updateTimingMetrics() {
        // 更新性能指标
        timingMetrics.totalAnimationCount = activeSequences.count

        // 计算同步准确度（模拟）
        timingMetrics.synchronizationAccuracy = min(1.0, 0.95 + Double.random(in: -0.05...0.05))

        // 计算错峰精度（模拟）
        timingMetrics.staggerPrecision = min(1.0, 0.92 + Double.random(in: -0.08...0.08))

        // 计算性能评分
        timingMetrics.performanceScore = (timingMetrics.synchronizationAccuracy + timingMetrics.staggerPrecision) / 2.0
    }
}

// MARK: - Private Methods

private extension BLLayeredTimingController {
    /// 生成动画序列
    func generateAnimationSequences(
        for layers: [BLBaseVisualLayer],
        with configuration: BLLayeredTimingConfiguration
    ) -> [BLLayerAnimationSequence] {
        var sequences: [BLLayerAnimationSequence] = []

        for (index, priority) in configuration.priorities.enumerated() {
            let delay = calculateDelay(for: index, with: configuration)
            let duration = calculateDuration(for: priority, with: configuration)

            let animations = generateAnimationsForPriority(priority, with: configuration)

            let sequence = BLLayerAnimationSequence(
                layerType: priority.layerType,
                priority: priority,
                delay: delay,
                duration: duration,
                animations: animations,
                completion: nil
            )

            sequences.append(sequence)
        }

        return sequences
    }

    /// 计算延迟
    func calculateDelay(for index: Int, with configuration: BLLayeredTimingConfiguration) -> TimeInterval {
        switch configuration.pattern {
        case .synchronized:
            return 0.0
        case .staggered:
            return TimeInterval(index) * configuration.staggerDelay
        case .cascading:
            return TimeInterval(index) * configuration.staggerDelay * 1.5
        case .ripple:
            // 波纹模式：从交互层开始
            let rippleIndex = configuration.priorities.count - index - 1
            return TimeInterval(rippleIndex) * configuration.staggerDelay * 0.8
        case .custom:
            return TimeInterval(index) * configuration.staggerDelay
        }
    }

    /// 计算时长
    func calculateDuration(
        for priority: BLLayeredTimingConfiguration.LayerPriority,
        with configuration: BLLayeredTimingConfiguration
    ) -> TimeInterval {
        let baseDuration = configuration.globalDuration
        let dampingAdjustment = configuration.dampingFactor

        switch priority {
        case .background:
            return baseDuration * dampingAdjustment * 1.2 // 背景动画稍长
        case .content:
            return baseDuration * dampingAdjustment
        case .lighting:
            return baseDuration * dampingAdjustment * 0.8 // 光效动画稍短
        case .interaction:
            return baseDuration * dampingAdjustment * 0.6 // 交互反馈最快
        }
    }

    /// 为优先级生成动画信息
    func generateAnimationsForPriority(
        _ priority: BLLayeredTimingConfiguration.LayerPriority,
        with configuration: BLLayeredTimingConfiguration
    ) -> [BLLayerAnimationSequence.BLTimingAnimationInfo] {
        var animations: [BLLayerAnimationSequence.BLTimingAnimationInfo] = []

        switch priority {
        case .background:
            animations.append(
                BLLayerAnimationSequence.BLTimingAnimationInfo(
                    keyPath: "opacity",
                    fromValue: 0.0,
                    toValue: 1.0,
                    timingFunction: configuration.easingFunction
                )
            )
        case .content:
            animations.append(
                BLLayerAnimationSequence.BLTimingAnimationInfo(
                    keyPath: "transform.scale",
                    fromValue: 0.95,
                    toValue: 1.0,
                    timingFunction: configuration.easingFunction
                )
            )
        case .lighting:
            animations.append(
                BLLayerAnimationSequence.BLTimingAnimationInfo(
                    keyPath: "shadowOpacity",
                    fromValue: 0.0,
                    toValue: 0.3,
                    timingFunction: configuration.easingFunction
                )
            )
        case .interaction:
            animations.append(
                BLLayerAnimationSequence.BLTimingAnimationInfo(
                    keyPath: "transform.scale",
                    fromValue: 1.0,
                    toValue: 1.05,
                    timingFunction: configuration.easingFunction
                )
            )
        }

        return animations
    }

    /// 应用动画序列
    func applyAnimationSequences(
        _ sequences: [BLLayerAnimationSequence],
        with configuration: BLLayeredTimingConfiguration,
        completion: (() -> Void)? = nil
    ) {
        activeSequences = sequences

        switch configuration.pattern {
        case .synchronized:
            synchronizeAnimations(sequences)
        case .staggered, .cascading:
            staggerAnimations(sequences, with: .sequential)
        case .ripple:
            staggerAnimations(sequences, with: .reverse)
        case .custom:
            staggerAnimations(sequences, with: .custom([0, 2, 1, 3]))
        }

        // 计算总完成时间
        let maxDelay = sequences.map { $0.delay + $0.duration }.max() ?? 0
        DispatchQueue.main.asyncAfter(deadline: .now() + maxDelay) {
            completion?()
        }
    }

    /// 执行单个动画序列
    func executeAnimationSequence(
        _ sequence: BLLayerAnimationSequence,
        completion: (() -> Void)? = nil
    ) {
        // 这里应该与实际的层实例协调执行动画
        // 由于这是时序控制器，主要关注时序逻辑

        print("执行动画序列: \(sequence.layerType) - 延迟: \(sequence.delay)s, 时长: \(sequence.duration)s")

        DispatchQueue.main.asyncAfter(deadline: .now() + sequence.duration) {
            sequence.completion?()
            completion?()
        }
    }

    /// 重新排序序列
    func reorderSequences(
        _ sequences: [BLLayerAnimationSequence],
        with pattern: BLStaggerPattern
    ) -> [BLLayerAnimationSequence] {
        switch pattern {
        case .sequential:
            return sequences
        case .reverse:
            return sequences.reversed()
        case .fromCenter:
            let midIndex = sequences.count / 2
            var reordered: [BLLayerAnimationSequence] = []
            for i in 0..<sequences.count {
                let index = i % 2 == 0 ? midIndex + i / 2 : midIndex - (i + 1) / 2
                if index >= 0 && index < sequences.count {
                    reordered.append(sequences[index])
                }
            }
            return reordered
        case .toCenter:
            return reorderSequences(sequences, with: .fromCenter).reversed()
        case .alternating:
            var reordered: [BLLayerAnimationSequence] = []
            let evenIndices = sequences.enumerated().compactMap { $0.offset % 2 == 0 ? $0.element : nil }
            let oddIndices = sequences.enumerated().compactMap { $0.offset % 2 == 1 ? $0.element : nil }
            reordered.append(contentsOf: evenIndices)
            reordered.append(contentsOf: oddIndices)
            return reordered
        case let .custom(indices):
            return indices.compactMap { index in
                index < sequences.count ? sequences[index] : nil
            }
        }
    }

    /// 设置监控
    func setupMonitoring() {
        // 初始化监控系统
        timingMetrics.reset()
    }
}

// MARK: - Convenience Extensions

extension BLLayeredTimingController {
    /// 快速聚焦动画
    func animateFocus(for layers: [BLBaseVisualLayer], focused: Bool) {
        let config: BLLayeredTimingConfiguration = focused ? .ripple : .cascading
        coordinateFocusState(for: layers, focused: focused, configuration: config)
    }

    /// 快速选择动画
    func animateSelection(for layers: [BLBaseVisualLayer], selected: Bool) {
        let config = BLLayeredTimingConfiguration(
            pattern: .synchronized,
            globalDuration: 0.3,
            staggerDelay: 0.0,
            dampingFactor: 0.9,
            priorities: BLLayeredTimingConfiguration.LayerPriority.allCases,
            easingFunction: CAMediaTimingFunction(name: .easeOut)
        )
        coordinateLayerAnimations(for: layers, with: config)
    }

    /// 快速状态变化动画
    func animateStateChange(for layers: [BLBaseVisualLayer], to state: String) {
        let config: BLLayeredTimingConfiguration

        switch state {
        case "loading":
            config = .synchronized
        case "error":
            config = .ripple
        case "success":
            config = .cascading
        default:
            config = .default
        }

        coordinateLayerAnimations(for: layers, with: config)
    }
}
