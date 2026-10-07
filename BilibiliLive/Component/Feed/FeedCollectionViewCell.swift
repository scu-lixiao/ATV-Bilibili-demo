//
//  FeedCollectionViewCell.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/20.
//

import Kingfisher
import MarqueeLabel
import SnapKit
import TVUIKit
import UIKit

class FeedCollectionViewCell: BLMotionCollectionViewCell {
    var onLongPress: (() -> Void)?
    var styleOverride: FeedDisplayStyle? { didSet { if oldValue != styleOverride { updateStyle() } }}

    private let titleLabel = UILabel()
    private let upLabel = UILabel()
    private let sortLabel = UILabel()
    private let imageView = UIImageView()
    let infoView = UIView()
    private let avatarView = UIImageView()
    private var avatarHeightConstraint: Constraint?
    private var oldStyle: FeedDisplayStyle?

    private static let infoAlphaNormal: CGFloat = 0.8

    override func setup() {
        super.setup()
        // 封面使用 adjustsImageWhenAncestorFocused，系统焦点效果自带阴影，
        // cell 自己再叠一层无 shadowPath 的阴影只会带来每帧离屏渲染
        usesFocusShadow = false

        let longpress = UILongPressGestureRecognizer(target: self, action: #selector(actionLongPress(sender:)))
        addGestureRecognizer(longpress)

        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.top.equalToSuperview()
            make.height.equalTo(imageView.snp.width).multipliedBy(9.0 / 16)
        }

        imageView.adjustsImageWhenAncestorFocused = true
        // 圆角和头像尺寸依赖 styleOverride，而 styleOverride 在 setup 之后才被赋值，统一放到 updateStyle 里处理
        imageView.layer.cornerCurve = .continuous
        imageView.layer.masksToBounds = true
        imageView.contentMode = .scaleAspectFill

        imageView.addSubview(avatarView)

        infoView.alpha = Self.infoAlphaNormal
        contentView.addSubview(infoView)
        infoView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(imageView.snp.bottom).offset(14)
        }

        let hStackView = UIStackView()
        let stackView = UIStackView()
        infoView.addSubview(hStackView)

        hStackView.addArrangedSubview(sortLabel)
        sortLabel.textColor = .white

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
            make.bottom.right.equalToSuperview().offset(-4)
            make.width.equalTo(avatarView.snp.height)
            avatarHeightConstraint = make.height.equalTo(33).constraint
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
        titleLabel.numberOfLines = 2
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        titleLabel.textColor = UIColor(named: "titleColor")
        upLabel.setContentHuggingPriority(.required, for: .vertical)
        upLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        upLabel.textColor = UIColor(named: "upTitleColor")
        // 0.1 会把较长的 "UP主 · 日期" 缩到几乎看不清，超出部分改为截断
        upLabel.adjustsFontSizeToFitWidth = true
        upLabel.minimumScaleFactor = 0.8
        upLabel.lineBreakMode = .byTruncatingTail
        updateStyle()
    }

    func setup(data: any DisplayData, indexPath: IndexPath? = nil) {
        updateStyle()
        titleLabel.text = data.title
        if let index = indexPath, index.row <= 98 {
            sortLabel.isHidden = false
            sortLabel.text = String(index.row + 1)
            sortLabel.sizeToFit()
        } else {
            sortLabel.text = "0"
            sortLabel.isHidden = true
        }
        upLabel.text = [data.ownerName, data.date].compactMap({ $0 }).joined(separator: " · ")
        if var pic = data.pic {
            if pic.scheme == nil {
                pic = URL(string: "http:\(pic.absoluteString)")!
            }
            // 按卡片实际尺寸 × 屏幕 scale 降采样：4K 下不再把 720px 的图拉伸到 1000+px 显示发虚，
            // 1080p 或小卡片下则比原先固定的 720px 更省内存
            let width = bounds.width > 0 ? bounds.width : 720
            imageView.kf.setImage(with: pic, options: [
                .processor(DownsamplingImageProcessor(size: CGSize(width: width, height: width * 9 / 16))),
                .scaleFactor(traitCollection.displayScale),
                .cacheOriginalImage,
            ])
        }
        if let avatar = data.avatar {
            avatarView.isHidden = false
            avatarView.kf.setImage(with: avatar.biliAvatarThumbnail, options: .roundAvatar)
        } else {
            avatarView.isHidden = true
        }
    }

    private func updateStyle() {
        let style = styleOverride ?? Settings.displayStyle
        guard oldStyle != style else { return }
        oldStyle = style

        titleLabel.font = style.titleFont
        upLabel.font = style.upFont
        sortLabel.font = style.sortFont
        switch style {
        case .big, .large:
            imageView.layer.cornerRadius = lessBigSornerRadius
        case .normal, .sideBar:
            imageView.layer.cornerRadius = normailSornerRadius
        }
        avatarHeightConstraint?.update(offset: style == .large ? 44 : 33)
    }

    @objc private func actionLongPress(sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        onLongPress?()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.kf.cancelDownloadTask()
        avatarView.kf.cancelDownloadTask()
        onLongPress = nil
        avatarView.image = nil
        infoView.alpha = Self.infoAlphaNormal
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations {
            self.infoView.alpha = self.isFocused ? 1 : Self.infoAlphaNormal
        }
    }
}

extension FeedDisplayStyle {
    var fractionalWidth: CGFloat {
        switch self {
        case .big:
            return 1.0 / CGFloat(bigItmeCount)
        case .large:
            return 1.0 / CGFloat(largeItmeCount)
        case .normal:
            return 1.0 / CGFloat(normalItmeCount)
        case .sideBar:
            return 1.0 / CGFloat(largeItmeCount)
        }
    }

    var fractionalHeight: CGFloat {
        switch self {
        case .large, .big:
            return fractionalWidth / 1.5
        case .normal:
            return fractionalWidth / 1.5
        case .sideBar:
            return fractionalWidth / 1.15
        }
    }

    var groupFractionalHeight: CGFloat {
        switch self {
        case .big:
            return 2 / 5
        case .large, .normal, .sideBar:
            return 1 / 3
        }
    }

    var hSpacing: CGFloat {
        switch self {
        case .big:
            return 30
        case .large, .normal, .sideBar:
            return 20
        }
    }

    var titleFont: UIFont {
        switch self {
        case .large, .big:
            return UIFont.systemFont(ofSize: 26, weight: .semibold)
        case .normal:
            return UIFont.systemFont(ofSize: 26, weight: .semibold)
        case .sideBar:
            return UIFont.systemFont(ofSize: 24, weight: .semibold)
        }
    }

    var upFont: UIFont {
        switch self {
        case .large, .big:
            return UIFont.systemFont(ofSize: 20)
        case .normal:
            return UIFont.systemFont(ofSize: 20)
        case .sideBar:
            return UIFont.systemFont(ofSize: 18, weight: .semibold)
        }
    }

    var sortFont: UIFont {
        switch self {
        case .large, .big:
            return UIFont.systemFont(ofSize: 60, weight: .bold)
        case .normal:
            return UIFont.systemFont(ofSize: 50, weight: .bold)
        case .sideBar:
            return UIFont.systemFont(ofSize: 50, weight: .bold)
        }
    }
}
