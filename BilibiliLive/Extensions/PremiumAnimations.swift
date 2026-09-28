//
//  PremiumAnimations.swift
//  BilibiliLive
//
//  Advanced animation system for premium UI
//  Created by AI Assistant on 2025/11/8
//

import UIKit

/// 交互成功（点赞 / 投币 / 收藏）时的脉冲反馈
@MainActor
enum PremiumAnimations {
    /// Success pulse animation
    static func successPulse(
        view: UIView,
        color: UIColor? = nil
    ) {
        // Use provided color or default pink
        let pulseColor = color ?? UIColor(displayP3Red: 1.0, green: 0.42, blue: 0.62, alpha: 1.0)
        let originalShadow = view.layer.shadowColor

        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: [.curveEaseOut]
        ) {
            view.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            view.layer.shadowColor = pulseColor.cgColor
            view.layer.shadowRadius = 32
            view.layer.shadowOpacity = 0.6
        } completion: { _ in
            UIView.animate(
                withDuration: 0.5,
                delay: 0,
                usingSpringWithDamping: 0.6,
                initialSpringVelocity: 0.8
            ) {
                view.transform = .identity
                view.layer.shadowColor = originalShadow
                view.layer.shadowRadius = 24
                view.layer.shadowOpacity = 0.3
            }
        }
    }
}
