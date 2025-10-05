//
//  BLSettingLineCollectionViewCell.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/29.
//

import UIKit

class BLSettingLineCollectionViewCell: BLMotionCollectionViewCell {
    let titleLabel = UILabel()

    override var isSelected: Bool {
        didSet {
            // We can add selection-specific visual changes here if needed in the future.
        }
    }

    override func setupCell() {
        super.setupCell()
        scaleFactor = 1.05 // A more subtle scale for settings items.

        // Configure the title label for the dark theme.
        titleLabel.textColor = .white
        titleLabel.textAlignment = .left
        titleLabel.font = UIFont.systemFont(ofSize: 40, weight: .regular)

        // Add the label directly to the content view to sit atop the inherited blur effect.
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(26)
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
        }
    }

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
