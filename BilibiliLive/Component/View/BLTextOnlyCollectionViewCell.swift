//
//  BLTextOnlyCollectionViewCell.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/24.
//

import Foundation
import UIKit

class BLTextOnlyCollectionViewCell: BLMotionCollectionViewCell {
    // MARK: - Properties

    let titleLabel = UILabel()

    // MARK: - Cell Setup

    override func setupCell() {
        // First, call the superclass's setup to inherit its visual properties and behaviors.
        super.setupCell()

        // Configure the title label.
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.font = UIFont.systemFont(ofSize: 26, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Add the title label to the content view, so it appears above the blur effect from the superclass.
        contentView.addSubview(titleLabel)

        // Set up constraints for the title label.
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            titleLabel.topAnchor.constraint(lessThanOrEqualTo: contentView.topAnchor, constant: 8),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8),
        ])
    }
}
