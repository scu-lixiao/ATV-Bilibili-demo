//
//  BLMenuLineCollectionViewCell.swift
//  BilibiliLive
//
//  Created by ManTie on 2024/7/4.
//

import UIKit

class BLMenuLineCollectionViewCell: BLSettingLineCollectionViewCell {
    var iconImageView = UIImageView()
    
    override func addsubViews() {
        // Apply multi-layer glass effect for premium look
        selectedWhiteView.setCornerRadius(cornerRadius: height / 2)
        selectedWhiteView.isHidden = !isFocused
        addSubview(selectedWhiteView)
        selectedWhiteView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Apply initial glass state
        applyGlassEffect(isFocused: false)
        
        addSubview(iconImageView)
        let imageViewHeight = 32.0
        iconImageView.setCornerRadius(cornerRadius: imageViewHeight / 2.0)
        iconImageView.contentMode = .scaleAspectFit
        
        iconImageView.setImageColor(color: UIColor(named: "titleColor"))
        iconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(imageViewHeight)
            make.left.equalTo(16)
            make.centerY.equalToSuperview()
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(iconImageView.snp.right).offset(12)
            make.trailing.equalToSuperview().offset(8)
            make.centerY.equalTo(iconImageView)
        }
        titleLabel.textAlignment = .left
        titleLabel.font = UIFont.systemFont(ofSize: 26, weight: .medium)
        titleLabel.textColor = UIColor(named: "titleColor")
    }
    
    // MARK: - Glass Effect Methods
    
    /// Applies glass effect based on focus state
    override func applyGlassEffect(isFocused: Bool) {
        if #available(tvOS 26.0, *) {
            // Use the new multi-layer glass system
            GlassNavigationHelper.applyMultiLayerGlass(
                to: selectedWhiteView,
                config: .menuItem,
                isFocused: isFocused
            )
        } else {
            // Fallback for older tvOS versions
            if isFocused {
                selectedWhiteView.backgroundColor = UIColor(named: "menuCellColor")?.withAlphaComponent(0.3)
            } else {
                selectedWhiteView.backgroundColor = UIColor(named: "menuCellColor")?.withAlphaComponent(0.15)
            }
        }
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        // 🎯 Phase 3: Use spring animations for smoother focus transitions
        coordinator.addCoordinatedAnimations({ [weak self] in
            guard let self = self else { return }
            
            // Animate glass effect transition
            self.applyGlassEffect(isFocused: self.isFocused)
            self.selectedWhiteView.isHidden = !self.isFocused
            
            // Enhanced scale animation for focus
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                
                // Brighten icon and text
                self.iconImageView.alpha = 1.0
                self.titleLabel.alpha = 1.0
            } else {
                self.transform = .identity
                
                // Subtle dimming when unfocused
                self.iconImageView.alpha = 0.8
                self.titleLabel.alpha = 0.8
            }
        }, completion: nil)
    }
}
