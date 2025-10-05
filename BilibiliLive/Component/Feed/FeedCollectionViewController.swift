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
            applySnapshotSafely()
        }
    }

    private var isLoading = false

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
        // {{CHENGQI:
        // Action: Modified
        // Timestamp: 2025-06-09 11:11:21 +08:00
        // Reason: 使用新的AnyDispplayData初始化方法
        // Principle_Applied: 保持接口一致性
        // }}
        _displayData.append(contentsOf: displayData.map { AnyDispplayData(data: $0) }.filter({ !_displayData.contains($0) }))
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
    // Action: Added
    // Timestamp: 2025-06-09 11:11:21 +08:00
    // Reason: 添加安全的快照应用方法，确保collection view完全准备就绪
    // Principle_Applied: KISS - 简单的状态检查逻辑
    // Optimization: 避免在collection view未就绪时应用快照
    // Architectural_Note (AR): 增强错误处理和tvOS兼容性
    // }}
    private func applySnapshotSafely() {
        // 检查collection view是否已经初始化且在视图层级中
        guard let collectionView = collectionView,
              collectionView.superview != nil
        else {
            // 延迟到下一个运行循环，确保UI完全就绪
            DispatchQueue.main.async { [weak self] in
                self?.applySnapshotSafely()
            }
            return
        }

        var snapshot = NSDiffableDataSourceSnapshot<Section, AnyDispplayData>()
        snapshot.appendSections(Section.allCases)
        snapshot.appendItems(_displayData, toSection: .main)

        // 使用动画应用快照，并提供完成回调
        dataSource.apply(snapshot, animatingDifferences: true) { [weak self] in
            // 快照应用完成后的处理
            if let self = self {
                Logger.debug("数据源快照已安全应用，当前项目数：\(self._displayData.count)")
            }
        }
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
            [weak self] supplementaryView, string, indexPath in
            guard let self else { return }
            supplementaryView.label.text = self.headerText
        }

        dataSource.supplementaryViewProvider = { view, kind, index in
            return self.collectionView.dequeueConfiguredReusableSupplementary(
                using: supplementaryRegistration, for: index
            )
        }

        return dataSource
    }

    private func makeCellRegistration() -> DisplayCellRegistration {
        DisplayCellRegistration { [weak self] cell, indexPath, displayData in
            cell.styleOverride = self?.styleOverride
            cell.setup(data: displayData.data)
            cell.onLongPress = {
                self?.didLongPress?(displayData.data)
            }
        }
    }
}

extension FeedCollectionViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let data = dataSource.itemIdentifier(for: indexPath) {
            didSelect?(data.data)
        }
    }

    func indexPathForPreferredFocusedView(in collectionView: UICollectionView) -> IndexPath? {
        let indexPath = IndexPath(item: 0, section: 0)
        return indexPath
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard _displayData.count > 0 else { return }
        guard indexPath.row == _displayData.count - 1, !isLoading, !finished else {
            return
        }
        isLoading = true
        loadMore?()
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
