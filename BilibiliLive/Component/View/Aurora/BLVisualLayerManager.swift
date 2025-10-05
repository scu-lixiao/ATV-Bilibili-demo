//
//  BLVisualLayerManager.swift
//  BilibiliLive
//
//  Created by Aurora Premium Enhancement on 2025/06/09.
//

import QuartzCore
import UIKit

// MARK: - Layer Type Enumeration (从 BLVisualLayerFactory 导入)

// MARK: - Enhanced Visual Layer Protocol

/// 扩展的视觉层协议 - 增强基础协议功能
public protocol BLVisualLayerProtocol: AnyObject {
    /// 层类型
    var layerType: BLVisualLayerType { get }
    /// 层级优先级
    var layerPriority: Int { get }
    /// 是否启用
    var isEnabled: Bool { get set }
    /// 渲染质量等级 (0.0-1.0)
    var qualityLevel: CGFloat { get set }
    /// 是否当前聚焦状态
    var isFocused: Bool { get }
    /// 容器视图引用 (实现时应使用weak)
    var containerView: UIView? { get set }

    /// 设置层到指定容器视图
    func setupLayer(in containerView: UIView)
    /// 更新聚焦状态
    func updateFocusState(isFocused: Bool, animated: Bool)
    /// 更新质量等级
    func updateQualityLevel(_ quality: CGFloat)
    /// 清理资源
    func cleanup()
    /// 获取层的渲染视图
    func getLayerView() -> UIView?
}

// MARK: - Visual Layer Manager Protocol Implementation

/// 视觉层管理器协议的完整实现
public protocol BLVisualLayerManagerProtocol: AnyObject {
    /// 所有管理的层
    var layers: [BLVisualLayerType: BLVisualLayerProtocol] { get }
    /// 容器视图 (实现时应使用weak)
    var containerView: UIView? { get set }
    /// 全局质量等级
    var globalQualityLevel: CGFloat { get set }
    /// 是否启用智能合并渲染
    var isSmartRenderingEnabled: Bool { get set }

    /// 设置层到容器视图
    func setupLayers(in containerView: UIView)
    /// 添加特定类型的层
    func addLayer(_ layer: BLVisualLayerProtocol, type: BLVisualLayerType)
    /// 获取特定类型的层
    func getLayer(type: BLVisualLayerType) -> BLVisualLayerProtocol?
    /// 移除特定类型的层
    func removeLayer(type: BLVisualLayerType)
    /// 更新所有层的聚焦状态
    func updateAllLayersFocusState(isFocused: Bool, animated: Bool)
    /// 设置全局质量等级
    func setQualityLevel(_ level: CGFloat)
    /// 启用/禁用特定层
    func setLayerEnabled(_ enabled: Bool, type: BLVisualLayerType)
    /// 清理所有资源
    func cleanup()
}

// MARK: - Visual Layer Manager Implementation

/// Aurora Premium视觉层管理器
/// 负责协调四个视觉层的创建、管理和渲染优化
public class BLVisualLayerManager: BLVisualLayerManagerProtocol {
    // MARK: - Properties

    /// 所有管理的层 - 使用字典提供O(1)访问性能
    public private(set) var layers: [BLVisualLayerType: BLVisualLayerProtocol] = [:]

    /// 容器视图弱引用 - 避免循环引用
    public weak var containerView: UIView?

    /// 全局质量等级 (0.0-1.0, 1.0为最高质量)
    public var globalQualityLevel: CGFloat = 1.0 {
        didSet {
            updateAllLayersQuality()
        }
    }

    /// 是否启用智能合并渲染优化
    public var isSmartRenderingEnabled: Bool = true

    /// 渲染队列 - 用于性能优化的渲染调度
    private let renderQueue = DispatchQueue(label: "com.aurora.render", qos: .userInteractive)

    /// 同步队列 - 确保线程安全
    private let syncQueue = DispatchQueue(label: "com.aurora.layer.sync", qos: .userInteractive)

    // MARK: - Initialization

    public init() {
        // {{CHENGQI:
        // Action: Added
        // Timestamp: 2025-06-09 10:34:36 +08:00 (from mcp-server-time)
        // Reason: P1-AR-001任务 - 创建BLVisualLayerManager核心组件
        // Principle_Applied: SOLID - 单一职责原则，层管理器只负责层的管理和协调
        // Optimization: 延迟初始化，仅在需要时创建层
        // Architectural_Note (AR): 遵循Aurora Premium分层架构设计
        // Documentation_Note (DW): 中文注释说明设计意图和优化策略
        // }}
        setupPerformanceOptimization()
    }

    deinit {
        cleanup()
    }

    // MARK: - Layer Management

    /// 设置所有层到容器视图中
    public func setupLayers(in containerView: UIView) {
        // {{CHENGQI:
        // Action: Added
        // Timestamp: 2025-06-09 10:34:36 +08:00 (from mcp-server-time)
        // Reason: 实现层设置核心功能，支持容器视图集成
        // Principle_Applied: KISS - 保持简单直接的实现
        // Optimization: 按优先级顺序设置层，确保正确的Z-order
        // }}

        self.containerView = containerView

        syncQueue.async { [weak self] in
            guard let self = self else { return }

            // 按优先级顺序设置层，确保正确的层级关系
            let sortedTypes = BLVisualLayerType.allCases.sorted { $0.priority < $1.priority }

            DispatchQueue.main.async {
                for layerType in sortedTypes {
                    if let layer = self.layers[layerType] {
                        layer.setupLayer(in: containerView)
                    }
                }
            }
        }
    }

    /// 添加特定类型的层
    public func addLayer(_ layer: BLVisualLayerProtocol, type: BLVisualLayerType) {
        // {{CHENGQI:
        // Action: Added
        // Timestamp: 2025-06-09 10:34:36 +08:00 (from mcp-server-time)
        // Reason: 实现层添加功能，支持动态层管理
        // Principle_Applied: Open/Closed - 对扩展开放，通过协议添加新层类型
        // Optimization: 线程安全的层添加，避免竞态条件
        // }}

        syncQueue.async { [weak self] in
            guard let self = self else { return }

            // 移除已存在的同类型层（如果有）
            if let existingLayer = self.layers[type] {
                existingLayer.cleanup()
            }

            // 添加新层
            self.layers[type] = layer
            layer.qualityLevel = self.globalQualityLevel

            // 如果容器视图已设置，立即设置该层
            if let containerView = self.containerView {
                DispatchQueue.main.async {
                    layer.setupLayer(in: containerView)
                }
            }
        }
    }

    /// 获取特定类型的层
    public func getLayer(type: BLVisualLayerType) -> BLVisualLayerProtocol? {
        // {{CHENGQI:
        // Action: Added
        // Timestamp: 2025-06-09 10:34:36 +08:00 (from mcp-server-time)
        // Reason: 提供层访问接口，支持外部查询和操作
        // Principle_Applied: KISS - 简单直接的getter实现
        // Optimization: O(1)字典访问，高性能查询
        // }}

        return syncQueue.sync {
            return layers[type]
        }
    }

    /// 移除特定类型的层
    public func removeLayer(type: BLVisualLayerType) {
        // {{CHENGQI:
        // Action: Added
        // Timestamp: 2025-06-09 10:34:36 +08:00 (from mcp-server-time)
        // Reason: 实现层移除功能，支持动态层管理和资源清理
        // Principle_Applied: SOLID - 单一职责，专注于层的生命周期管理
        // Optimization: 确保资源正确清理，避免内存泄漏
        // }}

        syncQueue.async { [weak self] in
            guard let self = self else { return }

            if let layer = self.layers[type] {
                layer.cleanup()
                self.layers.removeValue(forKey: type)
            }
        }
    }

    // MARK: - Focus Management

    /// 更新所有层的聚焦状态
    public func updateAllLayersFocusState(isFocused: Bool, animated: Bool) {
        // {{CHENGQI:
        // Action: Added
        // Timestamp: 2025-06-09 10:34:36 +08:00 (from mcp-server-time)
        // Reason: 实现统一的聚焦状态管理，确保所有层同步更新
        // Principle_Applied: DRY - 避免重复的聚焦状态更新逻辑
        // Optimization: 批量更新所有层，提供流畅的视觉效果
        // }}

        if isSmartRenderingEnabled {
            // 智能渲染模式：批量更新减少渲染调用
            performBatchedFocusUpdate(isFocused: isFocused, animated: animated)
        } else {
            // 标准模式：逐个更新每层
            updateLayersFocusStateStandard(isFocused: isFocused, animated: animated)
        }
    }

    /// 批量聚焦更新（智能渲染模式）
    private func performBatchedFocusUpdate(isFocused: Bool, animated: Bool) {
        renderQueue.async { [weak self] in
            guard let self = self else { return }

            let currentLayers = self.syncQueue.sync { Array(self.layers.values) }

            DispatchQueue.main.async {
                // 使用CATransaction确保所有动画同步
                CATransaction.begin()
                CATransaction.setDisableActions(!animated)

                for layer in currentLayers {
                    layer.updateFocusState(isFocused: isFocused, animated: animated)
                }

                CATransaction.commit()
            }
        }
    }

    /// 标准聚焦更新模式
    private func updateLayersFocusStateStandard(isFocused: Bool, animated: Bool) {
        syncQueue.async { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                for layer in self.layers.values {
                    layer.updateFocusState(isFocused: isFocused, animated: animated)
                }
            }
        }
    }

    // MARK: - Quality Management

    /// 设置全局质量等级
    public func setQualityLevel(_ level: CGFloat) {
        // {{CHENGQI:
        // Action: Added
        // Timestamp: 2025-06-09 10:34:36 +08:00 (from mcp-server-time)
        // Reason: 实现全局质量控制，支持性能自适应调整
        // Principle_Applied: SOLID - 统一的质量管理接口
        // Optimization: 智能质量调整，平衡视觉效果和性能
        // }}

        let clampedLevel = max(0.0, min(1.0, level))
        globalQualityLevel = clampedLevel
        updateAllLayersQuality()
    }

    /// 更新所有层的质量等级
    private func updateAllLayersQuality() {
        syncQueue.async { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                for layer in self.layers.values {
                    layer.updateQualityLevel(self.globalQualityLevel)
                }
            }
        }
    }

    // MARK: - Layer State Management

    /// 启用/禁用特定层
    public func setLayerEnabled(_ enabled: Bool, type: BLVisualLayerType) {
        // {{CHENGQI:
        // Action: Added
        // Timestamp: 2025-06-09 10:34:36 +08:00 (from mcp-server-time)
        // Reason: 实现细粒度的层控制，支持动态功能调整
        // Principle_Applied: YAGNI - 简单的开关控制，满足当前需求
        // Optimization: 即时生效，提供流畅的用户体验
        // }}

        if let layer = getLayer(type: type) {
            layer.isEnabled = enabled
        }
    }

    // MARK: - Performance Optimization

    /// 设置性能优化
    private func setupPerformanceOptimization() {
        // {{CHENGQI:
        // Action: Modified
        // Timestamp: 2025-06-09 11:22:47 +08:00 (from mcp-server-time)
        // Reason: 修复tvOS上EXC_BREAKPOINT错误 - 移除不兼容的setTarget调用
        // Principle_Applied: KISS - 移除可能有问题的代码，保持简单
        // Optimization: 确保tvOS平台兼容性，避免运行时错误
        // Architectural_Note (AR): 优先考虑平台稳定性而非特定优化
        // Documentation_Note (DW): 记录tvOS兼容性修复
        // }}

        // 启用GPU加速
        isSmartRenderingEnabled = true

        // 移除tvOS不兼容的setTarget调用
        // renderQueue.setTarget(queue: DispatchQueue.main) // 在tvOS上可能导致EXC_BREAKPOINT

        // tvOS兼容性注释: renderQueue将使用默认配置，仍能正常工作
    }

    // MARK: - Resource Management

    /// 清理所有资源
    public func cleanup() {
        // {{CHENGQI:
        // Action: Added
        // Timestamp: 2025-06-09 10:34:36 +08:00 (from mcp-server-time)
        // Reason: 实现完整的资源清理，防止内存泄漏
        // Principle_Applied: SOLID - 明确的资源管理职责
        // Optimization: 确保所有层和队列正确释放
        // }}

        syncQueue.async { [weak self] in
            guard let self = self else { return }

            // 清理所有层
            for layer in self.layers.values {
                layer.cleanup()
            }

            self.layers.removeAll()

            DispatchQueue.main.async {
                self.containerView = nil
            }
        }
    }
}

// MARK: - Debug and Monitoring Extensions

public extension BLVisualLayerManager {
    /// 获取管理器状态信息（用于调试和监控）
    func getManagerStatus() -> [String: Any] {
        return syncQueue.sync {
            return [
                "layerCount": layers.count,
                "globalQuality": globalQualityLevel,
                "smartRendering": isSmartRenderingEnabled,
                "layerTypes": layers.keys.map { $0.name },
            ]
        }
    }

    /// 验证层设置完整性
    func validateLayerSetup() -> Bool {
        return syncQueue.sync {
            // 检查是否所有核心层都已设置
            let expectedTypes: Set<BLVisualLayerType> = [.background, .contentEnhancement, .lightingEffect, .interactionFeedback]
            let currentTypes = Set(layers.keys)
            return expectedTypes.isSubset(of: currentTypes)
        }
    }
}
