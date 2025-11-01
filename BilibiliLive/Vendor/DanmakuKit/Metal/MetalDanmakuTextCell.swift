//
//  MetalDanmakuTextCell.swift
//  DanmakuKit
//
//  Created by AI Assistant on 2025/11/01.
//  Metal 4 优化：使用 Metal 纹理缓存加速的弹幕文本 Cell
//

import UIKit
import Metal

@available(tvOS 26.0, *)
class MetalDanmakuTextCell: DanmakuTextCell {
    
    override func displaying(_ context: CGContext, _ size: CGSize, _ isCancelled: Bool) {
        // 优先尝试使用 Metal 纹理缓存
        if let model = model as? DanmakuTextCellModel,
           MetalDanmakuConfig.enableMetalRendering,
           MetalDanmakuConfig.isMetalAvailable {
            
            // 从缓存获取或生成纹理
            if let texture = MetalTextureCache.shared.getTexture(
                for: model.text,
                font: model.font,
                color: model.color,
                size: size
            ) {
                // 使用缓存的纹理渲染
                renderFromMetalTexture(texture, to: context, size: size, model: model)
                return
            }
        }
        
        // 降级：使用父类的 Core Graphics 渲染
        super.displaying(context, size, isCancelled)
    }
    
    /// 从 Metal 纹理渲染到 CGContext
    private func renderFromMetalTexture(_ texture: MTLTexture, to context: CGContext, size: CGSize, model: DanmakuTextCellModel) {
        // 将 Metal 纹理转换为 CGImage
        let bytesPerRow = texture.width * 4
        let bufferSize = bytesPerRow * texture.height
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: bufferSize, alignment: 16)
        defer { buffer.deallocate() }
        
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        texture.getBytes(buffer, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        
        // 创建 CGImage
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let provider = CGDataProvider(dataInfo: nil, data: buffer, size: bufferSize, releaseData: { _, _, _ in }),
              let cgImage = CGImage(
                width: texture.width,
                height: texture.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else { return }
        
        // 绘制到目标 context
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
    }
    
    /// 获取缓存统计信息
    static func printMetalCacheStats() {
        if #available(tvOS 26.0, *) {
            let stats = MetalTextureCache.shared.getCacheStats()
            Logger.debug("Metal Cache Stats: \(stats)")
        }
    }
}

// MARK: - 工厂方法

@available(tvOS 26.0, *)
extension MetalDanmakuTextCell {
    /// 创建 Metal 或普通 Cell（根据系统能力）
    static func createCell(frame: CGRect) -> DanmakuCell {
        if MetalDanmakuConfig.enableMetalRendering {
            return MetalDanmakuTextCell(frame: frame)
        } else {
            return DanmakuTextCell(frame: frame)
        }
    }
}

// MARK: - UIColor 扩展

private extension UIColor {
    var components: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }
}
