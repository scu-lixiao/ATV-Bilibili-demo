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

class FeedCollectionViewCell: BLAuroraPremiumCell {
    var onLongPress: (() -> Void)?
    var styleOverride: FeedDisplayStyle? { didSet { if oldValue != styleOverride { updateStyle() } }}

    private let titleLabel = MarqueeLabel()
    private let upLabel = UILabel()
    private let imageView = UIImageView()
    private let infoView = UIView()
    private let avatarView = UIImageView()

    // Performance Optimization: Cache current image URL to avoid redundant loads
    private var currentImageURL: URL?
    private var currentAvatarURL: URL?

    override func setupCell() {
        super.setupCell()
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
        stackView.alignment = .leading
        stackView.spacing = 6
        stackView.setContentHuggingPriority(.required, for: .vertical)
        titleLabel.holdScrolling = true
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        upLabel.setContentHuggingPriority(.required, for: .vertical)
        upLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        upLabel.textColor = UIColor(named: "titleColor")
        upLabel.adjustsFontSizeToFitWidth = true
        upLabel.minimumScaleFactor = 0.1
    }

    func setup(data: any DisplayData) {
        titleLabel.text = data.title
        upLabel.text = [data.ownerName, data.date].compactMap { $0 }.joined(separator: " · ")

        // Performance Optimization: Load image only if URL changed
        if var pic = data.pic {
            if pic.scheme == nil {
                pic = URL(string: "http:\(pic.absoluteString)")!
            }

            // Only load if URL is different from current
            if currentImageURL != pic {
                currentImageURL = pic

                // Disable transition animation on low performance
                let shouldTransition = BLPremiumPerformanceMonitor.shared.currentQualityLevel >= .medium
                let transition: KingfisherOptionsInfoItem = shouldTransition ? .transition(.fade(0.2)) : .transition(.none)

                // {{CHENGQI:
                // Action: Modified
                // Timestamp: 2025-10-17 08:08:00 +08:00
                // Reason: Phase 2 内存优化 - 移除 .cacheOriginalImage (最大收益点!)
                // Principle_Applied: Resource Management - Feed 大图无需缓存原图
                // Optimization: 避免缓存 1920x1080 原图,只保留 360x202 下采样图
                // Impact: 预期减少 30-40MB 内存 (原图占用)
                // }}
                imageView.kf.setImage(
                    with: pic,
                    options: [
                        .processor(DownsamplingImageProcessor(size: CGSize(width: 360, height: 202))),
                        // .cacheOriginalImage removed - Feed images don't need original quality
                        transition,
                    ]
                )
            }
        }

        // Performance Optimization: Load avatar only if URL changed
        if let avatar = data.avatar {
            avatarView.isHidden = false

            if currentAvatarURL != avatar {
                currentAvatarURL = avatar

                let shouldTransition = BLPremiumPerformanceMonitor.shared.currentQualityLevel >= .medium
                let transition: KingfisherOptionsInfoItem = shouldTransition ? .transition(.fade(0.2)) : .transition(.none)

                avatarView.kf.setImage(
                    with: avatar,
                    options: [
                        .processor(DownsamplingImageProcessor(size: CGSize(width: 80, height: 80))),
                        .processor(RoundCornerImageProcessor(radius: .widthFraction(0.5))),
                        .cacheSerializer(FormatIndicatedCacheSerializer.png),
                        transition,
                    ]
                )
            }
        } else {
            avatarView.isHidden = true
            currentAvatarURL = nil
        }

        updateStyle()
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if isFocused {
            startScroll()
        } else {
            stopScroll()
        }
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

        // Performance Optimization: Reset URL cache
        currentImageURL = nil
        currentAvatarURL = nil

        // {{CHENGQI:
        // Action: Added
        // Timestamp: 2025-10-17 08:10:30 +08:00
        // Reason: Phase 4 内存优化 - prepareForReuse 时取消图片下载
        // Principle_Applied: Resource Management - 复用前清理资源
        // Optimization: 配合 didEndDisplaying,确保图片任务及时取消
        // }}
        // Cancel any ongoing Kingfisher download tasks
        imageView.kf.cancelDownloadTask()
        avatarView.kf.cancelDownloadTask()

        // Fix: Reset all visual states to prevent gray-out
        contentView.alpha = 1.0
        alpha = 1.0
        imageView.alpha = 1.0
        titleLabel.alpha = 1.0
        upLabel.alpha = 1.0
        avatarView.alpha = 1.0
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
}
