//
//  BLMotionCollectionViewCell.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/23.
//

import TVUIKit
import UIKit

class BLMotionCollectionViewCell: UICollectionViewCell {
    // MARK: - Properties

    var scaleFactor: CGFloat = 1.15

    // Premium 2025 enhancement: Deep background gradient layer
    private var deepBackgroundLayer: CAGradientLayer?

    // Premium 2025 enhancement: Multi-layered shadow system
    private var secondaryShadowLayer: CALayer?

    // --- Private Properties ---

    // A view that provides a frosted-glass effect.
    private lazy var blurEffectView: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: .dark)
        let view = UIVisualEffectView(effect: blurEffect)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alpha = 0
        return view
    }()

    // Animator for focus-related animations.
    private var focusAnimator: UIViewPropertyAnimator?

    // MARK: - State Management (Fix for selection gray-out issue)

    override var isSelected: Bool {
        didSet {
            // Prevent default UICollectionViewCell selection behavior
            // which causes the cell to gray out
        }
    }

    override var isHighlighted: Bool {
        didSet {
            // Prevent default UICollectionViewCell highlight behavior
        }
    }

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }

    // MARK: - Cell Setup

    func setupCell() {
        // Premium 2025: Setup deep background gradient layer
        setupDeepBackgroundLayer()

        // Premium 2025: Setup multi-layered shadow system
        setupMultiLayeredShadows()

        // Insert the blur view at the bottom of the view hierarchy.
        contentView.insertSubview(blurEffectView, at: 0)

        // Set up constraints for the blur view to fill the cell.
        NSLayoutConstraint.activate([
            blurEffectView.topAnchor.constraint(equalTo: contentView.topAnchor),
            blurEffectView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            blurEffectView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            blurEffectView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        // Configure layer properties for a premium look.
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowRadius = 45 // Premium 2025: Increased from 25 to 45 for deeper shadows
        layer.shadowOffset = CGSize(width: 0, height: 20)
    }

    // MARK: - Premium 2025 Setup Methods

    /// Setup deep background gradient for enhanced dark mode depth
    private func setupDeepBackgroundLayer() {
        deepBackgroundLayer = CAGradientLayer()
        guard let deepBackgroundLayer = deepBackgroundLayer else { return }

        deepBackgroundLayer.frame = contentView.bounds

        // Deep blue-black gradient for premium dark mode feel
        deepBackgroundLayer.colors = [
            UIColor(red: 0.04, green: 0.055, blue: 0.10, alpha: 1.0).cgColor, // #0a0e1a
            UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0).cgColor, // #000000
        ]
        deepBackgroundLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        deepBackgroundLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        deepBackgroundLayer.cornerRadius = 12
        deepBackgroundLayer.opacity = 0.0 // Will animate on focus

        contentView.layer.insertSublayer(deepBackgroundLayer, at: 0)
    }

    /// Setup multi-layered shadow system for depth perception
    private func setupMultiLayeredShadows() {
        secondaryShadowLayer = CALayer()
        guard let secondaryShadowLayer = secondaryShadowLayer else { return }

        secondaryShadowLayer.frame = bounds
        secondaryShadowLayer.cornerRadius = 12
        secondaryShadowLayer.shadowColor = UIColor(red: 0.3, green: 0.4, blue: 0.8, alpha: 1.0).cgColor // Subtle blue tint
        secondaryShadowLayer.shadowRadius = 60 // Larger, softer shadow
        secondaryShadowLayer.shadowOffset = CGSize(width: 0, height: 30)
        secondaryShadowLayer.shadowOpacity = 0.0 // Will animate on focus

        layer.insertSublayer(secondaryShadowLayer, at: 0)
    }

    // MARK: - Focus Handling

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        // Cancel any ongoing animations.
        focusAnimator?.stopAnimation(true)

        // Premium 2025: Enhanced fluid animation with lower damping ratio for smoother feel
        focusAnimator = UIViewPropertyAnimator(duration: 0.65, dampingRatio: 0.68) {
            if self.isFocused {
                self.applyFocusedState()
            } else {
                self.applyUnfocusedState()
            }
        }

        focusAnimator?.startAnimation()
    }

    private func applyFocusedState() {
        // Apply a 3D transform for a subtle lift and tilt effect.
        var transform = CATransform3DIdentity
        transform = CATransform3DScale(transform, scaleFactor, scaleFactor, 1)
        transform.m34 = 1.0 / -1000 // Perspective
        transform = CATransform3DRotate(transform, 0.1, 1, 0, 0) // Tilt

        layer.transform = transform

        // Premium 2025: Enhanced shadow system with deeper, more pronounced shadows
        layer.shadowOpacity = 0.6 // Increased from 0.4 for more depth
        secondaryShadowLayer?.shadowOpacity = 0.3 // Secondary shadow for layered depth

        // Premium 2025: Reveal deep background gradient
        deepBackgroundLayer?.opacity = 0.8

        // Fix: Reduce blur effect to prevent content blocking
        // Changed from 1.0 to 0.0 to avoid obscuring content
        blurEffectView.alpha = 0.0
    }

    private func applyUnfocusedState() {
        // Reset all transformations and effects.
        layer.transform = CATransform3DIdentity

        // Premium 2025: Subtle shadows remain for ambient depth
        layer.shadowOpacity = 0.15 // Changed from 0 to maintain subtle depth
        secondaryShadowLayer?.shadowOpacity = 0.0

        // Premium 2025: Fade out deep background
        deepBackgroundLayer?.opacity = 0.0

        blurEffectView.alpha = 0
    }

    // MARK: - Cell Reuse

    override func prepareForReuse() {
        super.prepareForReuse()

        // Reset alpha to prevent gray-out after selection
        contentView.alpha = 1.0
        alpha = 1.0

        // Reset transform to identity
        layer.transform = CATransform3DIdentity

        // Ensure unfocused state
        if !isFocused {
            applyUnfocusedState()
        }
    }
}
