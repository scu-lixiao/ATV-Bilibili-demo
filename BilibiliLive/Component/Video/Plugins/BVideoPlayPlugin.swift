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
    private var loadTask: Task<Void, Never>?

    init(detailData: PlayerDetailData) {
        playData = detailData
    }

    func playerDidLoad(playerVC: AVPlayerViewController) {
        self.playerVC = playerVC
        playerVC.player = nil
        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await playmedia(urlInfo: playData.videoPlayURLInfo, playerInfo: playData.playerInfo)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                Logger.warn("[player] prepare media failed: \(error)")
                (self.playerVC?.parent as? CommonPlayerViewController)?.showErrorAlertAndExit(message: String(describing: error))
            }
        }
    }

    func playerWillCleanUp(playerVC: AVPlayerViewController) {
        // 起播前要先探测 sidx / HDR 格式，期间退出播放时取消，避免之后再创建 AVPlayer 在后台出声
        loadTask?.cancel()
        loadTask = nil
        if let event = playerVC.player?.currentItem?.accessLog()?.events.last {
            Logger.debug("[player] last variant: \(event.uri ?? ""), dropped frames: \(event.numberOfDroppedVideoFrames), stalls: \(event.numberOfStalls)")
        }
    }

    func playerWillStart(player: AVPlayer) {
        if let playerStartPos = playData.playerStartPos {
            player.seek(to: CMTime(seconds: Double(playerStartPos), preferredTimescale: 1), toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    func playerDidDismiss(playerVC: AVPlayerViewController) {
        HDRDisplaySwitcher.reset(on: (playerVC.viewIfLoaded?.window ?? AppDelegate.shared.window)?.avDisplayManager)
        guard let currentTime = playerVC.player?.currentTime().seconds, currentTime > 0 else { return }
        WebRequest.reportWatchHistory(aid: playData.aid, cid: playData.cid, currentTime: Int(currentTime), epid: playData.epid, seasonId: playData.seasonId, subType: playData.subType)
    }

    @MainActor
    private func playmedia(urlInfo: VideoPlayURLInfo, playerInfo: PlayerInfo?) async throws {
        let playURL = URL(string: BilibiliVideoResourceLoaderDelegate.URLs.play)!
        let headers: [String: String] = [
            "User-Agent": Keys.userAgent,
            "Referer": Keys.referer(for: playData.aid),
        ]
        let asset = AVURLAsset(url: playURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let playerDelegate = BilibiliVideoResourceLoaderDelegate()
        self.playerDelegate = playerDelegate
        // 会先下载并解析 HDR / 杜比视界流的初始化分段，以生成准确的 CODECS 与 VIDEO-RANGE
        await playerDelegate.setBilibili(info: urlInfo, subtitles: playerInfo?.subtitle?.subtitles ?? [], aid: playData.aid)
        try Task.checkCancellation()

        // HDR / 杜比视界视频在创建 AVPlayerItem 之前自行切换显示模式，否则 AVPlayer 会在 SDR 模式下选定 SDR 档位（见 HDRDisplaySwitcher）；
        // 其余视频交给 AVKit 按内容匹配，可设置为仅 HDR 视频匹配
        let displayManager = (playerVC?.viewIfLoaded?.window ?? AppDelegate.shared.window)?.avDisplayManager
        let hdrCriteria = Settings.contentMatch && displayManager?.isDisplayCriteriaMatchingEnabled == true ? playerDelegate.hdrDisplayCriteria : nil
        playerVC?.appliesPreferredDisplayCriteriaAutomatically = hdrCriteria == nil && Settings.contentMatch
            && (playerDelegate.isHDR || !Settings.contentMatchOnlyInHDR)
        if let hdrCriteria, let displayManager {
            try await HDRDisplaySwitcher.apply(hdrCriteria, on: displayManager)
        } else {
            // 连播时还原上一个 HDR 视频设置的显示模式
            HDRDisplaySwitcher.reset(on: displayManager)
        }
        try Task.checkCancellation()

        asset.resourceLoader.setDelegate(playerDelegate, queue: DispatchQueue(label: "loader"))
        let playable = try await asset.load(.isPlayable)
        if !playable {
            throw "加载资源失败"
        }
        try Task.checkCancellation()
        await prepare(toPlay: asset)
    }

    @MainActor
    func prepare(toPlay asset: AVURLAsset) async {
        let playerItem = AVPlayerItem(asset: asset)
        NotificationCenter.default.addObserver(self, selector: #selector(accessLogDidUpdate(_:)), name: .AVPlayerItemNewAccessLogEntry, object: playerItem)
        let player = AVPlayer(playerItem: playerItem)
        playerVC?.player = player
    }

    /// AVPlayer 每切换一次档位新增一条 access log，记录实际播放的档位，用于确认是否播放了 HDR 档位
    @objc private func accessLogDidUpdate(_ notification: Notification) {
        guard let event = (notification.object as? AVPlayerItem)?.accessLog()?.events.last, let uri = event.uri else { return }
        Logger.debug("[player] playing variant: \(uri), indicated bitrate: \(Int(event.indicatedBitrate))")
    }
}
