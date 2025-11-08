//
//  DebugPlugin.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/25.
//

import AVFoundation
import AVKit
import CoreMedia
import UIKit

class DebugPlugin: NSObject, CommonPlayerPlugin {
    private var debugView: UILabel?
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
        // Return Debug action as a top-level menu item, alongside "Danmu" and other items
        return [debugAction]
    }

    deinit {
        debugTimer?.invalidate()
    }

    private func startDebug() {
        if debugView == nil {
            debugView = UILabel()
            debugView?.backgroundColor = UIColor.black.withAlphaComponent(0.8)
            debugView?.textColor = UIColor.white
            containerView?.addSubview(debugView!)
            debugView?.numberOfLines = 0
            debugView?.font = UIFont.systemFont(ofSize: 26)
            debugView?.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(12)
                make.right.equalToSuperview().offset(-12)
                make.width.equalTo(800)
            }
        }
        debugView?.isHidden = false
        debugTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            let info = self?.fetchDebugInfo()
            self?.debugView?.text = info
        }
    }

    private func stopDebug() {
        debugTimer?.invalidate()
        debugTimer = nil
        debugView?.isHidden = true
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
        
        // Try to get video format info from access log URI first (more reliable for custom protocols)
        var videoFormatInfo: String?
        if let log = player.currentItem?.accessLog(),
           let item = log.events.last,
           let uri = item.uri, !uri.isEmpty, uri.contains("atv://dash") {
            // The actual playing URI contains codec info
            videoFormatInfo = extractVideoFormatFromURI(uri, playerItem: player.currentItem)
        }
        
        // Fallback to asset-based extraction
        if videoFormatInfo == nil {
            videoFormatInfo = extractVideoFormatInfo(from: player)
        }
        
        // Add UHD/HDR video format information
        if let videoFormatInfo = videoFormatInfo {
            logs += "\n" + videoFormatInfo
        }

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
        logs += """
        
        uri:\(uri), ip:\(addr), change:\(changes)
        drop:\(dropped) stalls:\(stalls)
        bitrate audio:\(bitrateStr(averageAudioBitrate)), video: \(bitrateStr(averageVideoBitrate))
        observedBitrate:\(bitrateStr(observedBitrate))
        indicatedAverageBitrate:\(bitrateStr(indicatedBitrate))
        """

        if let additionDebugInfo = additionDebugInfo?() {
            logs = additionDebugInfo + "\n" + logs
        }
        if customInfo.isEmpty == false {
            logs = logs + "\n" + customInfo
        }
        return logs
    }
    
    private func extractVideoFormatFromURI(_ uri: String, playerItem: AVPlayerItem?) -> String? {
        var formatInfo = [String]()
        
        // Get resolution from presentationSize if available
        if let presentationSize = playerItem?.presentationSize, presentationSize != .zero {
            let width = Int(presentationSize.width)
            let height = Int(presentationSize.height)
            let resolutionLabel = getResolutionLabel(height: height)
            formatInfo.append("📺 Video: \(width)x\(height) (\(resolutionLabel))")
        }
        
        // Extract codec from URI
        if let codecInfo = extractCodecFromURL(uri) {
            formatInfo.append("🎞️  Codec: \(codecInfo)")
        }
        
        // Extract frame rate from URI
        if let components = URLComponents(string: uri),
           let queryItems = components.queryItems,
           let rateParam = queryItems.first(where: { $0.name == "rate" })?.value {
            if let rate = Double(rateParam) {
                formatInfo.append("🎬 Frame Rate: \(String(format: "%.2f", rate))fps")
            }
        }
        
        // Infer HDR from codec
        if let hdrInfo = inferHDRFromURL(uri) {
            formatInfo.append(hdrInfo)
        }
        
        return formatInfo.isEmpty ? nil : formatInfo.joined(separator: "\n")
    }
    
    private func extractVideoFormatInfo(from player: AVPlayer) -> String? {
        guard let playerItem = player.currentItem else { return nil }
        let asset = playerItem.asset
        
        var formatInfo = [String]()
        
        // Debug: log asset type
        Logger.debug("DebugPlugin - Asset type: \(type(of: asset))")
        
        // Try to get URL first for URL-based extraction
        var assetURL: URL?
        if let urlAsset = asset as? AVURLAsset {
            assetURL = urlAsset.url
            Logger.debug("DebugPlugin - Asset URL: \(urlAsset.url.absoluteString)")
        }
        
        // Get video tracks - works for both AVURLAsset and AVAsset
        let videoTracks = asset.tracks(withMediaType: .video)
        Logger.debug("DebugPlugin - Video tracks count: \(videoTracks.count)")
        
        guard let videoTrack = videoTracks.first else { 
            // If no video track info available yet, try to get from presentationSize
            if playerItem.presentationSize != .zero {
                let size = playerItem.presentationSize
                let width = Int(size.width)
                let height = Int(size.height)
                let resolutionLabel = getResolutionLabel(height: height)
                formatInfo.append("📺 Video: \(width)x\(height) (\(resolutionLabel))")
                
                // Try URL extraction even without video track
                if let url = assetURL, url.scheme == "atv" {
                    if let codecInfo = extractCodecFromURL(url.absoluteString) {
                        formatInfo.append("🎞️  Codec: \(codecInfo)")
                    }
                    if let hdrInfo = inferHDRFromURL(url.absoluteString) {
                        formatInfo.append(hdrInfo)
                    }
                }
                
                return formatInfo.joined(separator: "\n")
            }
            return nil 
        }
        
        // Get video dimensions
        let size = videoTrack.naturalSize
        let width = Int(size.width)
        let height = Int(size.height)
        let resolutionLabel = getResolutionLabel(height: height)
        
        formatInfo.append("📺 Video: \(width)x\(height) (\(resolutionLabel))")
        
        // Get frame rate
        let frameRate = videoTrack.nominalFrameRate
        formatInfo.append("🎬 Frame Rate: \(String(format: "%.2f", frameRate))fps")
        
        // Try to get URL info first (always available for custom protocol)
        var foundCodecInfo = false
        var foundHDRInfo = false
        
        if let url = assetURL, url.scheme == "atv" {
            let urlString = url.absoluteString
            Logger.debug("DebugPlugin - Parsing URL: \(urlString)")
            // Parse codec from URL like: atv://dash/3?codec=hev1.1.6.L150.90&rate=50.000...
            if let codecInfo = extractCodecFromURL(urlString) {
                formatInfo.append("🎞️  Codec: \(codecInfo)")
                foundCodecInfo = true
                Logger.debug("DebugPlugin - Found codec: \(codecInfo)")
            } else {
                Logger.debug("DebugPlugin - Failed to extract codec from URL")
            }
            // Try to infer HDR from codec string
            if let hdrInfo = inferHDRFromURL(urlString) {
                formatInfo.append(hdrInfo)
                foundHDRInfo = true
                Logger.debug("DebugPlugin - Found HDR: \(hdrInfo)")
            } else {
                Logger.debug("DebugPlugin - Failed to infer HDR from URL")
            }
        }
        
        // Get format descriptions - more accurate but may not be available for custom protocols
        if !foundCodecInfo || !foundHDRInfo {
            let formatDescs = videoTrack.formatDescriptions as? [CMFormatDescription] ?? []
            Logger.debug("DebugPlugin - Format descriptions count: \(formatDescs.count)")
            
            if !formatDescs.isEmpty, let formatDescription = formatDescs.first {
                
                if !foundCodecInfo {
                    // Get codec information
                    let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
                    let codecString = formatCodecType(codecType)
                    formatInfo.append("🎞️  Codec: \(codecString)")
                    Logger.debug("DebugPlugin - Codec from formatDesc: \(codecString)")
                }
                
                // Get HDR and color space information
                if !foundHDRInfo, let hdrInfo = extractHDRInfo(from: formatDescription) {
                    formatInfo.append(hdrInfo)
                    Logger.debug("DebugPlugin - HDR from formatDesc: \(hdrInfo)")
                }
                
                if let colorInfo = extractColorSpaceInfo(from: formatDescription) {
                    formatInfo.append(colorInfo)
                    Logger.debug("DebugPlugin - Color space: \(colorInfo)")
                }
            }
        }
        
        // Get estimated data rate if available
        if #available(tvOS 14.0, *) {
            let estimatedDataRate = videoTrack.estimatedDataRate
            if estimatedDataRate > 0 {
                let mbps = estimatedDataRate / 1_000_000
                formatInfo.append("💾 Track Bitrate: \(String(format: "%.2f", mbps))Mbps")
            }
        }
        
        return formatInfo.joined(separator: "\n")
    }
    
    private func formatCodecType(_ codecType: CMVideoCodecType) -> String {
        switch codecType {
        case kCMVideoCodecType_H264:
            return "H.264 (AVC)"
        case kCMVideoCodecType_HEVC:
            return "H.265 (HEVC)"
        case kCMVideoCodecType_HEVCWithAlpha:
            return "HEVC with Alpha"
        case kCMVideoCodecType_DolbyVisionHEVC:
            return "Dolby Vision HEVC"
        case kCMVideoCodecType_VP9:
            return "VP9"
        case kCMVideoCodecType_AV1:
            return "AV1"
        default:
            let fourCC = String(format: "%c%c%c%c",
                              (codecType >> 24) & 0xff,
                              (codecType >> 16) & 0xff,
                              (codecType >> 8) & 0xff,
                              codecType & 0xff)
            return fourCC
        }
    }
    
    private func extractHDRInfo(from formatDescription: CMFormatDescription) -> String? {
        // Check for HDR transfer function
        guard let extensions = CMFormatDescriptionGetExtensions(formatDescription) as? [String: Any] else {
            return nil
        }
        
        var hdrType = "SDR"
        var hdrIcon = "☀️"
        
        // Check for color primaries and transfer function
        if let colorPrimaries = extensions[kCVImageBufferColorPrimariesKey as String] as? String {
            if colorPrimaries == (kCVImageBufferColorPrimaries_ITU_R_2020 as String) {
                // BT.2020 color space indicates HDR content
                if let transferFunction = extensions[kCVImageBufferTransferFunctionKey as String] as? String {
                    if transferFunction == (kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ as String) {
                        hdrType = "HDR10/HDR10+"
                        hdrIcon = "✨"
                    } else if transferFunction == (kCVImageBufferTransferFunction_ITU_R_2100_HLG as String) {
                        hdrType = "HLG"
                        hdrIcon = "🌟"
                    } else if transferFunction == (kCVImageBufferTransferFunction_Linear as String) {
                        hdrType = "Linear HDR"
                        hdrIcon = "✨"
                    }
                }
            }
        }
        
        // Check for Dolby Vision
        if let codecType = CMFormatDescriptionGetMediaSubType(formatDescription) as CMVideoCodecType?,
           codecType == kCMVideoCodecType_DolbyVisionHEVC {
            hdrType = "Dolby Vision"
            hdrIcon = "🎆"
        }
        
        // Check for HDR10+ metadata
        if let contentLightLevel = extensions[kCVImageBufferContentLightLevelInfoKey as String] {
            if contentLightLevel != nil {
                if hdrType == "HDR10/HDR10+" {
                    hdrType = "HDR10"
                }
            }
        }
        
        return "\(hdrIcon) Dynamic Range: \(hdrType)"
    }
    
    private func extractColorSpaceInfo(from formatDescription: CMFormatDescription) -> String? {
        guard let extensions = CMFormatDescriptionGetExtensions(formatDescription) as? [String: Any] else {
            return nil
        }
        
        var colorSpaceComponents = [String]()
        
        // Color primaries
        if let colorPrimaries = extensions[kCVImageBufferColorPrimariesKey as String] as? String {
            let primariesName: String
            if colorPrimaries == (kCVImageBufferColorPrimaries_ITU_R_2020 as String) {
                primariesName = "BT.2020"
            } else if colorPrimaries == (kCVImageBufferColorPrimaries_ITU_R_709_2 as String) {
                primariesName = "BT.709"
            } else if colorPrimaries == (kCVImageBufferColorPrimaries_SMPTE_C as String) {
                primariesName = "SMPTE-C"
            } else if colorPrimaries == (kCVImageBufferColorPrimaries_P3_D65 as String) {
                primariesName = "P3-D65"
            } else {
                primariesName = "Unknown"
            }
            colorSpaceComponents.append(primariesName)
        }
        
        // Transfer function
        if let transferFunction = extensions[kCVImageBufferTransferFunctionKey as String] as? String {
            let transferName: String
            if transferFunction == (kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ as String) {
                transferName = "PQ"
            } else if transferFunction == (kCVImageBufferTransferFunction_ITU_R_2100_HLG as String) {
                transferName = "HLG"
            } else if transferFunction == (kCVImageBufferTransferFunction_sRGB as String) {
                transferName = "sRGB"
            } else if transferFunction == (kCVImageBufferTransferFunction_ITU_R_709_2 as String) {
                transferName = "BT.709"
            } else {
                transferName = ""
            }
            if !transferName.isEmpty {
                colorSpaceComponents.append(transferName)
            }
        }
        
        // YCbCr matrix
        if let matrix = extensions[kCVImageBufferYCbCrMatrixKey as String] as? String {
            let matrixName: String
            if matrix == (kCVImageBufferYCbCrMatrix_ITU_R_2020 as String) {
                matrixName = "YCbCr:2020"
            } else if matrix == (kCVImageBufferYCbCrMatrix_ITU_R_709_2 as String) {
                matrixName = "YCbCr:709"
            } else if matrix == (kCVImageBufferYCbCrMatrix_ITU_R_601_4 as String) {
                matrixName = "YCbCr:601"
            } else {
                matrixName = ""
            }
            if !matrixName.isEmpty {
                colorSpaceComponents.append(matrixName)
            }
        }
        
        if colorSpaceComponents.isEmpty {
            return nil
        }
        
        return "🎨 Color Space: " + colorSpaceComponents.joined(separator: " / ")
    }
    
    private func getResolutionLabel(height: Int) -> String {
        if height >= 2160 {
            return "4K UHD"
        } else if height >= 1440 {
            return "2K QHD"
        } else if height >= 1080 {
            return "1080p FHD"
        } else if height >= 720 {
            return "720p HD"
        } else {
            return "SD"
        }
    }
    
    private func extractCodecFromURL(_ urlString: String) -> String? {
        // Parse URL like: atv://dash/3?codec=hev1.1.6.L150.90&rate=50.000...
        guard let components = URLComponents(string: urlString),
              let queryItems = components.queryItems else {
            return nil
        }
        
        guard let codecParam = queryItems.first(where: { $0.name == "codec" })?.value else {
            return nil
        }
        
        // Map codec strings to readable names
        if codecParam.starts(with: "avc") {
            return "H.264 (AVC) - \(codecParam)"
        } else if codecParam.starts(with: "hev") || codecParam.starts(with: "hvc") {
            return "H.265 (HEVC) - \(codecParam)"
        } else if codecParam.starts(with: "dvh") || codecParam.starts(with: "dvhe") {
            return "Dolby Vision - \(codecParam)"
        } else if codecParam.starts(with: "vp09") {
            return "VP9 - \(codecParam)"
        } else if codecParam.starts(with: "av01") {
            return "AV1 - \(codecParam)"
        }
        
        return codecParam
    }
    
    private func inferHDRFromURL(_ urlString: String) -> String? {
        guard let components = URLComponents(string: urlString),
              let queryItems = components.queryItems else {
            return nil
        }
        
        guard let codecParam = queryItems.first(where: { $0.name == "codec" })?.value else {
            return nil
        }
        
        // Check for Dolby Vision
        if codecParam.starts(with: "dvh") || codecParam.starts(with: "dvhe") {
            return "🎆 Dynamic Range: Dolby Vision"
        }
        
        // Check for HDR10 indicators in HEVC codec
        // hev1.1.6.L150.90 - profile 1 (Main 10), typically used for HDR10
        if codecParam.starts(with: "hev1") || codecParam.starts(with: "hvc1") {
            let components = codecParam.components(separatedBy: ".")
            if components.count >= 3 {
                // Check profile - "1" is Main 10 profile (10-bit, used for HDR)
                if components[1] == "1" || components[1] == "2" {
                    // Level indicates potential HDR content
                    if let level = components.indices.contains(3) ? components[3] : nil {
                        if level.starts(with: "L15") || level.starts(with: "L12") {
                            return "✨ Dynamic Range: HDR10 (inferred)"
                        }
                    }
                }
            }
        }
        
        return "☀️ Dynamic Range: SDR"
    }
}
