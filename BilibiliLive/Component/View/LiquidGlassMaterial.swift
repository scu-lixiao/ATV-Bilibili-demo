//
//  LiquidGlassMaterial.swift
//  BilibiliLive
//
//  Created by Claude-4-Sonnet on 2025/10/24.
//  Liquid Glass 材质封装 - 简化使用,自动降级
//

import UIKit

/// Liquid Glass 材质视图
/// 自动检测系统版本并应用合适的视觉效果
/// tvOS 26+: UIGlassEffect
/// tvOS < 26: UIBlurEffect (降级)
class LiquidGlassView: UIVisualEffectView {
    // MARK: - Properties

    private let materialStyle: MaterialStyle
    private var customTintColor: UIColor?

    // MARK: - Initialization

    /// 初始化 Liquid Glass 视图
    /// - Parameters:
    ///   - style: 材质样式 (.control, .surface, .popup)
    ///   - tintColor: 可选的色调颜色
    init(style: MaterialStyle, tintColor: UIColor? = nil) {
        materialStyle = style
        customTintColor = tintColor

        // 创建合适的效果
        let effect = ThemeManager.shared.createEffect(
            style: style,
            tintColor: tintColor
        )

        super.init(effect: effect)

        setupView()
    }

    required init?(coder: NSCoder) {
        materialStyle = .surface
        customTintColor = nil
        super.init(coder: coder)
        setupView()
    }

    // MARK: - Setup

    private func setupView() {
        // 设置基础属性
        clipsToBounds = true
        layer.masksToBounds = true

        // 注册主题变更通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleThemeChange),
            name: .themeDidChange,
            object: nil
        )
    }

    // MARK: - Theme Updates

    @objc private func handleThemeChange() {
        // 主题变更时重新应用效果
        let newEffect = ThemeManager.shared.createEffect(
            style: materialStyle,
            tintColor: customTintColor
        )

        UIView.animate(withDuration: 0.3) {
            self.effect = newEffect
        }
    }

    // MARK: - Public Methods

    /// 动画显示材质效果
    /// - Parameter duration: 动画时长
    func materialize(duration: TimeInterval = 0.3) {
        let targetEffect = effect
        effect = nil

        UIView.animate(withDuration: duration) {
            self.effect = targetEffect
        }
    }

    /// 动画隐藏材质效果
    /// - Parameter duration: 动画时长
    func dematerialize(duration: TimeInterval = 0.3) {
        UIView.animate(withDuration: duration) {
            self.effect = nil
        }
    }

    /// 更新色调
    /// - Parameter color: 新的色调颜色
    func updateTintColor(_ color: UIColor?) {
        customTintColor = color

        if #available(tvOS 26.0, *), let glassEffect = effect as? UIGlassEffect {
            glassEffect.tintColor = color
        }
    }

    // MARK: - Cleanup

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Convenience Factory

extension LiquidGlassView {
    /// 创建控制栏材质视图 - 最透明
    static func control(tintColor: UIColor? = nil) -> LiquidGlassView {
        return LiquidGlassView(style: .control, tintColor: tintColor)
    }

    /// 创建表面材质视图 - 中等透明
    static func surface(tintColor: UIColor? = nil) -> LiquidGlassView {
        return LiquidGlassView(style: .surface, tintColor: tintColor)
    }

    /// 创建弹出层材质视图 - 较不透明
    static func popup(tintColor: UIColor? = nil) -> LiquidGlassView {
        return LiquidGlassView(style: .popup, tintColor: tintColor)
    }
}

// MARK: - Liquid Glass Container

/// Liquid Glass 容器视图
/// 用于将多个 Glass 元素组合在一起,实现流动融合效果
@available(tvOS 26.0, *)
class LiquidGlassContainerView: UIVisualEffectView {
    // MARK: - Properties

    private var glassViews: [UIView] = []
    var containerSpacing: CGFloat = 20.0 {
        didSet {
            updateContainerEffect()
        }
    }

    // MARK: - Initialization

    override init(effect: UIVisualEffect?) {
        super.init(effect: nil)
        setupContainer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupContainer()
    }

    // MARK: - Setup

    private func setupContainer() {
        updateContainerEffect()
    }

    private func updateContainerEffect() {
        let containerEffect = UIGlassContainerEffect()
        containerEffect.spacing = containerSpacing
        effect = containerEffect
    }

    // MARK: - Public Methods

    /// 添加 Glass 子视图
    /// - Parameter view: 要添加的视图
    func addGlassSubview(_ view: UIView) {
        glassViews.append(view)
        contentView.addSubview(view)
    }

    /// 批量添加 Glass 子视图
    /// - Parameter views: 视图数组
    func addGlassSubviews(_ views: [UIView]) {
        views.forEach { addGlassSubview($0) }
    }
}

// MARK: - UIView Extension for Easy Material Application

extension UIView {
    /// 为视图添加 Liquid Glass 背景
    /// - Parameters:
    ///   - style: 材质样式
    ///   - tintColor: 可选色调
    func applyLiquidGlass(style: MaterialStyle, tintColor: UIColor? = nil) {
        let glassView = LiquidGlassView(style: style, tintColor: tintColor)
        glassView.frame = bounds
        glassView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(glassView, at: 0)
    }

    /// 应用高级阴影效果
    func applyPremiumShadow() {
        ThemeManager.shared.applyPremiumShadow(to: layer)
    }

    /// 应用焦点阴影效果
    func applyFocusShadow() {
        ThemeManager.shared.applyFocusShadow(to: layer)
    }

    /// 移除阴影
    func removeShadow() {
        ThemeManager.shared.removeShadow(from: layer)
    }
}

// MARK: - Animatable Transition Helper

extension LiquidGlassView {
    /// 平滑过渡到新样式
    /// - Parameters:
    ///   - newStyle: 新的材质样式
    ///   - duration: 动画时长
    func transition(to newStyle: MaterialStyle, duration: TimeInterval = 0.3) {
        let newEffect = ThemeManager.shared.createEffect(
            style: newStyle,
            tintColor: customTintColor
        )

        UIView.animate(withDuration: duration) {
            self.effect = newEffect
        }
    }
}
