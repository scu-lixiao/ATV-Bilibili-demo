//
//  DanmakuImageCache.swift
//  DanmakuKit
//
//  Created by AI Assistant on 2025/01/01.
//  CGImage 缓存优化：简单高效的弹幕渲染加速方案
//

import UIKit

/// 弹幕图片缓存管理器（LRU 策略）
class DanmakuImageCache {
    static let shared = DanmakuImageCache()
    
    private var cache: [String: CacheEntry] = [:]
    private let lock = NSLock()
    private let maxCacheSize = 500
    
    // 统计信息
    private(set) var hitCount: Int = 0
    private(set) var missCount: Int = 0
    
    var hitRate: Double {
        let total = hitCount + missCount
        guard total > 0 else { return 0 }
        return Double(hitCount) / Double(total)
    }
    
    private struct CacheEntry {
        let image: CGImage
        var accessTime: Date
    }
    
    private init() {}
    
    /// 获取缓存的图片（如果不存在则生成）
    func getImage(for text: String,
                  font: UIFont,
                  color: UIColor,
                  size: CGSize) -> CGImage? {
        let key = makeKey(text: text, font: font, color: color)
        
        lock.lock()
        
        // 检查缓存
        if var entry = cache[key] {
            hitCount += 1
            entry.accessTime = Date()
            cache[key] = entry
            lock.unlock()
            return entry.image
        }
        
        missCount += 1
        lock.unlock()
        
        // 生成新图片
        guard let image = renderToCGImage(text: text, font: font, color: color, size: size) else {
            return nil
        }
        
        // 添加到缓存
        lock.lock()
        cache[key] = CacheEntry(image: image, accessTime: Date())
        
        // 检查缓存大小并淘汰
        if cache.count > maxCacheSize {
            evictOldEntries()
        }
        lock.unlock()
        
        return image
    }
    
    /// 清除缓存
    func clearCache() {
        lock.lock()
        cache.removeAll()
        hitCount = 0
        missCount = 0
        lock.unlock()
    }
    
    /// 获取缓存统计信息
    func getCacheStats() -> String {
        lock.lock()
        defer { lock.unlock() }
        
        return """
        Danmaku Image Cache Stats:
        - Size: \(cache.count)/\(maxCacheSize)
        - Hit Rate: \(String(format: "%.2f%%", hitRate * 100))
        - Hits: \(hitCount), Misses: \(missCount)
        """
    }
    
    // MARK: - Private Methods
    
    private func makeKey(text: String, font: UIFont, color: UIColor) -> String {
        let fontName = font.fontName
        let fontSize = font.pointSize
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return "\(text)|\(fontName)|\(fontSize)|\(r)|\(g)|\(b)|\(a)"
    }
    
    private func renderToCGImage(text: String,
                                 font: UIFont,
                                 color: UIColor,
                                 size: CGSize) -> CGImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        
        let scale = UIScreen.main.scale
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = scale
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let uiImage = renderer.image { rendererContext in
            let context = rendererContext.cgContext
            let nsText = NSString(string: text)
            
            // 设置透明度
            context.setAlpha(CGFloat(Settings.danmuAlpha.rawValue))
            context.setLineWidth(CGFloat(Settings.danmuStrokeWidth.rawValue))
            context.setLineJoin(.round)
            
            // 描边
            context.saveGState()
            context.setTextDrawingMode(.stroke)
            let strokeColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: CGFloat(Settings.danmuStrokeAlpha.rawValue))
            let strokeAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: strokeColor
            ]
            context.setStrokeColor(strokeColor.cgColor)
            nsText.draw(at: .zero, withAttributes: strokeAttributes)
            context.restoreGState()
            
            // 填充
            let fillAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color
            ]
            context.setTextDrawingMode(.fill)
            nsText.draw(at: .zero, withAttributes: fillAttributes)
        }
        
        return uiImage.cgImage
    }
    
    private func evictOldEntries() {
        // 简单 LRU：移除最旧的 25% 条目
        let sortedEntries = cache.sorted { $0.value.accessTime < $1.value.accessTime }
        let removeCount = maxCacheSize / 4
        
        for i in 0..<min(removeCount, sortedEntries.count) {
            cache.removeValue(forKey: sortedEntries[i].key)
        }
    }
}

// MARK: - DanmakuTextCell 扩展

extension DanmakuTextCell {
    /// 使用图片缓存优化渲染
    func displayingWithCache(_ context: CGContext, _ size: CGSize, _ isCancelled: Bool) {
        guard let model = model as? DanmakuTextCellModel else { return }
        
        // 尝试从缓存获取
        if let cachedImage = DanmakuImageCache.shared.getImage(
            for: model.text,
            font: model.font,
            color: model.color,
            size: size
        ) {
            // 直接绘制缓存的图片（非常快！）
            context.draw(cachedImage, in: CGRect(origin: .zero, size: size))
            return
        }
        
        // 降级：使用原始渲染方法
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
}
