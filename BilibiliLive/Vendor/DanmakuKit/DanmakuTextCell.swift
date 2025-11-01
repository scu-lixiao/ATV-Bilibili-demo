//
//  DanmakuTextCell.swift
//  DanmakuKit_Example
//
//  Created by Q YiZhong on 2020/8/29.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit

class DanmakuTextCell: DanmakuCell {
    required init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func willDisplay() {}

    override func displaying(_ context: CGContext, _ size: CGSize, _ isCancelled: Bool) {
        guard let model = model as? DanmakuTextCellModel else { return }
        
        // 使用图片缓存优化（10-20x 性能提升）
        if let cachedImage = DanmakuImageCache.shared.getImage(
            for: model.text,
            font: model.font,
            color: model.color,
            size: size
        ) {
            // 修复坐标系：CGImage 坐标系与 CGContext 不同
            context.saveGState()
            context.translateBy(x: 0, y: size.height)
            context.scaleBy(x: 1.0, y: -1.0)
            context.draw(cachedImage, in: CGRect(origin: .zero, size: size))
            context.restoreGState()
            return
        }
        
        // 降级：原始渲染（缓存生成失败时）
        let text = NSString(string: model.text)
        context.setAlpha(CGFloat(Settings.danmuAlpha.rawValue))
        context.setLineWidth(CGFloat(Settings.danmuStrokeWidth.rawValue))
        context.setLineJoin(.round)
        context.saveGState()
        context.setTextDrawingMode(.stroke)

        let strokeColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: CGFloat(Settings.danmuStrokeAlpha.rawValue))
        let attributes: [NSAttributedString.Key: Any] = [.font: model.font, .foregroundColor: strokeColor]
        context.setStrokeColor(strokeColor.cgColor)
        text.draw(at: .zero, withAttributes: attributes)
        context.restoreGState()

        let attributes1: [NSAttributedString.Key: Any] = [.font: model.font, .foregroundColor: model.color]
        context.setTextDrawingMode(.fill)
        context.setStrokeColor(UIColor.white.cgColor)
        text.draw(at: .zero, withAttributes: attributes1)
    }

    override func didDisplay(_ finished: Bool) {}
}
