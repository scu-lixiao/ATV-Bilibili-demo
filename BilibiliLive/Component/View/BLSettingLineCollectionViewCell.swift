//
//  BLSettingLineCollectionViewCell.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/29.
//
//  Aurora Glass Enhancement: 2025-10-07
//  Enhanced with Bilibili brand gradient and glass effects
//

import UIKit

class BLSettingLineCollectionViewCell: BLMotionCollectionViewCell {
    let titleLabel = UILabel()

    // MARK: - Aurora Glass Visual Constants

    // Gradient colors for unfocused state
    private let unfocusedGradientColors = [
        UIColor(hex: 0x1A1A1A, alpha: 0.7).cgColor,
        UIColor(hex: 0x000000, alpha: 0.85).cgColor,
    ]

    // Gradient colors for focused state (Bilibili brand colors)
    private let focusedGradientColors = [
        UIColor.bilipink.cgColor, // #FF6699
        UIColor.biliblue.cgColor, // #00AEEC
    ]

    // Shadow parameters
    private let unfocusedShadowOpacity: Float = 0.3
    private let focusedShadowOpacity: Float = 0.5
    private let unfocusedShadowRadius: CGFloat = 15
    private let focusedShadowRadius: CGFloat = 25

    // Animation parameters
    private let focusAnimationDuration: TimeInterval = 0.5
    private let focusAnimationDamping: CGFloat = 0.7
    private let focusAnimationVelocity: CGFloat = 0.8

    override var isSelected: Bool {
        didSet {
            // We can add selection-specific visual changes here if needed in the future.
        }
    }

    override func setupCell() {
        super.setupCell()
        scaleFactor = 1.05 // A more subtle scale for settings items.

        // Configure the title label for the dark theme.
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.7) // Aurora: Start with dimmed text
        titleLabel.textAlignment = .left
        titleLabel.font = UIFont.systemFont(ofSize: 40, weight: .regular)

        // Add the label directly to the content view to sit atop the inherited blur effect.
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(26)
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
        }

        // Aurora Glass: Configure visual effects
        configureAuroraGlassEffect()
    }

    // MARK: - Aurora Glass Configuration

    private func configureAuroraGlassEffect() {
        // Configure gradient layer (using parent's deepBackgroundLayer)
        if let gradientLayer = contentView.layer.sublayers?.first(where: { $0 is CAGradientLayer }) as? CAGradientLayer {
            gradientLayer.colors = unfocusedGradientColors
            gradientLayer.startPoint = CGPoint(x: 0, y: 0)
            gradientLayer.endPoint = CGPoint(x: 1, y: 1) // Diagonal gradient for dynamic feel
        }

        // Configure rounded corners
        contentView.layer.cornerRadius = 12
        contentView.layer.cornerCurve = .continuous
        contentView.layer.masksToBounds = false

        // Configure main shadow
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOpacity = unfocusedShadowOpacity
        contentView.layer.shadowRadius = unfocusedShadowRadius
        contentView.layer.shadowOffset = CGSize(width: 0, height: 8)

        // Configure secondary shadow layer (using parent's secondaryShadowLayer)
        if let secondaryShadow = contentView.layer.sublayers?.first(where: { $0 !== contentView.layer.sublayers?.first }) {
            secondaryShadow.shadowColor = UIColor.bilipink.cgColor
            secondaryShadow.shadowOpacity = 0.0 // Start hidden
            secondaryShadow.shadowRadius = 30
            secondaryShadow.shadowOffset = CGSize(width: 0, height: 12)
        }
    }

    // MARK: - Focus Animation Override

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        let isFocused = (context.nextFocusedView == self)

        // Use coordinator for synchronized animations
        coordinator.addCoordinatedAnimations({ [weak self] in
            guard let self = self else { return }

            // Update all visual elements with spring animation
            UIView.animate(
                withDuration: self.focusAnimationDuration,
                delay: 0,
                usingSpringWithDamping: self.focusAnimationDamping,
                initialSpringVelocity: self.focusAnimationVelocity,
                options: [.curveEaseInOut, .allowUserInteraction],
                animations: {
                    self.updateGradientColors(isFocused: isFocused)
                    self.updateShadowEffect(isFocused: isFocused)
                    self.updateBlurEffect(isFocused: isFocused)
                    self.updateTextEffect(isFocused: isFocused)
                },
                completion: nil
            )
        }, completion: nil)
    }

    // MARK: - Visual Update Methods

    private func updateGradientColors(isFocused: Bool) {
        // Update gradient colors with smooth transition
        if let gradientLayer = contentView.layer.sublayers?.first(where: { $0 is CAGradientLayer }) as? CAGradientLayer {
            CATransaction.begin()
            CATransaction.setAnimationDuration(focusAnimationDuration)
            CATransaction.setAnimationTimingFunction(
                CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1) // Spring curve
            )

            gradientLayer.colors = isFocused ? focusedGradientColors : unfocusedGradientColors

            CATransaction.commit()
        }
    }

    private func updateShadowEffect(isFocused: Bool) {
        // Main shadow
        contentView.layer.shadowOpacity = isFocused ? focusedShadowOpacity : unfocusedShadowOpacity
        contentView.layer.shadowRadius = isFocused ? focusedShadowRadius : unfocusedShadowRadius

        // Secondary colored shadow (Bilibili pink glow)
        if let secondaryShadow = contentView.layer.sublayers?.first(where: { $0 !== contentView.layer.sublayers?.first }) {
            secondaryShadow.shadowOpacity = isFocused ? 0.3 : 0.0
        }
    }

    private func updateBlurEffect(isFocused: Bool) {
        // Access parent's blur effect view
        if let blurView = contentView.subviews.first(where: { $0 is UIVisualEffectView }) as? UIVisualEffectView {
            blurView.alpha = isFocused ? 0.9 : 0.0
        }
    }

    private func updateTextEffect(isFocused: Bool) {
        // Update text color and glow effect
        titleLabel.textColor = isFocused ? .white : UIColor.white.withAlphaComponent(0.7)

        // Add text glow when focused
        if isFocused {
            titleLabel.layer.shadowColor = UIColor.white.cgColor
            titleLabel.layer.shadowOpacity = 0.5
            titleLabel.layer.shadowRadius = 8
            titleLabel.layer.shadowOffset = .zero
        } else {
            titleLabel.layer.shadowOpacity = 0.0
        }
    }

    // MARK: - Memory Management

    deinit {
        // Cleanup is handled by parent class BLMotionCollectionViewCell
    }

    // MARK: - Layout

    static func makeLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.9),
                                              heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .absolute(70))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize,
                                                       subitems: [item])
        group.edgeSpacing = .init(leading: nil, top: .fixed(10), trailing: nil, bottom: nil)
        let section = NSCollectionLayoutSection(group: group)
        let layout = UICollectionViewCompositionalLayout(section: section)
        return layout
    }
}
