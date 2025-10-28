//
//  BilibiliVideoResourceLoaderDelegate.swift
//  MPEGDASHAVPlayerDemo
//
//  Created by yicheng on 2022/08/20.
//  Copyright © 2022 yicheng. All rights reserved.
//

import Alamofire
import AVFoundation
import Swifter
import SwiftyJSON
import UIKit

class BilibiliVideoResourceLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate {
    enum URLs {
        static let customScheme = "atv"
        static let customPrefix = customScheme + "://list/"
        static let play = customPrefix + "play"
        static let customSubtitlePrefix = customScheme + "://subtitle/"
        static let customDashPrefix = customScheme + "://dash/"
    }

    struct PlaybackInfo {
        let info: VideoPlayURLInfo.DashInfo.DashMediaInfo
        let url: String
        let duration: Int
    }

    private var audioPlaylist = ""
    private var videoPlaylist = ""
    private var backupVideoPlaylist = ""
    private var masterPlaylist = ""

    private let badRequestErrorCode = 455

    private var playlists = [String]()
    private var subtitles = [String: String]()
    private var videoInfo = [PlaybackInfo]()
    private var segmentInfoCache = SidxDownloader()
    private var hasAudioInMasterListAdded = false
    private(set) var playInfo: VideoPlayURLInfo?
    private var hasSubtitle = false
    private var hasPreferSubtitleAdded = false
    private var httpServer = HttpServer()
    private var aid = 0
    private(set) var httpPort = 0
    private(set) var isHDR = false
    deinit {
        httpServer.stop()
    }

    var infoDebugText: String {
        let videoCodec = playInfo?.dash.video.map({ $0.codecs }).prefix(5).joined(separator: ",") ?? "nil"
        let audioCodec = playInfo?.dash.audio?.map({ $0.codecs }).prefix(5).joined(separator: ",") ?? "nil"
        return "video codecs: \(videoCodec), audio: \(audioCodec)"
    }

    let videoCodecBlackList = ["avc1.640034"] // high 5.2 is not supported
    
    // Extended codec compatibility checks
    private func isCodecSupported(_ codec: String) -> Bool {
        // Check blacklist
        if videoCodecBlackList.contains(codec) {
            return false
        }
        
        // Check for unsupported profiles
        // AVC High 5.2 and above are not supported on some devices
        if codec.hasPrefix("avc1.6400") {
            // avc1.640033 (High 5.1) and above may have issues
            if let profile = codec.split(separator: ".").last,
               let profileNum = Int(String(profile), radix: 16),
               profileNum >= 0x33 {
                Logger.warn("AVC profile \(codec) may not be supported on this device")
                return false
            }
        }
        
        // HEVC profiles check (most profiles are supported on Apple TV 4K)
        // But some exotic profiles might not work
        if codec.hasPrefix("hev1.") || codec.hasPrefix("hvc1.") {
            // Allow all standard HEVC profiles
            return true
        }
        
        // AV1 requires tvOS 14+ and Apple TV 4K (2nd gen or later)
        if codec.hasPrefix("av01.") {
            // Check if device supports AV1 (simplified check)
            if #available(tvOS 14.0, *) {
                return true
            } else {
                Logger.warn("AV1 codec requires tvOS 14+")
                return false
            }
        }
        
        // Dolby Vision codecs
        if codec.hasPrefix("dvh1.") || codec.hasPrefix("dvhe.") {
            // Dolby Vision requires tvOS 12+ and Apple TV 4K
            if #available(tvOS 12.0, *) {
                return true
            } else {
                Logger.warn("Dolby Vision requires tvOS 12+")
                return false
            }
        }
        
        // VP9 is not natively supported by AVFoundation
        if codec.hasPrefix("vp09.") || codec.hasPrefix("vp9") {
            Logger.warn("VP9 codec is not natively supported")
            return false
        }
        
        return true
    }

    private func reset() {
        playlists.removeAll()
        masterPlaylist = """
        #EXTM3U
        #EXT-X-VERSION:6
        #EXT-X-INDEPENDENT-SEGMENTS


        """
    }

    /// Parse Dolby Vision profile from codec string
    /// - Parameter codec: Codec string like "dvh1.08.07" or "dvh1.05.06"
    /// - Returns: Tuple containing (profile, subProfile, suffix) or nil if not a Dolby Vision codec
    private func parseDolbyVisionProfile(from codec: String) -> (profile: String, subProfile: String, suffix: String)? {
        // Expected format: dvh1.XX.YY where XX is profile (05, 08, 10) and YY is sub-profile
        let components = codec.split(separator: ".")
        guard components.count >= 3,
              (components[0] == "dvh1" || components[0] == "dvhe") else {
            return nil
        }

        let profile = String(components[1])
        let subProfile = String(components[2])

        // Determine suffix based on profile and sub-profile
        // Reference: https://developer.apple.com/documentation/http_live_streaming/hls_authoring_specification_for_apple_devices
        let suffix: String
        switch (profile, subProfile) {
        case ("05", _):
            // Profile 5: Backward compatible with HEVC Main 10
            suffix = "db1p" // PQ transfer function
        case ("08", "01"):
            // Profile 8.1: Single layer HEVC with PQ
            suffix = "db1p"
        case ("08", "07"):
            // Profile 8.4: Single layer HEVC with HLG
            suffix = "db4h"
        case ("09", _):
            // Profile 9: Gaming profile with low latency
            suffix = "db1p"
        case ("10", "07"):
            // Profile 10.7: Single layer AV1 with HLG (future support)
            suffix = "db4h"
        case ("10", "09"):
            // Profile 10.9: Single layer HEVC with HLG
            suffix = "db4h"
        default:
            // Default to PQ for unknown profiles
            Logger.warn("Unrecognized Dolby Vision profile: \(profile).\(subProfile), defaulting to PQ")
            suffix = "db1p"
        }

        return (profile, subProfile, suffix)
    }

    private func addVideoPlayBackInfo(info: VideoPlayURLInfo.DashInfo.DashMediaInfo, url: String, duration: Int) {
        // Check codec compatibility
        guard isCodecSupported(info.codecs) else {
            Logger.debug("Skipping unsupported codec: \(info.codecs)")
            return
        }
        
        let subtitlePlaceHolder = hasSubtitle ? ",SUBTITLES=\"subs\"" : ""
        
        // Detect video format type
        let isDolby = info.id == MediaQualityEnum.quality_hdr_dolby.qn || info.codecs.hasPrefix("dvh1.") || info.codecs.hasPrefix("dvhe.")
        let isHDR10Plus = info.id == MediaQualityEnum.quality_hdr10plus.qn
        let isHDR10 = info.id == MediaQualityEnum.quality_hdr10.qn
        let isHLG = info.id == MediaQualityEnum.quality_hlg.qn
        
        // HDR detection: any of the above formats
        let isHDR = isDolby || isHDR10Plus || isHDR10 || isHLG
        
        if isHDR {
            self.isHDR = true
        }
        
        var videoRange = isHDR ? "HLG" : "SDR"
        var codecs = info.codecs
        var supplementCodesc = ""
        var framerate = info.frame_rate ?? "25"

        // Handle HDR10 and HDR10+
        if isHDR10 || isHDR10Plus {
            videoRange = "PQ"
            // Limit framerate for HDR10 to ensure compatibility
            if let value = Double(framerate), value <= 30 {
                // Keep original framerate
            } else {
                framerate = "30"
            }
        }
        
        // Handle HLG (Hybrid Log-Gamma)
        if isHLG {
            videoRange = "HLG"
            // HLG typically supports higher framerates
        }

        // Handle Dolby Vision with profile-based configuration
        if isDolby, let dvProfile = parseDolbyVisionProfile(from: info.codecs) {
            // Set SUPPLEMENTAL-CODECS according to Apple HLS spec
            supplementCodesc = info.codecs + "/" + dvProfile.suffix

            // Determine VIDEO-RANGE: HLG for Profile 8.4/10.4/10.7, PQ for others
            if dvProfile.suffix == "db4h" {
                videoRange = "HLG"
                // HLG-based Dolby Vision profiles use specific base codecs
                if dvProfile.profile == "08" && dvProfile.subProfile == "07" {
                    // Profile 8.4 uses hvc1.2.4.L153.b0 as base codec
                    codecs = "hvc1.2.4.L153.b0"
                } else if dvProfile.profile == "10" && dvProfile.subProfile == "09" {
                    // Profile 10.9 uses similar base codec
                    codecs = "hvc1.2.4.L153.b0"
                }
            } else {
                videoRange = "PQ"
                // PQ-based Dolby Vision profiles
                if dvProfile.profile == "08" {
                    // Profile 8.1 uses hvc1.2.4.L150 as base codec
                    codecs = "hvc1.2.4.L150"
                } else if dvProfile.profile == "05" {
                    // Profile 5 keeps original base codec for backward compatibility
                    // Leave codecs unchanged for dvh1.05.xx
                } else if dvProfile.profile == "09" {
                    // Profile 9 (Gaming) uses similar to Profile 8.1
                    codecs = "hvc1.2.4.L150"
                }
            }
        } else if isDolby {
            // Fallback for unknown Dolby Vision formats
            Logger.warn("Unrecognized Dolby Vision codec format: \(info.codecs)")
            videoRange = "PQ" // Default to PQ for safety
        }

        // Normalize framerate
        if let value = Double(framerate), value >= 60 {
            framerate = "60"
        }

        if supplementCodesc.count > 0 {
            supplementCodesc = ",SUPPLEMENTAL-CODECS=\"\(supplementCodesc)\""
        }
        
        let content = """
        #EXT-X-STREAM-INF:AUDIO="audio"\(subtitlePlaceHolder),CODECS="\(codecs)"\(supplementCodesc),RESOLUTION=\(info.width ?? 0)x\(info.height ?? 0),FRAME-RATE=\(framerate),BANDWIDTH=\(info.bandwidth),VIDEO-RANGE=\(videoRange)
        \(URLs.customDashPrefix)\(videoInfo.count)?codec=\(info.codecs)&rate=\(info.frame_rate ?? framerate)&width=\(info.width ?? 0)&host=\(URL(string: url)?.host ?? "none")&range=\(info.id)

        """
        masterPlaylist.append(content)
        videoInfo.append(PlaybackInfo(info: info, url: url, duration: duration))
    }

    private func getVideoPlayList(info: PlaybackInfo) async -> String {
        let segment = await segmentInfoCache.sidx(from: info.info)
        let inits = info.info.segment_base.initialization.components(separatedBy: "-")
        guard let moovIdxStr = inits.last,
              let moovIdx = Int(moovIdxStr),
              let moovOffset = inits.first,
              let offsetStr = info.info.segment_base.index_range.components(separatedBy: "-").last,
              var offset = Int(offsetStr),
              let segment = segment
        else {
            return """
            #EXTM3U
            #EXT-X-VERSION:7
            #EXT-X-TARGETDURATION:\(info.duration)
            #EXT-X-MEDIA-SEQUENCE:1
            #EXT-X-INDEPENDENT-SEGMENTS
            #EXT-X-PLAYLIST-TYPE:VOD
            #EXTINF:\(info.duration)
            \(info.url)
            #EXT-X-ENDLIST
            """
        }

        var playList = """
        #EXTM3U
        #EXT-X-VERSION:7
        #EXT-X-TARGETDURATION:\(segment.maxSegmentDuration() ?? info.duration)
        #EXT-X-MEDIA-SEQUENCE:1
        #EXT-X-INDEPENDENT-SEGMENTS
        #EXT-X-PLAYLIST-TYPE:VOD
        #EXT-X-MAP:URI="\(info.url)",BYTERANGE="\(moovIdx + 1)@\(moovOffset)"

        """
        offset += 1
        for segInfo in segment.segments {
            let segStr = """
            #EXTINF:\(Double(segInfo.duration) / Double(segment.timescale)),
            #EXT-X-BYTERANGE:\(segInfo.size)@\(offset)
            \(info.url)

            """
            playList.append(segStr)
            offset += (segInfo.size)
        }

        playList.append("\n#EXT-X-ENDLIST")

        return playList
    }

    private func addAudioPlayBackInfo(info: VideoPlayURLInfo.DashInfo.DashMediaInfo, url: String, duration: Int) {
        guard isCodecSupported(info.codecs) else {
            Logger.debug("Skipping unsupported audio codec: \(info.codecs)")
            return
        }
        let defaultStr = !hasAudioInMasterListAdded ? "YES" : "NO"
        let content = """
        #EXT-X-MEDIA:TYPE=AUDIO,DEFAULT=\(defaultStr),GROUP-ID="audio",NAME="Main",URI="\(URLs.customDashPrefix)\(videoInfo.count)"

        """

        masterPlaylist.append(content)
        videoInfo.append(PlaybackInfo(info: info, url: url, duration: duration))
    }

    private func addAudioPlayBackInfo(codec: String, bandwidth: Int, duration: Int, url: String) {
        let defaultStr = !hasAudioInMasterListAdded ? "YES" : "NO"
        hasAudioInMasterListAdded = true
        let content = """
        #EXT-X-MEDIA:TYPE=AUDIO,DEFAULT=\(defaultStr),GROUP-ID="audio",NAME="Main",URI="\(URLs.customPrefix)\(playlists.count)"

        """
        masterPlaylist.append(content)

        let playList = """
        #EXTM3U
        #EXT-X-VERSION:6
        #EXT-X-TARGETDURATION:\(duration)
        #EXT-X-INDEPENDENT-SEGMENTS
        #EXT-X-MEDIA-SEQUENCE:1
        #EXT-X-PLAYLIST-TYPE:VOD
        #EXTINF:\(duration)
        \(url)
        #EXT-X-ENDLIST
        """
        playlists.append(playList)
    }

    private func addSubtitleData(lang: String, name: String, duration: Int, url: String) {
        var lang = lang
        var canBeDefault = !hasPreferSubtitleAdded
        if lang.hasPrefix("ai-") {
            lang = String(lang.dropFirst(3))
            canBeDefault = false
        }
        if canBeDefault {
            hasPreferSubtitleAdded = true
        }
        let defaultStr = canBeDefault ? "YES" : "NO"

        let master = """
        #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",LANGUAGE="\(lang)",NAME="\(name)",AUTOSELECT=\(defaultStr),DEFAULT=\(defaultStr),URI="\(URLs.customPrefix)\(playlists.count)"

        """
        masterPlaylist.append(master)

        let playList = """
        #EXTM3U
        #EXT-X-TARGETDURATION:\(duration)
        #EXT-X-VERSION:3
        #EXT-X-MEDIA-SEQUENCE:0
        #EXT-X-PLAYLIST-TYPE:VOD
        #EXTINF:\(duration),

        \(URLs.customSubtitlePrefix)\(url.addingPercentEncoding(withAllowedCharacters: .afURLQueryAllowed) ?? url)
        #EXT-X-ENDLIST

        """
        playlists.append(playList)
    }

    func setBilibili(info: VideoPlayURLInfo, subtitles: [SubtitleData], aid: Int) {
        playInfo = info
        self.aid = aid
        reset()
        hasSubtitle = subtitles.count > 0
        var videos = info.dash.video
        
        // Apply codec preference filtering
        let codecPref = Settings.codecPreference
        if codecPref != .auto {
            let videosMap = Dictionary(grouping: videos, by: { $0.id })
            for (key, values) in videosMap {
                switch codecPref {
                case .preferAV1:
                    // Prefer AV1, fallback to HEVC, then AVC
                    if values.contains(where: { $0.isAV1 }) {
                        videos.removeAll(where: { $0.id == key && !$0.isAV1 })
                    } else if values.contains(where: { $0.isHevc }) {
                        videos.removeAll(where: { $0.id == key && $0.isAVC })
                    }
                case .preferHEVC:
                    // Prefer HEVC, fallback to AVC
                    if values.contains(where: { $0.isHevc }) {
                        videos.removeAll(where: { $0.id == key && !$0.isHevc })
                    }
                case .preferAVC:
                    // Prefer AVC for compatibility
                    if values.contains(where: { $0.isAVC }) {
                        videos.removeAll(where: { $0.id == key && !$0.isAVC })
                    }
                case .auto:
                    break
                }
            }
        }
        
        // Legacy support for old preferAvc setting
        if Settings.preferAvc && codecPref == .auto {
            let videosMap = Dictionary(grouping: videos, by: { $0.id })
            for (key, values) in videosMap {
                if values.contains(where: { !$0.isHevc }) {
                    videos.removeAll(where: { $0.id == key && $0.isHevc })
                }
            }
        }

        for video in videos {
            for url in video.playableURLs {
                addVideoPlayBackInfo(info: video, url: url, duration: info.dash.duration)
            }
        }

        if Settings.losslessAudio {
            if let audios = info.dash.dolby?.audio {
                for audio in audios {
                    for url in BVideoUrlUtils.sortUrls(base: audio.base_url, backup: audio.backup_url) {
                        addAudioPlayBackInfo(info: audio, url: url, duration: info.dash.duration)
                    }
                }
            } else if let audio = info.dash.flac?.audio {
                for url in audio.playableURLs {
                    addAudioPlayBackInfo(info: audio, url: url, duration: info.dash.duration)
                }
            }
        }

        for audio in info.dash.audio ?? [] {
            for url in audio.playableURLs {
                addAudioPlayBackInfo(info: audio, url: url, duration: info.dash.duration)
            }
        }

        if hasSubtitle {
            try? httpServer.start(0)
            bindHttpServer()
            httpPort = (try? httpServer.port()) ?? 0
        }
        for subtitle in subtitles {
            if let url = subtitle.url {
                addSubtitleData(lang: subtitle.lan, name: subtitle.lan_doc, duration: info.dash.duration, url: url.absoluteString)
            }
        }

        // i-frame
        if let video = videos.last, let url = video.playableURLs.first {
            let media = """
            #EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=\(video.bandwidth),RESOLUTION=\(video.width!)x\(video.height!),URI="\(URLs.customDashPrefix)\(videoInfo.count)"

            """
            masterPlaylist.append(media)
            videoInfo.append(PlaybackInfo(info: video, url: url, duration: info.dash.duration))
        }

        masterPlaylist.append("\n#EXT-X-ENDLIST\n")

        Logger.debug("masterPlaylist: \(masterPlaylist)")
    }

    private func reportError(_ loadingRequest: AVAssetResourceLoadingRequest, withErrorCode error: Int) {
        loadingRequest.finishLoading(with: NSError(domain: NSURLErrorDomain, code: error, userInfo: nil))
    }

    private func report(_ loadingRequest: AVAssetResourceLoadingRequest, content: String) {
        if let data = content.data(using: .utf8) {
            loadingRequest.dataRequest?.respond(with: data)
            loadingRequest.finishLoading()
        } else {
            reportError(loadingRequest, withErrorCode: badRequestErrorCode)
        }
    }

    func resourceLoader(_: AVAssetResourceLoader,
                        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool
    {
        guard let scheme = loadingRequest.request.url?.scheme, scheme == URLs.customScheme else {
            return false
        }

        DispatchQueue.main.async {
            self.handleCustomPlaylistRequest(loadingRequest)
        }
        return true
    }
}

private extension BilibiliVideoResourceLoaderDelegate {
    func handleCustomPlaylistRequest(_ loadingRequest: AVAssetResourceLoadingRequest) {
        guard let customUrl = loadingRequest.request.url else {
            reportError(loadingRequest, withErrorCode: badRequestErrorCode)
            return
        }
        let urlStr = customUrl.absoluteString
        Logger.debug("handleCustomPlaylistRequest: \(urlStr)")
        if urlStr == URLs.play {
            report(loadingRequest, content: masterPlaylist)
            return
        }

        if urlStr.hasPrefix(URLs.customPrefix), let index = Int(customUrl.lastPathComponent) {
            let playlist = playlists[index]
            report(loadingRequest, content: playlist)
            return
        }
        if urlStr.hasPrefix(URLs.customDashPrefix), let index = Int(customUrl.lastPathComponent) {
            let info = videoInfo[index]
            Task {
                report(loadingRequest, content: await getVideoPlayList(info: info))
            }
        }
        if urlStr.hasPrefix(URLs.customSubtitlePrefix) {
            let url = String(urlStr.dropFirst(URLs.customSubtitlePrefix.count))
            let req = url.removingPercentEncoding ?? url
            Task {
                do {
                    if subtitles[req] == nil {
                        let content = try await WebRequest.requestSubtitle(url: URL(string: req)!)
                        let vtt = BVideoUrlUtils.convertToVTT(subtitle: content)
                        subtitles[req] = vtt
                    }
                    let port = try self.httpServer.port()
                    let url = "http://127.0.0.1:\(port)/subtitle?u=" + url
                    let redirectRequest = URLRequest(url: URL(string: url)!)
                    let redirectResponse = HTTPURLResponse(url: URL(string: url)!, statusCode: 302, httpVersion: nil, headerFields: nil)

                    loadingRequest.redirect = redirectRequest
                    loadingRequest.response = redirectResponse
                    loadingRequest.finishLoading()
                    return
                } catch let err {
                    loadingRequest.finishLoading(with: err)
                }
            }
            return
        }
        Logger.debug("handle loading \(customUrl)")
    }

    func bindHttpServer() {
        httpServer["/subtitle"] = { [weak self] req in
            if let url = req.queryParams.first(where: { $0.0 == "u" })?.1 {
                let req = url.removingPercentEncoding ?? url
                if let content = self?.subtitles[req] {
                    return HttpResponse.ok(.text(content))
                }
            }
            return HttpResponse.notFound()
        }
    }
}

enum BVideoUrlUtils {
    static func sortUrls(base: String, backup: [String]?) -> [String] {
        var urls = [base]
        if let backup {
            urls.append(contentsOf: backup)
        }
        return
            urls.sorted { lhs, rhs in
                let lhsIsPCDN = lhs.contains("szbdyd.com") || lhs.contains("mcdn.bilivideo.cn")
                let rhsIsPCDN = rhs.contains("szbdyd.com") || rhs.contains("mcdn.bilivideo.cn")
                switch (lhsIsPCDN, rhsIsPCDN) {
                case (true, false): return false
                case (false, true): return true
                case (true, true): fallthrough
                case (false, false): return lhs > rhs
                }
            }
    }

    static func convertVTTFormate(_ time: CGFloat) -> String {
        let seconds = Int(time)
        let hour = seconds / 3600
        let min = (seconds % 3600) / 60
        let second = CGFloat((seconds % 3600) % 60) + time - CGFloat(Int(time))
        return String(format: "%02d:%02d:%06.3f", hour, min, second)
    }

    static func convertToVTT(subtitle: [SubtitleContent]) -> String {
        var vtt = "WEBVTT\n\n"
        for model in subtitle {
            let from = convertVTTFormate(model.from)
            let to = convertVTTFormate(model.to)
            // hours:minutes:seconds.millisecond
            vtt.append("\(from) --> \(to)\n\(model.content)\n\n")
        }
        return vtt
    }
}

extension VideoPlayURLInfo.DashInfo.DashMediaInfo {
    var playableURLs: [String] {
        BVideoUrlUtils.sortUrls(base: base_url, backup: backup_url)
    }

    var isHevc: Bool {
        return codecs.starts(with: "hev") || codecs.starts(with: "hvc") || codecs.starts(with: "dvh1") || codecs.starts(with: "dvhe")
    }
    
    var isAV1: Bool {
        return codecs.starts(with: "av01") || codecs.starts(with: "av1")
    }
    
    var isAVC: Bool {
        return codecs.starts(with: "avc1")
    }
    
    var codecType: String {
        if isAV1 {
            return "AV1"
        } else if isHevc {
            return "HEVC"
        } else if isAVC {
            return "AVC"
        } else {
            return "Unknown"
        }
    }
}

actor SidxDownloader {
    private enum CacheEntry {
        case inProgress(Task<SidxParseUtil.Sidx?, Never>)
        case ready(SidxParseUtil.Sidx?)
    }

    private var cache: [VideoPlayURLInfo.DashInfo.DashMediaInfo: CacheEntry] = [:]

    func sidx(from info: VideoPlayURLInfo.DashInfo.DashMediaInfo) async -> SidxParseUtil.Sidx? {
        if let cached = cache[info] {
            switch cached {
            case let .ready(sidx):
                Logger.debug("sidx cache hit \(info.id)")
                return sidx
            case let .inProgress(sidx):
                Logger.debug("sidx cache wait \(info.id)")
                return await sidx.value
            }
        }

        let task = Task {
            await downloadSidx(info: info)
        }

        cache[info] = .inProgress(task)

        let sidx = await task.value
        cache[info] = .ready(sidx)
        Logger.debug("get sidx \(info.id)")
        return sidx
    }

    private func downloadSidx(info: VideoPlayURLInfo.DashInfo.DashMediaInfo) async -> SidxParseUtil.Sidx? {
        let range = info.segment_base.index_range
        let url = info.playableURLs.first ?? info.base_url
        if let res = try? await AF.request(url,
                                           headers: ["Range": "bytes=\(range)",
                                                     "Referer": "https://www.bilibili.com/"])
            .serializingData().result.get()
        {
            let segment = SidxParseUtil.processIndexData(data: res)
            return segment
        }
        return nil
    }
}
