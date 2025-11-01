//
//  MetalDanmakuConfig.swift
//  DanmakuKit
//
//  Created by AI Assistant on 2025/11/01.
//  Metal 4 优化：配置和功能开关
//

import Foundation
import Metal

/// Metal 弹幕渲染配置
@available(tvOS 26.0, *)
struct MetalDanmakuConfig {
    /// 是否全局启用 Metal 渲染
    static var enableMetalRendering: Bool = false  // 暂时禁用，避免卡死
    
    /// 纹理缓存大小
    static var textureCacheSize: Int = 500
    
    /// 是否启用高级渲染特效（模糊等）
    static var enableAdvancedEffects: Bool = false
    
    /// 是否打印性能统计信息
    static var enablePerformanceLogging: Bool = false
    
    /// 检查 Metal 是否可用
    static var isMetalAvailable: Bool {
        return MTLCreateSystemDefaultDevice() != nil
    }
    
    /// 获取 Metal 设备信息
    static func getDeviceInfo() -> String {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return "Metal not available"
        }
        
        return """
        Metal Device Info:
        - Name: \(device.name)
        - Supports Metal 4: \(device.supportsFamily(.apple4))
        - Max Threads Per Threadgroup: \(device.maxThreadsPerThreadgroup)
        - Recommended Max Working Set Size: \(device.recommendedMaxWorkingSetSize / 1024 / 1024) MB
        """
    }
    
    /// 性能监控
    static func startPerformanceMonitoring() {
        guard enablePerformanceLogging else { return }
        
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            let stats = MetalTextureCache.shared.getCacheStats()
            Logger.debug("[Metal Performance] \(stats)")
        }
    }
}

// MARK: - 全局配置扩展

extension Settings {
    /// 是否启用 Metal 4 弹幕渲染
    @UserDefault("DanmuMetalRenderingEnabled", defaultValue: true)
    static var danmuMetalRenderingEnabled: Bool
    
    /// Metal 渲染性能模式
    @UserDefaultCodable("DanmuMetalPerformanceMode", defaultValue: .balanced)
    static var danmuMetalPerformanceMode: MetalPerformanceMode
}

/// Metal 性能模式
enum MetalPerformanceMode: String, Codable {
    case lowPower       // 低功耗模式（减少缓存）
    case balanced       // 平衡模式（默认）
    case highPerformance // 高性能模式（大缓存 + 预加载）
    
    var cacheSize: Int {
        switch self {
        case .lowPower: return 200
        case .balanced: return 500
        case .highPerformance: return 1000
        }
    }
    
    var description: String {
        switch self {
        case .lowPower: return "低功耗"
        case .balanced: return "平衡"
        case .highPerformance: return "高性能"
        }
    }
}
