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

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Logger.setup()
        AVInfoPanelCollectionViewThumbnailCellHook.start()
        CookieHandler.shared.restoreCookies()
        BiliBiliUpnpDMR.shared.start()
        URLSession.shared.configuration.headers.add(.userAgent("BiLiBiLi AppleTV Client/1.0.0 (github/yichengchen/ATV-Bilibili-live-demo)"))

        // Performance Optimization: Start performance monitoring for adaptive quality
        BLPremiumPerformanceMonitor.shared.startMonitoring()
        Logger.debug("[Performance] Performance monitoring started")

        // {{CHENGQI:
        // Action: Added
        // Timestamp: 2025-10-06 08:00:00 +08:00
        // Reason: 内存占用 300MB+ 超标，添加内存警告监听器
        // Principle_Applied: Resource Management - 响应系统内存压力
        // Optimization: 清除缓存、降级质量、防止 SIGTERM
        // }}
        // Memory warning observer
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            Logger.warn("[Memory] ⚠️ MEMORY WARNING - Emergency cleanup initiated!")

            // Get current state
            let memory = BLPremiumPerformanceMonitor.shared.memoryUsage
            let quality = BLPremiumPerformanceMonitor.shared.currentQualityLevel
            Logger.warn("[Memory] Before cleanup: \(memory)MB, Quality: \(quality)")

            // Emergency actions
            BLShadowRenderer.clearAllCaches()
            BLPremiumPerformanceMonitor.shared.setQualityLevel(.minimal)

            // Log after cleanup
            let newMemory = BLPremiumPerformanceMonitor.shared.memoryUsage
            Logger.warn("[Memory] After cleanup: \(newMemory)MB, Quality: minimal")
        }

        window = UIWindow()
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

    func applicationDidBecomeActive(_: UIApplication) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
    }

    func showLogin() {
        window?.rootViewController = LoginViewController.create()
    }

    func showTabBar() {
        window?.rootViewController = BLTabBarViewController()
    }

    static var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
}
