//
//  FeedCollectionViewCell.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/20.
//

import Kingfisher
import MarqueeLabel
import TVUIKit
import UIKit

class FeedCollectionViewCell: BLMotionCollectionViewCell {
    var onLongPress: (() -> Void)?
    var styleOverride: FeedDisplayStyle? { didSet { if oldValue != styleOverride { updateStyle() } }}

    private let titleLabel = MarqueeLabel()
    private let upLabel = UILabel()
    private let statsLabel = UILabel()  // 新增统计信息标签
    private let imageView = UIImageView()
    private let infoView = UIView()
    private let avatarView = UIImageView()

    override func setup() {
        super.setup()
        let longpress = UILongPressGestureRecognizer(target: self, action: #selector(actionLongPress(sender:)))
        addGestureRecognizer(longpress)

        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.top.equalToSuperview()
            make.height.equalTo(imageView.snp.width).multipliedBy(9.0 / 16)
        }
        imageView.layer.cornerRadius = 12
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill

        contentView.addSubview(infoView)
        infoView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(imageView.snp.bottom).offset(8)
        }

        let hStackView = UIStackView()
        let stackView = UIStackView()
        infoView.addSubview(hStackView)
        hStackView.addArrangedSubview(avatarView)
        hStackView.addArrangedSubview(stackView)
        hStackView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().priority(.high)
            make.height.equalTo(stackView.snp.height)
        }

        hStackView.alignment = .top
        hStackView.spacing = 10
        avatarView.backgroundColor = .clear
        avatarView.snp.makeConstraints { make in
            make.width.equalTo(avatarView.snp.height)
            make.height.equalTo(stackView.snp.height).multipliedBy(0.7)
        }
        stackView.setContentHuggingPriority(.required, for: .vertical)
        avatarView.setContentHuggingPriority(.defaultLow, for: .vertical)
        avatarView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        avatarView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        avatarView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        stackView.axis = .vertical
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(upLabel)
        stackView.addArrangedSubview(statsLabel)  // 添加统计标签
        stackView.alignment = .leading
        stackView.spacing = 6
        stackView.setContentHuggingPriority(.required, for: .vertical)
        titleLabel.holdScrolling = true
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        titleLabel.fadeLength = 60
        upLabel.setContentHuggingPriority(.required, for: .vertical)
        upLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        upLabel.textColor = UIColor(named: "titleColor")
        upLabel.adjustsFontSizeToFitWidth = true
        upLabel.minimumScaleFactor = 0.1
        statsLabel.setContentHuggingPriority(.required, for: .vertical)
        statsLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        statsLabel.textColor = ThemeManager.shared.textSecondaryColor
        statsLabel.adjustsFontSizeToFitWidth = true
        statsLabel.minimumScaleFactor = 0.1
    }

    func setup(data: any DisplayData) {
        titleLabel.text = data.title
        upLabel.text = [data.ownerName, data.date].compactMap({ $0 }).joined(separator: " · ")
        
        // 格式化并显示统计信息
        var statsComponents: [String] = []
        if let viewCount = data.viewCount {
            statsComponents.append("▶︎ \(formatNumber(viewCount))")
        }
        if let replyCount = data.replyCount {
            statsComponents.append("💬 \(formatNumber(replyCount))")
        }
        statsLabel.text = statsComponents.isEmpty ? "" : statsComponents.joined(separator: "  ")
        statsLabel.isHidden = statsComponents.isEmpty
        
        if var pic = data.pic {
            if pic.scheme == nil {
                pic = URL(string: "http:\(pic.absoluteString)")!
            }
            imageView.kf.setImage(with: pic, options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 360, height: 202))), .cacheOriginalImage])
        }
        if let avatar = data.avatar {
            avatarView.isHidden = false
            avatarView.kf.setImage(with: avatar, options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 80, height: 80))), .processor(RoundCornerImageProcessor(radius: .widthFraction(0.5))), .cacheSerializer(FormatIndicatedCacheSerializer.png)])
        } else {
            avatarView.isHidden = true
        }
        updateStyle()
    }
    
    /// 格式化数字为简洁形式（如 1.2万, 3.5亿）
    private func formatNumber(_ number: Int) -> String {
        let num = Double(number)
        if num >= 100_000_000 {
            return String(format: "%.1f亿", num / 100_000_000)
        } else if num >= 10_000 {
            return String(format: "%.1f万", num / 10_000)
        } else {
            return "\(number)"
        }
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                // 焦点效果 - tvOS 26 Liquid Glass 风格
                self.applyFocusedStyle()
                self.startScroll()
            } else {
                // 失焦效果
                self.applyUnfocusedStyle()
                self.stopScroll()
            }
        }, completion: nil)
    }

    /// 应用焦点样式 - tvOS 26 Liquid Glass 深邃暗黑主题焦点效果
    private func applyFocusedStyle() {
        // 1. 缩放效果 - 轻微放大
        transform = CGAffineTransform(scaleX: 1.05, y: 1.05)

        // 2. 高级阴影 - 深邃且柔和
        layer.shadowColor = ColorPalette.focusShadow.cgColor
        layer.shadowOpacity = 0.8
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 24
        layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: 12
        ).cgPath

        // 3. 图片容器边框高光 - 品牌色
        imageView.layer.borderColor = ThemeManager.shared.accentColor.cgColor
        imageView.layer.borderWidth = 3

        // 4. 图片增强 - 轻微提亮,不添加模糊
        imageView.alpha = 1.0
        imageView.layer.shadowColor = ThemeManager.shared.accentColor.cgColor
        imageView.layer.shadowOpacity = 0.3
        imageView.layer.shadowOffset = CGSize(width: 0, height: 0)
        imageView.layer.shadowRadius = 8

        // 5. 文本颜色增强
        titleLabel.textColor = ThemeManager.shared.textPrimaryColor
        upLabel.textColor = ThemeManager.shared.accentColor
        statsLabel.textColor = ThemeManager.shared.accentColor.withAlphaComponent(0.8)

        // 6. tvOS 26 Liquid Glass 发光效果
        applyLiquidGlassGlow()
    }

    /// 移除焦点样式
    private func applyUnfocusedStyle() {
        // 1. 恢复原始大小
        transform = .identity

        // 2. 移除卡片阴影
        layer.shadowOpacity = 0

        // 3. 移除图片边框
        imageView.layer.borderWidth = 0

        // 4. 恢复图片阴影
        imageView.layer.shadowOpacity = 0

        // 5. 恢复正常文本颜色
        titleLabel.textColor = ThemeManager.shared.textPrimaryColor
        upLabel.textColor = ThemeManager.shared.textSecondaryColor
        statsLabel.textColor = ThemeManager.shared.textSecondaryColor

        // 6. 移除发光效果
        removeGlowEffect()
    }

    /// 应用 tvOS 26 Liquid Glass 发光效果
    private func applyLiquidGlassGlow() {
        if #available(tvOS 26.0, *), ThemeManager.shared.supportsLiquidGlass {
            // 使用 Liquid Glass 交互式效果
            let glowLayer = CALayer()
            glowLayer.name = "liquidGlassGlow"
            glowLayer.frame = bounds
            glowLayer.cornerRadius = 12
            glowLayer.borderColor = ThemeManager.shared.accentColor.withAlphaComponent(0.4).cgColor
            glowLayer.borderWidth = 2
            glowLayer.shadowColor = ThemeManager.shared.accentColor.cgColor
            glowLayer.shadowOpacity = 0.6
            glowLayer.shadowOffset = .zero
            glowLayer.shadowRadius = 16
            
            layer.insertSublayer(glowLayer, at: 0)
        } else {
            // 降级方案：传统发光效果
            applyGlowEffect()
        }
    }
    
    /// 应用轻微的发光效果 - 降级方案
    private func applyGlowEffect() {
        let glowLayer = CALayer()
        glowLayer.name = "glowLayer"
        glowLayer.frame = bounds
        glowLayer.cornerRadius = 12
        glowLayer.borderColor = ThemeManager.shared.accentColor.withAlphaComponent(0.3).cgColor
        glowLayer.borderWidth = 1
        glowLayer.shadowColor = ThemeManager.shared.accentColor.cgColor
        glowLayer.shadowOpacity = 0.5
        glowLayer.shadowOffset = .zero
        glowLayer.shadowRadius = 12

        layer.insertSublayer(glowLayer, at: 0)
    }

    /// 移除发光效果
    private func removeGlowEffect() {
        // 移除 Liquid Glass 效果
        layer.sublayers?.first(where: { $0.name == "liquidGlassGlow" })?.removeFromSuperlayer()
        // 移除传统效果
        layer.sublayers?.first(where: { $0.name == "glowLayer" })?.removeFromSuperlayer()
    }

    private func startScroll() {
        titleLabel.restartLabel()
        titleLabel.holdScrolling = false
    }

    private func stopScroll() {
        titleLabel.shutdownLabel()
        titleLabel.holdScrolling = true
    }

    private func updateStyle() {
        let style = styleOverride ?? Settings.displayStyle
        titleLabel.font = style.titleFont
        upLabel.font = style.upFont
        statsLabel.font = style.statsFont  // 添加统计标签字体
    }

    @objc private func actionLongPress(sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        onLongPress?()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onLongPress = nil
        avatarView.image = nil
        stopScroll()
    }
}

extension FeedDisplayStyle {
    var fractionalWidth: CGFloat {
        switch self {
        case .large, .sideBar:
            return 0.33
        case .normal:
            return 0.25
        }
    }

    var fractionalHeight: CGFloat {
        switch self {
        case .large:
            return fractionalWidth / 1.5
        case .normal:
            return fractionalWidth / 1.5
        case .sideBar:
            return fractionalWidth / 1.15
        }
    }

    var heightEstimated: CGFloat {
        switch self {
        case .large:
            return 516
        case .normal, .sideBar:
            return 380
        }
    }

    var titleFont: UIFont {
        switch self {
        case .large:
            return UIFont.preferredFont(forTextStyle: .headline)
        case .normal:
            return UIFont.systemFont(ofSize: 30, weight: .semibold)
        case .sideBar:
            return UIFont.systemFont(ofSize: 26, weight: .semibold)
        }
    }

    var upFont: UIFont {
        switch self {
        case .large:
            return UIFont.preferredFont(forTextStyle: .footnote)
        case .normal:
            return UIFont.systemFont(ofSize: 24)
        case .sideBar:
            return UIFont.systemFont(ofSize: 20, weight: .semibold)
        }
    }
    
    var statsFont: UIFont {
        switch self {
        case .large:
            return UIFont.systemFont(ofSize: 22, weight: .regular)
        case .normal:
            return UIFont.systemFont(ofSize: 22, weight: .regular)
        case .sideBar:
            return UIFont.systemFont(ofSize: 18, weight: .regular)
        }
    }
}
