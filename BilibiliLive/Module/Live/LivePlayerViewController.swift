//
//  LivePlayerViewController.swift
//  BilibiliLive
//
//  Created by Etan on 2021/3/27.
//

import Alamofire
import AVKit
import Foundation
import SwiftyJSON
import UIKit

class LivePlayerViewController: CommonPlayerViewController {
    var room: LiveRoom?

    private var viewModel: LivePlayerViewModel?
    deinit {
        Logger.debug("deinit live player")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // tvOS 26 Liquid Glass 直播间背景优化
        setupLiquidGlassLiveRoomBackground()

        viewModel = LivePlayerViewModel(room: room!)
        viewModel?.onPluginReady = { [weak self] plugins in
            DispatchQueue.main.async {
                plugins.forEach { self?.addPlugin(plugin: $0) }
            }
        }

        viewModel?.onError = { [weak self] in
            self?.showErrorAlertAndExit(message: $0)
        }

        viewModel?.start()
    }
    
    /// 配置 Liquid Glass 直播间背景（tvOS 26 优化）
    private func setupLiquidGlassLiveRoomBackground() {
        if #available(tvOS 26.0, *), ThemeManager.shared.supportsLiquidGlass {
            // 直播间使用动态氛围的 glass 效果
            applyLiveRoomGlassBackground()
        } else {
            // 降级方案：深邃黑色背景
            view.backgroundColor = ThemeManager.shared.backgroundColor
        }
    }
}
