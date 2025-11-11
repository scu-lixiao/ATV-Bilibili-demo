//
//  BLSettingLineCollectionViewCell.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/29.
//  Enhanced with Glass Navigation Effect - 2025/11/11
//

import UIKit

class BLSettingLineCollectionViewCell: BLMotionCollectionViewCell {
    let selectedWhiteView = UIView()
    let titleLabel = UILabel()
    
    // 添加一个回调，用于通知父视图焦点变化
    var onFocusChanged: ((Bool) -> Void)?
    
    override var isSelected: Bool {
        didSet {
            updateView()
        }
    }

    override func setup() {
        super.setup()
        scaleFactor = 1.05
        addsubViews()
    }

    func addsubViews() {
        // Apply glass effect container
        selectedWhiteView.setCornerRadius(cornerRadius: moreLittleSornerRadius)
        selectedWhiteView.isHidden = !isFocused
        contentView.addSubview(selectedWhiteView)
        selectedWhiteView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Apply initial glass state
        applyGlassEffect(isFocused: false)
        
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(26)
            make.trailing.equalToSuperview().offset(-26)
            make.top.bottom.equalToSuperview().inset(8)
        }
        titleLabel.textAlignment = .left
        titleLabel.font = UIFont.systemFont(ofSize: 30, weight: .medium)
        titleLabel.textColor = UIColor(named: "titleColor") ?? .white
    }

    // MARK: - Glass Effect Methods
    
    /// Applies glass effect based on focus state
    func applyGlassEffect(isFocused: Bool) {
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
                selectedWhiteView.layer.borderWidth = 0.5
                selectedWhiteView.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
            } else {
                selectedWhiteView.backgroundColor = UIColor(named: "menuCellColor")?.withAlphaComponent(0.15)
                selectedWhiteView.layer.borderWidth = 0
            }
            selectedWhiteView.layer.cornerRadius = moreLittleSornerRadius
        }
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        // 通知父视图焦点变化
        onFocusChanged?(isFocused)
        
        // Animate glass effect transition with spring physics
        coordinator.addCoordinatedAnimations({ [weak self] in
            guard let self = self else { return }
            
            // Update glass effect
            self.applyGlassEffect(isFocused: self.isFocused)
            self.updateView()
            
            // Enhanced scale animation for focus
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.03, y: 1.03)
                self.titleLabel.alpha = 1.0
            } else {
                self.transform = CGAffineTransform.identity
                self.titleLabel.alpha = 0.85
            }
        }, completion: nil)
    }

    func updateView() {
        selectedWhiteView.isHidden = !(isFocused || isSelected)
    }

    static func makeLayout() -> UICollectionViewCompositionalLayout {
        // 每个 item 的尺寸（宽度占容器的 90%，高度占满 group）
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.85),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        // 每个 group 的尺寸（宽度占满容器，高度固定 70pt）
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(70)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )

        // 创建 section
        let section = NSCollectionLayoutSection(group: group)

        // 🔹 垂直滚动方向
        section.orthogonalScrollingBehavior = .none

        // 🔹 cell 垂直方向间距
        section.interGroupSpacing = 12

        // 🔹 内容内边距：上下间距 + 左右留白（居中效果）
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 20, leading: 0, bottom: 20, trailing: 0
        )
        // ✅ 最终布局对象
        return UICollectionViewCompositionalLayout(section: section)
    }
}
