//
//  DebugPlugin.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/25.
//

import AVKit
import UIKit

class DebugPlugin: NSObject, CommonPlayerPlugin {
    private var debugView: UILabel?
    private var glassBackgroundView: UIView?  // 保存glass背景引用以便清理
    private weak var containerView: UIView?
    private var debugTimer: Timer?
    private weak var player: AVPlayer?
    private var debugEnable: Bool { debugTimer?.isValid ?? false }

    var customInfo: String = ""
    var additionDebugInfo: (() -> String)?

    func addViewToPlayerOverlay(container: UIView) {
        containerView = container
    }

    func playerDidChange(player: AVPlayer) {
        self.player = player
    }

    func addMenuItems(current: inout [UIMenuElement]) -> [UIMenuElement] {
        let debugEnableImage = UIImage(systemName: "terminal.fill")
        let debugDisableImage = UIImage(systemName: "terminal")
        let debugAction = UIAction(title: "Debug", image: debugEnable ? debugEnableImage : debugDisableImage) {
            [weak self] action in
            guard let self = self else { return }
            if self.debugEnable {
                self.stopDebug()
                action.image = debugDisableImage
            } else {
                action.image = debugEnableImage
                self.startDebug()
            }
        }
        if let setting = current.compactMap({ $0 as? UIMenu })
            .first(where: { $0.identifier == UIMenu.Identifier(rawValue: "setting") })
        {
            var child = setting.children
            child.append(debugAction)
            if let index = current.firstIndex(of: setting) {
                current[index] = setting.replacingChildren(child)
            }
            return []
        }
        return [debugAction]
    }

    deinit {
        debugTimer?.invalidate()
    }

    private func startDebug() {
        if debugView == nil {
            debugView = UILabel()
            
            // tvOS 26 Liquid Glass 背景优化
            if #available(tvOS 26.0, *), ThemeManager.shared.supportsLiquidGlass {
                // 使用 Liquid Glass 作为调试信息背景
                let glassBackground = LiquidGlassView.popup(
                    tintColor: UIColor.black.withAlphaComponent(0.5)
                )
                glassBackgroundView = glassBackground  // 保存引用
                containerView?.addSubview(glassBackground)
                glassBackground.snp.makeConstraints { make in
                    make.top.equalToSuperview().offset(12)
                    make.right.equalToSuperview().offset(-12)
                    make.width.equalTo(800)
                }
                
                // 将 label 放在 glass 视图的 contentView 上
                glassBackground.contentView.addSubview(debugView!)
                debugView?.snp.makeConstraints { make in
                    make.edges.equalToSuperview().inset(12)
                }
                
                // materialize 动画
                glassBackground.materialize(duration: 0.3)
            } else {
                // 降级方案：传统背景
                debugView?.backgroundColor = UIColor.black.withAlphaComponent(0.8)
                containerView?.addSubview(debugView!)
                debugView?.snp.makeConstraints { make in
                    make.top.equalToSuperview().offset(12)
                    make.right.equalToSuperview().offset(-12)
                    make.width.equalTo(800)
                }
            }
            
            debugView?.textColor = UIColor.white
            debugView?.numberOfLines = 0
            debugView?.font = UIFont.systemFont(ofSize: 26)
        }
        debugView?.isHidden = false
        glassBackgroundView?.isHidden = false  // 显示glass背景
        debugTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            let info = self?.fetchDebugInfo()
            self?.debugView?.text = info
        }
    }

    private func stopDebug() {
        debugTimer?.invalidate()
        debugTimer = nil
        debugView?.isHidden = true
        
        // 修复：隐藏或移除glass背景视图
        if #available(tvOS 26.0, *), ThemeManager.shared.supportsLiquidGlass {
            if let glassView = glassBackgroundView as? LiquidGlassView {
                // 使用 dematerialize 动画优雅地隐藏
                glassView.dematerialize(duration: 0.3)
                // 在动画后延迟清理
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.glassBackgroundView?.removeFromSuperview()
                    self?.glassBackgroundView = nil
                    self?.debugView?.removeFromSuperview()
                    self?.debugView = nil
                }
            } else {
                glassBackgroundView?.removeFromSuperview()
                glassBackgroundView = nil
                debugView?.removeFromSuperview()
                debugView = nil
            }
        } else {
            // 传统背景直接移除
            glassBackgroundView?.isHidden = true
        }
    }

    private func fetchDebugInfo() -> String {
        let bitrateStr: (Double) -> String = {
            bit in
            String(format: "%.2fMbps", bit / 1024.0 / 1024.0)
        }
        guard let player else { return "Player no init" }

        var logs = """
        time control status: \(player.timeControlStatus.rawValue) \(player.reasonForWaitingToPlay?.rawValue ?? "")
        player status:\(player.status.rawValue)
        """

        guard let log = player.currentItem?.accessLog() else { return logs }
        guard let item = log.events.last else { return logs }
        let uri = item.uri ?? ""
        let addr = item.serverAddress ?? ""
        let changes = item.numberOfServerAddressChanges
        let dropped = item.numberOfDroppedVideoFrames
        let stalls = item.numberOfStalls
        let averageAudioBitrate = item.averageAudioBitrate
        let averageVideoBitrate = item.averageVideoBitrate
        let indicatedBitrate = item.indicatedBitrate
        let observedBitrate = item.observedBitrate
        
        // 获取音频信息
        var audioInfo = ""
        if let tracks = player.currentItem?.tracks {
            for track in tracks where track.assetTrack?.mediaType == .audio {
                if let assetTrack = track.assetTrack {
                    let formatDescriptions = assetTrack.formatDescriptions as! [CMFormatDescription]
                    if let audioDesc = formatDescriptions.first,
                       let basicDesc = CMAudioFormatDescriptionGetStreamBasicDescription(audioDesc) {
                        let channels = basicDesc.pointee.mChannelsPerFrame
                        let sampleRate = basicDesc.pointee.mSampleRate
                        audioInfo = "Audio: \(channels)ch, \(Int(sampleRate))Hz"
                        break // 只需要第一个音频轨道信息
                    }
                }
            }
        }
        
        logs += """
        uri:\(uri), ip:\(addr), change:\(changes)
        drop:\(dropped) stalls:\(stalls)
        bitrate audio:\(bitrateStr(averageAudioBitrate)), video: \(bitrateStr(averageVideoBitrate))
        observedBitrate:\(bitrateStr(observedBitrate))
        indicatedAverageBitrate:\(bitrateStr(indicatedBitrate))
        \(audioInfo)
        """

        if let additionDebugInfo = additionDebugInfo?() {
            logs = additionDebugInfo + "\n" + logs
        }
        if customInfo.isEmpty == false {
            logs = logs + "\n" + customInfo
        }
        return logs
    }
}
