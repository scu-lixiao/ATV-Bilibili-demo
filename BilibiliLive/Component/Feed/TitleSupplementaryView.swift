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
    let glassBackgroundView = GlassPanelView(config: .subNavigation)
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
