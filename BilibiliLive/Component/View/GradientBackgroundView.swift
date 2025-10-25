//
//  GradientBackgroundView.swift
//  BilibiliLive
//
//  Created by Claude-4-Sonnet on 2025/10/24.
//  深邃渐变背景视图 - 为高级感提供光感基础
//

import UIKit

/// 深邃渐变背景视图
/// 提供从纯黑到微亮再到纯黑的垂直渐变
/// 打造"高级订阅服务"般的视觉深度
class GradientBackgroundView: UIView {
    // MARK: - Properties

    private let gradientLayer = CAGradientLayer()
    private var animationTimer: Timer?

    /// 渐变样式
    enum Style {
        case vertical // 垂直渐变 (默认)
        case radial // 径向渐变 (从中心扩散)
        case animated // 动态渐变 (微妙的呼吸效果)
    }

    private let style: Style

    // MARK: - Initialization

    init(style: Style = .vertical) {
        self.style = style
        super.init(frame: .zero)
        setupGradient()
    }

    required init?(coder: NSCoder) {
        style = .vertical
        super.init(coder: coder)
        setupGradient()
    }

    // MARK: - Setup

    private func setupGradient() {
        // 配置渐变层
        gradientLayer.colors = ColorPalette.backgroundGradientColors
        gradientLayer.locations = ColorPalette.backgroundGradientLocations

        switch style {
        case .vertical:
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)

        case .radial:
            // 径向渐变效果 (通过起止点模拟)
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
            gradientLayer.type = .radial

        case .animated:
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
            startBreathingAnimation()
        }

        layer.insertSublayer(gradientLayer, at: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    // MARK: - Animation

    /// 启动微妙的呼吸动画
    /// 渐变会缓慢地在不同强度之间过渡
    private func startBreathingAnimation() {
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [0.0, 0.5, 1.0]
        animation.toValue = [0.0, 0.55, 1.0]
        animation.duration = 4.0
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        gradientLayer.add(animation, forKey: "breathingAnimation")
    }

    /// 停止动画
    func stopAnimation() {
        gradientLayer.removeAnimation(forKey: "breathingAnimation")
    }

    // MARK: - Public Methods

    /// 更新渐变颜色
    /// - Parameter colors: 新的颜色数组
    func updateColors(_ colors: [CGColor], animated: Bool = true) {
        if animated {
            let animation = CABasicAnimation(keyPath: "colors")
            animation.fromValue = gradientLayer.colors
            animation.toValue = colors
            animation.duration = 0.5
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            gradientLayer.add(animation, forKey: "colorChange")
        }
        gradientLayer.colors = colors
    }

    // MARK: - Cleanup

    deinit {
        stopAnimation()
        animationTimer?.invalidate()
    }
}

// MARK: - UIView Extension for Easy Background Addition

extension UIView {
    /// 为视图添加深邃渐变背景
    /// - Parameter style: 渐变样式
    /// - Returns: 创建的渐变背景视图
    @discardableResult
    func addGradientBackground(style: GradientBackgroundView.Style = .vertical) -> GradientBackgroundView {
        let gradientView = GradientBackgroundView(style: style)
        gradientView.frame = bounds
        gradientView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(gradientView, at: 0)
        return gradientView
    }
}

// MARK: - Premium Card Effect Helper

extension UIView {
    /// 应用高级卡片效果包
    /// 包含: 阴影 + 圆角 + 微妙的顶部高光
    func applyPremiumCardStyle(cornerRadius: CGFloat = 12, shadowRadius: CGFloat = 12) {
        // 1. 圆角
        layer.cornerRadius = cornerRadius
        layer.masksToBounds = false

        // 2. 高级阴影
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.5
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = shadowRadius
        layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: cornerRadius
        ).cgPath

        // 3. 微妙的顶部高光 (使用渐变层)
        let highlightLayer = CAGradientLayer()
        highlightLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height * 0.3)
        highlightLayer.colors = ColorPalette.cardHighlightGradientColors
        highlightLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        highlightLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        highlightLayer.cornerRadius = cornerRadius
        highlightLayer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

        // 只在不存在高光层时添加
        if layer.sublayers?.contains(where: { $0.name == "highlightLayer" }) == false {
            highlightLayer.name = "highlightLayer"
            layer.insertSublayer(highlightLayer, at: 0)
        }
    }

    /// 移除高级卡片样式
    func removePremiumCardStyle() {
        layer.shadowOpacity = 0
        layer.sublayers?.first(where: { $0.name == "highlightLayer" })?.removeFromSuperlayer()
    }
}
