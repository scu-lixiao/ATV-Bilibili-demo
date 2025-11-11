//
//  TitleSupplementaryView.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/21.
//  Enhanced with glass effect - 2025/11/11
//

import SnapKit
import UIKit

class TitleSupplementaryView: UICollectionReusableView {
    let label = UILabel()
    let glassBackgroundView = UIView()
    static let reuseIdentifier = "title-supplementary-reuse-identifier"

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }
}

extension TitleSupplementaryView {
    func configure() {
        // Add glass background
        addSubview(glassBackgroundView)
        glassBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10))
        }
        
        // Apply glass navigation style for sub-navigation headers
        if #available(tvOS 26.0, *) {
            glassBackgroundView.applyGlassNavigationStyle(
                preset: .subNavigation,
                isFocused: false
            )
        } else {
            // Fallback for older tvOS versions
            glassBackgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
            glassBackgroundView.layer.cornerRadius = CornerRadiusToken.medium.rawValue
        }
        
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontForContentSizeCategory = true
        label.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalToSuperview().offset(30)
            make.trailing.equalToSuperview().offset(-20)
            make.bottom.equalToSuperview()
        }
        label.textColor = .white
        label.font = UIFont.preferredFont(forTextStyle: .headline)
    }
}
