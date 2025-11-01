//
//  MetalDanmakuLayer.swift
//  DanmakuKit
//
//  Created by AI Assistant on 2025/11/01.
//  Metal 4 优化：Metal 弹幕渲染层（替代 DanmakuAsyncLayer）
//

import Metal
import MetalKit
import UIKit

@available(tvOS 26.0, *)
class MetalDanmakuLayer: CAMetalLayer {
    /// 是否启用 Metal 渲染（如果为 false 则降级到 Core Graphics）
    public var enableMetalRendering = true
    
    /// 弹幕模型
    public weak var cellModel: DanmakuTextCellModel?
    
    // Metal 组件
    private let textureCache = MetalTextureCache.shared
    private static var batchRenderer: MetalBatchRenderer?
    
    // 渲染回调
    public var willDisplay: ((_ layer: MetalDanmakuLayer) -> Void)?
    public var didDisplay: ((_ layer: MetalDanmakuLayer, _ finished: Bool) -> Void)?
    
    // 降级模式（Metal 不可用时使用 Core Graphics）
    private var fallbackLayer: DanmakuAsyncLayer?
    
    override init() {
        super.init()
        setupMetalLayer()
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupMetalLayer()
    }
    
    private func setupMetalLayer() {
        // 初始化 Metal 设备
        guard let device = MTLCreateSystemDefaultDevice() else {
            Logger.warn("Metal not available, falling back to Core Graphics")
            enableMetalRendering = false
            return
        }
        
        self.device = device
        self.pixelFormat = .bgra8Unorm
        self.framebufferOnly = true
        self.isOpaque = false
        
        // 初始化批量渲染器（单例）
        if Self.batchRenderer == nil {
            Self.batchRenderer = MetalBatchRenderer()
        }
        
        guard Self.batchRenderer != nil else {
            Logger.warn("Failed to initialize MetalBatchRenderer, falling back")
            enableMetalRendering = false
            return
        }
    }
    
    /// 渲染弹幕
    func render() {
        guard enableMetalRendering else {
            // 降级到 Core Graphics
            renderWithCoreGraphics()
            return
        }
        
        guard let model = cellModel else { return }
        
        willDisplay?(self)
        
        // 1. 从缓存获取或生成纹理
        guard let texture = textureCache.getTexture(
            for: model.text,
            font: model.font,
            color: model.color,
            size: model.size
        ) else {
            didDisplay?(self, false)
            return
        }
        
        // 2. 获取 drawable
        guard let drawable = nextDrawable() else {
            didDisplay?(self, false)
            return
        }
        
        // 3. 渲染单个弹幕
        let frame = CGRect(origin: .zero, size: model.size)
        let alpha = Float(CGFloat(Settings.danmuAlpha.rawValue))
        
        Self.batchRenderer?.render(
            danmakus: [(texture: texture, frame: frame, alpha: alpha)],
            into: drawable,
            viewportSize: bounds.size
        )
        
        didDisplay?(self, true)
    }
    
    // MARK: - Fallback to Core Graphics
    
    private func renderWithCoreGraphics() {
        // 创建降级 layer（如果需要）
        if fallbackLayer == nil {
            fallbackLayer = DanmakuAsyncLayer()
            fallbackLayer?.frame = bounds
            fallbackLayer?.contentsScale = contentsScale
        }
        
        guard let fallbackLayer = fallbackLayer,
              let model = cellModel else { return }
        
        // 使用原有的 Core Graphics 渲染逻辑
        fallbackLayer.willDisplay = { [weak self] layer in
            self?.willDisplay?(self!)
        }
        
        fallbackLayer.displaying = { context, size, isCancelled in
            let text = NSString(string: model.text)
            context.setAlpha(CGFloat(Settings.danmuAlpha.rawValue))
            context.setLineWidth(CGFloat(Settings.danmuStrokeWidth.rawValue))
            context.setLineJoin(.round)
            
            // 绘制描边
            context.saveGState()
            context.setTextDrawingMode(.stroke)
            let strokeColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: CGFloat(Settings.danmuStrokeAlpha.rawValue))
            let attributes: [NSAttributedString.Key: Any] = [.font: model.font, .foregroundColor: strokeColor]
            context.setStrokeColor(strokeColor.cgColor)
            text.draw(at: .zero, withAttributes: attributes)
            context.restoreGState()
            
            // 绘制填充
            let attributes1: [NSAttributedString.Key: Any] = [.font: model.font, .foregroundColor: model.color]
            context.setTextDrawingMode(.fill)
            context.setStrokeColor(UIColor.white.cgColor)
            text.draw(at: .zero, withAttributes: attributes1)
        }
        
        fallbackLayer.didDisplay = { [weak self] layer, finished in
            self?.didDisplay?(self!, finished)
        }
        
        fallbackLayer.setNeedsDisplay()
    }
    
    /// 打印缓存统计信息
    static func printCacheStats() {
        let stats = MetalTextureCache.shared.getCacheStats()
        Logger.debug("Metal Texture Cache Stats: \(stats)")
    }
}

// MARK: - DanmakuCell Metal 扩展

@available(tvOS 26.0, *)
extension DanmakuCell {
    /// 使用 Metal 渲染（如果可用）
    func setupMetalRenderingIfAvailable() {
        // 替换 layer 类
        // 注意：这需要在 cell 创建时调用
        if let metalLayer = layer as? MetalDanmakuLayer {
            metalLayer.cellModel = model as? DanmakuTextCellModel
        }
    }
    
    /// 检查是否支持 Metal 渲染
    static var isMetalAvailable: Bool {
        if #available(tvOS 26.0, *) {
            return MTLCreateSystemDefaultDevice() != nil
        }
        return false
    }
}
