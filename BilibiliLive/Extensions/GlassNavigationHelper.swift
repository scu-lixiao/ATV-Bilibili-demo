//
//  GlassNavigationHelper.swift
//  BilibiliLive
//
//  Unified Glass Navigation System for tvOS 26
//  Created by AI Assistant on 2025/11/11
//

import UIKit

// MARK: - Glass Layer Configuration

/// Configuration for multi-layer glass effects
struct GlassLayerConfig {
    let cornerRadius: CGFloat
    let baseTint: UIColor
    let focusedTint: UIColor
    let strokeEnabled: Bool
    let glowEnabled: Bool
    let shadowElevation: ShadowElevation

    /// Preset for menu navigation items
    @MainActor
    static var menuItem: GlassLayerConfig {
        GlassLayerConfig(
            cornerRadius: 30.0,
            baseTint: .glassNeutralTintDark,
            focusedTint: .glassPinkTintDark,
            strokeEnabled: true,
            glowEnabled: true,
            shadowElevation: .level2
        )
    }

    /// Preset for sub-navigation headers
    @MainActor
    static var subNavigation: GlassLayerConfig {
        GlassLayerConfig(
            cornerRadius: CornerRadiusToken.medium.rawValue,
            baseTint: .glassBlueTintDark,
            focusedTint: .glassBlueTintDark,
            strokeEnabled: true,
            glowEnabled: false,
            shadowElevation: .level1
        )
    }
}

// MARK: - Glass Panel View

/// 导航类元素（菜单项、分区标题等）的玻璃背景。
///
/// - 玻璃视图只创建一次，焦点 / 显隐变化只更新 tint、描边、高光和阴影，
///   不再像之前那样每次焦点变化都销毁并重建 `UIVisualEffectView`。
/// - 玻璃、描边、阴影共用同一个圆角，避免描边圆角与玻璃圆角不一致。
/// - 阴影使用 `shadowPath`，不需要离屏渲染；也不再对包含实时玻璃的视图开启光栅化。
/// - 显隐通过设置 / 清空 `effect` 实现，在动画块中会呈现系统的玻璃浮现动画
///   （对 `UIVisualEffectView` 改 alpha 或 isHidden 会让效果渲染异常或生硬跳变）。
@MainActor
final class GlassPanelView: UIView {
    var config: GlassLayerConfig {
        didSet {
            setNeedsLayout()
            applyState()
        }
    }

    private(set) var isGlassFocused = false
    private(set) var isGlassVisible = true

    private let effectView = UIVisualEffectView()
    private let highlightLayer = CAGradientLayer()

    init(config: GlassLayerConfig) {
        self.config = config
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        isUserInteractionEnabled = false
        layer.cornerCurve = .continuous

        effectView.isUserInteractionEnabled = false
        effectView.clipsToBounds = true
        effectView.layer.cornerCurve = .continuous
        addSubview(effectView)

        // 顶部高光放在玻璃内部，自然被玻璃圆角裁剪
        highlightLayer.colors = [
            UIColor.white.withAlphaComponent(0.25).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor,
        ]
        highlightLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        highlightLayer.endPoint = CGPoint(x: 0.5, y: 0.5)
        highlightLayer.opacity = 0
        effectView.contentView.layer.addSublayer(highlightLayer)

        applyState()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = min(config.cornerRadius, bounds.height / 2)
        layer.cornerRadius = radius
        effectView.frame = bounds
        effectView.layer.cornerRadius = radius
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        highlightLayer.frame = effectView.contentView.bounds
        CATransaction.commit()
    }

    func setFocused(_ focused: Bool) {
        guard focused != isGlassFocused else { return }
        isGlassFocused = focused
        applyState()
    }

    func setGlassVisible(_ visible: Bool) {
        guard visible != isGlassVisible else { return }
        isGlassVisible = visible
        applyState()
    }

    private func applyState() {
        let focused = isGlassFocused
        let visible = isGlassVisible

        if visible {
            if effectView.effect == nil {
                effectView.effect = UIGlassEffect(style: .clear)
            }
            effectView.contentView.backgroundColor = focused ? config.focusedTint : config.baseTint
        } else {
            effectView.effect = nil
            effectView.contentView.backgroundColor = .clear
        }

        highlightLayer.opacity = visible && focused && config.glowEnabled ? 1 : 0

        // 聚焦时的描边同时承担了原来 "inner glow" 图层的作用
        if visible && config.strokeEnabled {
            layer.borderWidth = focused ? 1.5 : 1.0
            layer.borderColor = (focused ? UIColor.glassInnerGlow : UIColor.glassStrokeBorder).cgColor
        } else {
            layer.borderWidth = 0
        }

        let elevation: ShadowElevation = focused ? .focused : config.shadowElevation
        layer.shadowColor = (focused ? UIColor.pinkGlowShadow : UIColor.deepShadow).cgColor
        layer.shadowOffset = elevation.offset
        layer.shadowRadius = elevation.radius
        layer.shadowOpacity = visible ? elevation.opacity : 0
    }
}
