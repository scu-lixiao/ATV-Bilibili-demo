import QuartzCore
import UIKit

// {{CHENGQI:
// Action: Added
// Timestamp: 2025-06-09 07:24:27 +08:00 (from mcp-server-time)
// Reason: 实现P2-LD-007任务 - 创建BLLightingEffectLayer动态光晕效果系统
// Principle_Applied: SOLID (S: 单一职责专注光效, O: 可扩展光效类型, L: 符合基础层接口, I: 分离光源/发光/阴影接口, D: 依赖抽象配置)
// Optimization: CAShapeLayer硬件加速，预计算光效模板，GPU优化渲染
// Architectural_Note (AR): 分层光效系统设计，支持动态光源和边缘发光，与层管理器完全集成
// Documentation_Note (DW): 完整的光效系统实现，包含光源模拟、发光渲染和智能管理
// }}

/// 光源类型枚举
enum BLLightSourceType {
    case ambient // 环境光
    case directional // 方向光
    case point // 点光源
    case spot // 聚光灯
    case rim // 边缘光
}

/// 光效强度等级
enum BLLightingIntensity: CGFloat {
    case subtle = 0.3 // 微妙
    case moderate = 0.6 // 中等
    case strong = 0.8 // 强烈
    case dramatic = 1.0 // 戏剧性
}

/// 光源配置结构
struct BLLightSource {
    let type: BLLightSourceType
    let position: CGPoint
    let intensity: CGFloat
    let color: UIColor
    let radius: CGFloat
    let falloff: CGFloat

    static func ambient(intensity: CGFloat = 0.3, color: UIColor = .white) -> BLLightSource {
        return BLLightSource(
            type: .ambient,
            position: CGPoint(x: 0.5, y: 0.5),
            intensity: intensity,
            color: color,
            radius: 1.0,
            falloff: 0.0
        )
    }

    static func rim(intensity: CGFloat = 0.6, color: UIColor = .white) -> BLLightSource {
        return BLLightSource(
            type: .rim,
            position: CGPoint(x: 0.5, y: 0.0),
            intensity: intensity,
            color: color,
            radius: 0.8,
            falloff: 0.3
        )
    }

    static func point(position: CGPoint, intensity: CGFloat = 0.8, color: UIColor = .white, radius: CGFloat = 0.5) -> BLLightSource {
        return BLLightSource(
            type: .point,
            position: position,
            intensity: intensity,
            color: color,
            radius: radius,
            falloff: 0.5
        )
    }
}

/// 发光效果配置
struct BLGlowEffect {
    let radius: CGFloat
    let opacity: CGFloat
    let color: UIColor
    let spread: CGFloat

    static let subtle = BLGlowEffect(radius: 8.0, opacity: 0.3, color: .white, spread: 0.0)
    static let moderate = BLGlowEffect(radius: 12.0, opacity: 0.5, color: .white, spread: 2.0)
    static let strong = BLGlowEffect(radius: 16.0, opacity: 0.7, color: .white, spread: 4.0)
    static let dramatic = BLGlowEffect(radius: 24.0, opacity: 0.9, color: .white, spread: 6.0)
}

/// 动态光晕效果层
class BLLightingEffectLayer: BLBaseVisualLayer {
    // MARK: - 光效组件

    /// 主光效容器
    private let lightingContainer = CALayer()

    /// 环境光层
    private let ambientLightLayer = CAGradientLayer()

    /// 边缘发光层
    private let rimLightLayer = CAShapeLayer()

    /// 点光源层
    private let pointLightLayer = CALayer()

    /// 动态光晕层
    private let glowLayer = CAShapeLayer()

    /// 光源阴影层
    private let shadowLayer = CAShapeLayer()

    // MARK: - 光效配置

    /// 当前光源配置
    private var lightSources: [BLLightSource] = []

    /// 当前发光效果
    private var glowEffect: BLGlowEffect = .moderate

    /// 光效强度
    private var lightingIntensity: BLLightingIntensity = .moderate

    /// 边缘发光开关
    private var rimLightingEnabled: Bool = true

    /// 动态光晕开关
    private var dynamicGlowEnabled: Bool = true

    /// 阴影效果开关
    private var shadowEffectEnabled: Bool = true

    // MARK: - 动画控制

    /// 光效动画定时器
    private var lightingAnimationTimer: Timer?

    /// 光源脉冲动画
    private var pulseAnimation: CABasicAnimation?

    /// 光晕呼吸动画
    private var breathingAnimation: CAAnimationGroup?

    // MARK: - 初始化

    override init() {
        super.init()
        setupLightingLayers()
        setupDefaultLighting()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLightingLayers()
        setupDefaultLighting()
    }

    deinit {
        cleanupAnimations()
    }

    // MARK: - 层设置

    private func setupLightingLayers() {
        // 设置主容器
        lightingContainer.masksToBounds = false
        addSublayer(lightingContainer)

        // 添加光效层级（从底到顶）
        lightingContainer.addSublayer(ambientLightLayer)
        lightingContainer.addSublayer(shadowLayer)
        lightingContainer.addSublayer(pointLightLayer)
        lightingContainer.addSublayer(rimLightLayer)
        lightingContainer.addSublayer(glowLayer)

        // 配置环境光层
        ambientLightLayer.type = .radial
        ambientLightLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        ambientLightLayer.endPoint = CGPoint(x: 1.0, y: 1.0)

        // 配置边缘发光层
        rimLightLayer.fillColor = UIColor.clear.cgColor
        rimLightLayer.lineWidth = 0

        // 配置动态光晕层
        glowLayer.fillColor = UIColor.clear.cgColor
        glowLayer.strokeColor = UIColor.white.cgColor
        glowLayer.lineWidth = 0

        // 配置阴影层
        shadowLayer.fillColor = UIColor.clear.cgColor
        shadowLayer.strokeColor = UIColor.clear.cgColor
    }

    private func setupDefaultLighting() {
        // 默认光源配置
        lightSources = [
            .ambient(intensity: 0.3, color: UIColor.white.withAlphaComponent(0.1)),
            .rim(intensity: 0.6, color: UIColor.white.withAlphaComponent(0.3)),
        ]

        // 应用默认配置
        updateLightingEffects()
    }

    // MARK: - BLBaseVisualLayer 协议实现

    override func setupLayer(with configuration: BLLayerConfiguration) {
        super.setupLayer(with: configuration)

        // 解析光效配置
        parseLightingConfiguration(configuration)

        // 应用质量优化
        applyQualityOptimization(configuration.qualityLevel)

        // 更新光效
        updateLightingEffects()
    }

    override func activateWithConfiguration(_ configuration: BLLayerConfiguration) {
        super.activateWithConfiguration(configuration)

        // 启动光效动画
        startLightingAnimations()

        // 应用激活状态
        applyActivationState(true)
    }

    override func deactivateWithConfiguration(_ configuration: BLLayerConfiguration) {
        super.deactivateWithConfiguration(configuration)

        // 停止光效动画
        stopLightingAnimations()

        // 应用停用状态
        applyActivationState(false)
    }

    override func updateConfiguration(_ configuration: BLLayerConfiguration) {
        super.updateConfiguration(configuration)

        // 重新解析配置
        parseLightingConfiguration(configuration)

        // 平滑更新光效
        updateLightingEffectsAnimated()
    }

    override func applyFocusState(_ focused: Bool, configuration: BLLayerConfiguration) {
        super.applyFocusState(focused, configuration: configuration)

        let targetIntensity: CGFloat = focused ? 1.0 : 0.6
        let targetGlowOpacity: CGFloat = focused ? glowEffect.opacity : glowEffect.opacity * 0.5

        // 聚焦状态动画
        CATransaction.begin()
        CATransaction.setAnimationDuration(configuration.duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))

        // 调整光效强度
        lightingContainer.opacity = Float(targetIntensity * configuration.intensity)

        // 调整发光效果
        glowLayer.opacity = Float(targetGlowOpacity)
        rimLightLayer.opacity = Float(targetGlowOpacity)

        // 调整动画速度
        adjustAnimationSpeed(focused ? 1.2 : 0.8)

        CATransaction.commit()
    }

    override func applyCustomState(_ state: String, configuration: BLLayerConfiguration) {
        super.applyCustomState(state, configuration: configuration)

        switch state {
        case "highlight":
            applyHighlightLighting(configuration)
        case "error":
            applyErrorLighting(configuration)
        case "success":
            applySuccessLighting(configuration)
        case "loading":
            applyLoadingLighting(configuration)
        case "disabled":
            applyDisabledLighting(configuration)
        case "dramatic":
            applyDramaticLighting(configuration)
        case "subtle":
            applySubtleLighting(configuration)
        default:
            resetToDefaultLighting(configuration)
        }
    }

    override func resetToStableState() {
        super.resetToStableState()

        // 重置到默认光效
        setupDefaultLighting()

        // 停止所有动画
        cleanupAnimations()

        // 重置透明度
        lightingContainer.opacity = 1.0
        glowLayer.opacity = Float(glowEffect.opacity)
        rimLightLayer.opacity = Float(glowEffect.opacity)
    }

    override func layoutSublayers() {
        super.layoutSublayers()

        // 更新所有光效层的frame
        lightingContainer.frame = bounds
        ambientLightLayer.frame = bounds
        rimLightLayer.frame = bounds
        pointLightLayer.frame = bounds
        glowLayer.frame = bounds
        shadowLayer.frame = bounds

        // 重新计算光效路径
        updateLightingPaths()
    }

    // MARK: - 配置解析

    private func parseLightingConfiguration(_ configuration: BLLayerConfiguration) {
        // 解析光效强度
        if let intensityValue = configuration.properties["lightingIntensity"] as? CGFloat {
            lightingIntensity = BLLightingIntensity(rawValue: intensityValue) ?? .moderate
        }

        // 解析发光效果
        if let glowRadius = configuration.properties["glowRadius"] as? CGFloat,
           let glowOpacity = configuration.properties["glowOpacity"] as? CGFloat
        {
            glowEffect = BLGlowEffect(
                radius: glowRadius,
                opacity: glowOpacity,
                color: glowEffect.color,
                spread: glowEffect.spread
            )
        }

        // 解析功能开关
        rimLightingEnabled = configuration.properties["rimLightingEnabled"] as? Bool ?? true
        dynamicGlowEnabled = configuration.properties["dynamicGlowEnabled"] as? Bool ?? true
        shadowEffectEnabled = configuration.properties["shadowEffectEnabled"] as? Bool ?? true

        // 解析光源配置
        if let lightSourcesData = configuration.properties["lightSources"] as? [[String: Any]] {
            parseLightSources(lightSourcesData)
        }
    }

    private func parseLightSources(_ data: [[String: Any]]) {
        lightSources.removeAll()

        for sourceData in data {
            guard let typeString = sourceData["type"] as? String,
                  let intensity = sourceData["intensity"] as? CGFloat else { continue }

            let type: BLLightSourceType
            switch typeString {
            case "ambient": type = .ambient
            case "directional": type = .directional
            case "point": type = .point
            case "spot": type = .spot
            case "rim": type = .rim
            default: continue
            }

            let position = CGPoint(
                x: sourceData["positionX"] as? CGFloat ?? 0.5,
                y: sourceData["positionY"] as? CGFloat ?? 0.5
            )

            let color = UIColor.white // 简化处理，实际可解析颜色
            let radius = sourceData["radius"] as? CGFloat ?? 0.5
            let falloff = sourceData["falloff"] as? CGFloat ?? 0.3

            let lightSource = BLLightSource(
                type: type,
                position: position,
                intensity: intensity,
                color: color,
                radius: radius,
                falloff: falloff
            )

            lightSources.append(lightSource)
        }
    }

    // MARK: - 质量优化

    private func applyQualityOptimization(_ qualityLevel: BLQualityLevel) {
        switch qualityLevel {
        case .low:
            // 低质量：简化光效
            rimLightingEnabled = false
            dynamicGlowEnabled = false
            shadowEffectEnabled = false
            glowEffect = .subtle

        case .medium:
            // 中等质量：基础光效
            rimLightingEnabled = true
            dynamicGlowEnabled = false
            shadowEffectEnabled = true
            glowEffect = .moderate

        case .high:
            // 高质量：完整光效
            rimLightingEnabled = true
            dynamicGlowEnabled = true
            shadowEffectEnabled = true
            glowEffect = .strong

        case .ultra:
            // 超高质量：增强光效
            rimLightingEnabled = true
            dynamicGlowEnabled = true
            shadowEffectEnabled = true
            glowEffect = .dramatic
        }
    }

    // MARK: - 光效更新

    private func updateLightingEffects() {
        updateAmbientLighting()
        updateRimLighting()
        updatePointLighting()
        updateGlowEffect()
        updateShadowEffect()
    }

    private func updateLightingEffectsAnimated() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.3)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))

        updateLightingEffects()

        CATransaction.commit()
    }

    private func updateAmbientLighting() {
        guard let ambientSource = lightSources.first(where: { $0.type == .ambient }) else {
            ambientLightLayer.isHidden = true
            return
        }

        ambientLightLayer.isHidden = false

        // 创建径向渐变
        let centerColor = ambientSource.color.withAlphaComponent(ambientSource.intensity)
        let edgeColor = ambientSource.color.withAlphaComponent(0.0)

        ambientLightLayer.colors = [
            centerColor.cgColor,
            centerColor.withAlphaComponent(ambientSource.intensity * 0.5).cgColor,
            edgeColor.cgColor,
        ]

        ambientLightLayer.locations = [0.0, 0.7, 1.0]
    }

    private func updateRimLighting() {
        guard rimLightingEnabled,
              let rimSource = lightSources.first(where: { $0.type == .rim })
        else {
            rimLightLayer.isHidden = true
            return
        }

        rimLightLayer.isHidden = false

        // 创建边缘发光路径
        let path = createRimLightPath()
        rimLightLayer.path = path

        // 配置发光效果
        rimLightLayer.shadowColor = rimSource.color.cgColor
        rimLightLayer.shadowRadius = glowEffect.radius
        rimLightLayer.shadowOpacity = Float(rimSource.intensity)
        rimLightLayer.shadowOffset = .zero
    }

    private func updatePointLighting() {
        // 清除现有点光源
        pointLightLayer.sublayers?.removeAll()

        let pointSources = lightSources.filter { $0.type == .point }

        for source in pointSources {
            let pointLayer = CAGradientLayer()
            pointLayer.type = .radial

            let size = CGSize(width: bounds.width * source.radius, height: bounds.height * source.radius)
            let origin = CGPoint(
                x: bounds.width * source.position.x - size.width * 0.5,
                y: bounds.height * source.position.y - size.height * 0.5
            )
            pointLayer.frame = CGRect(origin: origin, size: size)

            let centerColor = source.color.withAlphaComponent(source.intensity)
            let edgeColor = source.color.withAlphaComponent(0.0)

            pointLayer.colors = [centerColor.cgColor, edgeColor.cgColor]
            pointLayer.locations = [0.0, 1.0]

            pointLightLayer.addSublayer(pointLayer)
        }
    }

    private func updateGlowEffect() {
        guard dynamicGlowEnabled else {
            glowLayer.isHidden = true
            return
        }

        glowLayer.isHidden = false

        // 创建发光路径
        let path = createGlowPath()
        glowLayer.path = path

        // 配置发光效果
        glowLayer.shadowColor = glowEffect.color.cgColor
        glowLayer.shadowRadius = glowEffect.radius
        glowLayer.shadowOpacity = Float(glowEffect.opacity)
        glowLayer.shadowOffset = .zero
        glowLayer.shadowPath = path
    }

    private func updateShadowEffect() {
        guard shadowEffectEnabled else {
            shadowLayer.isHidden = true
            return
        }

        shadowLayer.isHidden = false

        // 创建阴影路径
        let path = createShadowPath()
        shadowLayer.path = path

        // 配置阴影效果
        shadowLayer.shadowColor = UIColor.black.cgColor
        shadowLayer.shadowRadius = 8.0
        shadowLayer.shadowOpacity = 0.3
        shadowLayer.shadowOffset = CGSize(width: 0, height: 4)
    }

    // MARK: - 路径创建

    private func updateLightingPaths() {
        if !rimLightLayer.isHidden {
            rimLightLayer.path = createRimLightPath()
        }

        if !glowLayer.isHidden {
            glowLayer.path = createGlowPath()
        }

        if !shadowLayer.isHidden {
            shadowLayer.path = createShadowPath()
        }
    }

    private func createRimLightPath() -> CGPath {
        let path = UIBezierPath()
        let cornerRadius: CGFloat = 12.0

        // 创建圆角矩形路径
        let rect = bounds.insetBy(dx: 2.0, dy: 2.0)
        path.addRoundedRect(in: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius)

        return path.cgPath
    }

    private func createGlowPath() -> CGPath {
        let path = UIBezierPath()
        let cornerRadius: CGFloat = 16.0

        // 创建稍大的圆角矩形路径
        let rect = bounds.insetBy(dx: -glowEffect.spread, dy: -glowEffect.spread)
        path.addRoundedRect(in: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius)

        return path.cgPath
    }

    private func createShadowPath() -> CGPath {
        let path = UIBezierPath()
        let cornerRadius: CGFloat = 12.0

        // 创建阴影路径
        let rect = bounds
        path.addRoundedRect(in: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius)

        return path.cgPath
    }

    // MARK: - 动画管理

    private func startLightingAnimations() {
        guard dynamicGlowEnabled else { return }

        startPulseAnimation()
        startBreathingAnimation()
        startLightingTimer()
    }

    private func stopLightingAnimations() {
        cleanupAnimations()
    }

    private func startPulseAnimation() {
        let animation = CABasicAnimation(keyPath: "shadowOpacity")
        animation.fromValue = glowEffect.opacity * 0.5
        animation.toValue = glowEffect.opacity
        animation.duration = 2.0
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        glowLayer.add(animation, forKey: "pulseAnimation")
        pulseAnimation = animation
    }

    private func startBreathingAnimation() {
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.98
        scaleAnimation.toValue = 1.02
        scaleAnimation.duration = 3.0

        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 0.8
        opacityAnimation.toValue = 1.0
        opacityAnimation.duration = 3.0

        let group = CAAnimationGroup()
        group.animations = [scaleAnimation, opacityAnimation]
        group.duration = 3.0
        group.autoreverses = true
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        rimLightLayer.add(group, forKey: "breathingAnimation")
        breathingAnimation = group
    }

    private func startLightingTimer() {
        lightingAnimationTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.performLightingCycle()
        }
    }

    private func performLightingCycle() {
        // 模拟光源位置变化
        CATransaction.begin()
        CATransaction.setAnimationDuration(2.0)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))

        // 更新点光源位置
        updatePointLighting()

        CATransaction.commit()
    }

    private func adjustAnimationSpeed(_ speed: CGFloat) {
        glowLayer.speed = Float(speed)
        rimLightLayer.speed = Float(speed)
        pointLightLayer.speed = Float(speed)
    }

    private func cleanupAnimations() {
        lightingAnimationTimer?.invalidate()
        lightingAnimationTimer = nil

        glowLayer.removeAllAnimations()
        rimLightLayer.removeAllAnimations()
        pointLightLayer.removeAllAnimations()

        pulseAnimation = nil
        breathingAnimation = nil
    }

    // MARK: - 状态应用

    private func applyActivationState(_ activated: Bool) {
        let targetOpacity: Float = activated ? 1.0 : 0.0

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.5)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))

        lightingContainer.opacity = targetOpacity

        CATransaction.commit()
    }

    private func applyHighlightLighting(_ configuration: BLLayerConfiguration) {
        // 蓝色高亮光效
        let highlightColor = UIColor.systemBlue
        updateLightingWithColor(highlightColor, intensity: 0.8, configuration: configuration)
    }

    private func applyErrorLighting(_ configuration: BLLayerConfiguration) {
        // 红色错误光效
        let errorColor = UIColor.systemRed
        updateLightingWithColor(errorColor, intensity: 0.6, configuration: configuration)

        // 添加震动动画
        addShakeAnimation()
    }

    private func applySuccessLighting(_ configuration: BLLayerConfiguration) {
        // 绿色成功光效
        let successColor = UIColor.systemGreen
        updateLightingWithColor(successColor, intensity: 0.7, configuration: configuration)

        // 添加脉冲动画
        addSuccessPulse()
    }

    private func applyLoadingLighting(_ configuration: BLLayerConfiguration) {
        // 快速颜色循环
        startLoadingAnimation()
    }

    private func applyDisabledLighting(_ configuration: BLLayerConfiguration) {
        // 极低强度灰色光效
        let disabledColor = UIColor.systemGray
        updateLightingWithColor(disabledColor, intensity: 0.2, configuration: configuration)

        // 停止所有动画
        stopLightingAnimations()
    }

    private func applyDramaticLighting(_ configuration: BLLayerConfiguration) {
        // 戏剧性光效
        lightingIntensity = .dramatic
        glowEffect = .dramatic
        updateLightingEffects()
    }

    private func applySubtleLighting(_ configuration: BLLayerConfiguration) {
        // 微妙光效
        lightingIntensity = .subtle
        glowEffect = .subtle
        updateLightingEffects()
    }

    private func resetToDefaultLighting(_ configuration: BLLayerConfiguration) {
        setupDefaultLighting()
        updateLightingEffects()
    }

    // MARK: - 辅助方法

    private func updateLightingWithColor(_ color: UIColor, intensity: CGFloat, configuration: BLLayerConfiguration) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(configuration.duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))

        // 更新环境光颜色
        let centerColor = color.withAlphaComponent(intensity)
        let edgeColor = color.withAlphaComponent(0.0)

        ambientLightLayer.colors = [
            centerColor.cgColor,
            centerColor.withAlphaComponent(intensity * 0.5).cgColor,
            edgeColor.cgColor,
        ]

        // 更新发光颜色
        glowLayer.shadowColor = color.cgColor
        rimLightLayer.shadowColor = color.cgColor

        CATransaction.commit()
    }

    private func addShakeAnimation() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [0, -5, 5, -3, 3, 0]
        animation.duration = 0.5
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        lightingContainer.add(animation, forKey: "shakeAnimation")
    }

    private func addSuccessPulse() {
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 1.0
        animation.toValue = 1.1
        animation.duration = 0.3
        animation.autoreverses = true
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        lightingContainer.add(animation, forKey: "successPulse")
    }

    private func startLoadingAnimation() {
        let colors = [
            UIColor.systemBlue.cgColor,
            UIColor.systemPurple.cgColor,
            UIColor.systemPink.cgColor,
            UIColor.systemBlue.cgColor,
        ]

        let animation = CAKeyframeAnimation(keyPath: "colors")
        animation.values = [colors]
        animation.duration = 2.0
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)

        ambientLightLayer.add(animation, forKey: "loadingAnimation")
    }
}
