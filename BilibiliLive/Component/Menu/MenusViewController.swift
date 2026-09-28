//
//  MenusViewController.swift
//  BilibiliLive
//
//  Created by ManTie on 2024/7/4.
//

import Alamofire
import Kingfisher
import SwiftyJSON
import UIKit

class MenusViewController: UIViewController, BLTabBarContentVCProtocol {
    static func create() -> MenusViewController {
        return UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(identifier: String(describing: self)) as! MenusViewController
    }

    @IBOutlet var contentView: UIView!
    @IBOutlet var avatarImageView: UIImageView!
    @IBOutlet var usernameLabel: UILabel! {
        didSet {
            usernameLabel.text = "主页"
        }
    }

    @IBOutlet var leftCollectionView: BSCollectionVIew!
    weak var currentViewController: UIViewController?
    private var menuIsShowing = false
    private var selectMenuItem: CellModel?
    /// 菜单的玻璃层。展开 / 收起时圆角要和 menusView 的描边同步变化
    private weak var menusGlassView: UIVisualEffectView?

    @IBOutlet var menusView: UIView! {
        didSet {
            // Use enhanced multi-layer glass with dark theme optimization
            menusGlassView = menusView.applyLiquidGlass(
                style: .clear,
                tintColor: UIColor.glassPinkTintDark,
                cornerRadius: lessBigSornerRadius,
                interactive: false
            )
            menusView.layer.cornerCurve = .continuous

            // Add subtle stroke for definition
            menusView.layer.borderWidth = 1.0
            menusView.layer.borderColor = UIColor.glassStrokeBorder.cgColor
            menusView.alpha = 0
            menusView.removeFromSuperview()
        }
    }

    @IBOutlet var homeIcon: UIImageView! {
        didSet {
            homeIcon.setImageColor(color: .gray)
            homeIcon.alpha = 0
        }
    }

    @IBOutlet var menusLeft: NSLayoutConstraint!
    @IBOutlet var menusViewHeight: NSLayoutConstraint!

    @IBOutlet var vcLeft: NSLayoutConstraint!
    @IBOutlet var collectionTop: NSLayoutConstraint!
    @IBOutlet var headViewLeading: NSLayoutConstraint!
    @IBOutlet var headingViewTop: NSLayoutConstraint!

    @IBOutlet var menuViewWidth: NSLayoutConstraint!

    var userName = ""

    var cellModels = [CellModel]()
    override func viewDidLoad() {
        super.viewDidLoad()
        setupData()
        leftCollectionView.reloadData()
        avatarImageView.layer.cornerRadius = avatarImageView.frame.size.width / 2
        leftCollectionView.register(BLMenuLineCollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        leftCollectionView.selectItem(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .top)
        collectionView(leftCollectionView, didSelectItemAt: IndexPath(row: 0, section: 0))
        WebRequest.requestLoginInfo { [weak self] response in
            switch response {
            case let .success(json):
                self?.avatarImageView.kf.setImage(with: URL(string: json["face"].stringValue))
                self?.userName = json["uname"].stringValue
            case .failure:
                break
            }
        }
        menusLeft.constant = 40

        // Use premium deep dark background
        view.backgroundColor = UIColor.deepDarkBG
        
        // Add ambient gradient for depth with enhanced glow
        view.applyDarkGradient()
        
        // Add subtle radial glow behind menu for depth perception
        addAmbientGlowToMenu()

        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.addObserver(forName: EVENT_COLLECTION_TO_SHOW_MENU, object: nil, queue: .main) { [weak self] _ in
            self?.showMenus()
        }
        
        // Add memory warning observer for performance optimization
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleMemoryWarning()
        }

        // 移除旧的 gesture recognizer 方式，改用 pressesEnded 方法处理 Menu 按键
        BLAfter(afterTime: 2) {
            self.view.addSubview(self.menusView)
            self.hiddenMenus(isHiddenSubView: true)

            self.menusView.snp.makeConstraints { make in
                make.top.left.equalTo(30)
            }
            BLAfter(afterTime: 1) {
                BLAnimate(withDuration: 0.4) {
                    self.menusView.alpha = 1
                    self.homeIcon.alpha = 1
                }
            }
        }
    }

    /// 导航栏收起时按 Menu：交给当前可见的信息流页面处理（回到顶部 → 恢复大图 → 请求展开导航栏），
    /// 没有信息流的页面（设置、关注UP 等）直接展开导航栏。
    ///
    /// 不要改成通知广播：切换页面后旧页面并不会释放，广播会让不可见的页面也响应，
    /// 是否展开导航栏就取决于这些隐藏页面的滚动位置。
    func handleMenuPress() {
        if let feed = visibleFeed(in: currentViewController) {
            feed.handleMenuPress()
        } else {
            showMenus()
        }
    }

    private func visibleFeed(in viewController: UIViewController?) -> FeedCollectionViewController? {
        guard let viewController, viewController.viewIfLoaded?.window != nil else { return nil }
        if let feed = viewController as? FeedCollectionViewController {
            return feed
        }
        for child in viewController.children {
            if let feed = visibleFeed(in: child) {
                return feed
            }
        }
        return nil
    }

    func showMenus() {
        guard !menuIsShowing else { return }

        BLAfter(afterTime: 0.1) {
            self.view.setNeedsFocusUpdate()
            self.view.updateFocusIfNeeded()

            // 直接弹簧展开。原先先用 0.3s 把菜单缩到 0.95 再展开，按下遥控器后约 0.4s 才开始有反馈
            self.menusView.animateSpring(.standard) {
                // 渐变显示子元素
                self.leftCollectionView.alpha = 1
                self.homeIcon.alpha = 0

                // 调整布局常量
                self.collectionTop.constant = 40
                self.menusViewHeight.constant = 1020
                self.headViewLeading.constant = 20
                self.headingViewTop.constant = 20
                self.menuViewWidth.constant = 320
                self.setMenusCornerRadius(bigSornerRadius)

                // Premium shadow with enhanced depth
                self.menusView.applyPremiumShadow(elevation: .level3, glowColor: .pinkGlowShadow)

                // Update ambient glow for expanded state
                self.updateAmbientGlow(isExpanded: true)

                // label 动画
                UIView.transition(with: self.usernameLabel,
                                  duration: AnimationDuration.standard.rawValue,
                                  options: [.transitionCrossDissolve]) {
                    self.usernameLabel.text = self.userName
                }
                self.usernameLabel.transform = CGAffineTransform(scaleX: 1.01, y: 1.01)
                self.usernameLabel.alpha = 0.6
                self.view.layoutIfNeeded()
            } completion: { _ in
                // Smooth follow-through
                UIView.animate(withDuration: AnimationDuration.standard.rawValue) {
                    self.usernameLabel.transform = .identity
                    self.usernameLabel.alpha = 1
                }
                self.menuIsShowing = true
            }
        }
    }

    /// 同时更新描边（menusView.layer）和玻璃层的圆角。
    /// 原先只改了 menusView 的圆角，玻璃层固定为 35，展开后描边和玻璃的圆角对不上
    private func setMenusCornerRadius(_ radius: CGFloat) {
        menusView.layer.cornerRadius = radius
        menusGlassView?.layer.cornerRadius = radius
    }
    
    func hiddenMenus(isHiddenSubView: Bool = false) {
        // Use refined spring parameters for collapse animation
        menusView.animateSpring(.subtle) {
            self.leftCollectionView.alpha = 0
            self.homeIcon.alpha = isHiddenSubView ? 0 : 1

            // 缩回布局
            self.collectionTop.constant = 0
            self.menusViewHeight.constant = 60
            self.headViewLeading.constant = 5
            self.headingViewTop.constant = 5
            self.menuViewWidth.constant = 180
            self.setMenusCornerRadius(30)

            // Reduced shadow in collapsed state
            self.menusView.applyPremiumShadow(elevation: .level1)
            
            // Update ambient glow for collapsed state
            self.updateAmbientGlow(isExpanded: false)

            // usernameLabel 动画
            UIView.transition(with: self.usernameLabel,
                              duration: AnimationDuration.standard.rawValue,
                              options: [.transitionCrossDissolve]) {
                self.usernameLabel.text = self.selectMenuItem?.title
            }
            self.usernameLabel.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            self.usernameLabel.alpha = 0.8

            self.view.layoutIfNeeded()
        } completion: { _ in
            UIView.animate(withDuration: AnimationDuration.fast.rawValue) {
                self.usernameLabel.transform = .identity
                self.usernameLabel.alpha = 1
            }
            self.menuIsShowing = false
        }
    }

    override var preferredFocusedView: UIView? {
        return leftCollectionView
    }

    func setupData() {
        let lastLeft: () -> Void = { [weak self] in
            self?.showMenus()
        }
        let followsViewController = FollowsViewController()
        followsViewController.didSelectToLastLeft = lastLeft
        followsViewController.isShowTopCover = {
            true
        }
        followsViewController.isNeedFocusToMenu = {
            true
        }
        cellModels.append(CellModel(iconImage: UIImage(systemName: "person.crop.circle.badge.checkmark"), title: "关注", contentVC: followsViewController))

        let FeedViewController = FeedViewController()
        FeedViewController.isNeedFocusToMenu = {
            true
        }
        FeedViewController.didSelectToLastLeft = lastLeft
        cellModels.append(CellModel(iconImage: UIImage(systemName: "timelapse"), title: "推荐", contentVC: FeedViewController))

        let HotViewController = HotViewController()
        HotViewController.isNeedFocusToMenu = {
            true
        }
        HotViewController.didSelectToLastLeft = lastLeft
        cellModels.append(CellModel(iconImage: UIImage(systemName: "livephoto.play"), title: "热门", contentVC: HotViewController))

        cellModels.append(CellModel(iconImage: UIImage(systemName: "theatermasks.circle"), title: "排行榜", contentVC: RankingViewController()))
        cellModels.append(CellModel(iconImage: UIImage(systemName: "infinity.circle"), title: "直播", contentVC: LiveViewController()))

        cellModels.append(CellModel(iconImage: UIImage(systemName: "star.circle"), title: "收藏", contentVC: FavoriteViewController()))

        let logout = CellModel(iconImage: UIImage(systemName: "magnifyingglass.circle"), title: "搜索", autoSelect: false) {
            [weak self] in
//            self?.actionLogout()
            let resultVC = SearchResultViewController()
            let searchVC = UISearchController(searchResultsController: resultVC)
            searchVC.searchResultsUpdater = resultVC
            self?.present(UISearchContainerViewController(searchController: searchVC), animated: true)
        }
        cellModels.append(logout)
        cellModels.append(CellModel(iconImage: UIImage(systemName: "gear"), title: "设置", contentVC: PersonalViewController.create()))
    }

    func setViewController(vc: UIViewController, isHiddenMenus: Bool = true) {
        currentViewController?.willMove(toParent: nil)
        currentViewController?.view.removeFromSuperview()
        currentViewController?.removeFromParent()

        currentViewController = vc
        addChild(vc)
        contentView.addSubview(vc.view)
        vc.view.makeConstraintsToBindToSuperview()
        vc.didMove(toParent: self)

        BLAfter(afterTime: 0.3) {
            self.hiddenMenus(isHiddenSubView: true)
        }
    }

    func reloadData() {
        (currentViewController as? BLTabBarContentVCProtocol)?.reloadData()
    }

    func actionLogout() {
        let alert = UIAlertController(title: "确定登出？", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) {
            _ in
            ApiRequest.logout {
                WebRequest.logout {
                    AppDelegate.shared.showLogin()
                }
            }
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var didHandlePress = false
        
        for press in presses {
            switch press.type {
            case .menu:
                // 如果导航栏已展开，不拦截 Menu 按键，让系统处理（退出应用返回主界面）
                if menuIsShowing {
                    Logger.debug("Menu pressed - menu is showing, passing to super (exit app)")
                    // 不设置 didHandlePress，让事件传递给系统退出应用
                }
                // 如果导航栏未展开，拦截 Menu 按键，触发调出导航栏的逻辑
                else {
                    Logger.debug("Menu pressed - menu is hidden, triggering handleMenuPress")
                    handleMenuPress()
                    didHandlePress = true
                }
                
            case .playPause:
                // 处理 Play/Pause 按键（保持原有功能）
                if let reloadVC = topMostViewController() as? BLTabBarContentVCProtocol {
                    Logger.debug("PlayPause pressed - reloading: \(reloadVC)")
                    reloadVC.reloadData()
                    didHandlePress = true
                }
                
            default:
                break
            }
        }
        
        // 如果没有处理任何按键，传递给 super
        if !didHandlePress {
            super.pressesEnded(presses, with: event)
        }
    }
    
    // MARK: - Enhanced Visual Effects
    
    /// Adds ambient glow effect behind menu for enhanced depth perception
    private func addAmbientGlowToMenu() {
        // Create a subtle radial gradient glow
        let glowLayer = CAGradientLayer()
        glowLayer.type = .radial
        glowLayer.colors = [
            UIColor.luminousPink.withAlphaComponent(0.08).cgColor,
            UIColor.luminousPink.withAlphaComponent(0.04).cgColor,
            UIColor.clear.cgColor
        ]
        glowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        glowLayer.endPoint = CGPoint(x: 1.5, y: 1.5)
        glowLayer.frame = CGRect(x: -100, y: -100, width: 600, height: 1200)
        glowLayer.opacity = 0.0
        
        // Insert behind menu view
        view.layer.insertSublayer(glowLayer, at: 0)
        
        // Store reference for animation
        glowLayer.name = "ambient-glow"
        
        // Initial fade in
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            CATransaction.begin()
            CATransaction.setAnimationDuration(1.0)
            glowLayer.opacity = 1.0
            CATransaction.commit()
        }
    }
    
    /// Updates ambient glow intensity based on menu state
    private func updateAmbientGlow(isExpanded: Bool) {
        guard let glowLayer = view.layer.sublayers?.first(where: { $0.name == "ambient-glow" }) as? CAGradientLayer else {
            return
        }
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(AnimationDuration.smooth.rawValue)
        glowLayer.opacity = isExpanded ? 1.0 : 0.5
        CATransaction.commit()
    }
    
    /// Handles memory warning by reducing visual effects temporarily
    private func handleMemoryWarning() {
        Logger.info("Memory warning received - optimizing visual effects")
        
        // Temporarily reduce ambient glow opacity
        if let glowLayer = view.layer.sublayers?.first(where: { $0.name == "ambient-glow" }) as? CAGradientLayer {
            glowLayer.opacity = 0.3
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self else { return }
            if let glowLayer = self.view.layer.sublayers?.first(where: { $0.name == "ambient-glow" }) as? CAGradientLayer {
                glowLayer.opacity = self.menuIsShowing ? 1.0 : 0.5
            }
        }
    }
}

extension MenusViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! BLMenuLineCollectionViewCell
        cell.titleLabel.text = cellModels[indexPath.item].title
        if let icon = cellModels[indexPath.item].iconImage {
            cell.iconImageView.image = icon
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cellModels.count
    }
}

extension MenusViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let model = cellModels[indexPath.item]
        if let vc = model.contentVC {
            setViewController(vc: vc)
        }
        selectMenuItem = model
        model.action?()
    }

    func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        // 检查新的焦点是否是UICollectionViewCell，失去焦点后隐藏菜单
        guard context.nextFocusedIndexPath != nil else {
            hiddenMenus()
            return
        }
    }
}
