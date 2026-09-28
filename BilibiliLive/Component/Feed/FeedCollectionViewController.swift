//
//  FeedCollectionViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2021/4/5.
//

import Kingfisher
import SnapKit
import SwiftUI
import TVUIKit
import UIKit

let normailSornerRadius = 25.0
let lessBigSornerRadius = 35.0
let bigSornerRadius = 45.0

let EVENT_COLLECTION_TO_SHOW_MENU = NSNotification.Name("EVENT_COLLECTION_TO_SHOW_MENU")

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

    static func == (lhs: AnyDispplayData, rhs: AnyDispplayData) -> Bool {
        func eq<T: Equatable>(lhs: T, rhs: any Equatable) -> Bool {
            lhs == rhs as? T
        }
        return eq(lhs: lhs.data, rhs: rhs.data)
    }

    func hash(into hasher: inout Hasher) {
        data.hash(into: &hasher)
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
    var showHeader: Bool = false  // 隐藏所有栏目的标题栏
    var headerText = ""
    let collectionEdgeInsetTop = 40.0

    let bgImageView = UIImageView()

    var isShowTopCover: (() -> Bool)?
    var isToToped: ((_ isTop: Bool) -> Void)?

    var didSelectToLastLeft: (() -> Void)?

    /// 顶部大图的三种布局状态。焦点在同一行内移动时状态不变，据此跳过重复的弹簧动画和整页 layout
    private enum TopCoverState {
        case expanded // 大图完整展示
        case peek // 焦点在第一行，大图上移露出第一行
        case collapsed // 焦点在第二行及以下，大图完全收起
    }

    private var topCoverState = TopCoverState.expanded
    
    // 标志位：是否正在滚动到顶部（防止在滚动过程中立即调出导航栏）
    private var isScrollingToTop = false

    private let viewModel = BannerViewModel()
    private var bannerUIView: UIView?
    private let animationOffSet = -200.0
    private let animateTime = 0.8

    var displayDatas: [any DisplayData] {
        set {
            replaceItems(with: newValue)
            finished = false
        }
        get {
            _displayData.map { $0.data }
        }
    }

    private var _displayData = [AnyDispplayData]()
    /// 与 _displayData 同步，用于 O(1) 去重（原先每次追加都对整个数组 contains，分页越多越慢）
    private var displayDataSet = Set<AnyDispplayData>()

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
        // 同一批数据内部也可能重复，重复的 identifier 会让 diffable data source 直接崩溃
        let newItems = displayData.map { AnyDispplayData(data: $0) }.filter { displayDataSet.insert($0).inserted }
        _displayData.append(contentsOf: newItems)
        applySnapshot(animated: true)
        handlePageLoaded(count: displayData.count)
    }

    /// 刷新时一次性替换全部数据，避免先置空再追加导致两次 apply、列表闪一下
    func resetData(displayData: [any DisplayData]) {
        isLoading = false
        finished = false
        let wasEmpty = _displayData.isEmpty
        replaceItems(with: displayData, animated: wasEmpty)
        handlePageLoaded(count: displayData.count)
    }

    private func replaceItems(with displayData: [any DisplayData], animated: Bool = true) {
        _displayData = displayData.map { AnyDispplayData(data: $0) }.uniqued()
        displayDataSet = Set(_displayData)
        applySnapshot(animated: animated)
    }

    private func applySnapshot(animated: Bool) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, AnyDispplayData>()
        snapshot.appendSections(Section.allCases)
        snapshot.appendItems(_displayData, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: animated)
    }

    private func handlePageLoaded(count: Int) {
        if count < pageSize - 5 || count == 0 {
            finished = true
            return
        }

        if _displayData.count < 12 {
            isLoading = true
            loadMore?()
        }
    }

    func reloadData() {
        Task {
            try await viewModel.loadFavList()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

//        背景图
        view.addSubview(bgImageView)
        bgImageView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.top.equalToSuperview().offset(-60)
        }
        bgImageView.contentMode = .scaleAspectFill
        bgImageView.clipsToBounds = true
        bgImageView.setBlurEffectView()

        if isShowTopCover?() ?? false {
            // 顶部大图
            let bannerSwiftUIView = BannerView(viewModel: viewModel)
            viewModel.focusedBannerButton = { [weak self] in
                guard let self = self else { return }
                resetTopView()
            }

            viewModel.overMoveLeft = { [weak self] in
                guard let self = self else { return }
                didSelectToLastLeft?()
            }

            viewModel.playAction = { [weak self] data in
                guard let self = self else { return }
                let player = VideoPlayerViewController(playInfo: PlayInfo(aid: data.id, cid: data.cid, epid: 0, isBangumi: false))
                self.present(player, animated: true)
            }

            viewModel.detailAction = { [weak self] data in
                guard let self = self else { return }
                let detailVC = VideoDetailViewController.create(aid: data.id, cid: data.cid)
                detailVC.present(from: self)
            }
            // 创建 UIHostingController
            let hostingController = UIHostingController(rootView: bannerSwiftUIView)
            // 获取 hostingController 的 view
            bannerUIView = hostingController.view
            bannerUIView?.translatesAutoresizingMaskIntoConstraints = false

            if let bannerUIView = bannerUIView {
                view.addSubview(bannerUIView)
                bannerUIView.snp.makeConstraints { make in
                    make.left.right.equalToSuperview()
                    make.top.equalToSuperview()
                    make.height.equalTo(1080)
                }
            }

            // 内容
            collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeCollectionViewLayout())
            view.addSubview(collectionView)
            collectionView.snp.makeConstraints { make in
                make.left.right.equalToSuperview()
                make.top.equalTo(bannerUIView!.snp.bottom).offset(animationOffSet)
                make.height.equalTo(1120)
            }
            collectionView.contentInset = UIEdgeInsets(top: collectionEdgeInsetTop, left: 0, bottom: 0, right: 0)

            Task {
                try await viewModel.loadFavList()
            }

        } else {
            // 内容
            collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeCollectionViewLayout())
            view.addSubview(collectionView)
            collectionView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            collectionView.contentInset = UIEdgeInsets(top: collectionEdgeInsetTop, left: 0, bottom: 0, right: 0)
        }

        collectionView.dataSource = dataSource
        collectionView.delegate = self
    }

    /// 由 MenusViewController 直接调用（只会调用当前可见的页面）
    func handleMenuPress() {
        // 如果正在滚动到顶部，忽略此次 Menu 按键（避免立即调出导航栏）
        if isScrollingToTop {
            Logger.debug("Menu press ignored - still scrolling to top")
            return
        }
        
        // 检查是否需要滚动到顶部
        if collectionView.contentOffset.y > 100 {
            isScrollingToTop = true
            scrollPositionToTop()
            
            // 延迟重置标志位，确保滚动动画完成后才能调出导航栏
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.isScrollingToTop = false
            }
            return
        } 
        
        // 检查是否需要重置顶部视图
        if collectionView.contentOffset.y == -collectionEdgeInsetTop
            && isShowTopCover?() ?? false
            && topCoverState != .expanded {
            resetTopView()
            return
        }
        
        // 已经在顶部且顶部视图已重置，调出导航栏
        NotificationCenter.default.post(name: EVENT_COLLECTION_TO_SHOW_MENU, object: nil)
    }

    // MARK: - Private

    private func makeCollectionViewLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout {
            [weak self] _, _ in
            self?.makeGridLayoutSection()
        }
    }

    private func makeGridLayoutSection() -> NSCollectionLayoutSection {
        let style = styleOverride ?? Settings.displayStyle

        // top
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(style.fractionalWidth),

            heightDimension: .fractionalHeight(1)

        ))
        let hSpacing = style.hSpacing
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: hSpacing, bottom: 0, trailing: hSpacing)

        let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalHeight(style.groupFractionalHeight)
        ), repeatingSubitem: item, count: style.feedColCount)

        let vSpacing: CGFloat = style == .large ? 34 : 26
        let baseSpacing: CGFloat = style == .sideBar ? 34 : 0

        group.edgeSpacing = NSCollectionLayoutEdgeSpacing(leading: .fixed(baseSpacing), top: .fixed(vSpacing), trailing: .fixed(0), bottom: .fixed(vSpacing))

        // section
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

        // dataSource 被 self 持有，闭包里不能强引用 self（原先的 self.collectionView 造成循环引用，控制器永远不会释放），
        // 直接使用闭包参数里的 collectionView
        dataSource.supplementaryViewProvider = { collectionView, _, index in
            collectionView.dequeueConfiguredReusableSupplementary(
                using: supplementaryRegistration, for: index
            )
        }

        return dataSource
    }

    private func makeCellRegistration() -> DisplayCellRegistration {
        DisplayCellRegistration { [weak self] cell, index, displayData in
            cell.styleOverride = self?.styleOverride
            cell.setup(data: displayData.data, indexPath: index)
            cell.onLongPress = { [weak self] in
                self?.didLongPress?(displayData.data)
            }
        }
    }

    func scrollPositionToTop() {
        let indexPath = IndexPath(item: 0, section: 0)
        // 使用平滑滚动动画，而不是 reloadData
        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .top)
        // 移除 reloadData()，避免打断滚动动画和焦点流程
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
        loadBackgroundImageIfNeeded(for: indexPath)
        return indexPath
    }

    /// 背景图会被整屏模糊，只需小尺寸即可；并且只在还没有设置过时加载一次，
    /// 避免首屏每个 cell 的 willDisplay 都发起一次全尺寸下载并互相取消
    private func loadBackgroundImageIfNeeded(for indexPath: IndexPath) {
        guard bgImageView.image == nil, bgImageView.kf.taskIdentifier == nil,
              let pic = dataSource.itemIdentifier(for: indexPath)?.data.pic else { return }
        bgImageView.kf.setImage(with: pic.addSchemeIfNeed(), options: [
            .processor(DownsamplingImageProcessor(size: CGSize(width: 480, height: 270))),
            .transition(.fade(0.3)),
        ])
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard _displayData.count > 0 else { return }
        loadBackgroundImageIfNeeded(for: indexPath)
        guard indexPath.row == _displayData.count - 1, !isLoading, !finished else {
            return
        }
        isLoading = true
        loadMore?()
    }

    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        collectionView.visibleCells.compactMap { $0 as? BLMotionCollectionViewCell }.forEach { cell in
            cell.updateTransform()
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 模糊背景的轻微视差：直接设置 transform（滚动本身已逐帧驱动），不再每帧创建一个 UIView 动画。
        // 位移限制在 [0, 60]，与 bgImageView 顶部多出的 60pt 对应，保证上下边缘不会露出空白
        let offset = min(max(scrollView.contentOffset.y + collectionEdgeInsetTop, 0) * 0.5, 60)
        bgImageView.transform = CGAffineTransform(translationX: 0, y: offset)
    }

    func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        guard let indexPath = context.nextFocusedIndexPath else { return }
        guard isShowTopCover?() ?? false else { return }
        let style = styleOverride ?? Settings.displayStyle
        if (indexPath.row + 1) > style.feedColCount {
            // 第二行把上面的全部隐藏
            setTopCoverState(.collapsed)
            isToToped?(false)
        } else {
            // 第一行
            BLAfter(afterTime: 0.0) {
                self.setTopCoverState(.peek)
            }
            isToToped?(false)
        }
    }

    func resetTopView() {
        setTopCoverState(.expanded)
        isToToped?(true)
    }

    private func setTopCoverState(_ state: TopCoverState) {
        // 收起状态下大图不可见，保持原来的 offsetY 不动
        let offsetY: CGFloat? = switch state {
        case .expanded: 0
        case .peek: 130
        case .collapsed: nil
        }
        // @Published 即使赋相同的值也会触发 SwiftUI 刷新，先比较
        if let offsetY, viewModel.offsetY != offsetY {
            viewModel.offsetY = offsetY
        }
        guard state != topCoverState, let bannerUIView, bannerUIView.superview != nil else { return }
        topCoverState = state

        let bannerTop: CGFloat
        let collectionOffset: CGFloat
        switch state {
        case .expanded:
            bannerTop = 0
            collectionOffset = animationOffSet
        case .peek:
            bannerTop = -820
            collectionOffset = 0
        case .collapsed:
            bannerTop = -1110
            collectionOffset = -10
        }
        UIView.animate(springDuration: animateTime, bounce: 0.1) {
            bannerUIView.snp.updateConstraints { make in
                make.top.equalToSuperview().offset(bannerTop)
            }
            self.collectionView.snp.updateConstraints { make in
                make.top.equalTo(bannerUIView.snp.bottom).offset(collectionOffset)
            }
            self.view.layoutIfNeeded()
        }
    }
}

extension FeedDisplayStyle {
    var feedColCount: Int {
        switch self {
        case .big: return bigItmeCount
        case .normal: return normalItmeCount
        case .large, .sideBar: return largeItmeCount
        }
    }
}
