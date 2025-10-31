//
//  UIGlassEffect+Helpers.swift
//  BilibiliLive
//
//  Created for tvOS 26 Liquid Glass optimization
//

import UIKit

@available(tvOS 26.0, *)
extension UIVisualEffectView {
    /// 创建带有 Liquid Glass 效果的视图
    /// - Parameters:
    ///   - tintColor: 玻璃色调，默认为半透明系统蓝色
    ///   - isInteractive: 是否启用交互式效果
    ///   - cornerRadius: 圆角半径
    /// - Returns: 配置好的 UIVisualEffectView
    static func createGlassView(
        tintColor: UIColor? = UIColor.systemBlue.withAlphaComponent(0.15),
        isInteractive: Bool = false,
        cornerRadius: CGFloat = 20
    ) -> UIVisualEffectView {
        let glassEffect = UIGlassEffect()
        if let tintColor = tintColor {
            glassEffect.tintColor = tintColor
        }
        glassEffect.isInteractive = isInteractive
        
        let visualEffectView = UIVisualEffectView(effect: glassEffect)
        visualEffectView.layer.cornerRadius = cornerRadius
        visualEffectView.clipsToBounds = true
        
        return visualEffectView
    }
}

@available(tvOS 26.0, *)
extension UIView {
    /// 为现有视图添加 Liquid Glass 背景
    /// - Parameters:
    ///   - tintColor: 玻璃色调
    ///   - isInteractive: 是否启用交互式效果
    func addGlassBackground(
        tintColor: UIColor? = UIColor.systemBlue.withAlphaComponent(0.15),
        isInteractive: Bool = false
    ) {
        let glassView = UIVisualEffectView.createGlassView(
            tintColor: tintColor,
            isInteractive: isInteractive,
            cornerRadius: layer.cornerRadius
        )
        glassView.frame = bounds
        glassView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(glassView, at: 0)
    }
}

@available(tvOS 26.0, *)
class GlassCardView: UIView {
    /// 创建可复用的玻璃卡片视图
    private let visualEffectView: UIVisualEffectView
    private let contentContainerView = UIView()
    
    init(
        frame: CGRect,
        tintColor: UIColor? = UIColor.systemBlue.withAlphaComponent(0.15),
        isInteractive: Bool = false,
        cornerRadius: CGFloat = 20
    ) {
        visualEffectView = UIVisualEffectView.createGlassView(
            tintColor: tintColor,
            isInteractive: isInteractive,
            cornerRadius: cornerRadius
        )
        
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        visualEffectView = UIVisualEffectView.createGlassView()
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        // 添加玻璃效果视图
        visualEffectView.frame = bounds
        visualEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(visualEffectView)
        
        // 添加内容容器
        contentContainerView.frame = bounds
        contentContainerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentContainerView.backgroundColor = .clear
        visualEffectView.contentView.addSubview(contentContainerView)
    }
    
    /// 添加内容视图到玻璃卡片
    func addContent(_ view: UIView) {
        view.frame = contentContainerView.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentContainerView.addSubview(view)
    }
    
    /// 更新玻璃效果的色调
    func updateTintColor(_ color: UIColor) {
        if let glassEffect = visualEffectView.effect as? UIGlassEffect {
            glassEffect.tintColor = color
            visualEffectView.effect = glassEffect
        }
    }
}

/// 玻璃效果配置辅助工具
@available(tvOS 26.0, *)
struct GlassEffectConfiguration {
    static let playerControl = UIColor.systemBlue.withAlphaComponent(0.12)
    static let settingsPanel = UIColor.systemGray.withAlphaComponent(0.18)
    static let videoDetail = UIColor.black.withAlphaComponent(0.25)
    static let overlay = UIColor.white.withAlphaComponent(0.08)
    
    /// 标准圆角半径
    static let standardCornerRadius: CGFloat = 20
    static let smallCornerRadius: CGFloat = 12
    static let largeCornerRadius: CGFloat = 28
}
