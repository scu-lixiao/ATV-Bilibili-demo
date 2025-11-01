//
//  UIViewController+LiquidGlass.swift
//  BilibiliLive
//
//  Created for tvOS 26 Liquid Glass Full Application
//  提供便捷的 ViewController 级别 Liquid Glass 应用方法
//

import UIKit
import SnapKit

// MARK: - Liquid Glass Scene Configuration

/// Liquid Glass 场景配置
/// 为不同界面提供预定义的视觉效果配置
@available(tvOS 26.0, *)
struct LiquidGlassSceneConfig {
    let style: MaterialStyle
    let tintColor: UIColor?
    let animationDuration: TimeInterval
    let useMaterializeAnimation: Bool
    
    // MARK: - Predefined Scenes
    
    /// 播放器场景 - 最透明，专注内容
    static let player = LiquidGlassSceneConfig(
        style: .control,
        tintColor: UIColor.black.withAlphaComponent(0.15),
        animationDuration: 0.35,
        useMaterializeAnimation: true
    )
    
    /// Feed 流场景 - 轻量背景
    static let feed = LiquidGlassSceneConfig(
        style: .surface,
        tintColor: UIColor.systemBlue.withAlphaComponent(0.08),
        animationDuration: 0.3,
        useMaterializeAnimation: true
    )
    
    /// 视频详情场景 - 突出内容卡片
    static let videoDetail = LiquidGlassSceneConfig(
        style: .surface,
        tintColor: GlassEffectConfiguration.videoDetail,
        animationDuration: 0.4,
        useMaterializeAnimation: true
    )
    
    /// 直播间场景 - 动态氛围
    static let liveRoom = LiquidGlassSceneConfig(
        style: .surface,
        tintColor: UIColor.systemPink.withAlphaComponent(0.12),
        animationDuration: 0.3,
        useMaterializeAnimation: true
    )
    
    /// 搜索场景 - 清晰输入
    static let search = LiquidGlassSceneConfig(
        style: .surface,
        tintColor: UIColor.systemGray.withAlphaComponent(0.15),
        animationDuration: 0.3,
        useMaterializeAnimation: true
    )
    
    /// 设置场景 - 稳重专业
    static let settings = LiquidGlassSceneConfig(
        style: .surface,
        tintColor: GlassEffectConfiguration.settingsPanel,
        animationDuration: 0.35,
        useMaterializeAnimation: true
    )
    
    /// 弹出层场景 - 模态对话框
    static let popup = LiquidGlassSceneConfig(
        style: .popup,
        tintColor: UIColor.black.withAlphaComponent(0.35),
        animationDuration: 0.3,
        useMaterializeAnimation: true
    )
    
    /// 控制按钮场景 - 交互元素
    static let control = LiquidGlassSceneConfig(
        style: .control,
        tintColor: GlassEffectConfiguration.playerControl,
        animationDuration: 0.25,
        useMaterializeAnimation: false
    )
}

// MARK: - UIViewController Extension

extension UIViewController {
    
    // MARK: - Background Application
    
    /// 为 ViewController 应用 Liquid Glass 背景
    /// - Parameters:
    ///   - config: 场景配置
    ///   - insertAtIndex: 插入层级（默认 0，最底层）
    /// - Returns: 创建的 LiquidGlassView 实例
    @available(tvOS 26.0, *)
    @discardableResult
    func applyLiquidGlassBackground(
        config: LiquidGlassSceneConfig,
        insertAtIndex: Int = 0
    ) -> LiquidGlassView? {
        guard #available(tvOS 26.0, *), ThemeManager.shared.supportsLiquidGlass else {
            // 降级：应用传统背景
            applyFallbackBackground()
            return nil
        }
        
        // 创建 Liquid Glass 背景
        let glassView = LiquidGlassView(
            style: config.style,
            tintColor: config.tintColor
        )
        
        view.insertSubview(glassView, at: insertAtIndex)
        glassView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 应用 materialize 动画
        if config.useMaterializeAnimation {
            glassView.materialize(duration: config.animationDuration)
        }
        
        return glassView
    }
    
    /// 应用降级背景（tvOS < 26）
    private func applyFallbackBackground() {
        let effectView = UIVisualEffectView(
            effect: ThemeManager.shared.createEffect(style: .surface)
        )
        view.insertSubview(effectView, at: 0)
        effectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    // MARK: - Convenience Methods
    
    /// 快速应用播放器场景 Glass 效果
    @available(tvOS 26.0, *)
    func applyPlayerGlassBackground() {
        applyLiquidGlassBackground(config: .player)
    }
    
    /// 快速应用 Feed 场景 Glass 效果
    @available(tvOS 26.0, *)
    func applyFeedGlassBackground() {
        applyLiquidGlassBackground(config: .feed)
    }
    
    /// 快速应用视频详情场景 Glass 效果
    @available(tvOS 26.0, *)
    func applyVideoDetailGlassBackground() {
        applyLiquidGlassBackground(config: .videoDetail)
    }
    
    /// 快速应用直播间场景 Glass 效果
    @available(tvOS 26.0, *)
    func applyLiveRoomGlassBackground() {
        applyLiquidGlassBackground(config: .liveRoom)
    }
    
    /// 快速应用搜索场景 Glass 效果
    @available(tvOS 26.0, *)
    func applySearchGlassBackground() {
        applyLiquidGlassBackground(config: .search)
    }
    
    /// 快速应用设置场景 Glass 效果
    @available(tvOS 26.0, *)
    func applySettingsGlassBackground() {
        applyLiquidGlassBackground(config: .settings)
    }
}

// MARK: - Liquid Glass Container Helper

@available(tvOS 26.0, *)
extension UIView {
    
    /// 为一组子视图创建 Liquid Glass 容器
    /// - Parameters:
    ///   - views: 需要组合的视图数组
    ///   - spacing: 视图间距，影响融合效果
    /// - Returns: 创建的容器视图
    @discardableResult
    func createGlassContainer(
        for views: [UIView],
        spacing: CGFloat = 20.0
    ) -> LiquidGlassContainerView {
        let container = LiquidGlassContainerView(effect: nil)
        container.containerSpacing = spacing
        
        addSubview(container)
        container.addGlassSubviews(views)
        
        return container
    }
    
    /// 为视图应用交互式 Glass 效果（用于焦点元素）
    /// - Parameters:
    ///   - tintColor: 色调颜色
    ///   - cornerRadius: 圆角半径
    func applyInteractiveGlass(
        tintColor: UIColor? = GlassEffectConfiguration.playerControl,
        cornerRadius: CGFloat = GlassEffectConfiguration.standardCornerRadius
    ) {
        let glassView = UIVisualEffectView.createGlassView(
            tintColor: tintColor,
            isInteractive: true,
            cornerRadius: cornerRadius
        )
        
        glassView.frame = bounds
        glassView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(glassView, at: 0)
    }
}

// MARK: - Theme Manager Extension for Scene Management

extension ThemeManager {
    
    /// 获取场景配置
    /// - Parameter sceneType: 场景类型
    /// - Returns: 场景配置
    @available(tvOS 26.0, *)
    func sceneConfig(for sceneType: SceneType) -> LiquidGlassSceneConfig {
        switch sceneType {
        case .player:
            return .player
        case .feed:
            return .feed
        case .videoDetail:
            return .videoDetail
        case .liveRoom:
            return .liveRoom
        case .search:
            return .search
        case .settings:
            return .settings
        case .popup:
            return .popup
        case .control:
            return .control
        }
    }
}

// MARK: - Scene Type Enum

/// 应用场景类型
enum SceneType {
    case player      // 播放器
    case feed        // Feed 流
    case videoDetail // 视频详情
    case liveRoom    // 直播间
    case search      // 搜索
    case settings    // 设置
    case popup       // 弹出层
    case control     // 控制按钮
}
