//
//  ThemeManager.swift
//  BilibiliLive
//
//  Created by Claude-4-Sonnet on 2025/10/24.
//  tvOS 26 主题管理器 - 自动适配系统版本
//

import UIKit

/// 主题变更通知
extension Notification.Name {
    static let themeDidChange = Notification.Name("ThemeDidChange")
}

/// tvOS 26 主题管理器
/// 功能:
/// 1. 检测系统版本,自动选择 Liquid Glass 或传统模糊
/// 2. 统一的颜色和材质访问接口
/// 3. 主题变更通知机制
class ThemeManager {
    // MARK: - Singleton

    static let shared = ThemeManager()

    private init() {
        setupObservers()
    }

    // MARK: - System Capabilities

    /// 当前设备是否支持 Liquid Glass
    /// tvOS 26+ 且 Apple TV 4K (2nd gen) 及更新型号
    var supportsLiquidGlass: Bool {
        if #available(tvOS 26.0, *) {
            // 理论上 tvOS 26 应该都支持,但保留检测逻辑
            return true
        }
        return false
    }

    /// 当前系统版本信息
    var systemVersion: String {
        return UIDevice.current.systemVersion
    }

    // MARK: - Color Accessors

    /// 主背景色 - 纯黑
    var backgroundColor: UIColor {
        return ColorPalette.background
    }

    /// 提亮背景色
    var backgroundElevatedColor: UIColor {
        return ColorPalette.backgroundElevated
    }

    /// 表面色
    var surfaceColor: UIColor {
        return ColorPalette.surface
    }

    /// 浮起表面色
    var surfaceElevatedColor: UIColor {
        return ColorPalette.surfaceElevated
    }

    /// 主文本色
    var textPrimaryColor: UIColor {
        return ColorPalette.textPrimary
    }

    /// 次要文本色
    var textSecondaryColor: UIColor {
        return ColorPalette.textSecondary
    }

    /// 三级文本色
    var textTertiaryColor: UIColor {
        return ColorPalette.textTertiary
    }

    /// 品牌强调色
    var accentColor: UIColor {
        return ColorPalette.accent
    }

    /// 品牌粉色
    var accentPinkColor: UIColor {
        return ColorPalette.accentPink
    }

    /// 分割线色
    var separatorColor: UIColor {
        return ColorPalette.separator
    }

    // MARK: - Material Creation

    /// 创建适配当前系统的视觉效果
    /// - Parameters:
    ///   - style: 材质样式
    ///   - tintColor: 可选的色调
    /// - Returns: UIVisualEffect 实例
    func createEffect(style: MaterialStyle, tintColor: UIColor? = nil) -> UIVisualEffect {
        if #available(tvOS 26.0, *), supportsLiquidGlass {
            return createGlassEffect(style: style, tintColor: tintColor)
        } else {
            return createBlurEffect(style: style)
        }
    }

    /// 创建 Liquid Glass 效果 (tvOS 26+)
    @available(tvOS 26.0, *)
    private func createGlassEffect(style: MaterialStyle, tintColor: UIColor?) -> UIVisualEffect {
        let glassStyle: UIGlassEffect.Style
        switch style {
        case .control:
            glassStyle = .clear // 控制栏最透明
        case .surface, .popup:
            glassStyle = .regular // 表面和弹出层使用常规
        }

        let effect = UIGlassEffect(style: glassStyle)
        if let tintColor = tintColor {
            effect.tintColor = tintColor
        }
        return effect
    }

    /// 创建传统模糊效果 (降级方案)
    private func createBlurEffect(style: MaterialStyle) -> UIVisualEffect {
        let blurStyle: UIBlurEffect.Style
        switch style {
        case .control:
            blurStyle = .dark
        case .surface:
            blurStyle = .dark
        case .popup:
            blurStyle = .prominent
        }
        return UIBlurEffect(style: blurStyle)
    }

    // MARK: - Gradient Helpers

    /// 创建背景渐变层
    /// - Returns: CAGradientLayer 配置好的渐变层
    func createBackgroundGradientLayer() -> CAGradientLayer {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = ColorPalette.backgroundGradientColors
        gradientLayer.locations = ColorPalette.backgroundGradientLocations
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        return gradientLayer
    }

    /// 创建卡片高光渐变层
    func createCardHighlightGradientLayer() -> CAGradientLayer {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = ColorPalette.cardHighlightGradientColors
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0.3)
        return gradientLayer
    }

    // MARK: - Shadow Presets

    /// 应用高级卡片阴影
    /// - Parameter layer: 目标图层
    func applyPremiumShadow(to layer: CALayer) {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.5
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 12
        layer.shadowPath = UIBezierPath(
            roundedRect: layer.bounds,
            cornerRadius: layer.cornerRadius
        ).cgPath
    }

    /// 应用焦点阴影
    /// - Parameter layer: 目标图层
    func applyFocusShadow(to layer: CALayer) {
        layer.shadowColor = ColorPalette.focusShadow.cgColor
        layer.shadowOpacity = 0.8
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 20
    }

    /// 移除阴影
    /// - Parameter layer: 目标图层
    func removeShadow(from layer: CALayer) {
        layer.shadowOpacity = 0
    }

    // MARK: - Button Specific Styles

    /// 应用按钮焦点视觉效果（增强版）
    /// - Parameters:
    ///   - layer: 目标图层
    ///   - buttonType: 按钮类型，决定效果强度
    func applyButtonFocusEffect(to layer: CALayer, buttonType: String = "action") {
        let isActionButton = buttonType == "action"
        
        layer.shadowColor = isActionButton ? 
            ColorPalette.accentPink.cgColor : 
            UIColor.black.cgColor
        layer.shadowOpacity = isActionButton ? 0.9 : 0.7
        layer.shadowOffset = CGSize(width: 0, height: isActionButton ? 10 : 8)
        layer.shadowRadius = isActionButton ? 24 : 20
    }

    /// 创建按钮专用的渐变配置
    /// - Parameter accentColor: 是否使用品牌强调色
    /// - Returns: 渐变颜色数组
    func createButtonGradientColors(useAccent: Bool = false) -> [CGColor] {
        if useAccent {
            return [
                ColorPalette.accentPink.withAlphaComponent(0.35).cgColor,
                ColorPalette.accent.withAlphaComponent(0.25).cgColor,
                UIColor.clear.cgColor
            ]
        } else {
            return [
                ColorPalette.surfaceElevated.withAlphaComponent(0.3).cgColor,
                UIColor.clear.cgColor
            ]
        }
    }

    /// 获取按钮图标色（根据状态）
    /// - Parameter isFocused: 是否处于焦点状态
    /// - Returns: 图标颜色
    func buttonIconColor(isFocused: Bool) -> UIColor {
        return isFocused ? textPrimaryColor : textSecondaryColor
    }

    /// 获取按钮文本色（根据状态）
    /// - Parameter isFocused: 是否处于焦点状态
    /// - Returns: 文本颜色
    func buttonTextColor(isFocused: Bool) -> UIColor {
        return isFocused ? UIColor.black : textPrimaryColor
    }

    // MARK: - Notification

    private func setupObservers() {
        // 监听系统外观变化(虽然我们主要是暗黑主题,但保留扩展性)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTraitCollectionChange),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func handleTraitCollectionChange() {
        // 发送主题变更通知
        NotificationCenter.default.post(name: .themeDidChange, object: nil)
    }

    /// 手动触发主题刷新
    func refreshTheme() {
        NotificationCenter.default.post(name: .themeDidChange, object: nil)
    }

    // MARK: - Debug Info

    /// 获取调试信息
    var debugInfo: String {
        return """
        ThemeManager Debug Info:
        - System Version: \(systemVersion)
        - Supports Liquid Glass: \(supportsLiquidGlass)
        - Current Theme: Deep Dark with Liquid Glass
        """
    }
}

// MARK: - Material Style Enum

/// 材质样式
enum MaterialStyle {
    case control // 控制栏 - 最透明,用于播放器控制等
    case surface // 表面 - 中等透明,用于卡片背景
    case popup // 弹出层 - 较不透明,用于模态视图
}
