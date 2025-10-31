//
//  URLPlayPlugin.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/6/6.
//

import AVKit
import Foundation

class URLPlayPlugin: NSObject {
    var onPlayFail: (() -> Void)?

    private weak var playerVC: AVPlayerViewController?
    private let referer: String
    private let isLive: Bool
    private var currentUrl: String?

    init(referer: String = "", isLive: Bool = false) {
        self.referer = referer
        self.isLive = isLive
    }

    func play(urlString: String) {
        currentUrl = urlString
        let headers: [String: String] = [
            "User-Agent": Keys.userAgent,
            "Referer": referer,
        ]
        let asset = AVURLAsset(url: URL(string: urlString)!, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let playerItem = AVPlayerItem(asset: asset)
        
        // tvOS 26 性能优化：根据内容类型优化缓冲策略
        if !isLive {
            // 点播视频：减少前向缓冲以降低网络负载
            playerItem.preferredForwardBufferDuration = TimeInterval(1.0)
            playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = false
        }
        // 直播内容保持默认设置以确保流畅性
        
        let player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = !isLive
        playerVC?.player = player
    }
}

extension URLPlayPlugin: CommonPlayerPlugin {
    func playerDidLoad(playerVC: AVPlayerViewController) {
        self.playerVC = playerVC
        playerVC.requiresLinearPlayback = isLive
        playerVC.player = nil
        if let currentUrl {
            play(urlString: currentUrl)
        }
    }

    func playerDidFail(player: AVPlayer) {
        onPlayFail?()
    }

    func playerDidPause(player: AVPlayer) {
        if isLive {
            onPlayFail?()
        }
    }
}
