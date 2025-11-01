//
//  MetalBatchRenderer.swift
//  DanmakuKit
//
//  Created by AI Assistant on 2025/11/01.
//  Metal 4 优化：批量渲染器（Instanced Drawing）
//

import Metal
import MetalKit
import UIKit

/// Metal 批量渲染器
@available(tvOS 26.0, *)
class MetalBatchRenderer {
    // Metal 设备和队列
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let renderPipelineState: MTLRenderPipelineState
    
    // 顶点数据（四边形）
    private let vertexBuffer: MTLBuffer
    private let indexBuffer: MTLBuffer
    
    // 实例数据缓冲区
    private var instanceBuffer: MTLBuffer?
    private var maxInstances: Int = 1000
    
    // 纹理采样器
    private let sampler: MTLSamplerState
    
    init?() {
        // 1. 初始化 Metal 设备
        guard let device = MTLCreateSystemDefaultDevice() else {
            Logger.warn("Metal is not supported on this device")
            return nil
        }
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            Logger.warn("Failed to create Metal command queue")
            return nil
        }
        self.commandQueue = commandQueue
        
        // 2. 加载 Shader
        guard let library = device.makeDefaultLibrary() else {
            Logger.warn("Failed to load Metal shader library")
            return nil
        }
        
        guard let vertexFunction = library.makeFunction(name: "danmaku_vertex"),
              let fragmentFunction = library.makeFunction(name: "danmaku_fragment") else {
            Logger.warn("Failed to load Metal shader functions")
            return nil
        }
        
        // 3. 创建渲染管线
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // 配置混合模式（预乘 Alpha）
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        
        // 配置顶点描述符
        let vertexDescriptor = MTLVertexDescriptor()
        // 位置属性
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        // 纹理坐标属性
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.size * 2
        vertexDescriptor.attributes[1].bufferIndex = 0
        // 布局
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.size * 4
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            Logger.warn("Failed to create render pipeline state: \(error)")
            return nil
        }
        
        // 4. 创建顶点缓冲区（四边形：2 个三角形）
        let vertices: [Float] = [
            // 位置 (x, y), 纹理坐标 (u, v)
            -0.5, -0.5,  0.0, 1.0,  // 左下
             0.5, -0.5,  1.0, 1.0,  // 右下
             0.5,  0.5,  1.0, 0.0,  // 右上
            -0.5,  0.5,  0.0, 0.0,  // 左上
        ]
        
        guard let vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<Float>.size,
            options: .storageModeShared
        ) else {
            Logger.warn("Failed to create vertex buffer")
            return nil
        }
        self.vertexBuffer = vertexBuffer
        
        // 5. 创建索引缓冲区
        let indices: [UInt16] = [0, 1, 2, 2, 3, 0]
        guard let indexBuffer = device.makeBuffer(
            bytes: indices,
            length: indices.count * MemoryLayout<UInt16>.size,
            options: .storageModeShared
        ) else {
            Logger.warn("Failed to create index buffer")
            return nil
        }
        self.indexBuffer = indexBuffer
        
        // 6. 创建纹理采样器
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        
        guard let sampler = device.makeSamplerState(descriptor: samplerDescriptor) else {
            Logger.warn("Failed to create sampler state")
            return nil
        }
        self.sampler = sampler
        
        Logger.debug("MetalBatchRenderer initialized successfully")
    }
    
    /// 渲染弹幕批次
    func render(danmakus: [(texture: MTLTexture, frame: CGRect, alpha: Float)],
                into drawable: CAMetalDrawable,
                viewportSize: CGSize) {
        guard !danmakus.isEmpty else { return }
        
        // 1. 准备实例数据
        var instances: [InstanceData] = []
        var textures: [MTLTexture] = []
        
        for danmaku in danmakus {
            let instance = InstanceData(
                position: SIMD2<Float>(Float(danmaku.frame.midX), Float(danmaku.frame.midY)),
                size: SIMD2<Float>(Float(danmaku.frame.width), Float(danmaku.frame.height)),
                alpha: danmaku.alpha,
                rotation: 0.0
            )
            instances.append(instance)
            textures.append(danmaku.texture)
        }
        
        // 2. 更新实例缓冲区
        let instanceBufferSize = instances.count * MemoryLayout<InstanceData>.stride
        if instanceBuffer == nil || instanceBuffer!.length < instanceBufferSize {
            instanceBuffer = device.makeBuffer(length: max(instanceBufferSize, maxInstances * MemoryLayout<InstanceData>.stride),
                                               options: .storageModeShared)
        }
        
        guard let instanceBuffer = instanceBuffer else { return }
        memcpy(instanceBuffer.contents(), instances, instanceBufferSize)
        
        // 3. 创建命令缓冲区
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        // 4. 创建渲染通道
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        // 5. 设置渲染状态
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(instanceBuffer, offset: 0, index: 1)
        
        // 传递视口大小
        var viewport = SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height))
        renderEncoder.setVertexBytes(&viewport, length: MemoryLayout<SIMD2<Float>>.size, index: 2)
        
        // 6. 批量绘制（每个弹幕一个 draw call，因为纹理不同）
        // 注意：理想情况下应该使用纹理数组，但为了简化先这样实现
        for (index, texture) in textures.enumerated() {
            renderEncoder.setFragmentTexture(texture, index: 0)
            renderEncoder.setFragmentSamplerState(sampler, index: 0)
            
            renderEncoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: 6,
                indexType: .uint16,
                indexBuffer: indexBuffer,
                indexBufferOffset: 0,
                instanceCount: 1,
                baseVertex: 0,
                baseInstance: index
            )
        }
        
        renderEncoder.endEncoding()
        
        // 7. 提交渲染
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// MARK: - InstanceData 结构

/// 弹幕实例数据（对应 Metal Shader）
private struct InstanceData {
    var position: SIMD2<Float>
    var size: SIMD2<Float>
    var alpha: Float
    var rotation: Float
}
