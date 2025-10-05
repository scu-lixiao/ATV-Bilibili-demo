//
//  BLVisualLayerFactory.swift
//  BilibiliLive
//
//  Created by Aurora Premium Enhancement on 2025/06/09.
//

import UIKit

// MARK: - Supporting Types and Protocols

/// 层配置结构
public struct BLLayerConfiguration {
    public let intensity: CGFloat
    public let duration: TimeInterval
    public let isAnimated: Bool
    public let properties: [String: Any]
    public let timing: CAMediaTimingFunction

    public init(
        intensity: CGFloat = 1.0,
        duration: TimeInterval = 0.3,
        isAnimated: Bool = true,
        properties: [String: Any] = [:],
        timing: CAMediaTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    ) {
        self.intensity = intensity
        self.duration = duration
        self.isAnimated = isAnimated
        self.properties = properties
        self.timing = timing
    }

    public static let `default` = BLLayerConfiguration()
}

/// 层通信协议 - 用于层间消息传递
public protocol BLLayerCommunicationProtocol: AnyObject {
    func layerDidUpdate(_ layerType: BLVisualLayerType, state: BLLayerState)
}

/// 层状态枚举
public enum BLLayerState {
    case inactive
    case active
    case transitioning
}

// MARK: - Visual Layer Types

/// 视觉层类型枚举 - 定义四个核心视觉层
public enum BLVisualLayerType: Int, CaseIterable {
    case background = 0 // Aurora背景层 - 动态渐变和噪点纹理
    case contentEnhancement = 1 // 内容增强层 - 毛玻璃效果和色彩叠加
    case lightingEffect = 2 // 光效层 - 动态光晕和边缘发光
    case interactionFeedback = 3 // 交互反馈层 - 微交互和状态指示

    public var layerPriority: Int {
        return rawValue
    }

    public var layerName: String {
        switch self {
        case .background: return "Aurora Background"
        case .contentEnhancement: return "Content Enhancement"
        case .lightingEffect: return "Lighting Effect"
        case .interactionFeedback: return "Interaction Feedback"
        }
    }

    /// 层级优先级（Z-order）
    public var priority: Int {
        return rawValue
    }

    /// 层级名称
    public var name: String {
        return layerName
    }
}

// MARK: - Base Visual Layer

/// 基础视觉层实现 - 提供通用功能
public class BLBaseVisualLayer: BLVisualLayerProtocol {
    // MARK: - Protocol Properties

    public let layerType: BLVisualLayerType
    public let layerPriority: Int
    public var isEnabled: Bool = true {
        didSet {
            updateLayerVisibility()
        }
    }

    public var qualityLevel: CGFloat = 1.0 {
        didSet {
            updateQualityLevel()
        }
    }

    public var isFocused: Bool = false

    public weak var containerView: UIView?

    // MARK: - Internal Properties

    /// 通信代理
    weak var communicationDelegate: BLLayerCommunicationProtocol?

    /// 主要的CALayer
    var mainLayer: CALayer?

    /// 当前配置
    var currentConfiguration: BLLayerConfiguration = .default

    /// 是否已设置
    private var isSetup: Bool = false

    /// 是否激活状态
    var isActive: Bool = false

    // MARK: - Initialization

    public init(type: BLVisualLayerType) {
        layerType = type
        layerPriority = type.layerPriority
    }

    // MARK: - Protocol Implementation

    public func setupLayer(in containerView: UIView) {
        // {{CHENGQI:
        // Action: Modified
        // Timestamp: 2025-06-09 10:44:33 +08:00 (from mcp-server-time)
        // Reason: 修复编译错误 - 添加public访问修饰符和协议实现
        // Principle_Applied: Template Method Pattern - 定义算法骨架，子类实现具体步骤
        // Optimization: 避免重复设置，提供清理机制
        // }}

        guard !isSetup else { return }

        self.containerView = containerView

        // 创建主层
        createMainLayer()

        // 添加到容器视图
        if let layer = mainLayer {
            containerView.layer.insertSublayer(layer, at: UInt32(layerPriority))
        }

        // 执行具体层的设置 - 子类重写此方法
        performSpecificSetup()

        isSetup = true
    }

    public func updateFocusState(isFocused: Bool, animated: Bool) {
        self.isFocused = isFocused

        // 基础实现 - 子类可重写以添加特定行为
        let duration = animated ? 0.3 : 0.0

        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)

        performFocusUpdate(isFocused: isFocused)

        CATransaction.commit()
    }

    public func updateQualityLevel(_ quality: CGFloat) {
        qualityLevel = quality
    }

    public func cleanup() {
        mainLayer?.removeFromSuperlayer()
        mainLayer = nil
        containerView = nil
        communicationDelegate = nil
        isSetup = false
        isActive = false
    }

    public func getLayerView() -> UIView? {
        // 基础实现返回容器视图，子类可重写
        return containerView
    }

    // MARK: - Aurora Premium Manager Integration

    /// 使用配置激活层
    func activateWithConfiguration(_ configuration: BLLayerConfiguration) {
        currentConfiguration = configuration
        communicationDelegate?.layerDidUpdate(layerType, state: .transitioning)

        isActive = true
        applyConfiguration()

        communicationDelegate?.layerDidUpdate(layerType, state: .active)
    }

    /// 使用配置停用层
    func deactivateWithConfiguration(_ configuration: BLLayerConfiguration) {
        currentConfiguration = configuration
        communicationDelegate?.layerDidUpdate(layerType, state: .transitioning)

        isActive = false
        applyConfiguration()

        communicationDelegate?.layerDidUpdate(layerType, state: .inactive)
    }

    /// 更新配置
    func updateConfiguration(_ configuration: BLLayerConfiguration) {
        currentConfiguration = configuration
        applyConfiguration()
    }

    /// 应用当前配置 - 子类重写
    func applyConfiguration() {
        // 子类实现具体的配置应用逻辑
        updateQualityLevel()
    }

    /// 应用自定义状态
    func applyCustomState(_ state: String, configuration: BLLayerConfiguration) {
        currentConfiguration = configuration
        // 子类实现自定义状态处理
        applyConfiguration()
    }

    /// 重置到稳定状态
    func resetToStableState() {
        isActive = false
        currentConfiguration = .default
        applyConfiguration()
        communicationDelegate?.layerDidUpdate(layerType, state: .inactive)
    }

    // MARK: - Template Methods (子类重写)

    /// 创建主要的CALayer - 子类重写
    func createMainLayer() {
        mainLayer = CALayer()
        mainLayer?.frame = containerView?.bounds ?? .zero
    }

    /// 执行特定的层设置 - 子类重写
    func performSpecificSetup() {
        // 子类实现具体的设置逻辑
    }

    /// 执行聚焦状态更新 - 子类重写
    func performFocusUpdate(isFocused: Bool) {
        // 子类实现具体的聚焦效果
    }

    /// 更新质量等级 - 子类重写
    func updateQualityLevel() {
        // 子类实现质量调整逻辑
    }

    // MARK: - Private Methods

    func updateLayerVisibility() {
        mainLayer?.isHidden = !isEnabled
    }
}

// MARK: - Visual Layer Factory

/// 视觉层工厂 - 负责创建不同类型的视觉层 (Factory Pattern)
class BLVisualLayerFactory {
    /// 创建指定类型的视觉层
    /// - Parameter type: 视觉层类型
    /// - Parameter parentView: 父视图
    /// - Returns: 对应的视觉层实例
    static func createLayer(type: BLVisualLayerType, parentView: UIView) -> BLBaseVisualLayer? {
        let layer: BLBaseVisualLayer

        switch type {
        case .background:
            layer = BLAuroraBackgroundLayer()
        case .contentEnhancement:
            layer = BLContentEnhancementLayer()
        case .lightingEffect:
            layer = BLLightingEffectLayer()
        case .interactionFeedback:
            layer = BLInteractionFeedbackLayer()
        }

        // 设置层到父视图
        layer.setupLayer(in: parentView)

        return layer
    }

    /// 创建所有类型的视觉层
    /// - Parameter parentView: 父视图
    /// - Returns: 包含所有视觉层的数组，按优先级排序
    static func createAllLayers(parentView: UIView) -> [BLVisualLayerProtocol] {
        return BLVisualLayerType.allCases.compactMap { createLayer(type: $0, parentView: parentView) }
    }
}

// MARK: - Placeholder Layer Implementations (将在后续任务中完整实现)

/// Aurora背景层 - 完整实现
class BLAuroraBackgroundLayer: BLBaseVisualLayer {
    // MARK: - Properties

    private var gradientLayer: CAGradientLayer?
    private var noiseLayer: CALayer?
    private var animationTimer: Timer?
    private var currentColorIndex: Int = 0

    // Aurora color palette - inspired by natural aurora colors
    private let auroraColors: [[CGColor]] = [
        // Green Aurora (most common)
        [
            UIColor(red: 0.0, green: 0.8, blue: 0.4, alpha: 0.3).cgColor,
            UIColor(red: 0.2, green: 0.9, blue: 0.6, alpha: 0.2).cgColor,
            UIColor(red: 0.0, green: 0.6, blue: 0.3, alpha: 0.4).cgColor,
        ],
        // Blue Aurora
        [
            UIColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 0.3).cgColor,
            UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 0.2).cgColor,
            UIColor(red: 0.1, green: 0.3, blue: 0.8, alpha: 0.4).cgColor,
        ],
        // Purple Aurora (rare but beautiful)
        [
            UIColor(red: 0.6, green: 0.2, blue: 0.9, alpha: 0.3).cgColor,
            UIColor(red: 0.8, green: 0.4, blue: 1.0, alpha: 0.2).cgColor,
            UIColor(red: 0.5, green: 0.1, blue: 0.8, alpha: 0.4).cgColor,
        ],
        // Pink Aurora
        [
            UIColor(red: 0.9, green: 0.3, blue: 0.6, alpha: 0.3).cgColor,
            UIColor(red: 1.0, green: 0.5, blue: 0.8, alpha: 0.2).cgColor,
            UIColor(red: 0.8, green: 0.2, blue: 0.5, alpha: 0.4).cgColor,
        ],
        // Red Aurora (for error states)
        [
            UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 0.3).cgColor,
            UIColor(red: 1.0, green: 0.4, blue: 0.3, alpha: 0.2).cgColor,
            UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 0.4).cgColor,
        ],
    ]

    // Animation properties
    private var animationDuration: TimeInterval = 8.0
    private var colorTransitionDuration: TimeInterval = 3.0

    init() {
        super.init(type: .background)
    }

    deinit {
        stopAnimation()
    }

    // MARK: - Layer Creation

    override func createMainLayer() {
        super.createMainLayer()

        // Create gradient layer for aurora effect
        createGradientLayer()

        // Create noise layer for texture
        createNoiseLayer()

        // Set initial state
        updateLayerVisibility()
    }

    private func createGradientLayer() {
        gradientLayer = CAGradientLayer()
        guard let gradientLayer = gradientLayer,
              let mainLayer = mainLayer else { return }

        gradientLayer.frame = mainLayer.bounds
        gradientLayer.colors = auroraColors[0]

        // Aurora-like gradient configuration
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        gradientLayer.locations = [0.0, 0.5, 1.0]

        // Add subtle animation-ready properties
        gradientLayer.opacity = 0.0

        mainLayer.addSublayer(gradientLayer)
    }

    private func createNoiseLayer() {
        noiseLayer = CALayer()
        guard let noiseLayer = noiseLayer,
              let mainLayer = mainLayer else { return }

        noiseLayer.frame = mainLayer.bounds
        noiseLayer.opacity = 0.0

        // Generate noise texture
        if let noiseTexture = generateNoiseTexture() {
            noiseLayer.contents = noiseTexture
            noiseLayer.contentsGravity = .resizeAspectFill
        }

        // Blend mode for subtle texture overlay
        noiseLayer.compositingFilter = "multiplyBlendMode"

        mainLayer.addSublayer(noiseLayer)
    }

    private func generateNoiseTexture() -> CGImage? {
        let size = CGSize(width: 256, height: 256)
        let colorSpace = CGColorSpaceCreateDeviceGray()

        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        // Generate Perlin-like noise
        let data = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(size.width * size.height))
        defer { data.deallocate() }

        for y in 0..<Int(size.height) {
            for x in 0..<Int(size.width) {
                let noise = generatePerlinNoise(x: Double(x) / 32.0, y: Double(y) / 32.0)
                let value = UInt8((noise + 1.0) * 127.5) // Convert from [-1,1] to [0,255]
                data[y * Int(size.width) + x] = value
            }
        }

        context.data?.copyMemory(from: data, byteCount: Int(size.width * size.height))

        return context.makeImage()
    }

    private func generatePerlinNoise(x: Double, y: Double) -> Double {
        // Simplified Perlin noise implementation
        let xi = Int(x) & 255
        let yi = Int(y) & 255
        let xf = x - Double(Int(x))
        let yf = y - Double(Int(y))

        let u = fade(xf)
        let v = fade(yf)

        let aa = hash(xi) + yi
        let ab = hash(xi) + yi + 1
        let ba = hash(xi + 1) + yi
        let bb = hash(xi + 1) + yi + 1

        let x1 = lerp(grad(hash(aa), xf, yf), grad(hash(ba), xf - 1, yf), u)
        let x2 = lerp(grad(hash(ab), xf, yf - 1), grad(hash(bb), xf - 1, yf - 1), u)

        return lerp(x1, x2, v)
    }

    private func fade(_ t: Double) -> Double {
        return t * t * t * (t * (t * 6 - 15) + 10)
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        return a + t * (b - a)
    }

    private func grad(_ hash: Int, _ x: Double, _ y: Double) -> Double {
        let h = hash & 15
        let u = h < 8 ? x : y
        let v = h < 4 ? y : (h == 12 || h == 14 ? x : 0)
        return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v)
    }

    private func hash(_ x: Int) -> Int {
        var h = x
        h = ((h >> 16) ^ h) &* 0x45d9f3b
        h = ((h >> 16) ^ h) &* 0x45d9f3b
        h = (h >> 16) ^ h
        return h & 255
    }

    // MARK: - Configuration and State Management

    override func applyConfiguration() {
        super.applyConfiguration()

        // Adjust animation based on quality level and configuration
        let intensity = currentConfiguration.intensity
        let duration = currentConfiguration.duration

        // Update animation timing based on configuration
        animationDuration = 8.0 / intensity // Higher intensity = faster animation
        colorTransitionDuration = duration * 2.0

        // Apply quality-specific optimizations
        applyQualityOptimizations()

        // Update layer properties if active
        if isActive {
            updateLayerProperties()
        }
    }

    private func applyQualityOptimizations() {
        guard let gradientLayer = gradientLayer,
              let noiseLayer = noiseLayer else { return }

        let intensity = currentConfiguration.intensity
        let properties = currentConfiguration.properties

        // Quality-based optimizations
        if let reducedEffects = properties["reducedEffects"] as? Bool, reducedEffects {
            // Low quality: Reduce complexity
            gradientLayer.locations = [0.0, 1.0] // Simpler gradient
            noiseLayer.opacity = Float(0.1 * intensity)
        } else if let enhancedEffects = properties["enhancedEffects"] as? Bool, enhancedEffects {
            // Ultra quality: Enhanced effects
            gradientLayer.locations = [0.0, 0.3, 0.7, 1.0] // More complex gradient
            noiseLayer.opacity = Float(0.3 * intensity)
        } else {
            // Normal quality
            gradientLayer.locations = [0.0, 0.5, 1.0]
            noiseLayer.opacity = Float(0.2 * intensity)
        }
    }

    private func updateLayerProperties() {
        guard let gradientLayer = gradientLayer else { return }

        let intensity = currentConfiguration.intensity

        // Update opacity based on intensity
        gradientLayer.opacity = Float(0.6 * intensity)

        // Update colors if custom color is specified
        if let colorName = currentConfiguration.properties["color"] as? String {
            updateColorsForTheme(colorName)
        }
    }

    private func updateColorsForTheme(_ theme: String) {
        guard let gradientLayer = gradientLayer else { return }

        let colors: [CGColor]
        switch theme.lowercased() {
        case "blue":
            colors = auroraColors[1]
        case "purple":
            colors = auroraColors[2]
        case "pink":
            colors = auroraColors[3]
        case "red":
            colors = auroraColors[4]
        default:
            colors = auroraColors[0] // Default to green
        }

        // Animate color change
        let animation = CABasicAnimation(keyPath: "colors")
        animation.fromValue = gradientLayer.colors
        animation.toValue = colors
        animation.duration = colorTransitionDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        gradientLayer.add(animation, forKey: "colorTransition")
        gradientLayer.colors = colors
    }

    // MARK: - Focus State Management

    override func performFocusUpdate(isFocused: Bool) {
        guard let gradientLayer = gradientLayer,
              let noiseLayer = noiseLayer else { return }

        let targetOpacity: Float = isFocused ? Float(0.8 * currentConfiguration.intensity) : Float(0.3 * currentConfiguration.intensity)
        let targetNoiseOpacity: Float = isFocused ? Float(0.4 * currentConfiguration.intensity) : Float(0.1 * currentConfiguration.intensity)

        // Animate opacity changes
        CATransaction.begin()
        CATransaction.setAnimationDuration(currentConfiguration.duration)
        CATransaction.setAnimationTimingFunction(currentConfiguration.timing)

        gradientLayer.opacity = targetOpacity
        noiseLayer.opacity = targetNoiseOpacity

        CATransaction.commit()

        // Start/stop animation based on focus
        if isFocused {
            startAnimation()
        } else {
            // Keep subtle animation even when unfocused
            adjustAnimationForUnfocused()
        }
    }

    // MARK: - Animation Management

    private func startAnimation() {
        stopAnimation() // Stop any existing animation

        // Start gradient animation
        startGradientAnimation()

        // Start color cycling
        startColorCycling()
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil

        gradientLayer?.removeAllAnimations()
        noiseLayer?.removeAllAnimations()
    }

    private func startGradientAnimation() {
        guard let gradientLayer = gradientLayer else { return }

        // Create flowing gradient animation
        let startPointAnimation = CABasicAnimation(keyPath: "startPoint")
        startPointAnimation.fromValue = CGPoint(x: 0.0, y: 0.0)
        startPointAnimation.toValue = CGPoint(x: 1.0, y: 0.0)
        startPointAnimation.duration = animationDuration
        startPointAnimation.repeatCount = .infinity
        startPointAnimation.autoreverses = true
        startPointAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let endPointAnimation = CABasicAnimation(keyPath: "endPoint")
        endPointAnimation.fromValue = CGPoint(x: 1.0, y: 1.0)
        endPointAnimation.toValue = CGPoint(x: 0.0, y: 1.0)
        endPointAnimation.duration = animationDuration * 1.2
        endPointAnimation.repeatCount = .infinity
        endPointAnimation.autoreverses = true
        endPointAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        gradientLayer.add(startPointAnimation, forKey: "startPointAnimation")
        gradientLayer.add(endPointAnimation, forKey: "endPointAnimation")
    }

    private func startColorCycling() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: colorTransitionDuration * 2, repeats: true) { [weak self] _ in
            self?.cycleToNextColor()
        }
    }

    private func cycleToNextColor() {
        currentColorIndex = (currentColorIndex + 1) % auroraColors.count

        guard let gradientLayer = gradientLayer else { return }

        let newColors = auroraColors[currentColorIndex]

        // Animate to new colors
        let animation = CABasicAnimation(keyPath: "colors")
        animation.fromValue = gradientLayer.colors
        animation.toValue = newColors
        animation.duration = colorTransitionDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        gradientLayer.add(animation, forKey: "colorCycle")
        gradientLayer.colors = newColors
    }

    private func adjustAnimationForUnfocused() {
        // Slow down animations when unfocused
        gradientLayer?.speed = 0.3
        noiseLayer?.speed = 0.3
    }

    // MARK: - Custom State Handling

    override func applyCustomState(_ state: String, configuration: BLLayerConfiguration) {
        super.applyCustomState(state, configuration: configuration)

        switch state.lowercased() {
        case "highlight":
            applyHighlightState()
        case "error":
            applyErrorState()
        case "success":
            applySuccessState()
        case "loading":
            applyLoadingState()
        case "disabled":
            applyDisabledState()
        default:
            // Return to normal state
            applyConfiguration()
        }
    }

    private func applyHighlightState() {
        updateColorsForTheme("blue")
        gradientLayer?.opacity = Float(0.9 * currentConfiguration.intensity)
    }

    private func applyErrorState() {
        updateColorsForTheme("red")
        // Add subtle shake animation
        addShakeAnimation()
    }

    private func applySuccessState() {
        updateColorsForTheme("green")
        // Add gentle pulse
        addPulseAnimation()
    }

    private func applyLoadingState() {
        // Faster color cycling for loading state
        animationDuration = 2.0
        colorTransitionDuration = 1.0
        startAnimation()
    }

    private func applyDisabledState() {
        gradientLayer?.opacity = Float(0.1 * currentConfiguration.intensity)
        stopAnimation()
    }

    private func addShakeAnimation() {
        guard let gradientLayer = gradientLayer else { return }

        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.values = [0, -5, 5, -3, 3, 0]
        shake.duration = 0.5
        shake.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        gradientLayer.add(shake, forKey: "shake")
    }

    private func addPulseAnimation() {
        guard let gradientLayer = gradientLayer else { return }

        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = gradientLayer.opacity
        pulse.toValue = Float(min(1.0, Double(gradientLayer.opacity) * 1.3))
        pulse.duration = 0.3
        pulse.autoreverses = true
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        gradientLayer.add(pulse, forKey: "pulse")
    }

    // MARK: - Cleanup

    override func cleanup() {
        stopAnimation()
        gradientLayer?.removeFromSuperlayer()
        noiseLayer?.removeFromSuperlayer()
        gradientLayer = nil
        noiseLayer = nil
        super.cleanup()
    }

    // MARK: - Layer Bounds Updates

    override func performSpecificSetup() {
        super.performSpecificSetup()

        // Update layer frames when container bounds change
        updateLayerFrames()
    }

    private func updateLayerFrames() {
        guard let containerView = containerView else { return }

        let bounds = containerView.bounds
        gradientLayer?.frame = bounds
        noiseLayer?.frame = bounds
    }
}

/// 内容增强层 - 完整实现
class BLContentEnhancementLayer: BLBaseVisualLayer {
    // MARK: - Properties

    private var blurEffectView: UIVisualEffectView?
    private var contentMaskLayer: CALayer?
    private var edgeEnhancementLayer: CAGradientLayer?
    private var adaptiveBlurLayer: CALayer?

    // Blur configuration
    private var currentBlurStyle: UIBlurEffect.Style = .regular
    private var blurIntensity: CGFloat = 0.8
    private var edgeEnhancementEnabled: Bool = true
    private var contentAdaptiveEnabled: Bool = true

    // Animation properties
    private var blurAnimationDuration: TimeInterval = 0.4
    private var intensityAnimationDuration: TimeInterval = 0.6

    // Content analysis
    private var contentBrightness: CGFloat = 0.5
    private var contentContrast: CGFloat = 1.0
    private var lastAnalysisTime: TimeInterval = 0

    init() {
        super.init(type: .contentEnhancement)
    }

    deinit {
        cleanupBlurEffects()
    }

    // MARK: - Layer Creation

    override func createMainLayer() {
        super.createMainLayer()

        // Create blur effect view
        createBlurEffectView()

        // Create content mask layer
        createContentMaskLayer()

        // Create edge enhancement layer
        createEdgeEnhancementLayer()

        // Create adaptive blur layer
        createAdaptiveBlurLayer()

        // Set initial state
        updateLayerVisibility()
    }

    private func createBlurEffectView() {
        guard let containerView = containerView else { return }

        let blurEffect = UIBlurEffect(style: currentBlurStyle)
        blurEffectView = UIVisualEffectView(effect: blurEffect)

        guard let blurEffectView = blurEffectView else { return }

        blurEffectView.frame = containerView.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurEffectView.alpha = 0.0 // Initial state

        // Add to container view (not as sublayer)
        containerView.addSubview(blurEffectView)
        containerView.sendSubviewToBack(blurEffectView)
    }

    private func createContentMaskLayer() {
        contentMaskLayer = CALayer()
        guard let contentMaskLayer = contentMaskLayer,
              let mainLayer = mainLayer else { return }

        contentMaskLayer.frame = mainLayer.bounds
        contentMaskLayer.backgroundColor = UIColor.white.cgColor
        contentMaskLayer.opacity = 0.0

        // Create subtle gradient mask for content awareness
        let maskGradient = CAGradientLayer()
        maskGradient.frame = contentMaskLayer.bounds
        maskGradient.colors = [
            UIColor.white.withAlphaComponent(0.9).cgColor,
            UIColor.white.withAlphaComponent(0.7).cgColor,
            UIColor.white.withAlphaComponent(0.9).cgColor,
        ]
        maskGradient.locations = [0.0, 0.5, 1.0]
        maskGradient.startPoint = CGPoint(x: 0.0, y: 0.0)
        maskGradient.endPoint = CGPoint(x: 1.0, y: 1.0)

        contentMaskLayer.addSublayer(maskGradient)
        mainLayer.addSublayer(contentMaskLayer)
    }

    private func createEdgeEnhancementLayer() {
        edgeEnhancementLayer = CAGradientLayer()
        guard let edgeEnhancementLayer = edgeEnhancementLayer,
              let mainLayer = mainLayer else { return }

        edgeEnhancementLayer.frame = mainLayer.bounds
        edgeEnhancementLayer.opacity = 0.0

        // Create edge enhancement gradient
        updateEdgeEnhancementGradient()

        mainLayer.addSublayer(edgeEnhancementLayer)
    }

    private func updateEdgeEnhancementGradient() {
        guard let edgeEnhancementLayer = edgeEnhancementLayer else { return }

        // Edge enhancement colors based on current configuration
        let baseColor = UIColor.white.withAlphaComponent(0.1)
        let edgeColor = UIColor.white.withAlphaComponent(0.3)

        edgeEnhancementLayer.colors = [
            edgeColor.cgColor,
            baseColor.cgColor,
            baseColor.cgColor,
            edgeColor.cgColor,
        ]

        edgeEnhancementLayer.locations = [0.0, 0.1, 0.9, 1.0]
        edgeEnhancementLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        edgeEnhancementLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
    }

    private func createAdaptiveBlurLayer() {
        adaptiveBlurLayer = CALayer()
        guard let adaptiveBlurLayer = adaptiveBlurLayer,
              let mainLayer = mainLayer else { return }

        adaptiveBlurLayer.frame = mainLayer.bounds
        adaptiveBlurLayer.backgroundColor = UIColor.clear.cgColor
        adaptiveBlurLayer.opacity = 0.0

        // Add subtle overlay for adaptive blur enhancement
        let overlayGradient = CAGradientLayer()
        overlayGradient.frame = adaptiveBlurLayer.bounds
        overlayGradient.colors = [
            UIColor.black.withAlphaComponent(0.05).cgColor,
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.05).cgColor,
        ]
        overlayGradient.locations = [0.0, 0.5, 1.0]

        adaptiveBlurLayer.addSublayer(overlayGradient)
        mainLayer.addSublayer(adaptiveBlurLayer)
    }

    // MARK: - Configuration and State Management

    override func applyConfiguration() {
        super.applyConfiguration()

        // Adjust blur based on configuration
        let intensity = currentConfiguration.intensity
        let duration = currentConfiguration.duration
        let properties = currentConfiguration.properties

        // Update blur intensity
        blurIntensity = 0.3 + (0.7 * intensity) // Range: 0.3 to 1.0
        blurAnimationDuration = duration * 1.5
        intensityAnimationDuration = duration * 2.0

        // Apply quality-specific optimizations
        applyQualityOptimizations()

        // Update blur style based on properties
        if let blurStyleName = properties["blurStyle"] as? String {
            updateBlurStyle(blurStyleName)
        }

        // Update feature flags
        edgeEnhancementEnabled = properties["edgeEnhancement"] as? Bool ?? true
        contentAdaptiveEnabled = properties["contentAdaptive"] as? Bool ?? true

        // Update layer properties if active
        if isActive {
            updateBlurProperties()
        }
    }

    private func applyQualityOptimizations() {
        let intensity = currentConfiguration.intensity
        let properties = currentConfiguration.properties

        if let reducedEffects = properties["reducedEffects"] as? Bool, reducedEffects {
            // Low quality: Simplified blur
            currentBlurStyle = .light
            edgeEnhancementEnabled = false
            contentAdaptiveEnabled = false
        } else if let enhancedEffects = properties["enhancedEffects"] as? Bool, enhancedEffects {
            // Ultra quality: Enhanced effects
            currentBlurStyle = .extraLight
            edgeEnhancementEnabled = true
            contentAdaptiveEnabled = true
        } else {
            // Normal quality
            currentBlurStyle = .regular
            edgeEnhancementEnabled = true
            contentAdaptiveEnabled = properties["contentAdaptive"] as? Bool ?? true
        }
    }

    private func updateBlurStyle(_ styleName: String) {
        let newStyle: UIBlurEffect.Style

        switch styleName.lowercased() {
        case "thin":
            newStyle = .light
        case "ultrathin":
            newStyle = .extraLight
        case "thick":
            newStyle = .dark
        case "chrome":
            newStyle = .regular
        default:
            newStyle = .regular
        }

        if newStyle != currentBlurStyle {
            currentBlurStyle = newStyle
            updateBlurEffect()
        }
    }

    private func updateBlurEffect() {
        guard let blurEffectView = blurEffectView else { return }

        let newBlurEffect = UIBlurEffect(style: currentBlurStyle)

        // Animate blur style change
        UIView.transition(with: blurEffectView, duration: blurAnimationDuration, options: .transitionCrossDissolve) {
            blurEffectView.effect = newBlurEffect
        }
    }

    private func updateBlurProperties() {
        guard let blurEffectView = blurEffectView else { return }

        let targetAlpha = blurIntensity * currentConfiguration.intensity

        // Animate blur intensity
        UIView.animate(withDuration: intensityAnimationDuration, delay: 0, options: [.curveEaseInOut]) {
            blurEffectView.alpha = targetAlpha
        }

        // Update other layers
        updateContentMaskOpacity()
        updateEdgeEnhancementOpacity()
        updateAdaptiveBlurOpacity()
    }

    private func updateContentMaskOpacity() {
        guard let contentMaskLayer = contentMaskLayer else { return }

        let targetOpacity = contentAdaptiveEnabled ? Float(0.3 * currentConfiguration.intensity) : 0.0

        CATransaction.begin()
        CATransaction.setAnimationDuration(intensityAnimationDuration)
        CATransaction.setAnimationTimingFunction(currentConfiguration.timing)

        contentMaskLayer.opacity = targetOpacity

        CATransaction.commit()
    }

    private func updateEdgeEnhancementOpacity() {
        guard let edgeEnhancementLayer = edgeEnhancementLayer else { return }

        let targetOpacity = edgeEnhancementEnabled ? Float(0.4 * currentConfiguration.intensity) : 0.0

        CATransaction.begin()
        CATransaction.setAnimationDuration(intensityAnimationDuration)
        CATransaction.setAnimationTimingFunction(currentConfiguration.timing)

        edgeEnhancementLayer.opacity = targetOpacity

        CATransaction.commit()
    }

    private func updateAdaptiveBlurOpacity() {
        guard let adaptiveBlurLayer = adaptiveBlurLayer else { return }

        let targetOpacity = contentAdaptiveEnabled ? Float(0.2 * currentConfiguration.intensity) : 0.0

        CATransaction.begin()
        CATransaction.setAnimationDuration(intensityAnimationDuration)
        CATransaction.setAnimationTimingFunction(currentConfiguration.timing)

        adaptiveBlurLayer.opacity = targetOpacity

        CATransaction.commit()
    }

    // MARK: - Focus State Management

    override func performFocusUpdate(isFocused: Bool) {
        let targetIntensity = isFocused ? blurIntensity : blurIntensity * 0.6
        let targetEdgeOpacity: Float = isFocused ? Float(0.4 * currentConfiguration.intensity) : Float(0.2 * currentConfiguration.intensity)

        // Animate blur intensity
        UIView.animate(withDuration: currentConfiguration.duration, delay: 0, options: [.curveEaseInOut]) {
            self.blurEffectView?.alpha = targetIntensity * self.currentConfiguration.intensity
        }

        // Animate edge enhancement
        CATransaction.begin()
        CATransaction.setAnimationDuration(currentConfiguration.duration)
        CATransaction.setAnimationTimingFunction(currentConfiguration.timing)

        if edgeEnhancementEnabled {
            edgeEnhancementLayer?.opacity = targetEdgeOpacity
        }

        CATransaction.commit()

        // Trigger content analysis if focused and adaptive enabled
        if isFocused && contentAdaptiveEnabled {
            performContentAnalysis()
        }
    }

    // MARK: - Content Analysis

    private func performContentAnalysis() {
        let currentTime = CACurrentMediaTime()

        // Throttle analysis to avoid performance impact
        guard currentTime - lastAnalysisTime > 0.5 else { return }
        lastAnalysisTime = currentTime

        // Simulate content analysis (in real implementation, this would analyze the underlying content)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.analyzeContentProperties()
        }
    }

    private func analyzeContentProperties() {
        // Simulate content brightness and contrast analysis
        // In real implementation, this would analyze the actual content behind the blur

        let simulatedBrightness = 0.3 + (Double.random(in: 0...1) * 0.4) // 0.3 to 0.7
        let simulatedContrast = 0.8 + (Double.random(in: 0...1) * 0.4) // 0.8 to 1.2

        DispatchQueue.main.async { [weak self] in
            self?.updateAdaptiveBlurForContent(brightness: simulatedBrightness, contrast: simulatedContrast)
        }
    }

    private func updateAdaptiveBlurForContent(brightness: CGFloat, contrast: CGFloat) {
        contentBrightness = brightness
        contentContrast = contrast

        // Adjust blur intensity based on content
        let adaptiveIntensity = calculateAdaptiveIntensity()

        // Update blur with adaptive intensity
        UIView.animate(withDuration: 0.8, delay: 0, options: [.curveEaseInOut]) {
            self.blurEffectView?.alpha = adaptiveIntensity * self.currentConfiguration.intensity
        }

        // Update edge enhancement based on contrast
        updateEdgeEnhancementForContent()
    }

    private func calculateAdaptiveIntensity() -> CGFloat {
        // Higher brightness content needs more blur for readability
        // Higher contrast content can handle less blur
        let brightnessAdjustment = contentBrightness * 0.3 // 0 to 0.21
        let contrastAdjustment = (2.0 - contentContrast) * 0.2 // Inverse relationship

        let adaptiveIntensity = blurIntensity + brightnessAdjustment + contrastAdjustment
        return max(0.2, min(1.0, adaptiveIntensity)) // Clamp to reasonable range
    }

    private func updateEdgeEnhancementForContent() {
        guard let edgeEnhancementLayer = edgeEnhancementLayer,
              edgeEnhancementEnabled else { return }

        // Higher contrast content benefits from more edge enhancement
        let contrastBasedOpacity = Float(contentContrast * 0.3 * currentConfiguration.intensity)
        let targetOpacity = max(0.1, min(0.6, contrastBasedOpacity))

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.8)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))

        edgeEnhancementLayer.opacity = targetOpacity

        CATransaction.commit()
    }

    // MARK: - Custom State Handling

    override func applyCustomState(_ state: String, configuration: BLLayerConfiguration) {
        super.applyCustomState(state, configuration: configuration)

        switch state.lowercased() {
        case "highlight":
            applyHighlightState()
        case "error":
            applyErrorState()
        case "success":
            applySuccessState()
        case "loading":
            applyLoadingState()
        case "disabled":
            applyDisabledState()
        case "reading":
            applyReadingState()
        case "media":
            applyMediaState()
        default:
            // Return to normal state
            applyConfiguration()
        }
    }

    private func applyHighlightState() {
        // Enhanced blur for highlight
        currentBlurStyle = .extraLight
        blurIntensity = 0.9
        edgeEnhancementEnabled = true
        updateBlurEffect()
        updateBlurProperties()
    }

    private func applyErrorState() {
        // Reduced blur for error visibility
        currentBlurStyle = .light
        blurIntensity = 0.4
        edgeEnhancementEnabled = false
        updateBlurEffect()
        updateBlurProperties()
    }

    private func applySuccessState() {
        // Gentle blur for success
        currentBlurStyle = .regular
        blurIntensity = 0.7
        edgeEnhancementEnabled = true
        updateBlurEffect()
        updateBlurProperties()
    }

    private func applyLoadingState() {
        // Minimal blur for loading
        currentBlurStyle = .light
        blurIntensity = 0.3
        edgeEnhancementEnabled = false
        contentAdaptiveEnabled = false
        updateBlurEffect()
        updateBlurProperties()
    }

    private func applyDisabledState() {
        // Very light blur for disabled
        currentBlurStyle = .extraLight
        blurIntensity = 0.2
        edgeEnhancementEnabled = false
        contentAdaptiveEnabled = false
        updateBlurEffect()
        updateBlurProperties()
    }

    private func applyReadingState() {
        // Optimized for text readability
        currentBlurStyle = .regular
        blurIntensity = 0.8
        edgeEnhancementEnabled = true
        contentAdaptiveEnabled = true
        updateBlurEffect()
        updateBlurProperties()
    }

    private func applyMediaState() {
        // Optimized for media content
        currentBlurStyle = .dark
        blurIntensity = 0.6
        edgeEnhancementEnabled = false
        contentAdaptiveEnabled = true
        updateBlurEffect()
        updateBlurProperties()
    }

    // MARK: - Cleanup

    override func cleanup() {
        cleanupBlurEffects()
        super.cleanup()
    }

    private func cleanupBlurEffects() {
        blurEffectView?.removeFromSuperview()
        blurEffectView = nil

        contentMaskLayer?.removeFromSuperlayer()
        contentMaskLayer = nil

        edgeEnhancementLayer?.removeFromSuperlayer()
        edgeEnhancementLayer = nil

        adaptiveBlurLayer?.removeFromSuperlayer()
        adaptiveBlurLayer = nil
    }

    // MARK: - Layer Bounds Updates

    override func performSpecificSetup() {
        super.performSpecificSetup()

        // Update layer frames when container bounds change
        updateLayerFrames()
    }

    private func updateLayerFrames() {
        guard let containerView = containerView else { return }

        let bounds = containerView.bounds

        blurEffectView?.frame = bounds
        contentMaskLayer?.frame = bounds
        edgeEnhancementLayer?.frame = bounds
        adaptiveBlurLayer?.frame = bounds

        // Update sublayer frames
        contentMaskLayer?.sublayers?.forEach { $0.frame = bounds }
        adaptiveBlurLayer?.sublayers?.forEach { $0.frame = bounds }
    }
}

/// 光效层 - 完整实现
class BLLightingEffectLayer: BLBaseVisualLayer {
    // MARK: - Properties

    private var particleEmitterLayer: CAEmitterLayer?
    private var focusRingLayer: CAShapeLayer?
    private var ambientGlowLayer: CAGradientLayer?
    private var sparkleLayer: CALayer?

    // Lighting configuration
    private var lightingIntensity: CGFloat = 0.6
    private var particleCount: Float = 50
    private var glowRadius: CGFloat = 20.0
    private var sparkleEnabled: Bool = true
    private var focusRingEnabled: Bool = true

    // Animation properties
    private var particleAnimationDuration: TimeInterval = 3.0
    private var glowAnimationDuration: TimeInterval = 2.0
    private var sparkleAnimationDuration: TimeInterval = 1.5

    // Color themes for lighting
    private let lightingColors: [[CGColor]] = [
        // Warm glow (default)
        [
            UIColor(red: 1.0, green: 0.9, blue: 0.6, alpha: 0.3).cgColor,
            UIColor(red: 1.0, green: 0.8, blue: 0.4, alpha: 0.2).cgColor,
            UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 0.1).cgColor,
        ],
        // Cool glow
        [
            UIColor(red: 0.6, green: 0.9, blue: 1.0, alpha: 0.3).cgColor,
            UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 0.2).cgColor,
            UIColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 0.1).cgColor,
        ],
        // Purple glow
        [
            UIColor(red: 0.9, green: 0.6, blue: 1.0, alpha: 0.3).cgColor,
            UIColor(red: 0.8, green: 0.4, blue: 1.0, alpha: 0.2).cgColor,
            UIColor(red: 0.7, green: 0.3, blue: 1.0, alpha: 0.1).cgColor,
        ],
        // Green glow
        [
            UIColor(red: 0.6, green: 1.0, blue: 0.7, alpha: 0.3).cgColor,
            UIColor(red: 0.4, green: 1.0, blue: 0.6, alpha: 0.2).cgColor,
            UIColor(red: 0.3, green: 1.0, blue: 0.5, alpha: 0.1).cgColor,
        ],
    ]

    private var currentColorTheme: Int = 0

    init() {
        super.init(type: .lightingEffect)
    }

    deinit {
        cleanupLightingEffects()
    }

    // MARK: - Layer Creation

    override func createMainLayer() {
        super.createMainLayer()

        // Create particle emitter layer
        createParticleEmitterLayer()

        // Create focus ring layer
        createFocusRingLayer()

        // Create ambient glow layer
        createAmbientGlowLayer()

        // Create sparkle layer
        createSparkleLayer()

        // Set initial state
        updateLayerVisibility()
    }

    private func createParticleEmitterLayer() {
        particleEmitterLayer = CAEmitterLayer()
        guard let particleEmitterLayer = particleEmitterLayer,
              let mainLayer = mainLayer else { return }

        particleEmitterLayer.frame = mainLayer.bounds
        particleEmitterLayer.emitterPosition = CGPoint(x: mainLayer.bounds.midX, y: mainLayer.bounds.midY)
        particleEmitterLayer.emitterSize = mainLayer.bounds.size
        particleEmitterLayer.emitterShape = .rectangle
        particleEmitterLayer.emitterMode = .surface
        particleEmitterLayer.renderMode = .additive

        // Create particle cell
        let particleCell = createParticleCell()
        particleEmitterLayer.emitterCells = [particleCell]

        // Initial state
        particleEmitterLayer.opacity = 0.0

        mainLayer.addSublayer(particleEmitterLayer)
    }

    private func createParticleCell() -> CAEmitterCell {
        let cell = CAEmitterCell()

        // Particle appearance
        cell.contents = createParticleImage()?.cgImage
        cell.birthRate = particleCount
        cell.lifetime = 3.0
        cell.lifetimeRange = 1.0

        // Particle physics
        cell.velocity = 20.0
        cell.velocityRange = 10.0
        cell.emissionRange = .pi * 2
        cell.spin = .pi / 4
        cell.spinRange = .pi / 8

        // Particle appearance animation
        cell.scale = 0.3
        cell.scaleRange = 0.2
        cell.scaleSpeed = -0.1

        cell.alphaRange = 0.3
        cell.alphaSpeed = -0.3

        // Color
        cell.color = lightingColors[currentColorTheme][0]
        cell.redRange = 0.2
        cell.greenRange = 0.2
        cell.blueRange = 0.2

        return cell
    }

    private func createParticleImage() -> UIImage? {
        let size = CGSize(width: 8, height: 8)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(ovalIn: rect)

            // Create radial gradient
            let colors = [UIColor.white.cgColor, UIColor.clear.cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0.0, 1.0])

            context.cgContext.saveGState()
            context.cgContext.addPath(path.cgPath)
            context.cgContext.clip()

            if let gradient = gradient {
                context.cgContext.drawRadialGradient(
                    gradient,
                    startCenter: CGPoint(x: size.width / 2, y: size.height / 2),
                    startRadius: 0,
                    endCenter: CGPoint(x: size.width / 2, y: size.height / 2),
                    endRadius: size.width / 2,
                    options: []
                )
            }

            context.cgContext.restoreGState()
        }
    }

    private func createFocusRingLayer() {
        focusRingLayer = CAShapeLayer()
        guard let focusRingLayer = focusRingLayer,
              let mainLayer = mainLayer else { return }

        focusRingLayer.frame = mainLayer.bounds
        focusRingLayer.fillColor = UIColor.clear.cgColor
        focusRingLayer.strokeColor = lightingColors[currentColorTheme][1]
        focusRingLayer.lineWidth = 2.0
        focusRingLayer.opacity = 0.0

        // Create ring path
        updateFocusRingPath()

        mainLayer.addSublayer(focusRingLayer)
    }

    private func updateFocusRingPath() {
        guard let focusRingLayer = focusRingLayer else { return }

        let bounds = focusRingLayer.bounds
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) * 0.4

        let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        focusRingLayer.path = path.cgPath
    }

    private func createAmbientGlowLayer() {
        ambientGlowLayer = CAGradientLayer()
        guard let ambientGlowLayer = ambientGlowLayer,
              let mainLayer = mainLayer else { return }

        ambientGlowLayer.frame = mainLayer.bounds
        ambientGlowLayer.type = .radial
        ambientGlowLayer.colors = lightingColors[currentColorTheme]
        ambientGlowLayer.locations = [0.0, 0.7, 1.0]
        ambientGlowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        ambientGlowLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        ambientGlowLayer.opacity = 0.0

        mainLayer.insertSublayer(ambientGlowLayer, at: 0) // Behind other layers
    }

    private func createSparkleLayer() {
        sparkleLayer = CALayer()
        guard let sparkleLayer = sparkleLayer,
              let mainLayer = mainLayer else { return }

        sparkleLayer.frame = mainLayer.bounds
        sparkleLayer.opacity = 0.0

        // Create sparkle sublayers
        createSparkleSublayers()

        mainLayer.addSublayer(sparkleLayer)
    }

    private func createSparkleSublayers() {
        guard let sparkleLayer = sparkleLayer else { return }

        let sparkleCount = 8
        let bounds = sparkleLayer.bounds

        for _ in 0..<sparkleCount {
            let sparkle = CAShapeLayer()

            // Random position
            let x = CGFloat.random(in: bounds.minX...bounds.maxX)
            let y = CGFloat.random(in: bounds.minY...bounds.maxY)
            let size = CGFloat.random(in: 2...4)

            sparkle.frame = CGRect(x: x, y: y, width: size, height: size)
            sparkle.path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: CGSize(width: size, height: size))).cgPath
            sparkle.fillColor = lightingColors[currentColorTheme][0]
            sparkle.opacity = 0.0

            sparkleLayer.addSublayer(sparkle)
        }
    }

    // MARK: - Configuration and State Management

    override func applyConfiguration() {
        super.applyConfiguration()

        // Adjust lighting based on configuration
        let intensity = currentConfiguration.intensity
        let duration = currentConfiguration.duration
        let properties = currentConfiguration.properties

        // Update lighting intensity
        lightingIntensity = 0.2 + (0.6 * intensity) // Range: 0.2 to 0.8
        particleCount = Float(20 + (50 * intensity)) // Range: 20 to 70
        glowRadius = 10.0 + (20.0 * intensity) // Range: 10 to 30

        // Update animation durations
        particleAnimationDuration = duration * 4.0
        glowAnimationDuration = duration * 3.0
        sparkleAnimationDuration = duration * 2.0

        // Apply quality-specific optimizations
        applyQualityOptimizations()

        // Update color theme if specified
        if let colorTheme = properties["lightingTheme"] as? String {
            updateColorTheme(colorTheme)
        }

        // Update feature flags
        sparkleEnabled = properties["sparkleEnabled"] as? Bool ?? true
        focusRingEnabled = properties["focusRingEnabled"] as? Bool ?? true

        // Update layer properties if active
        if isActive {
            updateLightingProperties()
        }
    }

    private func applyQualityOptimizations() {
        let intensity = currentConfiguration.intensity
        let properties = currentConfiguration.properties

        if let reducedEffects = properties["reducedEffects"] as? Bool, reducedEffects {
            // Low quality: Minimal effects
            particleCount = Float(10 + (20 * intensity))
            sparkleEnabled = false
            focusRingEnabled = false
        } else if let enhancedEffects = properties["enhancedEffects"] as? Bool, enhancedEffects {
            // Ultra quality: Enhanced effects
            particleCount = Float(30 + (80 * intensity))
            sparkleEnabled = true
            focusRingEnabled = true
        } else {
            // Normal quality
            particleCount = Float(20 + (50 * intensity))
            sparkleEnabled = properties["sparkleEnabled"] as? Bool ?? true
            focusRingEnabled = properties["focusRingEnabled"] as? Bool ?? true
        }
    }

    private func updateColorTheme(_ theme: String) {
        let newTheme: Int

        switch theme.lowercased() {
        case "cool":
            newTheme = 1
        case "purple":
            newTheme = 2
        case "green":
            newTheme = 3
        default:
            newTheme = 0 // Warm
        }

        if newTheme != currentColorTheme {
            currentColorTheme = newTheme
            updateLayerColors()
        }
    }

    private func updateLayerColors() {
        let colors = lightingColors[currentColorTheme]

        // Update ambient glow colors
        ambientGlowLayer?.colors = colors

        // Update focus ring color
        focusRingLayer?.strokeColor = colors[1]

        // Update particle colors
        if let particleCell = particleEmitterLayer?.emitterCells?.first {
            particleCell.color = colors[0]
        }

        // Update sparkle colors
        sparkleLayer?.sublayers?.forEach { layer in
            if let sparkle = layer as? CAShapeLayer {
                sparkle.fillColor = colors[0]
            }
        }
    }

    private func updateLightingProperties() {
        let targetOpacity = Float(lightingIntensity * currentConfiguration.intensity)

        // Update particle emitter
        updateParticleEmitter()

        // Update ambient glow
        updateAmbientGlow(targetOpacity: targetOpacity)

        // Update focus ring
        updateFocusRing(targetOpacity: targetOpacity)

        // Update sparkles
        updateSparkles(targetOpacity: targetOpacity)
    }

    private func updateParticleEmitter() {
        guard let particleEmitterLayer = particleEmitterLayer,
              let particleCell = particleEmitterLayer.emitterCells?.first else { return }

        let targetOpacity = Float(lightingIntensity * currentConfiguration.intensity)

        CATransaction.begin()
        CATransaction.setAnimationDuration(particleAnimationDuration)
        CATransaction.setAnimationTimingFunction(currentConfiguration.timing)

        particleEmitterLayer.opacity = targetOpacity
        particleCell.birthRate = particleCount

        CATransaction.commit()
    }

    private func updateAmbientGlow(targetOpacity: Float) {
        guard let ambientGlowLayer = ambientGlowLayer else { return }

        CATransaction.begin()
        CATransaction.setAnimationDuration(glowAnimationDuration)
        CATransaction.setAnimationTimingFunction(currentConfiguration.timing)

        ambientGlowLayer.opacity = targetOpacity * 0.6 // Subtle ambient glow

        CATransaction.commit()
    }

    private func updateFocusRing(targetOpacity: Float) {
        guard let focusRingLayer = focusRingLayer,
              focusRingEnabled else { return }

        CATransaction.begin()
        CATransaction.setAnimationDuration(glowAnimationDuration)
        CATransaction.setAnimationTimingFunction(currentConfiguration.timing)

        focusRingLayer.opacity = targetOpacity * 0.8

        CATransaction.commit()
    }

    private func updateSparkles(targetOpacity: Float) {
        guard let sparkleLayer = sparkleLayer,
              sparkleEnabled else { return }

        CATransaction.begin()
        CATransaction.setAnimationDuration(sparkleAnimationDuration)
        CATransaction.setAnimationTimingFunction(currentConfiguration.timing)

        sparkleLayer.opacity = targetOpacity * 0.7

        CATransaction.commit()
    }

    // MARK: - Focus State Management

    override func performFocusUpdate(isFocused: Bool) {
        let intensityMultiplier: CGFloat = isFocused ? 1.0 : 0.4
        let targetOpacity = Float(lightingIntensity * intensityMultiplier * currentConfiguration.intensity)

        // Animate particle system
        animateParticleSystem(isFocused: isFocused, targetOpacity: targetOpacity)

        // Animate focus ring
        animateFocusRing(isFocused: isFocused, targetOpacity: targetOpacity)

        // Animate ambient glow
        animateAmbientGlow(isFocused: isFocused, targetOpacity: targetOpacity)

        // Animate sparkles
        animateSparkles(isFocused: isFocused, targetOpacity: targetOpacity)
    }

    private func animateParticleSystem(isFocused: Bool, targetOpacity: Float) {
        guard let particleEmitterLayer = particleEmitterLayer,
              let particleCell = particleEmitterLayer.emitterCells?.first else { return }

        let targetBirthRate = isFocused ? particleCount : particleCount * 0.3

        CATransaction.begin()
        CATransaction.setAnimationDuration(currentConfiguration.duration)
        CATransaction.setAnimationTimingFunction(currentConfiguration.timing)

        particleEmitterLayer.opacity = targetOpacity
        particleCell.birthRate = targetBirthRate

        CATransaction.commit()
    }

    private func animateFocusRing(isFocused: Bool, targetOpacity: Float) {
        guard let focusRingLayer = focusRingLayer,
              focusRingEnabled else { return }

        let ringOpacity = isFocused ? targetOpacity * 0.8 : 0.0

        CATransaction.begin()
        CATransaction.setAnimationDuration(currentConfiguration.duration)
        CATransaction.setAnimationTimingFunction(currentConfiguration.timing)

        focusRingLayer.opacity = ringOpacity

        CATransaction.commit()

        // Add pulsing animation when focused
        if isFocused {
            addFocusRingPulse()
        } else {
            focusRingLayer.removeAnimation(forKey: "pulse")
        }
    }

    private func addFocusRingPulse() {
        guard let focusRingLayer = focusRingLayer else { return }

        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.1
        pulse.duration = 1.0
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        focusRingLayer.add(pulse, forKey: "pulse")
    }

    private func animateAmbientGlow(isFocused: Bool, targetOpacity: Float) {
        guard let ambientGlowLayer = ambientGlowLayer else { return }

        let glowOpacity = isFocused ? targetOpacity * 0.6 : targetOpacity * 0.2

        CATransaction.begin()
        CATransaction.setAnimationDuration(currentConfiguration.duration * 1.5)
        CATransaction.setAnimationTimingFunction(currentConfiguration.timing)

        ambientGlowLayer.opacity = glowOpacity

        CATransaction.commit()
    }

    private func animateSparkles(isFocused: Bool, targetOpacity: Float) {
        guard let sparkleLayer = sparkleLayer,
              sparkleEnabled else { return }

        let sparkleOpacity = isFocused ? targetOpacity * 0.7 : 0.0

        CATransaction.begin()
        CATransaction.setAnimationDuration(currentConfiguration.duration)
        CATransaction.setAnimationTimingFunction(currentConfiguration.timing)

        sparkleLayer.opacity = sparkleOpacity

        CATransaction.commit()

        // Add twinkling animation when focused
        if isFocused {
            addSparkleAnimation()
        } else {
            sparkleLayer.removeAllAnimations()
        }
    }

    private func addSparkleAnimation() {
        guard let sparkleLayer = sparkleLayer else { return }

        sparkleLayer.sublayers?.enumerated().forEach { index, layer in
            let delay = Double(index) * 0.2

            let twinkle = CABasicAnimation(keyPath: "opacity")
            twinkle.fromValue = 0.0
            twinkle.toValue = 1.0
            twinkle.duration = sparkleAnimationDuration
            twinkle.autoreverses = true
            twinkle.repeatCount = .infinity
            twinkle.beginTime = CACurrentMediaTime() + delay
            twinkle.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            layer.add(twinkle, forKey: "twinkle")
        }
    }

    // MARK: - Custom State Handling

    override func applyCustomState(_ state: String, configuration: BLLayerConfiguration) {
        super.applyCustomState(state, configuration: configuration)

        switch state.lowercased() {
        case "highlight":
            applyHighlightState()
        case "error":
            applyErrorState()
        case "success":
            applySuccessState()
        case "loading":
            applyLoadingState()
        case "disabled":
            applyDisabledState()
        case "celebration":
            applyCelebrationState()
        case "warning":
            applyWarningState()
        default:
            // Return to normal state
            applyConfiguration()
        }
    }

    private func applyHighlightState() {
        updateColorTheme("cool")
        lightingIntensity = 0.9
        particleCount = 80
        sparkleEnabled = true
        focusRingEnabled = true
        updateLightingProperties()
    }

    private func applyErrorState() {
        // Red-tinted lighting for error
        currentColorTheme = 0 // Use warm theme but will be tinted red
        lightingIntensity = 0.3
        particleCount = 20
        sparkleEnabled = false
        focusRingEnabled = false
        updateLightingProperties()

        // Add red tint
        addErrorTint()
    }

    private func addErrorTint() {
        let redTint = UIColor.red.withAlphaComponent(0.2).cgColor
        ambientGlowLayer?.colors = [redTint, UIColor.clear.cgColor]
    }

    private func applySuccessState() {
        updateColorTheme("green")
        lightingIntensity = 0.8
        particleCount = 60
        sparkleEnabled = true
        focusRingEnabled = true
        updateLightingProperties()

        // Add success pulse
        addSuccessPulse()
    }

    private func addSuccessPulse() {
        guard let ambientGlowLayer = ambientGlowLayer else { return }

        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = ambientGlowLayer.opacity
        pulse.toValue = Float(min(1.0, Double(ambientGlowLayer.opacity) * 1.5))
        pulse.duration = 0.5
        pulse.autoreverses = true
        pulse.repeatCount = 3
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        ambientGlowLayer.add(pulse, forKey: "successPulse")
    }

    private func applyLoadingState() {
        updateColorTheme("purple")
        lightingIntensity = 0.5
        particleCount = 40
        sparkleEnabled = false
        focusRingEnabled = true
        updateLightingProperties()

        // Add loading rotation
        addLoadingRotation()
    }

    private func addLoadingRotation() {
        guard let focusRingLayer = focusRingLayer else { return }

        let rotation = CABasicAnimation(keyPath: "transform.rotation")
        rotation.fromValue = 0
        rotation.toValue = Double.pi * 2
        rotation.duration = 2.0
        rotation.repeatCount = .infinity
        rotation.timingFunction = CAMediaTimingFunction(name: .linear)

        focusRingLayer.add(rotation, forKey: "loadingRotation")
    }

    private func applyDisabledState() {
        lightingIntensity = 0.1
        particleCount = 5
        sparkleEnabled = false
        focusRingEnabled = false
        updateLightingProperties()
    }

    private func applyCelebrationState() {
        updateColorTheme("warm")
        lightingIntensity = 1.0
        particleCount = 100
        sparkleEnabled = true
        focusRingEnabled = true
        updateLightingProperties()

        // Add celebration burst
        addCelebrationBurst()
    }

    private func addCelebrationBurst() {
        guard let particleEmitterLayer = particleEmitterLayer,
              let particleCell = particleEmitterLayer.emitterCells?.first else { return }

        // Temporary burst of particles
        let originalBirthRate = particleCell.birthRate

        particleCell.birthRate = 200

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            particleCell.birthRate = originalBirthRate
        }
    }

    private func applyWarningState() {
        // Orange-tinted lighting for warning
        currentColorTheme = 0 // Use warm theme
        lightingIntensity = 0.6
        particleCount = 30
        sparkleEnabled = true
        focusRingEnabled = true
        updateLightingProperties()
    }

    // MARK: - Cleanup

    override func cleanup() {
        cleanupLightingEffects()
        super.cleanup()
    }

    private func cleanupLightingEffects() {
        particleEmitterLayer?.removeFromSuperlayer()
        particleEmitterLayer = nil

        focusRingLayer?.removeFromSuperlayer()
        focusRingLayer = nil

        ambientGlowLayer?.removeFromSuperlayer()
        ambientGlowLayer = nil

        sparkleLayer?.removeFromSuperlayer()
        sparkleLayer = nil
    }

    // MARK: - Layer Bounds Updates

    override func performSpecificSetup() {
        super.performSpecificSetup()

        // Update layer frames when container bounds change
        updateLayerFrames()
    }

    private func updateLayerFrames() {
        guard let containerView = containerView else { return }

        let bounds = containerView.bounds

        particleEmitterLayer?.frame = bounds
        particleEmitterLayer?.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        particleEmitterLayer?.emitterSize = bounds.size

        focusRingLayer?.frame = bounds
        updateFocusRingPath()

        ambientGlowLayer?.frame = bounds
        sparkleLayer?.frame = bounds

        // Recreate sparkle sublayers for new bounds
        sparkleLayer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        createSparkleSublayers()
    }
}

/// 交互反馈层 - 占位实现
class BLInteractionFeedbackLayer: BLBaseVisualLayer {
    init() {
        super.init(type: .interactionFeedback)
    }

    override func createMainLayer() {
        // 将在P2-LD-008任务中实现微交互反馈
        super.createMainLayer()
        mainLayer?.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.01).cgColor
    }
}
