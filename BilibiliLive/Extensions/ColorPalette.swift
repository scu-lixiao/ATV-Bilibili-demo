//
//  ColorPalette.swift
//  BilibiliLive
//
//  Created by Claude-4-Sonnet on 2025/10/24.
//  tvOS 26 Liquid Glass 深邃暗黑主题色彩系统
//

import UIKit

/// tvOS 26 深邃暗黑主题色彩系统
/// 设计理念: 纯黑背景 + 微妙层次 + 高级光感
enum ColorPalette {
    // MARK: - Background Colors (背景色层次)

    /// 纯黑背景 - 最深邃的基础层 #000000
    /// 用于: 主视图背景, 全屏播放器背景
    static let background = UIColor(hex: 0x000000)

    /// 微提亮背景 - 第二层 #0A0A0A
    /// 用于: 内容区域背景, 轻微区分主背景
    static let backgroundElevated = UIColor(hex: 0x0A0A0A)

    /// 表面色 - 卡片和组件背景 #121212
    /// 用于: 卡片背景, 列表背景
    static let surface = UIColor(hex: 0x121212)

    /// 浮起表面 - 悬浮元素 #1C1C1E
    /// 用于: 悬浮按钮, 弹出层, 焦点元素
    static let surfaceElevated = UIColor(hex: 0x1C1C1E)

    // MARK: - Text Colors (文本色)

    /// 主要文本 - 最高对比度 #FFFFFF
    /// 用于: 标题, 重要文本
    static let textPrimary = UIColor.white

    /// 次要文本 - 60% 不透明度
    /// 用于: 副标题, 描述文本
    static let textSecondary = UIColor(hex: 0xEBEBF5, alpha: 0.6)

    /// 三级文本 - 30% 不透明度
    /// 用于: 辅助信息, 时间戳
    static let textTertiary = UIColor(hex: 0xEBEBF5, alpha: 0.3)

    /// 禁用文本 - 18% 不透明度
    static let textDisabled = UIColor(hex: 0xEBEBF5, alpha: 0.18)

    // MARK: - Brand Colors (品牌色 - 保留 Bilibili 特色)

    /// Bilibili 蓝 - 主品牌色 #00aeec
    /// 用于: 交互元素, 强调按钮, 选中态
    static let accent = UIColor(hex: 0x00aeec)

    /// Bilibili 粉 - 副品牌色 #ff6699
    /// 用于: 点赞, 收藏, 特殊标记
    static let accentPink = UIColor(hex: 0xff6699)

    /// 品牌色暗色版 - 用于按下态
    static let accentDark = UIColor(hex: 0x008EBC)

    // MARK: - Functional Colors (功能色)

    /// 成功 - Apple 标准绿
    static let success = UIColor(hex: 0x34C759)

    /// 警告 - Apple 标准橙
    static let warning = UIColor(hex: 0xFF9F0A)

    /// 错误 - Apple 标准红
    static let error = UIColor(hex: 0xFF3B30)

    /// 信息 - 使用品牌蓝
    static let info = accent

    // MARK: - Overlay Colors (叠加层)

    /// 模态遮罩 - 60% 不透明黑色
    /// 用于: 弹出层背景
    static let modalOverlay = UIColor(hex: 0x000000, alpha: 0.6)

    /// 轻遮罩 - 30% 不透明黑色
    /// 用于: 图片渐变遮罩
    static let lightOverlay = UIColor(hex: 0x000000, alpha: 0.3)

    // MARK: - Separator (分割线)

    /// 分割线 - 15% 不透明白色
    static let separator = UIColor(hex: 0xFFFFFF, alpha: 0.15)

    /// 粗分割线 - 25% 不透明白色
    static let separatorStrong = UIColor(hex: 0xFFFFFF, alpha: 0.25)

    // MARK: - Focus & Interaction (焦点与交互)

    /// 焦点边框 - 亮白色
    static let focusRing = UIColor.white

    /// 焦点阴影色 - 品牌色半透明
    static let focusShadow = UIColor(hex: 0x00aeec, alpha: 0.4)

    // MARK: - Gradient Definitions (渐变定义)

    /// 背景渐变 - 从纯黑到微亮再到纯黑
    static let backgroundGradientColors: [CGColor] = [
        UIColor(hex: 0x000000).cgColor,
        UIColor(hex: 0x0A0A0A).cgColor,
        UIColor(hex: 0x000000).cgColor,
    ]

    static let backgroundGradientLocations: [NSNumber] = [0.0, 0.5, 1.0]

    /// 卡片高光渐变 - 用于顶部微光效果
    static let cardHighlightGradientColors: [CGColor] = [
        UIColor(hex: 0xFFFFFF, alpha: 0.05).cgColor,
        UIColor(hex: 0xFFFFFF, alpha: 0.0).cgColor,
    ]

    /// 品牌色渐变 - 用于特殊效果
    static let accentGradientColors: [CGColor] = [
        UIColor(hex: 0x00aeec).cgColor,
        UIColor(hex: 0x0088CC).cgColor,
    ]
}

// MARK: - UIColor 扩展保持兼容

extension UIColor {
    /// 主题背景色 - 兼容现有代码
    static var themeBackground: UIColor {
        ColorPalette.background
    }

    /// 主题表面色
    static var themeSurface: UIColor {
        ColorPalette.surface
    }

    /// 主题文本色
    static var themeText: UIColor {
        ColorPalette.textPrimary
    }

    /// 主题次要文本色
    static var themeTextSecondary: UIColor {
        ColorPalette.textSecondary
    }
}
