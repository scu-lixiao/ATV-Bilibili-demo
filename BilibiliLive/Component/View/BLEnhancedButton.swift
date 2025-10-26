//
//  BLEnhancedButton.swift
//  BilibiliLive
//
//  Created by AI Assistant on 2025/10/26.
//  深度优化的按钮系统 - 支持 Liquid Glass、渐变、高级动画
//

import UIKit
import SnapKit

// MARK: - Button Type

/// 按钮类型，决定视觉样式
enum BLButtonType {
    case action      // 动作按钮（播放、点赞、投币等）
    case info        // 信息按钮（关注、UP主等）
    case text        // 文本按钮
}

// MARK: - Enhanced Button Base

/// 增强版按钮基类
/// 特性：Liquid Glass 材质、动态阴影、弹簧动画、多层视觉效果
@MainActor
class BLEnhancedButton: UIControl {
    
    // MARK: - Properties
    
    var buttonType: BLButtonType = .action
    var onPrimaryAction: ((BLEnhancedButton) -> Void)?
    
    // 视图层次
    fileprivate let containerView = UIView()
    fileprivate let effectView = UIVisualEffectView()
    fileprivate let highlightView = UIView()
    fileprivate let gradientLayer = CAGradientLayer()
    
    // Motion Effect
    private var motionEffect: UIMotionEffectGroup?
    
    // 动画属性
    private var focusAnimator: UIViewPropertyAnimator?
    private var pulseAnimator: UIViewPropertyAnimator?
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupTheme()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
        setupTheme()
    }
    
    override var canBecomeFocused: Bool { return true }
    
    // MARK: - Setup
    
    private func setupViews() {
        isUserInteractionEnabled = true
        
        // Container
        addSubview(containerView)
        containerView.isUserInteractionEnabled = false
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Effect View
        containerView.addSubview(effectView)
        effectView.clipsToBounds = true
        effectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Highlight View
        effectView.contentView.addSubview(highlightView)
        highlightView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Gradient Layer
        effectView.contentView.layer.insertSublayer(gradientLayer, at: 0)
        
        setupMotionEffect()
    }
    
    private func setupTheme() {
        // 基础样式
        backgroundColor = .clear
        
        // Effect View - 使用 ThemeManager
        effectView.effect = ThemeManager.shared.createEffect(style: .control)
        
        // Highlight View
        highlightView.backgroundColor = UIColor.white
        highlightView.alpha = 0
        
        // Corner Radius - 动态计算
        updateCornerRadius()
        
        // Shadow - 初始为0
        ThemeManager.shared.removeShadow(from: layer)
    }
    
    private func updateCornerRadius() {
        let radius = bounds.height * 0.25
        effectView.layer.cornerRadius = radius
        layer.cornerRadius = radius
        containerView.layer.cornerRadius = radius
    }
    
    private func setupMotionEffect() {
        let horizontal = UIInterpolatingMotionEffect(
            keyPath: "center.x",
            type: .tiltAlongHorizontalAxis
        )
        horizontal.minimumRelativeValue = -10
        horizontal.maximumRelativeValue = 10
        
        let vertical = UIInterpolatingMotionEffect(
            keyPath: "center.y",
            type: .tiltAlongVerticalAxis
        )
        vertical.minimumRelativeValue = -10
        vertical.maximumRelativeValue = 10
        
        let group = UIMotionEffectGroup()
        group.motionEffects = [horizontal, vertical]
        motionEffect = group
    }
    
    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateCornerRadius()
        gradientLayer.frame = effectView.bounds
        
        // 更新阴影路径
        if layer.shadowOpacity > 0 {
            layer.shadowPath = UIBezierPath(
                roundedRect: bounds,
                cornerRadius: layer.cornerRadius
            ).cgPath
        }
    }
    
    // MARK: - Focus Animation
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        if isFocused {
            animateToFocusedState(with: coordinator)
        } else {
            animateToUnfocusedState(with: coordinator)
        }
    }
    
    private func animateToFocusedState(with coordinator: UIFocusAnimationCoordinator) {
        // 停止之前的动画
        focusAnimator?.stopAnimation(true)
        pulseAnimator?.stopAnimation(true)
        
        coordinator.addCoordinatedAnimations { [weak self] in
            guard let self = self else { return }
            
            // 缩放
            self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            
            // 高亮显示
            self.highlightView.alpha = 1.0
            
            // 应用焦点阴影
            ThemeManager.shared.applyFocusShadow(to: self.layer)
            
            // 添加 Motion Effect
            if let motionEffect = self.motionEffect {
                self.addMotionEffect(motionEffect)
            }
            
        } completion: { [weak self] in
            // 焦点后启动脉动动画
            self?.startPulseAnimation()
        }
        
        // 渐变动画（如果有）
        animateGradient(show: true)
    }
    
    private func animateToUnfocusedState(with coordinator: UIFocusAnimationCoordinator) {
        // 停止脉动
        pulseAnimator?.stopAnimation(true)
        pulseAnimator = nil
        
        coordinator.addCoordinatedAnimations { [weak self] in
            guard let self = self else { return }
            
            // 恢复大小
            self.transform = .identity
            
            // 隐藏高亮
            self.highlightView.alpha = 0
            
            // 移除阴影
            ThemeManager.shared.removeShadow(from: self.layer)
            
            // 移除 Motion Effect
            if let motionEffect = self.motionEffect {
                self.removeMotionEffect(motionEffect)
            }
        }
        
        // 隐藏渐变
        animateGradient(show: false)
    }
    
    private func startPulseAnimation() {
        // 微妙的脉动效果
        pulseAnimator = UIViewPropertyAnimator(
            duration: 2.0,
            dampingRatio: 0.5
        ) { [weak self] in
            self?.transform = CGAffineTransform(scaleX: 1.12, y: 1.12)
        }
        
        pulseAnimator?.addCompletion { [weak self] _ in
            guard let self = self, self.isFocused else { return }
            
            UIViewPropertyAnimator(duration: 2.0, dampingRatio: 0.5) { [weak self] in
                self?.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }.startAnimation()
            
            // 递归循环
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.startPulseAnimation()
            }
        }
        
        pulseAnimator?.startAnimation()
    }
    
    private func animateGradient(show: Bool) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = show ? 0.0 : 1.0
        animation.toValue = show ? 1.0 : 0.0
        animation.duration = 0.3
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        gradientLayer.add(animation, forKey: "opacityAnimation")
    }
    
    // MARK: - Press Handling
    
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)
        if presses.first?.type == .select {
            performPressAnimation()
            sendActions(for: .primaryActionTriggered)
            onPrimaryAction?(self)
        }
    }
    
    private func performPressAnimation() {
        // 点击反馈动画
        let animator = UIViewPropertyAnimator(duration: 0.1, dampingRatio: 0.6) { [weak self] in
            self?.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        }
        
        animator.addCompletion { [weak self] _ in
            UIViewPropertyAnimator(duration: 0.2, dampingRatio: 0.7) { [weak self] in
                self?.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }.startAnimation()
        }
        
        animator.startAnimation()
    }
}

// MARK: - Action Button

/// 动作按钮（播放、点赞、投币、收藏等）
/// 特性：品牌色渐变、图标动画、状态切换
@IBDesignable
@MainActor
class BLActionButton: BLEnhancedButton {
    
    // MARK: - Properties
    
    @IBInspectable var image: UIImage? {
        didSet { updateIcon() }
    }
    
    @IBInspectable var onImage: UIImage? {
        didSet { updateIcon() }
    }
    
    @IBInspectable var title: String? {
        didSet { updateTitle() }
    }
    
    @IBInspectable var useAccentGradient: Bool = false {
        didSet { setupGradient() }
    }
    
    var isOn: Bool = false {
        didSet {
            if oldValue != isOn {
                animateStateChange()
            }
        }
    }
    
    // Views
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    
    // MARK: - Setup
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupActionButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupActionButton()
    }
    
    private func setupActionButton() {
        buttonType = .action
        
        // Icon
        effectView.contentView.addSubview(iconImageView)
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalToSuperview().multipliedBy(0.5)
        }
        
        // Title
        addSubview(titleLabel)
        titleLabel.textAlignment = .center
        titleLabel.font = .systemFont(ofSize: 24, weight: .medium)
        titleLabel.textColor = ThemeManager.shared.textPrimaryColor
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(effectView.snp.bottom).offset(10)
        }
        
        updateIcon()
        updateTitle()
        setupGradient()
    }
    
    private func setupGradient() {
        guard useAccentGradient else {
            gradientLayer.colors = nil
            return
        }
        
        // 品牌粉色渐变
        let color1 = ThemeManager.shared.accentPinkColor.withAlphaComponent(0.3)
        let color2 = ThemeManager.shared.accentColor.withAlphaComponent(0.2)
        
        gradientLayer.colors = [color1.cgColor, color2.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        gradientLayer.opacity = 0
    }
    
    // MARK: - Updates
    
    private func updateIcon() {
        let currentImage = isOn ? (onImage ?? image) : image
        iconImageView.image = currentImage
        iconImageView.tintColor = isFocused ? 
            ThemeManager.shared.textPrimaryColor : 
            ThemeManager.shared.textSecondaryColor
    }
    
    private func updateTitle() {
        titleLabel.text = title
        titleLabel.isHidden = title == nil || title?.isEmpty == true
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        coordinator.addCoordinatedAnimations { [weak self] in
            guard let self = self else { return }
            self.iconImageView.tintColor = self.isFocused ? 
                ThemeManager.shared.textPrimaryColor : 
                ThemeManager.shared.textSecondaryColor
        }
    }
    
    private func animateStateChange() {
        // 图标切换动画
        let animation = CATransition()
        animation.duration = 0.3
        animation.type = .fade
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        iconImageView.layer.add(animation, forKey: "iconTransition")
        
        // 缩放弹跳
        UIViewPropertyAnimator(duration: 0.3, dampingRatio: 0.6) { [weak self] in
            self?.iconImageView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }.startAnimation()
        
        UIViewPropertyAnimator(duration: 0.3, dampingRatio: 0.7) { [weak self] in
            self?.iconImageView.transform = .identity
        }.startAnimation(afterDelay: 0.15)
        
        updateIcon()
    }
}

// MARK: - Info Button

/// 信息按钮（关注、UP主等）
/// 特性：更柔和的视觉效果、文本为主
@IBDesignable
@MainActor
class BLInfoButton: BLEnhancedButton {
    
    // MARK: - Properties
    
    @IBInspectable var image: UIImage? {
        didSet { updateIcon() }
    }
    
    @IBInspectable var title: String? {
        didSet { titleLabel.text = title }
    }
    
    @IBInspectable var titleColor: UIColor = .white {
        didSet { updateColors() }
    }
    
    @IBInspectable var titleFocusedColor: UIColor = .black {
        didSet { updateColors() }
    }
    
    // Views
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    
    // MARK: - Setup
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupInfoButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupInfoButton()
    }
    
    private func setupInfoButton() {
        buttonType = .info
        
        // Icon (可选)
        effectView.contentView.addSubview(iconImageView)
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(30)
        }
        
        // Title
        effectView.contentView.addSubview(titleLabel)
        titleLabel.font = .systemFont(ofSize: 28, weight: .medium)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(12)
            make.trailing.equalToSuperview().inset(20)
            make.centerY.equalToSuperview()
        }
        
        updateIcon()
        updateColors()
    }
    
    private func updateIcon() {
        iconImageView.image = image
        iconImageView.isHidden = image == nil
    }
    
    private func updateColors() {
        titleLabel.textColor = isFocused ? titleFocusedColor : titleColor
        iconImageView.tintColor = isFocused ? titleFocusedColor : titleColor
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        coordinator.addCoordinatedAnimations { [weak self] in
            self?.updateColors()
        }
    }
}

// MARK: - Text Button

/// 纯文本按钮
/// 特性：简洁的文本样式
@IBDesignable
@MainActor
class BLTextButton: BLEnhancedButton {
    
    @IBInspectable var title: String? {
        didSet { titleLabel.text = title }
    }
    
    @IBInspectable var titleColor: UIColor = .white {
        didSet { updateColors() }
    }
    
    @IBInspectable var titleFocusedColor: UIColor = .black {
        didSet { updateColors() }
    }
    
    private let titleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTextButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextButton()
    }
    
    private func setupTextButton() {
        buttonType = .text
        
        effectView.contentView.addSubview(titleLabel)
        titleLabel.textAlignment = .center
        titleLabel.font = .systemFont(ofSize: 28, weight: .medium)
        titleLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(12)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        updateColors()
    }
    
    private func updateColors() {
        titleLabel.textColor = isFocused ? titleFocusedColor : titleColor
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        coordinator.addCoordinatedAnimations { [weak self] in
            self?.updateColors()
        }
    }
}
