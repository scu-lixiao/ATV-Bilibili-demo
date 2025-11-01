//
//  AppDelegate.swift
//  BilibiliLive
//
//  Created by Etan on 2021/3/27.
//

import AVFoundation
import CocoaLumberjackSwift
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Logger.setup()
        AVInfoPanelCollectionViewThumbnailCellHook.start()
        AccountManager.shared.bootstrap()
        BiliBiliUpnpDMR.shared.start()
        URLSession.shared.configuration.headers.add(.userAgent("BiLiBiLi AppleTV Client/1.0.0 (github/yichengchen/ATV-Bilibili-live-demo)"))

        // 初始化窗口并应用深邃暗黑主题
        window = UIWindow()
        setupGlobalTheme()

        if ApiRequest.isLogin() {
            if let expireDate = ApiRequest.getToken()?.expireDate {
                let now = Date()
                if expireDate.timeIntervalSince(now) < 60 * 60 * 30 {
                    ApiRequest.refreshToken()
                }
            } else {
                ApiRequest.refreshToken()
            }
            window?.rootViewController = BLTabBarViewController()
        } else {
            window?.rootViewController = LoginViewController.create()
        }
        WebRequest.requestIndex()
        window?.makeKeyAndVisible()
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // 根据用户设置配置音频会话
        let enablePassthrough = Settings.audioPassthrough
        AudioSessionManager.shared.configureAudioSession(enablePassthrough: enablePassthrough)
    }

    func showLogin() {
        replaceRootViewController(with: LoginViewController.create(), animated: false)
    }

    func showTabBar() {
        replaceRootViewController(with: BLTabBarViewController(), animated: false)
    }

    func resetTabBar() {
        replaceRootViewController(with: BLTabBarViewController(), animated: true)
    }

    static var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    private func replaceRootViewController(with viewController: UIViewController, animated: Bool) {
        guard let window else { return }
        if animated, let snapshot = window.snapshotView(afterScreenUpdates: false) {
            window.rootViewController = viewController
            window.makeKeyAndVisible()
            viewController.view.addSubview(snapshot)
            UIView.animate(withDuration: 0.25, animations: {
                snapshot.alpha = 0
            }, completion: { _ in
                snapshot.removeFromSuperview()
            })
        } else {
            window.rootViewController = viewController
            window.makeKeyAndVisible()
        }
    }

    // MARK: - Theme Setup

    private func setupGlobalTheme() {
        guard let window = window else { return }

        // 应用深邃纯黑背景到窗口
        window.backgroundColor = ThemeManager.shared.backgroundColor

        // 配置全局外观
        configureGlobalAppearance()
    }

    private func configureGlobalAppearance() {
        // 全局色调 - 使用 Bilibili 品牌蓝
        window?.tintColor = ThemeManager.shared.accentColor

        // 配置导航栏外观
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundColor = ThemeManager.shared.surfaceColor.withAlphaComponent(0.95)
        navAppearance.titleTextAttributes = [
            .foregroundColor: ThemeManager.shared.textPrimaryColor,
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: ThemeManager.shared.textPrimaryColor,
        ]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
    }
}
