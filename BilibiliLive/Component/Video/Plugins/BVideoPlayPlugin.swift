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

    /// 当前播放资源实际生效的传输模式（创建资源时按设置快照，中途改设置只影响下一次播放）
    private var transportMode: MediaTransportMode = .direct
    /// 加速传输出问题时只回退一次直连，避免反复重建
    private var didRecoverToDirect = false
    /// 回退直连后新播放器起播的位置（覆盖 playerStartPos）
    private var resumeTime: TimeInterval?
    /// 加速模式下的卡顿看门狗：持续等待缓冲超过 acceleratedStallTimeout 秒即回退直连。
    /// 代理整体失败时 AVPlayer 不会报错，只会一直缓冲；下载器内部的换源与竞速都在这之前完成，
    /// 回退直连本身没有副作用，因此阈值比上游的 60 秒短
    private var stallWatchdog: Timer?
    private var waitingSince: TimeInterval?
    private let acceleratedStallTimeout: TimeInterval = 20

    init(detailData: PlayerDetailData) {
        playData = detailData
    }

    /// 供 DebugPlugin 显示的传输诊断
    var networkDebugInfo: String {
        guard let playerDelegate, playerDelegate.effectiveTransportMode != .direct else { return "" }
        let accel = playerDelegate.accelerationDebugInfo
        return accel.isEmpty ? "[cdn] \(playerDelegate.effectiveTransportMode)" : accel
    }

    func playerDidLoad(playerVC: AVPlayerViewController) {
        self.playerVC = playerVC
        playerVC.player = nil
        let transportMode: MediaTransportMode = Settings.multiCDNEnabled ? .accelerated : .direct
        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await playmedia(urlInfo: playData.videoPlayURLInfo, playerInfo: playData.playerInfo, transportMode: transportMode)
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
        stopStallWatchdog()
        if let event = playerVC.player?.currentItem?.accessLog()?.events.last {
            Logger.debug("[player] last variant: \(event.uri ?? ""), dropped frames: \(event.numberOfDroppedVideoFrames), stalls: \(event.numberOfStalls)")
        }
    }

    func playerWillStart(player: AVPlayer) {
        if let startTime = resumeTime ?? playData.playerStartPos.map({ TimeInterval($0) }) {
            player.seek(to: CMTime(seconds: startTime, preferredTimescale: 1), toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    func playerDidFail(player: AVPlayer) {
        guard transportMode == .accelerated else { return }
        Logger.warn("[cdn] accelerated playback failed: \(String(describing: player.currentItem?.error))")
        recoverAcceleratedToDirect()
    }

    func playerDidDismiss(playerVC: AVPlayerViewController) {
        stopStallWatchdog()
        HDRDisplaySwitcher.reset(on: (playerVC.viewIfLoaded?.window ?? AppDelegate.shared.window)?.avDisplayManager)
        guard let currentTime = playerVC.player?.currentTime().seconds, currentTime > 0 else { return }
        WebRequest.reportWatchHistory(aid: playData.aid, cid: playData.cid, currentTime: Int(currentTime), epid: playData.epid, seasonId: playData.seasonId, subType: playData.subType)
    }

    /// - Parameter isRecovery: 加速传输回退直连时重建播放资源，沿用当前的显示模式
    @MainActor
    private func playmedia(urlInfo: VideoPlayURLInfo, playerInfo: PlayerInfo?, transportMode: MediaTransportMode, isRecovery: Bool = false) async throws {
        let playURL = URL(string: BilibiliVideoResourceLoaderDelegate.URLs.play)!
        let headers: [String: String] = [
            "User-Agent": Keys.userAgent,
            "Referer": Keys.referer(for: playData.aid),
        ]
        let asset = AVURLAsset(url: playURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let playerDelegate = BilibiliVideoResourceLoaderDelegate()
        // 会先下载并解析 HDR / 杜比视界流的初始化分段，以生成准确的 CODECS 与 VIDEO-RANGE
        await playerDelegate.setBilibili(info: urlInfo, subtitles: playerInfo?.subtitle?.subtitles ?? [], aid: playData.aid, transportMode: transportMode)
        try Task.checkCancellation()
        self.playerDelegate = playerDelegate
        // 本地代理启动失败时播放列表已回退直连，按直连处理
        self.transportMode = playerDelegate.effectiveTransportMode

        if !isRecovery {
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
        }

        asset.resourceLoader.setDelegate(playerDelegate, queue: DispatchQueue(label: "loader"))
        let playable = try await asset.load(.isPlayable)
        if !playable {
            throw "加载资源失败"
        }
        try Task.checkCancellation()
        await prepare(toPlay: asset)
        if self.transportMode == .accelerated {
            startStallWatchdog()
        }
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

// MARK: - 多 CDN 加速的回退

private extension BVideoPlayPlugin {
    /// 下载器内部已经做了 CDN 调度、竞速与重试；这里只兜底「整体不可恢复」：
    /// 播放失败，或持续等待缓冲超过 acceleratedStallTimeout（用户暂停时是 .paused，不会计时）
    func startStallWatchdog() {
        stopStallWatchdog()
        stallWatchdog = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.checkStall()
        }
    }

    func stopStallWatchdog() {
        stallWatchdog?.invalidate()
        stallWatchdog = nil
        waitingSince = nil
    }

    func checkStall() {
        guard transportMode == .accelerated,
              playerVC?.player?.timeControlStatus == .waitingToPlayAtSpecifiedRate
        else {
            waitingSince = nil
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        guard let waitingSince else {
            self.waitingSince = now
            return
        }
        if now - waitingSince >= acceleratedStallTimeout {
            Logger.warn("[cdn] accelerated playback waiting for \(Int(now - waitingSince))s")
            recoverAcceleratedToDirect()
        }
    }

    /// 用直连重建播放资源，并回到当前进度继续播放
    func recoverAcceleratedToDirect() {
        guard transportMode == .accelerated, !didRecoverToDirect, let player = playerVC?.player else { return }
        didRecoverToDirect = true
        stopStallWatchdog()
        let currentTime = player.currentTime().seconds
        if currentTime.isFinite, currentTime > 0 {
            resumeTime = currentTime
        }
        player.pause()
        Logger.info("[cdn] fall back to direct CDN at \(resumeTime ?? 0)s")

        loadTask?.cancel()
        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await playmedia(urlInfo: playData.videoPlayURLInfo, playerInfo: playData.playerInfo, transportMode: .direct, isRecovery: true)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                Logger.warn("[cdn] fall back to direct failed: \(error)")
                (self.playerVC?.parent as? CommonPlayerViewController)?.showErrorAlertAndExit(message: String(describing: error))
            }
        }
    }
}
