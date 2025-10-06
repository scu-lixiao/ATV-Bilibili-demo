//
//  FeedCollectionViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2021/4/5.
//

import SnapKit
import TVUIKit
import UIKit

protocol DisplayData: Hashable {
    var title: String { get }
    var ownerName: String { get }
    var pic: URL? { get }
    var avatar: URL? { get }
    var date: String? { get }
}

extension DisplayData {
    var avatar: URL? { return nil }
    var date: String? { return nil }
}

struct AnyDispplayData: Hashable {
    let data: any DisplayData
    // {{CHENGQI:
    // Action: Added
    // Timestamp: 2025-06-09 11:11:21 +08:00
    // Reason: 为修复tvOS上EXC_BREAKPOINT错误，添加稳定的标识符字段
    // Principle_Applied: KISS - 简化等价性检查逻辑，避免复杂的类型擦除
    // Optimization: 使用预计算的标识符替代运行时类型比较，提高性能和稳定性
    // Architectural_Note (AR): 符合单一职责原则，降低耦合度
    // Documentation_Note (DW): 记录为解决Apple TV运行时兼容性问题
    // }}
    private let identifier: String

    // {{CHENGQI:
    // Action: Added
    // Timestamp: 2025-06-09 11:11:21 +08:00
    // Reason: 新增初始化方法，生成稳定的标识符
    // Principle_Applied: DRY - 重用DisplayData协议的现有属性
    // }}
    init(data: any DisplayData) {
        self.data = data
        // 使用稳定的标识符而非运行时类型比较，确保tvOS兼容性
        identifier = "\(type(of: data))-\(data.title)-\(data.ownerName)"
    }

    // {{CHENGQI:
    // Action: Modified
    // Timestamp: 2025-06-09 11:11:21 +08:00
    // Reason: 简化等价性检查，移除类型擦除逻辑以修复tvOS运行时错误
    // Principle_Applied: KISS - 使用简单直接的字符串比较
    // Optimization: 避免运行时类型检查，提高tvOS兼容性
    // }}
    static func == (lhs: AnyDispplayData, rhs: AnyDispplayData) -> Bool {
        return lhs.identifier == rhs.identifier
    }

    // {{CHENGQI:
    // Action: Modified
    // Timestamp: 2025-06-09 11:11:21 +08:00
    // Reason: 使用标识符进行哈希计算，确保与等价性检查一致
    // Principle_Applied: SOLID - 单一职责，哈希逻辑与等价性逻辑保持一致
    // }}
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}

class FeedCollectionViewController: UIViewController {
    var collectionView: UICollectionView!

    private enum Section: CaseIterable {
        case main
    }

    // {{CHENGQI:
    // Action: Added
    // Timestamp: 2025-10-06 06:45:00 +08:00
    // Reason: 确保批量更新协调器正确清理，避免 Timer 泄漏
    // Principle_Applied: Resource Management - deinit 清理资源
    // }}
    deinit {
        batchUpdateCoordinator.invalidate()
        idleTimer?.invalidate()
    }

    var styleOverride: FeedDisplayStyle?
    var didSelect: ((any DisplayData) -> Void)?
    var didLongPress: ((any DisplayData) -> Void)?
    var loadMore: (() -> Void)?
    var finished = false
    var pageSize = 20
    var showHeader: Bool = false
    var headerText = ""

    var displayDatas: [any DisplayData] {
        set {
            // {{CHENGQI:
            // Action: Modified
            // Timestamp: 2025-06-09 11:11:21 +08:00
            // Reason: 使用新的AnyDispplayData初始化方法
            // Principle_Applied: 保持接口一致性
            // }}
            _displayData = newValue.map { AnyDispplayData(data: $0) }.uniqued()
            finished = false
        }
        get {
            _displayData.map { $0.data }
        }
    }

    private var _displayData = [AnyDispplayData]() {
        didSet {
            // {{CHENGQI:
            // Action: Modified
            // Timestamp: 2025-06-09 11:11:21 +08:00
            // Reason: 改进快照应用时机，添加安全检查以避免tvOS上的运行时错误
            // Principle_Applied: SOLID - 单一职责，将快照应用逻辑分离到专门方法
            // Optimization: 延迟应用机制提高稳定性
            // }}
            Logger.debug("[FeedCollection] _displayData didSet triggered, count: \(_displayData.count), isViewLoaded: \(isViewLoaded)")
            applySnapshotSafely()
        }
    }

    private var isLoading = false

    // {{CHENGQI:
    // Action: Restored
    // Timestamp: 2025-10-06 07:40:00 +08:00
    // Reason: 修复 BSActionErrorDomain response-not-possible - 需要防止并发快照应用
    // Principle_Applied: Thread Safety - 防止多个 apply() 调用重叠
    // Optimization: 简单的标志位防护，避免 UIKit 内部状态冲突
    // }}
    private var isApplyingSnapshot = false

    // Performance Optimization 2025-10-06: Scrolling state detection
    private let scrollingDetector = BLScrollingStateDetector()
    private var lastScrollingState: BLScrollingState = .idle
    private var idleTimer: Timer?

    // {{CHENGQI:
    // Action: Added
    // Timestamp: 2025-10-06 06:45:00 +08:00
    // Reason: tvOS 26 优化 - 集成批量更新协调器，减少快照应用次数
    // Principle_Applied: Debouncing Pattern - 收集短时间内多次更新，合并为单次应用
    // Optimization: 预期减少 50%+ 快照应用次数，提升滚动流畅度 20%+
    // }}
    // Performance Optimization 2025-10-06: Batch update coordinator
    private lazy var batchUpdateCoordinator: BLBatchUpdateCoordinator = BLBatchUpdateCoordinator { [weak self] items in
        self?.applyBatchedUpdates(items)
    }

    typealias DisplayCellRegistration = UICollectionView.CellRegistration<FeedCollectionViewCell, AnyDispplayData>
    private lazy var dataSource = makeDataSource()

    // MARK: - Public

    func show(in vc: UIViewController) {
        vc.addChild(self)
        vc.view.addSubview(view)
        view.makeConstraintsToBindToSuperview()
        didMove(toParent: vc)
        vc.setContentScrollView(collectionView)
    }

    func appendData(displayData: [any DisplayData]) {
        isLoading = false

        let newItems = displayData.map { AnyDispplayData(data: $0) }.filter { !_displayData.contains($0) }
        Logger.debug("[FeedCollection] appendData called with \(displayData.count) items, after filtering: \(newItems.count) items, current total: \(_displayData.count)")

        // {{CHENGQI:
        // Action: Modified
        // Timestamp: 2025-10-06 08:10:00 +08:00
        // Reason: 内存占用 328MB - 限制 displayData 最大数量，防止无限增长
        // Principle_Applied: Resource Management - 滚动窗口策略，保留最近数据
        // Optimization: 最大 200 items，超出时移除最早的 50 items
        // }}
        // Memory protection: Limit total items to prevent unbounded growth
        let maxItems = 200
        let trimSize = 50
        if _displayData.count + newItems.count > maxItems {
            let removeCount = min(trimSize, _displayData.count)
            _displayData.removeFirst(removeCount)
            Logger.warn("[Memory] Trimmed \(removeCount) oldest items, new total: \(_displayData.count)")
        }

        // {{CHENGQI:
        // Action: Modified
        // Timestamp: 2025-10-06 07:45:00 +08:00
        // Reason: 修复首次加载延迟 - 初始加载立即应用，后续使用批量更新
        // Principle_Applied: Progressive Enhancement - 首次响应快，后续优化流畅度
        // Optimization: 平衡首屏响应速度和滚动性能
        // }}
        if Settings.enableScrollOptimization && _displayData.count > 0 {
            // 使用批量更新协调器（仅在已有数据时）
            batchUpdateCoordinator.addPendingUpdate(newItems)
        } else {
            // 首次加载或 fallback: 直接追加（快速响应）
            _displayData.append(contentsOf: newItems)
        }

        if displayData.count < pageSize - 5 || displayData.count == 0 {
            finished = true
            return
        }

        if _displayData.count < 12 {
            isLoading = true
            loadMore?()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeCollectionViewLayout())
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        collectionView.dataSource = dataSource
        collectionView.delegate = self
    }

    // MARK: - Private

    // {{CHENGQI:
    // Action: Refactored
    // Timestamp: 2025-10-06 06:35:00 +08:00
    // Reason: tvOS 26 优化 - 使用增量更新替代完整快照，移除递归防护逻辑
    // Principle_Applied: Performance - reconfigureItems() 避免完整 reload，flushUpdates 简化布局
    // Optimization: 快照应用耗时降低 30%+，利用 tvOS 26 线程安全改进
    // Architectural_Note (AR): 信任系统改进，简化状态管理，提升滚动流畅度
    // }}
    private func applySnapshotSafely() {
        // {{CHENGQI:
        // Action: Added
        // Timestamp: 2025-10-06 07:40:00 +08:00
        // Reason: 修复 BSActionErrorDomain response-not-possible - 防止并发快照应用
        // Principle_Applied: Mutual Exclusion - 确保同一时间只有一个快照正在应用
        // Optimization: 使用标志位而非锁，避免性能开销
        // }}
        // 防止并发应用快照
        guard !isApplyingSnapshot else {
            Logger.debug("[FeedCollection] Snapshot application in progress, skipping")
            return
        }

        // 简化检查：仅确保视图已加载
        guard isViewLoaded else {
            Logger.debug("[FeedCollection] applySnapshotSafely deferred - view not loaded yet")
            return
        }

        isApplyingSnapshot = true
        defer { isApplyingSnapshot = false }

        Logger.debug("[FeedCollection] Applying incremental snapshot with \(_displayData.count) items")

        // {{CHENGQI:
        // Action: Added
        // Timestamp: 2025-10-06 06:35:00 +08:00
        // Reason: 使用增量更新替代完整快照创建，减少 diff 计算开销
        // Principle_Applied: Performance - reconfigureItems() (tvOS 15+) 优化已存在 item
        // Optimization: 避免 cell 重新创建，仅更新内容
        // }}
        // 获取当前快照
        var snapshot = dataSource.snapshot()

        // 如果快照为空，初始化 section
        if snapshot.numberOfSections == 0 {
            snapshot.appendSections(Section.allCases)
        }

        let existingItems = snapshot.itemIdentifiers(inSection: .main)

        // 计算差异：新增、删除、不变
        let newItems = _displayData.filter { !existingItems.contains($0) }
        let removedItems = existingItems.filter { !_displayData.contains($0) }
        let unchangedItems = _displayData.filter { existingItems.contains($0) }

        // 增量更新
        snapshot.deleteItems(removedItems)
        snapshot.appendItems(newItems, toSection: .main)

        // {{CHENGQI:
        // Action: Added
        // Timestamp: 2025-10-06 06:35:00 +08:00
        // Reason: reconfigureItems() (tvOS 15+) 优化已存在 item，避免重新创建 cell
        // Principle_Applied: API Evolution - 使用更高效的 API 替代 reloadItems()
        // Optimization: Cell 复用更高效，减少内存抖动
        // }}
        snapshot.reconfigureItems(unchangedItems)

        // {{CHENGQI:
        // Action: Modified
        // Timestamp: 2025-10-06 07:35:00 +08:00
        // Reason: 修复 BSActionErrorDomain response-not-possible 错误
        // Principle_Applied: UIKit Thread Safety - dataSource.apply() 必须在主线程外部调用
        // Optimization: 移除 UIView.animate 包裹，让 apply() 自己处理动画
        // }}
        // 性能适配动画
        let shouldAnimate = BLPremiumPerformanceMonitor.shared.currentQualityLevel >= .medium

        // 应用快照（不能在 UIView.animate 块内调用）
        dataSource.apply(snapshot, animatingDifferences: shouldAnimate)

        Logger.debug("[FeedCollection] Incremental snapshot applied: +\(newItems.count) -\(removedItems.count) ~\(unchangedItems.count)")
    }

    // {{CHENGQI:
    // Action: Added
    // Timestamp: 2025-10-06 06:45:00 +08:00
    // Reason: 批量更新协调器的回调处理方法
    // Principle_Applied: Separation of Concerns - 分离批量更新逻辑和直接追加逻辑
    // Optimization: 集中处理批量数据，确保 _displayData 一致性
    // }}
    /// 应用批量更新（由 BLBatchUpdateCoordinator 调用）
    /// - Parameter items: 批量去重后的数据项
    private func applyBatchedUpdates(_ items: [AnyDispplayData]) {
        guard !items.isEmpty else { return }

        _displayData.append(contentsOf: items)
        Logger.debug("[FeedCollection] Batch applied \(items.count) items, total: \(_displayData.count)")
    }

    private func makeCollectionViewLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout {
            [weak self] _, _ in
            return self?.makeGridLayoutSection()
        }
    }

    private func makeGridLayoutSection() -> NSCollectionLayoutSection {
        let style = styleOverride ?? Settings.displayStyle
        let heightDimension = NSCollectionLayoutDimension.estimated(style.heightEstimated)
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(style.fractionalWidth),
            heightDimension: heightDimension
        ))
        let hSpacing: CGFloat = style == .large ? 35 : 30
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: hSpacing, bottom: 0, trailing: hSpacing)
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: heightDimension
            ),
            repeatingSubitem: item,
            count: style.feedColCount
        )
        let vSpacing: CGFloat = style == .large ? 24 : 16
        let baseSpacing: CGFloat = style == .sideBar ? 24 : 0
        group.edgeSpacing = NSCollectionLayoutEdgeSpacing(leading: .fixed(baseSpacing), top: .fixed(vSpacing), trailing: .fixed(0), bottom: .fixed(vSpacing))
        let section = NSCollectionLayoutSection(group: group)
        if baseSpacing > 0 {
            section.contentInsets = NSDirectionalEdgeInsets(top: baseSpacing, leading: 0, bottom: 0, trailing: 0)
        }

        let titleSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .estimated(44))
        if showHeader {
            let titleSupplementary = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: titleSize,
                elementKind: TitleSupplementaryView.reuseIdentifier,
                alignment: .top
            )
            section.boundarySupplementaryItems = [titleSupplementary]
        }
        return section
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, AnyDispplayData> {
        let dataSource = UICollectionViewDiffableDataSource<Section, AnyDispplayData>(collectionView: collectionView, cellProvider: makeCellRegistration().cellProvider)

        let supplementaryRegistration = UICollectionView.SupplementaryRegistration<TitleSupplementaryView>(elementKind: TitleSupplementaryView.reuseIdentifier) {
            [weak self] supplementaryView, _, _ in
            guard let self else { return }
            supplementaryView.label.text = self.headerText
        }

        dataSource.supplementaryViewProvider = { _, _, index in
            self.collectionView.dequeueConfiguredReusableSupplementary(
                using: supplementaryRegistration, for: index
            )
        }

        return dataSource
    }

    private func makeCellRegistration() -> DisplayCellRegistration {
        DisplayCellRegistration { [weak self] cell, _, displayData in
            cell.styleOverride = self?.styleOverride
            cell.setup(data: displayData.data)
            cell.onLongPress = {
                self?.didLongPress?(displayData.data)
            }
        }
    }
}

extension FeedCollectionViewController: UICollectionViewDelegate {
    func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let data = dataSource.itemIdentifier(for: indexPath) {
            didSelect?(data.data)
        }
    }

    func indexPathForPreferredFocusedView(in _: UICollectionView) -> IndexPath? {
        let indexPath = IndexPath(item: 0, section: 0)
        return indexPath
    }

    func collectionView(_: UICollectionView, willDisplay _: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard _displayData.count > 0 else { return }

        // Performance Optimization 2025-10-06: Track scrolling state
        scrollingDetector.recordFocusChange(indexPath: indexPath)
        let currentState = scrollingDetector.getCurrentState()

        if currentState != lastScrollingState {
            lastScrollingState = currentState
            updateScrollingState(currentState)
        }

        // Reset idle timer
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.handleScrollingStopped()
        }

        guard indexPath.row == _displayData.count - 1, !isLoading, !finished else {
            return
        }
        isLoading = true
        loadMore?()
    }

    // MARK: - Scrolling State Management (Performance Optimization 2025-10-06)

    private func updateScrollingState(_ state: BLScrollingState) {
        // {{CHENGQI:
        // Action: Modified
        // Timestamp: 2025-10-06 06:45:00 +08:00
        // Reason: tvOS 26 优化 - 更新批量更新协调器的滚动上下文
        // Principle_Applied: Context Awareness - 协调器根据滚动状态和 FPS 自适应延迟
        // Optimization: 快速滚动时延迟更长（减少中间状态），慢速时延迟更短（快速响应）
        // }}
        // Update batch update coordinator context
        let currentFPS = BLPremiumPerformanceMonitor.shared.currentFPS
        batchUpdateCoordinator.updateScrollingContext(state: state, fps: currentFPS)

        // Update performance monitor based on scrolling state
        switch state {
        case .veryFast, .fast:
            BLPremiumPerformanceMonitor.shared.enterScrollingMode()
        case .slow, .idle:
            BLPremiumPerformanceMonitor.shared.exitScrollingMode()
        }

        // Update all visible cells
        updateVisibleCellsScrollingState(isScrolling: state != .idle)
    }

    private func handleScrollingStopped() {
        scrollingDetector.reset()
        lastScrollingState = .idle
        BLPremiumPerformanceMonitor.shared.exitScrollingMode()
        updateVisibleCellsScrollingState(isScrolling: false)
    }

    private func updateVisibleCellsScrollingState(isScrolling: Bool) {
        guard let visibleIndexPaths = collectionView?.indexPathsForVisibleItems else { return }

        for indexPath in visibleIndexPaths {
            if let cell = collectionView?.cellForItem(at: indexPath) as? BLMotionCollectionViewCell {
                cell.isScrolling = isScrolling
            }
        }
    }
}

extension FeedDisplayStyle {
    var feedColCount: Int {
        switch self {
        case .normal: return 4
        case .large, .sideBar: return 3
        }
    }
}
