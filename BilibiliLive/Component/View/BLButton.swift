//
//  BLButton.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/22.
//

import SnapKit
import TVUIKit

@IBDesignable
@MainActor
class BLCustomButton: BLButton {
    @IBInspectable var image: UIImage? {
        didSet { updateButton() }
    }

    @IBInspectable var onImage: UIImage? {
        didSet { updateButton() }
    }

    @IBInspectable var highLightImage: UIImage? {
        didSet { updateButton() }
    }

    @IBInspectable var title: String? {
        didSet {
            updateTitleLabel()
        }
    }

    @IBInspectable var titleColor: UIColor = UIColor.black.withAlphaComponent(0.9) {
        didSet { titleLabel.textColor = titleColor }
    }

    @IBInspectable var titleFont: UIFont = .systemFont(ofSize: 24) {
        didSet { titleLabel.font = titleFont }
    }

    var isOn: Bool = false {
        didSet {
            updateButton()
        }
    }

    private let titleLabel = UILabel()
    private let imageView = UIImageView()

    override func setup() {
        super.setup()
        titleLabel.isUserInteractionEnabled = false
        effectView.contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(0.5)
            make.height.equalTo(imageView.snp.width)
        }
        imageView.image = image
        addSubview(titleLabel)
        titleLabel.textAlignment = .center
        titleLabel.font = titleFont
        titleLabel.textColor = titleColor
        updateTitleLabel(force: true)
    }

    private func updateTitleLabel(force: Bool = false) {
        let shouldHide = title == nil || title?.count == 0
        titleLabel.text = title
        if force || titleLabel.isHidden != shouldHide {
            titleLabel.isHidden = shouldHide
            if shouldHide {
                titleLabel.snp.removeConstraints()
            } else {
                titleLabel.snp.makeConstraints { make in
                    make.leading.trailing.bottom.equalToSuperview()
                    make.top.equalTo(effectView.snp.bottom).offset(10)
                }
            }
        }
    }

    private func getImage() -> UIImage? {
        isOn ? onImage : image
    }

    private func updateButton() {
        if isFocused {
            imageView.image = highLightImage ?? getImage()
            // 使用主题色替代硬编码黑色
            imageView.tintColor = ThemeManager.shared.buttonTextColor(isFocused: true)
        } else {
            imageView.image = getImage()
            // 使用主题色替代硬编码白色
            imageView.tintColor = ThemeManager.shared.buttonIconColor(isFocused: false)
        }
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        coordinator.addCoordinatedAnimations { [weak self] in
            self?.updateButton()
            
            // 添加图标缩放动画
            if let imageView = self?.imageView, self?.isFocused == true {
                UIView.animate(withDuration: 0.2, delay: 0.1, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: []) {
                    imageView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                } completion: { _ in
                    UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.3, options: []) {
                        imageView.transform = .identity
                    }
                }
            } else if let imageView = self?.imageView {
                imageView.transform = .identity
            }
        }
    }
}

@IBDesignable
@MainActor
class BLCustomTextButton: BLButton {
    private let titleLabel = UILabel()
    var object: Any?

    @IBInspectable var title: String? {
        didSet { titleLabel.text = title }
    }

    @IBInspectable var titleColor: UIColor = UIColor.white {
        didSet { updateTitleColor() }
    }

    @IBInspectable var titleSelectedColor: UIColor = UIColor.black {
        didSet { updateTitleColor() }
    }

    @IBInspectable var titleFont: UIFont = .systemFont(ofSize: 28) {
        didSet { titleLabel.font = titleFont }
    }

    override func setup() {
        super.setup()
        effectView.layer.cornerRadius = 12
        effectView.contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(12)
            make.left.right.equalToSuperview().inset(28)
        }
        titleLabel.text = title
        titleLabel.font = titleFont
        updateTitleColor()
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
    }
    
    private func updateTitleColor() {
        titleLabel.textColor = isFocused ? titleSelectedColor : titleColor
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        coordinator.addCoordinatedAnimations { [weak self] in
            self?.updateTitleColor()
            
            // 添加文本微妙缩放
            if let label = self?.titleLabel, self?.isFocused == true {
                UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseOut]) {
                    label.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                } completion: { _ in
                    UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseIn]) {
                        label.transform = .identity
                    }
                }
            }
        }
    }
}

class BLButton: UIControl {
    private var motionEffect: UIInterpolatingMotionEffect!
    internal let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let selectedWhiteView = UIView()

    var onPrimaryAction: ((BLButton) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override var canBecomeFocused: Bool { return true }

    func setup() {
        isUserInteractionEnabled = true
        motionEffect = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
        motionEffect.maximumRelativeValue = 8
        motionEffect.minimumRelativeValue = -8
        selectedWhiteView.isHidden = !isFocused
        addSubview(effectView)
        effectView.isUserInteractionEnabled = false
        effectView.layer.cornerRadius = 8
        effectView.clipsToBounds = true
        effectView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().priority(.high)
        }
        effectView.contentView.addSubview(selectedWhiteView)
        selectedWhiteView.backgroundColor = UIColor.white
        selectedWhiteView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)
        if presses.first?.type == .select {
            sendActions(for: .primaryActionTriggered)
            onPrimaryAction?(self)
        }
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if isFocused {
            selectedWhiteView.isHidden = false
            coordinator.addCoordinatedAnimations {
                // 增强的缩放效果（使用弹簧动画）
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [.curveEaseInOut]) {
                    self.transform = CGAffineTransformMakeScale(1.1, 1.1)
                    let scaleDiff = (self.bounds.size.height * 1.1 - self.bounds.size.height) / 2
                    self.transform = CGAffineTransformTranslate(self.transform, 0, -scaleDiff)
                }
                
                // 增强的阴影效果
                ThemeManager.shared.applyButtonFocusEffect(to: self.layer, buttonType: "action")
                
                // 显示渐变层（如果存在）
                if let gradientLayer = self.layer.value(forKey: "gradientLayer") as? CAGradientLayer {
                    let animation = CABasicAnimation(keyPath: "opacity")
                    animation.fromValue = 0.0
                    animation.toValue = 1.0
                    animation.duration = 0.3
                    animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    animation.fillMode = .forwards
                    animation.isRemovedOnCompletion = false
                    gradientLayer.add(animation, forKey: "showGradient")
                }
                
                self.addMotionEffect(self.motionEffect)
            }
        } else {
            selectedWhiteView.isHidden = true
            coordinator.addCoordinatedAnimations {
                // 恢复动画
                UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3, options: [.curveEaseInOut]) {
                    self.transform = CGAffineTransformIdentity
                }
                
                ThemeManager.shared.removeShadow(from: self.layer)
                
                // 隐藏渐变层
                if let gradientLayer = self.layer.value(forKey: "gradientLayer") as? CAGradientLayer {
                    let animation = CABasicAnimation(keyPath: "opacity")
                    animation.fromValue = 1.0
                    animation.toValue = 0.0
                    animation.duration = 0.3
                    animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    animation.fillMode = .forwards
                    animation.isRemovedOnCompletion = false
                    gradientLayer.add(animation, forKey: "hideGradient")
                }
                
                self.removeMotionEffect(self.motionEffect)
            }
        }
    }
}
