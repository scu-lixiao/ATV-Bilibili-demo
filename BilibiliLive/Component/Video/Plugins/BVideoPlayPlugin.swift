//
//  BVideoPlayPlugin.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/24.
//

import AVKit

class BVideoPlayPlugin: NSObject, CommonPlayerPlugin {
    private weak var playerVC: AVPlayerViewController?
    private var playerDelegate: BilibiliVideoResourceLoaderDelegate?
    private let playData: PlayerDetailData
    
    // 暴露视频源 URL 信息供其他插件访问（如 DebugPlugin）
    var currentVideoURLInfo: String {
        guard let playerDelegate = playerDelegate else {
            return "Video URL: Not loaded"
        }
        
        var urlInfo = ""
        if let playInfo = playerDelegate.playInfo {
            // 获取视频和音频的 URL 信息
            if let videoURL = playInfo.dash.video.first?.base_url {
                urlInfo += "Video URL: \(videoURL)\n"
            }
            if let audioURL = playInfo.dash.audio?.first?.base_url {
                urlInfo += "Audio URL: \(audioURL)\n"
            }
            
            // 添加 HDR 信息
            if playerDelegate.isHDR {
                urlInfo += "🎨 HDR/Dolby Vision Enabled\n"
            }
        }
        
        // 添加其他调试信息
        urlInfo += playerDelegate.infoDebugText
        
        return urlInfo
    }

    init(detailData: PlayerDetailData) {
        playData = detailData
    }

    func playerDidLoad(playerVC: AVPlayerViewController) {
        self.playerVC = playerVC
        playerVC.player = nil
        playerVC.appliesPreferredDisplayCriteriaAutomatically = Settings.contentMatch
        Task {
            try? await playmedia(urlInfo: playData.videoPlayURLInfo, playerInfo: playData.playerInfo)
        }
    }

    func playerWillStart(player: AVPlayer) {
        if let playerStartPos = playData.playerStartPos {
            player.seek(to: CMTime(seconds: Double(playerStartPos), preferredTimescale: 1), toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    func playerDidDismiss(playerVC: AVPlayerViewController) {
        guard let currentTime = playerVC.player?.currentTime().seconds, currentTime > 0 else { return }
        WebRequest.reportWatchHistory(aid: playData.aid, cid: playData.cid, currentTime: Int(currentTime))
    }

    @MainActor
    private func playmedia(urlInfo: VideoPlayURLInfo, playerInfo: PlayerInfo?) async throws {
        let playURL = URL(string: BilibiliVideoResourceLoaderDelegate.URLs.play)!
        let headers: [String: String] = [
            "User-Agent": Keys.userAgent,
            "Referer": Keys.referer(for: playData.aid),
        ]
        let asset = AVURLAsset(url: playURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        playerDelegate = BilibiliVideoResourceLoaderDelegate()
        playerDelegate?.setBilibili(info: urlInfo, subtitles: playerInfo?.subtitle?.subtitles ?? [], aid: playData.aid)
        if Settings.contentMatchOnlyInHDR {
            if playerDelegate?.isHDR != true {
                playerVC?.appliesPreferredDisplayCriteriaAutomatically = false
            }
        }
        asset.resourceLoader.setDelegate(playerDelegate, queue: DispatchQueue(label: "loader"))
        let playable = try await asset.load(.isPlayable)
        if !playable {
            throw "加载资源失败"
        }
        await prepare(toPlay: asset)
    }

    @MainActor
    func prepare(toPlay asset: AVURLAsset) async {
        let playerItem = AVPlayerItem(asset: asset)
        
        // tvOS 26 性能优化：减少缓冲区大小以降低网络负载
        // 参考：https://medium.com/@sojik/avplayer-video-optimization-part-1-2a45ea002ea2
        playerItem.preferredForwardBufferDuration = TimeInterval(1.0)
        
        // 暂停时不使用网络资源，节省带宽
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = false
        
        let player = AVPlayer(playerItem: playerItem)
        playerVC?.player = player
    }
}
