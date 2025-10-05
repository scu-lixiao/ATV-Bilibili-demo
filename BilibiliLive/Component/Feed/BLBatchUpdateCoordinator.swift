//
//  BLBatchUpdateCoordinator.swift
//  BilibiliLive
//
//  Created by Claude-4-Sonnet on 2025/10/06.
//  tvOS 26 Performance Optimization: Batch Update Coordinator
//
//  {{CHENGQI:
//  Action: Created
//  Timestamp: 2025-10-06 06:40:00 +08:00
//  Reason: 实现批量更新协调器，收集短时间内的多次数据变更，合并为单次快照应用
//  Principle_Applied: Debouncing Pattern - 减少频繁的 diff 计算，提升滚动流畅度
//  Optimization: 自适应延迟策略（根据滚动速度和 FPS），预期减少 50%+ 快照应用次数
//  Architectural_Note (AR): 遵循 Aurora Premium 命名规范，支持与性能监控系统集成
//  Documentation_Note (DW): 提供完整的自适应延迟策略和批量处理文档
//  }}

import Foundation
import UIKit

// MARK: - Batch Update Coordinator

/// Aurora Premium 批量更新协调器
/// 收集短时间内的多次数据变更，合并为单次快照应用，减少频繁的 diff 计算
///
/// **自适应延迟策略**：
/// - 滚动状态因子：idle (0.01s) → slow (0.02s) → fast (0.05s) → veryFast (0.1s)
/// - FPS 因子：>=55fps (1.0x) → >=45fps (1.5x) → <45fps (2.0x)
/// - 最终延迟 = 滚动状态因子 × FPS 因子
///
/// **使用示例**：
/// ```swift
/// let coordinator = BLBatchUpdateCoordinator { items in
///     self.applySnapshot(with: items)
/// }
///
/// coordinator.addPendingUpdate(newItems)
/// coordinator.updateScrollingContext(state: .fast, fps: 55.0)
/// ```
public class BLBatchUpdateCoordinator {
    // MARK: - Type Aliases

    /// 更新处理闭包，接收去重后的所有待更新项
    typealias UpdateHandler = ([AnyDispplayData]) -> Void

    // MARK: - Properties

    /// 待更新的数据项（未去重）
    private var pendingUpdates: [AnyDispplayData] = []

    /// 防抖计时器
    private var debounceTimer: Timer?

    /// 当前滚动状态
    private var scrollingState: BLScrollingState = .idle

    /// 当前 FPS
    private var currentFPS: Double = 60.0

    /// 更新处理闭包
    private let updateHandler: UpdateHandler

    /// 是否已失效（用于防止 deinit 后继续调用）
    private var isInvalidated: Bool = false

    // MARK: - Initialization

    /// 初始化批量更新协调器
    /// - Parameter updateHandler: 更新处理闭包，在批量刷新时调用
    init(updateHandler: @escaping UpdateHandler) {
        self.updateHandler = updateHandler
    }

    deinit {
        // {{CHENGQI:
        // Action: Added
        // Timestamp: 2025-10-06 06:40:00 +08:00
        // Reason: 确保 Timer 正确取消，避免内存泄漏
        // Principle_Applied: Resource Management - 清理资源
        // }}
        invalidate()
    }

    // MARK: - Public Methods

    /// 添加待更新的数据项
    /// - Parameter items: 新增的数据项数组
    func addPendingUpdate(_ items: [AnyDispplayData]) {
        guard !isInvalidated else { return }
        guard !items.isEmpty else { return }

        pendingUpdates.append(contentsOf: items)
        scheduleFlush()
    }

    /// 更新滚动上下文（用于自适应延迟计算）
    /// - Parameters:
    ///   - state: 当前滚动状态
    ///   - fps: 当前 FPS
    func updateScrollingContext(state: BLScrollingState, fps: Double) {
        guard !isInvalidated else { return }

        scrollingState = state
        currentFPS = fps

        // 如果滚动状态或 FPS 变化，重新调度刷新
        if debounceTimer != nil {
            scheduleFlush()
        }
    }

    /// 立即刷新所有待更新项（不等待 debounce）
    public func flushImmediately() {
        guard !isInvalidated else { return }

        debounceTimer?.invalidate()
        debounceTimer = nil
        flushUpdates()
    }

    /// 使协调器失效，取消所有待处理的更新
    public func invalidate() {
        isInvalidated = true
        debounceTimer?.invalidate()
        debounceTimer = nil
        pendingUpdates.removeAll()
    }

    // MARK: - Private Methods

    /// 计算自适应延迟时间
    /// - Returns: 延迟时间（秒）
    private func adaptiveDelay() -> TimeInterval {
        // {{CHENGQI:
        // Action: Added
        // Timestamp: 2025-10-06 06:40:00 +08:00
        // Reason: 自适应延迟策略 - 根据滚动速度和 FPS 动态调整
        // Principle_Applied: Adaptive Performance - 平衡响应性和批量效率
        // Optimization: 快速滚动时延迟更长（减少中间状态），慢速/停止时延迟更短（快速响应）
        // }}

        // 因子 1: 滚动状态（基础延迟）
        let scrollFactor: TimeInterval = {
            switch scrollingState {
            case .idle:
                return 0.01 // 10ms - 快速响应用户操作
            case .slow:
                return 0.02 // 20ms - 平衡响应性和批量
            case .fast:
                return 0.05 // 50ms - 减少中间状态更新
            case .veryFast:
                return 0.1 // 100ms - 最大批量效率
            }
        }()

        // 因子 2: FPS（性能调节）
        let fpsFactor: TimeInterval = {
            if currentFPS >= 55.0 {
                return 1.0 // 性能良好，使用标准延迟
            } else if currentFPS >= 45.0 {
                return 1.5 // 性能一般，增加延迟减少更新频率
            } else {
                return 2.0 // 性能较差，显著增加延迟
            }
        }()

        let finalDelay = scrollFactor * fpsFactor

        // {{CHENGQI:
        // Action: Added
        // Timestamp: 2025-10-06 06:40:00 +08:00
        // Reason: 限制最小和最大延迟，避免极端情况
        // Principle_Applied: Safe Boundaries - 确保延迟在合理范围
        // }}
        // 最小 10ms（避免过于频繁），最大 200ms（避免用户感知延迟）
        return max(0.01, min(finalDelay, 0.2))
    }

    /// 调度刷新（使用 debounce）
    private func scheduleFlush() {
        guard !isInvalidated else { return }

        // 取消现有 timer
        debounceTimer?.invalidate()

        // 计算自适应延迟
        let delay = adaptiveDelay()

        // {{CHENGQI:
        // Action: Added
        // Timestamp: 2025-10-06 06:40:00 +08:00
        // Reason: 使用 Timer.scheduledTimer 在主线程创建定时器
        // Principle_Applied: UIKit Thread Safety - 确保 UI 更新在主线程
        // Optimization: weak self 避免循环引用
        // }}
        // 创建新 timer（必须在主线程）
        debounceTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.flushUpdates()
        }
    }

    /// 刷新所有待更新项
    private func flushUpdates() {
        guard !isInvalidated else { return }
        guard !pendingUpdates.isEmpty else { return }

        // {{CHENGQI:
        // Action: Added
        // Timestamp: 2025-10-06 06:40:00 +08:00
        // Reason: 去重逻辑 - 使用 AnyDispplayData 的 Hashable 特性
        // Principle_Applied: DRY - 避免重复更新相同的数据项
        // Optimization: uniqued() 扩展方法（需确保已实现）
        // }}
        // 去重
        let uniqueUpdates = pendingUpdates.uniqued()

        // 清空待更新队列
        pendingUpdates.removeAll()

        // 调用更新处理闭包
        updateHandler(uniqueUpdates)
    }
}

// MARK: - Array Extension (去重支持)

extension Array where Element: Hashable {
    /// 去重数组元素，保持原有顺序
    /// - Returns: 去重后的数组
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
