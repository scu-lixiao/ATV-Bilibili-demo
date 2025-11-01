//
//  MetalTextureCache.swift
//  DanmakuKit
//
//  Created by AI Assistant on 2025/11/01.
//  Metal 4 优化：LRU 纹理缓存管理器
//

import Metal
import UIKit

/// LRU 缓存节点
private class CacheNode {
    let key: String
    var texture: MTLTexture
    var timestamp: Date
    var prev: CacheNode?
    var next: CacheNode?
    
    init(key: String, texture: MTLTexture) {
        self.key = key
        self.texture = texture
        self.timestamp = Date()
    }
}

/// Metal 纹理缓存管理器（LRU 策略）
@available(tvOS 26.0, *)
class MetalTextureCache {
    static let shared = MetalTextureCache()
    
    private let device: MTLDevice
    private let maxCacheSize: Int
    private var cache: [String: CacheNode] = [:]
    private var head: CacheNode?
    private var tail: CacheNode?
    private let lock = NSLock()
    
    // 统计信息
    private(set) var hitCount: Int = 0
    private(set) var missCount: Int = 0
    
    var hitRate: Double {
        let total = hitCount + missCount
        guard total > 0 else { return 0 }
        return Double(hitCount) / Double(total)
    }
    
    private init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        self.device = device
        self.maxCacheSize = 500 // 最多缓存 500 条弹幕纹理
    }
    
    /// 获取纹理（如果不存在则生成）
    func getTexture(for text: String, 
                    font: UIFont, 
                    color: UIColor, 
                    size: CGSize) -> MTLTexture? {
        let key = makeCacheKey(text: text, font: font, color: color)
        
        lock.lock()
        defer { lock.unlock() }
        
        // 检查缓存
        if let node = cache[key] {
            hitCount += 1
            moveToHead(node)
            return node.texture
        }
        
        missCount += 1
        
        // 生成新纹理
        guard let texture = generateTexture(text: text, font: font, color: color, size: size) else {
            return nil
        }
        
        // 添加到缓存
        let node = CacheNode(key: key, texture: texture)
        addToHead(node)
        cache[key] = node
        
        // 检查缓存大小
        if cache.count > maxCacheSize {
            removeTail()
        }
        
        return texture
    }
    
    /// 清除缓存
    func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        
        cache.removeAll()
        head = nil
        tail = nil
        hitCount = 0
        missCount = 0
    }
    
    /// 获取缓存统计信息
    func getCacheStats() -> String {
        lock.lock()
        defer { lock.unlock() }
        
        return """
        Metal Texture Cache Stats:
        - Size: \(cache.count)/\(maxCacheSize)
        - Hit Rate: \(String(format: "%.2f%%", hitRate * 100))
        - Hits: \(hitCount), Misses: \(missCount)
        """
    }
    
    // MARK: - Private Methods
    
    private func makeCacheKey(text: String, font: UIFont, color: UIColor) -> String {
        // 生成唯一键：文本 + 字体 + 颜色
        let fontName = font.fontName
        let fontSize = font.pointSize
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return "\(text)|\(fontName)|\(fontSize)|\(r)|\(g)|\(b)|\(a)"
    }
    
    private func generateTexture(text: String, 
                                 font: UIFont, 
                                 color: UIColor, 
                                 size: CGSize) -> MTLTexture? {
        // 使用 CoreText 渲染文本到位图
        let scale = UIScreen.main.scale
        let pixelSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        guard pixelSize.width > 0, pixelSize.height > 0 else { return nil }
        
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = scale
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            // 绘制描边
            let strokeColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: CGFloat(Settings.danmuStrokeAlpha.rawValue))
            let strokeAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: strokeColor,
                .strokeColor: strokeColor,
                .strokeWidth: CGFloat(Settings.danmuStrokeWidth.rawValue)
            ]
            
            let nsText = NSString(string: text)
            context.cgContext.setTextDrawingMode(.stroke)
            nsText.draw(at: .zero, withAttributes: strokeAttributes)
            
            // 绘制填充
            let fillAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color
            ]
            context.cgContext.setTextDrawingMode(.fill)
            nsText.draw(at: .zero, withAttributes: fillAttributes)
        }
        
        // 转换为 Metal 纹理
        guard let cgImage = image.cgImage else { return nil }
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: cgImage.width,
            height: cgImage.height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead]
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }
        
        // 复制图像数据到纹理
        guard let context = CGContext(
            data: nil,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: cgImage.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        
        guard let data = context.data else { return nil }
        
        let region = MTLRegionMake2D(0, 0, cgImage.width, cgImage.height)
        texture.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: cgImage.width * 4)
        
        return texture
    }
    
    // MARK: - LRU Operations
    
    private func moveToHead(_ node: CacheNode) {
        if node === head { return }
        
        // 从当前位置移除
        if let prev = node.prev {
            prev.next = node.next
        }
        if let next = node.next {
            next.prev = node.prev
        }
        if node === tail {
            tail = node.prev
        }
        
        // 移动到头部
        node.prev = nil
        node.next = head
        head?.prev = node
        head = node
        
        if tail == nil {
            tail = node
        }
        
        node.timestamp = Date()
    }
    
    private func addToHead(_ node: CacheNode) {
        node.next = head
        node.prev = nil
        head?.prev = node
        head = node
        
        if tail == nil {
            tail = node
        }
    }
    
    private func removeTail() {
        guard let tail = tail else { return }
        
        cache.removeValue(forKey: tail.key)
        
        if let prev = tail.prev {
            prev.next = nil
            self.tail = prev
        } else {
            head = nil
            self.tail = nil
        }
    }
}
