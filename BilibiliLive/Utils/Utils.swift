//
//  Utils.swift
//  BilibiliLive
//
//  Created by iManTie on 10/13/25.
//

import UIKit

public func BLAnimate(withDuration: CGFloat, animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
    UIView.animate(withDuration: withDuration, delay: 0, options: .curveEaseIn, animations: animations, completion: completion)
}

public func BLAfter(afterTime: CGFloat, complete: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + afterTime, execute: {
        complete()
    })
}

public func getblurEffectView(style: UIBlurEffect.Style? = .light) -> UIVisualEffectView {
    // 首先创建一个模糊效果
    let blurEffect = UIBlurEffect(style: style!)
    // 接着创建一个承载模糊效果的视图
    let headView = UIVisualEffectView(effect: blurEffect)

    return headView
}
