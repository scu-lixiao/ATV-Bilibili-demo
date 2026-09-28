//
//  BLMotionCollectionViewCell.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/23.
//

import TVUIKit
import UIKit

class BLMotionCollectionViewCell: UICollectionViewCell {
    private var motionEffectV: UIInterpolatingMotionEffect!
    private var motionEffectH: UIInterpolatingMotionEffect!
    var scaleFactor: CGFloat = 1
    /// 聚焦时是否由 cell 自己绘制阴影。内容自带焦点效果/阴影的子类（如封面使用 adjustsImageWhenAncestorFocused）应关闭
    var usesFocusShadow = true
    /// 阴影形状的圆角。设置后使用 shadowPath，避免系统每帧根据内容 alpha 离屏计算阴影
    var focusShadowCornerRadius: CGFloat?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func setup() {
        motionEffectV = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
        motionEffectV.maximumRelativeValue = 8
        motionEffectV.minimumRelativeValue = -8
        motionEffectH = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
        motionEffectH.maximumRelativeValue = 8
        motionEffectH.minimumRelativeValue = -8
        
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if isFocused {
            coordinator.addCoordinatedAnimations {
                self.updateTransform()
                self.addMotionEffect(self.motionEffectH)
                self.addMotionEffect(self.motionEffectV)
            }
        } else {
            coordinator.addCoordinatedAnimations {
                self.updateTransform()
                self.removeMotionEffect(self.motionEffectH)
                self.removeMotionEffect(self.motionEffectV)
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateShadowPath()
    }

    private func updateShadowPath() {
        guard usesFocusShadow, let radius = focusShadowCornerRadius else {
            layer.shadowPath = nil
            return
        }
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
    }

    func updateTransform() {
        if isFocused {
            transform = CGAffineTransformMakeScale(scaleFactor, scaleFactor)
            guard usesFocusShadow else { return }
            updateShadowPath()
            layer.shadowOffset = CGSizeMake(0, 4)
            layer.shadowOpacity = 0.2
            layer.shadowRadius = 9.0

        } else {
            transform = CGAffineTransformIdentity
            layer.shadowOpacity = 0
            layer.shadowOffset = CGSizeMake(0, 0)
        }
    }
}
