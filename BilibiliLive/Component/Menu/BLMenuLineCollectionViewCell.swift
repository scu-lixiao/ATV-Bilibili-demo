//
//  BLMenuLineCollectionViewCell.swift
//  BilibiliLive
//
//  Created by ManTie on 2024/7/4.
//

import UIKit

class BLMenuLineCollectionViewCell: BLSettingLineCollectionViewCell {
    var iconImageView = UIImageView()

    override func setup() {
        super.setup()
        scaleFactor = 1.05
    }

    override func addsubViews() {
        addSubview(selectedWhiteView)
        selectedWhiteView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

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

    override func updateView() {
        super.updateView()
        // 未聚焦时轻微压暗图标和文字
        iconImageView.alpha = isFocused ? 1.0 : 0.8
        titleLabel.alpha = isFocused ? 1.0 : 0.8
    }
}
