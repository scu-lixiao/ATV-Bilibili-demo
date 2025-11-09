//
//  SkeletonLoadingView.swift
//  BilibiliLive
//
//  Premium skeleton loading animations for content placeholders
//  Elegant shimmer effects during async loading states
//

import UIKit

// MARK: - Skeleton Configuration

struct SkeletonConfig {
    let baseColor: UIColor
    let shimmerColor: UIColor
    let animationDuration: TimeInterval
    let cornerRadius: CGFloat
    let shimmerAngle: CGFloat
    
    static let `default` = SkeletonConfig(
        baseColor: UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0),  // elevatedDarkBG
        shimmerColor: UIColor(white: 0.25, alpha: 1.0),
        animationDuration: 1.5,
        cornerRadius: 24,  // medium corner radius
        shimmerAngle: -20 * .pi / 180
    )
    
    static let premium = SkeletonConfig(
        baseColor: UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0),  // elevatedDarkBG
        shimmerColor: UIColor(red: 1.0, green: 0.4, blue: 0.7, alpha: 0.15),  // luminousPink with alpha
        animationDuration: 1.8,
        cornerRadius: 24,  // medium corner radius
        shimmerAngle: -20 * .pi / 180
    )
    
    static let card = SkeletonConfig(
        baseColor: UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0),  // elevatedDarkBG
        shimmerColor: UIColor(white: 0.22, alpha: 1.0),
        animationDuration: 1.6,
        cornerRadius: 44,  // large corner radius
        shimmerAngle: -25 * .pi / 180
    )
}

// MARK: - Skeleton View

class SkeletonView: UIView {
    
    private let gradientLayer = CAGradientLayer()
    private var config: SkeletonConfig
    
    var isAnimating: Bool {
        return gradientLayer.animation(forKey: "shimmer") != nil
    }
    
    init(config: SkeletonConfig = .default) {
        self.config = config
        super.init(frame: .zero)
        setupSkeleton()
    }
    
    required init?(coder: NSCoder) {
        self.config = .default
        super.init(coder: coder)
        setupSkeleton()
    }
    
    private func setupSkeleton() {
        backgroundColor = config.baseColor
        layer.cornerRadius = config.cornerRadius
        clipsToBounds = true
        
        // Setup gradient for shimmer effect
        gradientLayer.colors = [
            config.baseColor.cgColor,
            config.shimmerColor.cgColor,
            config.baseColor.cgColor
        ]
        
        gradientLayer.locations = [0, 0.5, 1]
        
        // Angle the gradient
        let angle = config.shimmerAngle
        gradientLayer.startPoint = CGPoint(
            x: 0.5 + cos(angle) * 0.5,
            y: 0.5 + sin(angle) * 0.5
        )
        gradientLayer.endPoint = CGPoint(
            x: 0.5 - cos(angle) * 0.5,
            y: 0.5 - sin(angle) * 0.5
        )
        
        layer.addSublayer(gradientLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Make gradient wider than view for smooth animation
        let width = bounds.width
        let height = bounds.height
        gradientLayer.frame = CGRect(
            x: -width,
            y: 0,
            width: width * 3,
            height: height
        )
    }
    
    /// Start shimmer animation
    func startAnimating() {
        guard !isAnimating else { return }
        
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = 0
        animation.toValue = bounds.width * 2
        animation.duration = config.animationDuration
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        gradientLayer.add(animation, forKey: "shimmer")
    }
    
    /// Stop shimmer animation
    func stopAnimating() {
        gradientLayer.removeAnimation(forKey: "shimmer")
    }
}

// MARK: - UIView + Skeleton

extension UIView {
    
    private struct AssociatedKeys {
        static var skeletonViews = "skeletonViews"
        static var originalSubviews = "originalSubviews"
    }
    
    private var skeletonViews: [UIView] {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.skeletonViews) as? [UIView] ?? []
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.skeletonViews, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// Show skeleton loading state
    /// - Parameters:
    ///   - config: Skeleton configuration
    ///   - animated: Whether to animate appearance
    func showSkeleton(config: SkeletonConfig = .default, animated: Bool = true) {
        // Remove existing skeletons
        hideSkeleton(animated: false)
        
        // Create skeleton views for skeletonable subviews
        let skeletons = createSkeletonViews(config: config)
        skeletonViews = skeletons
        
        skeletons.forEach { skeleton in
            addSubview(skeleton)
            if let skeletonView = skeleton as? SkeletonView {
                skeletonView.startAnimating()
            }
        }
        
        // Animate appearance
        if animated {
            skeletons.forEach { skeleton in
                skeleton.alpha = 0
                UIView.animate(
                    withDuration: 0.25,
                    delay: 0,
                    options: [.curveEaseOut]
                ) {
                    skeleton.alpha = 1.0
                }
            }
        }
        
        // Hide original content
        subviews.forEach { view in
            guard !skeletons.contains(view) else { return }
            view.alpha = 0
        }
    }
    
    /// Hide skeleton and show content
    /// - Parameter animated: Whether to animate disappearance
    func hideSkeleton(animated: Bool = true) {
        let skeletons = skeletonViews
        
        if animated {
            // Show original content
            subviews.forEach { view in
                guard !skeletons.contains(view) else { return }
                UIView.animate(
                    withDuration: 0.25,
                    delay: 0,
                    options: [.curveEaseIn]
                ) {
                    view.alpha = 1.0
                }
            }
            
            // Hide skeletons
            UIView.animate(
                withDuration: 0.25,
                delay: 0,
                options: [.curveEaseIn],
                animations: {
                    skeletons.forEach { $0.alpha = 0 }
                },
                completion: { _ in
                    skeletons.forEach { skeleton in
                        if let skeletonView = skeleton as? SkeletonView {
                            skeletonView.stopAnimating()
                        }
                        skeleton.removeFromSuperview()
                    }
                }
            )
        } else {
            // Immediate removal
            skeletons.forEach { skeleton in
                if let skeletonView = skeleton as? SkeletonView {
                    skeletonView.stopAnimating()
                }
                skeleton.removeFromSuperview()
            }
            
            // Show original content
            subviews.forEach { $0.alpha = 1.0 }
        }
        
        skeletonViews = []
    }
    
    private func createSkeletonViews(config: SkeletonConfig) -> [UIView] {
        var skeletons: [UIView] = []
        
        // Auto-detect skeletonable views (labels, imageviews, buttons)
        for subview in subviews {
            if subview is UILabel {
                let skeleton = createTextSkeleton(for: subview, config: config)
                skeletons.append(skeleton)
            } else if subview is UIImageView {
                let skeleton = createImageSkeleton(for: subview, config: config)
                skeletons.append(skeleton)
            } else if subview is UIButton {
                let skeleton = createButtonSkeleton(for: subview, config: config)
                skeletons.append(skeleton)
            }
        }
        
        return skeletons
    }
    
    private func createTextSkeleton(for view: UIView, config: SkeletonConfig) -> UIView {
        let skeleton = SkeletonView(config: config)
        skeleton.frame = view.frame
        
        // Make text skeleton narrower and multi-line aware
        if let label = view as? UILabel {
            let lineHeight: CGFloat = 16
            let lines = max(1, label.numberOfLines == 0 ? 3 : label.numberOfLines)
            
            skeleton.frame.size.height = CGFloat(lines) * lineHeight + CGFloat(lines - 1) * 4
            skeleton.frame.size.width = view.frame.width * 0.7 // 70% width for natural look
        }
        
        return skeleton
    }
    
    private func createImageSkeleton(for view: UIView, config: SkeletonConfig) -> UIView {
        let skeleton = SkeletonView(config: config)
        skeleton.frame = view.frame
        return skeleton
    }
    
    private func createButtonSkeleton(for view: UIView, config: SkeletonConfig) -> UIView {
        let skeleton = SkeletonView(config: config)
        skeleton.frame = view.frame
        return skeleton
    }
}

// MARK: - Skeletonable Protocol

protocol Skeletonable {
    var isSkeletonEnabled: Bool { get set }
    func showSkeleton()
    func hideSkeleton()
}

extension Skeletonable where Self: UIView {
    func showSkeleton() {
        showSkeleton(config: .default, animated: true)
    }
    
    func hideSkeleton() {
        hideSkeleton(animated: true)
    }
}

// MARK: - Pre-built Skeleton Templates

class VideoCardSkeletonView: UIView {
    
    private let thumbnailSkeleton = SkeletonView(config: .card)
    private let titleSkeleton = SkeletonView(config: .default)
    private let subtitleSkeleton = SkeletonView(config: .default)
    private let avatarSkeleton = SkeletonView(config: .default)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSkeletons()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSkeletons()
    }
    
    private func setupSkeletons() {
        // Thumbnail (16:9 aspect ratio)
        addSubview(thumbnailSkeleton)
        thumbnailSkeleton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            thumbnailSkeleton.topAnchor.constraint(equalTo: topAnchor),
            thumbnailSkeleton.leadingAnchor.constraint(equalTo: leadingAnchor),
            thumbnailSkeleton.trailingAnchor.constraint(equalTo: trailingAnchor),
            thumbnailSkeleton.heightAnchor.constraint(equalTo: thumbnailSkeleton.widthAnchor, multiplier: 9.0/16.0)
        ])
        
        // Title
        addSubview(titleSkeleton)
        titleSkeleton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleSkeleton.topAnchor.constraint(equalTo: thumbnailSkeleton.bottomAnchor, constant: 12),
            titleSkeleton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleSkeleton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
            titleSkeleton.heightAnchor.constraint(equalToConstant: 18)
        ])
        
        // Subtitle
        addSubview(subtitleSkeleton)
        subtitleSkeleton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            subtitleSkeleton.topAnchor.constraint(equalTo: titleSkeleton.bottomAnchor, constant: 8),
            subtitleSkeleton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            subtitleSkeleton.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.5),
            subtitleSkeleton.heightAnchor.constraint(equalToConstant: 14)
        ])
        
        // Avatar
        addSubview(avatarSkeleton)
        avatarSkeleton.translatesAutoresizingMaskIntoConstraints = false
        avatarSkeleton.layer.cornerRadius = 18
        NSLayoutConstraint.activate([
            avatarSkeleton.topAnchor.constraint(equalTo: thumbnailSkeleton.bottomAnchor, constant: 12),
            avatarSkeleton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            avatarSkeleton.widthAnchor.constraint(equalToConstant: 36),
            avatarSkeleton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }
    
    func startAnimating() {
        thumbnailSkeleton.startAnimating()
        titleSkeleton.startAnimating()
        subtitleSkeleton.startAnimating()
        avatarSkeleton.startAnimating()
    }
    
    func stopAnimating() {
        thumbnailSkeleton.stopAnimating()
        titleSkeleton.stopAnimating()
        subtitleSkeleton.stopAnimating()
        avatarSkeleton.stopAnimating()
    }
}

// MARK: - Collection View Skeleton

extension UICollectionView {
    
    /// Show skeleton for all visible cells
    func showCellSkeletons(config: SkeletonConfig = .card) {
        visibleCells.forEach { cell in
            cell.contentView.showSkeleton(config: config, animated: true)
        }
    }
    
    /// Hide skeleton for all visible cells
    func hideCellSkeletons() {
        visibleCells.forEach { cell in
            cell.contentView.hideSkeleton(animated: true)
        }
    }
}

// MARK: - Usage Helpers

extension UIViewController {
    
    /// Show skeleton loading state for main view
    func showLoadingSkeleton(config: SkeletonConfig = .default) {
        view.showSkeleton(config: config, animated: true)
    }
    
    /// Hide skeleton loading state
    func hideLoadingSkeleton() {
        view.hideSkeleton(animated: true)
    }
}
