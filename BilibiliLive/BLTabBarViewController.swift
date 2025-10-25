//
//  BLTabBarViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/5.
//

import UIKit

protocol BLTabBarContentVCProtocol {
    func reloadData()
}

let selectedIndexKey = "BLTabBarViewController.selectedIndex"

class BLTabBarViewController: UITabBarController, UITabBarControllerDelegate {
    static func clearSelected() {
        UserDefaults.standard.removeObject(forKey: selectedIndexKey)
    }

    deinit {
        print("BLTabBarViewController deinit")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self

        // 应用 tvOS 26 深邃暗黑主题
        setupDarkTheme()

        var vcs = [UIViewController]()

        let liveVC = LiveViewController()
        liveVC.tabBarItem.title = "直播"
        vcs.append(liveVC)

        let feedVC = FeedViewController()
        feedVC.tabBarItem.title = "推荐"
        vcs.append(feedVC)

        let hotVC = HotViewController()
        hotVC.tabBarItem.title = "热门"
        vcs.append(hotVC)

        let rank = RankingViewController()
        rank.tabBarItem.title = "排行榜"
        vcs.append(rank)

        let followVC = FollowsViewController()
        followVC.tabBarItem.title = "关注"
        vcs.append(followVC)

        let fav = FavoriteViewController()
        fav.tabBarItem.title = "收藏"
        vcs.append(fav)

        let persionVC = PersonalViewController.create()
        persionVC.extendedLayoutIncludesOpaqueBars = true
        persionVC.tabBarItem.title = "我的"
        vcs.append(persionVC)

        setViewControllers(vcs, animated: false)
        selectedIndex = UserDefaults.standard.integer(forKey: selectedIndexKey)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)
        guard let buttonPress = presses.first?.type else { return }
        if buttonPress == .playPause {
            if let reloadVC = topMostViewController() as? BLTabBarContentVCProtocol {
                print("send reload to \(reloadVC)")
                reloadVC.reloadData()
            }
        }
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        UserDefaults.standard.set(tabBarController.selectedIndex, forKey: selectedIndexKey)
    }

    // MARK: - Theme Setup

    private func setupDarkTheme() {
        // 应用深邃纯黑背景
        view.backgroundColor = ThemeManager.shared.backgroundColor

        // 配置 Tab Bar 外观
        configureTabBarAppearance()

        // 为所有 ViewController 设置深邃背景
        applyBackgroundToAllTabs()
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()

        // 背景配置 - 使用 Liquid Glass 或深色背景
        if #available(tvOS 26.0, *), ThemeManager.shared.supportsLiquidGlass {
            // tvOS 26: 使用 Liquid Glass 效果
            let glassEffect = ThemeManager.shared.createEffect(style: .surface)
            appearance.backgroundEffect = glassEffect as? UIBlurEffect
        } else {
            // 降级: 使用深邃纯黑背景
            appearance.backgroundColor = ThemeManager.shared.surfaceColor
        }

        // 文本颜色配置
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: ThemeManager.shared.textSecondaryColor,
            .font: UIFont.systemFont(ofSize: 29, weight: .medium),
        ]

        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: ThemeManager.shared.accentColor,
            .font: UIFont.systemFont(ofSize: 29, weight: .semibold),
        ]

        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes
        appearance.stackedLayoutAppearance.focused.titleTextAttributes = selectedAttributes

        // 应用外观
        tabBar.standardAppearance = appearance
        if #available(tvOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }

        // 设置 Tab Bar 色调
        tabBar.tintColor = ThemeManager.shared.accentColor
        tabBar.unselectedItemTintColor = ThemeManager.shared.textSecondaryColor
    }

    private func applyBackgroundToAllTabs() {
        // 为每个 tab 的根视图控制器应用深邃背景
        viewControllers?.forEach { vc in
            vc.view.backgroundColor = ThemeManager.shared.backgroundColor
        }
    }
}
