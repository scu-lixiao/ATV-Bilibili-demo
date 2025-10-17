//
//  AppDelegate.swift
//  BilibiliLive
//
//  Created by Etan on 2021/3/27.
//

import AVFoundation
import CocoaLumberjackSwift
import Kingfisher
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

        // {{CHENGQI:
        // Action: Added
        // Timestamp: 2025-10-06 08:05:00 +08:00
        // Reason: 内存占用 313MB 主要来自 Kingfisher 图片缓存，需要限制
        // Principle_Applied: Resource Management - 平衡图片质量和内存占用
        // Optimization: Memory 100MB→50MB, Disk 250MB 保持，Count 100→50
        // }}
        // {{CHENGQI:
        // Action: Modified
        // Timestamp: 2025-10-17 08:07:30 +08:00
        // Reason: Phase 1 内存优化 - 进一步压缩内存缓存限制
        // Principle_Applied: Resource Management - 平衡缓存命中率和内存占用
        // Optimization: Memory 30MB→20MB, Count 30→25 (预期减少 10MB)
        // }}
        // Configure Kingfisher memory limits - Ultra-aggressive optimization
        let cache = ImageCache.default
        cache.memoryStorage.config.totalCostLimit = 20 * 1024 * 1024 // 20MB (Phase 1 optimization)
        cache.memoryStorage.config.countLimit = 25 // 25 images (Phase 1 optimization)
        cache.diskStorage.config.sizeLimit = 250 * 1024 * 1024 // 250MB disk cache
        Logger.debug("[Performance] Kingfisher cache limits: Memory 20MB, Disk 250MB, Count 25")

        // Performance Optimization: Start performance monitoring for adaptive quality
        BLPremiumPerformanceMonitor.shared.startMonitoring()
        Logger.debug("[Performance] Performance monitoring started")

        // {{CHENGQI:
        // Action: Added
        // Timestamp: 2025-10-17 08:09:00 +08:00
        // Reason: Phase 3 内存优化 - 启动主动内存压力监控
        // Principle_Applied: Proactive Management - 在系统 warning 前主动清理
        // Optimization: 每 3 秒检查内存,分级清理 (150MB/180MB/200MB)
        // }}
        // Memory Pressure Monitoring: Proactive cleanup before system warnings
        BLMemoryPressureManager.shared.startMonitoring()
        Logger.debug("[Performance] Memory pressure monitoring started")

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
            ImageCache.default.clearMemoryCache() // Clear Kingfisher memory cache
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
