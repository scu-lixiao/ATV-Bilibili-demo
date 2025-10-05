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
        layer.shadowRadius = 25
        layer.shadowOffset = CGSize(width: 0, height: 20)
    }

    // MARK: - Focus Handling

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        // Cancel any ongoing animations.
        focusAnimator?.stopAnimation(true)

        // Create a new animator for the focus transition.
        focusAnimator = UIViewPropertyAnimator(duration: 0.5, dampingRatio: 0.8) {
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

        // Enhance shadow and reveal the blur effect.
        layer.shadowOpacity = 0.4
        blurEffectView.alpha = 1.0
    }

    private func applyUnfocusedState() {
        // Reset all transformations and effects.
        layer.transform = CATransform3DIdentity
        layer.shadowOpacity = 0
        blurEffectView.alpha = 0
    }
}
