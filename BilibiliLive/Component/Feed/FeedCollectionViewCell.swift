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

    private let titleLabel = UILabel()
    private let upLabel = UILabel()
    private let sortLabel = UILabel()
    private let imageView = UIImageView()
    private let imageViewParallax = UIImageView()
    let infoView = UIView()
    private let avatarView = UIImageView()
    private var oldStyle: FeedDisplayStyle?

    deinit {
        print("🧹 FeedCollectionViewCell deinitialized")
    }
    
    override func setup() {
        super.setup()
        let longpress = UILongPressGestureRecognizer(target: self, action: #selector(actionLongPress(sender:)))
        addGestureRecognizer(longpress)

        // Tag for parallax effect
        contentView.tag = 999
        
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.top.equalToSuperview()
            make.height.equalTo(imageView.snp.width).multipliedBy(9.0 / 16)
        }
        
//        contentView.addSubview(imageViewParallax)
//        imageViewParallax.snp.makeConstraints { make in
//            make.leading.equalToSuperview()
//            make.trailing.equalToSuperview()
//            make.top.equalToSuperview()
//            make.height.equalTo(imageViewParallax.snp.width).multipliedBy(9.0 / 16)
//        }
//        
//        imageViewParallax.image = UIImage(named: "cover")
//        imageViewParallax.backgroundColor = .red
        
        imageView.adjustsImageWhenAncestorFocused = true
        let style = styleOverride ?? Settings.displayStyle

//        switch style.feedColCount {
//        case 3:
//            imageView.layer.cornerRadius = lessBigSornerRadius
//        case 4:
//            imageView.layer.cornerRadius = lessBigSornerRadius
//        case 5:
//            imageView.layer.cornerRadius = normailSornerRadius
//        default:
//            imageView.layer.cornerRadius = lessBigSornerRadius
//        }
//        imageView.layer.cornerCurve = .continuous
//        imageView.layer.masksToBounds = true
//        imageView.layer.shouldRasterize = true
//        imageView.layer.rasterizationScale = UIScreen.main.scale
//        imageView.contentMode = .scaleAspectFill

        imageView.addSubview(avatarView)

        infoView.alpha = 0.8
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

        let aHeight: CGFloat = style == .large ? 44 : 33
        avatarView.snp.makeConstraints { make in
            make.bottom.right.equalToSuperview().offset(-4)
            make.width.equalTo(avatarView.snp.height)
            make.height.equalTo(aHeight)
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
        upLabel.adjustsFontSizeToFitWidth = true
        upLabel.minimumScaleFactor = 0.1
    }
   

    func setup(data: any DisplayData, indexPath: IndexPath? = nil) {
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
            imageView.kf.setImage(with: pic, options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 720, height: 404))), .cacheOriginalImage]) { [weak self] result in
                guard let self = self else { return }
                // Apply smart glow based on image content after loading
                if case .success(let imageResult) = result {
                    self.imageView.applySmartGlow(from: imageResult.image, config: .subtle)
                }
            }
        }
        if let avatar = data.avatar {
            avatarView.isHidden = false
            avatarView.kf.setImage(with: avatar, options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 80, height: 80))), .processor(RoundCornerImageProcessor(radius: .widthFraction(0.5))), .cacheSerializer(FormatIndicatedCacheSerializer.png)])
        } else {
            avatarView.isHidden = true
        }
        updateStyle()
    }

    private func updateStyle() {
        let style = styleOverride ?? Settings.displayStyle
        if oldStyle != style {
            titleLabel.font = style.titleFont
            upLabel.font = style.upFont
            sortLabel.font = style.sortFont
        }

        oldStyle = style
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
        
        // Remove glow effects
        imageView.removeGlow()
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        coordinator.addCoordinatedAnimations {
            if self.isFocused {
                // Enhanced focus glow with smart color adaptation
                self.imageView.applySmartFocusGlow(from: self.imageView.image, isFocused: true)
                
                // 🚀 Performance: Disable rasterization when focused (dynamic content)
                self.imageView.layer.disableRasterization()
            } else {
                // Fade out glow
                self.imageView.animateGlowIntensity(to: 0.3, duration: 0.3)
                
                // 🚀 Performance: Enable rasterization when unfocused (static content)
                self.imageView.isStatic(timeout: 0.5) { [weak self] isStatic in
                    if isStatic {
                        self?.imageView.layer.enableSmartRasterization()
                    }
                }
            }
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

    var heightEstimated: CGFloat {
        switch self {
        case .big:
            return 516
        case .large:
            return 516
        case .normal, .sideBar:
            return 380
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
