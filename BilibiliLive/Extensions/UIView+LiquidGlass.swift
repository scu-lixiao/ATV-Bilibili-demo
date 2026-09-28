//
//  UIView+LiquidGlass.swift
//  BilibiliLive
//
//  Liquid Glass effect extensions for tvOS 26
//  Created by AI Assistant on 2025/11/8
//

import UIKit

@MainActor
extension UIView {
    // MARK: - Liquid Glass Effects

    /// Applies Liquid Glass effect
    /// - Parameters:
    ///   - style: Glass effect style (.clear for most use cases)
    ///   - tintColor: Optional tint color for the glass
    ///   - cornerRadius: Corner radius for the glass container
    ///   - interactive: Whether glass should respond to interactions
    /// - Returns: 创建的玻璃视图；圆角需要随容器变化时（如可展开的菜单），调用方可持有它同步更新
    @discardableResult
    func applyLiquidGlass(
        style: UIGlassEffect.Style = .clear,
        tintColor: UIColor? = nil,
        cornerRadius: CGFloat = CornerRadiusToken.medium.rawValue,
        interactive: Bool = false
    ) -> UIVisualEffectView {
        // Remove any existing blur effects
        subviews.first(where: { $0 is UIVisualEffectView })?.removeFromSuperview()

        let effectView = UIVisualEffectView(effect: UIGlassEffect(style: style))
        effectView.clipsToBounds = true
        effectView.layer.cornerRadius = cornerRadius
        effectView.layer.cornerCurve = .continuous
        effectView.isUserInteractionEnabled = interactive

        if let tint = tintColor {
            effectView.contentView.backgroundColor = tint
        }

        // Insert at the bottom of the view hierarchy
        insertSubview(effectView, at: 0)
        effectView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        return effectView
    }

    /// Adds a subtle glass stroke/border for definition
    func applyGlassStroke(
        width: CGFloat = 1.0,
        color: UIColor? = nil
    ) {
        layer.borderWidth = width
        layer.borderColor = (color ?? UIColor.glassStrokeBorder).cgColor
    }

    // MARK: - Shadow

    /// Applies premium shadow with optional colored glow
    /// - Parameters:
    ///   - elevation: Shadow elevation level
    ///   - glowColor: Optional colored shadow for accents
    func applyPremiumShadow(
        elevation: ShadowElevation = .level2,
        glowColor: UIColor? = nil
    ) {
        layer.shadowOffset = elevation.offset
        layer.shadowRadius = elevation.radius
        layer.shadowOpacity = elevation.opacity
        layer.shadowColor = (glowColor ?? UIColor.deepShadow).cgColor
        layer.masksToBounds = false
        // 不要开启 shouldRasterize：调用方都是包含实时玻璃 / 聚焦动画的容器，
        // 光栅化会让玻璃失去实时效果，且内容一变就重新离屏光栅化，反而更慢。
        // 尺寸固定的容器可在布局后自行设置 shadowPath 来省掉阴影的离屏计算。
    }

    // MARK: - Gradient Background

    /// Applies a dark gradient background
    func applyDarkGradient() {
        let gradient = UIColor.createDarkGradient()
        gradient.frame = bounds
        layer.insertSublayer(gradient, at: 0)
    }

    // MARK: - Smooth Animations

    /// Animate with spring physics
    func animateSpring(
        _ params: SpringParams = .standard,
        animations: @escaping () -> Void,
        completion: ((Bool) -> Void)? = nil
    ) {
        UIView.animate(
            withDuration: params.duration,
            delay: 0,
            usingSpringWithDamping: params.damping,
            initialSpringVelocity: params.velocity,
            options: [.curveEaseInOut, .allowUserInteraction],
            animations: animations,
            completion: completion
        )
    }
}
