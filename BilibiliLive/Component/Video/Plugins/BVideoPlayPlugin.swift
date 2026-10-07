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
        playerVC.appliesPreferredDisplayCriteriaAutomatically = Settings.contentMatch
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
        let playerDelegate = BilibiliVideoResourceLoaderDelegate()
        self.playerDelegate = playerDelegate
        // 会先下载并解析 HDR / 杜比视界流的初始化分段，以生成准确的 CODECS 与 VIDEO-RANGE
        await playerDelegate.setBilibili(info: urlInfo, subtitles: playerInfo?.subtitle?.subtitles ?? [], aid: playData.aid)
        try Task.checkCancellation()
        if Settings.contentMatchOnlyInHDR {
            if !playerDelegate.isHDR {
                playerVC?.appliesPreferredDisplayCriteriaAutomatically = false
            }
        }
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
        let player = AVPlayer(playerItem: playerItem)
        playerVC?.player = player
    }
}
