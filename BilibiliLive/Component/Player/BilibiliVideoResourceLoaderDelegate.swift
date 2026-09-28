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

    private func reset() {
        playlists.removeAll()
        masterPlaylist = """
        #EXTM3U
        #EXT-X-VERSION:6
        #EXT-X-INDEPENDENT-SEGMENTS


        """
    }

    private func addVideoPlayBackInfo(info: VideoPlayURLInfo.DashInfo.DashMediaInfo, url: String, duration: Int) {
        guard !videoCodecBlackList.contains(info.codecs) else { return }
        let subtitlePlaceHolder = hasSubtitle ? ",SUBTITLES=\"subs\"" : ""
        let isDolby = info.id == MediaQualityEnum.quality_hdr_dolby.qn
        let isHDR10 = info.id == 125
        // hdr 10 formate exp: hev1.2.4.L156.90
        //  Codec.Profile.Flags.TierLevel.Constraints
        let isHDR = isDolby || isHDR10
        if isHDR {
            self.isHDR = true
        }
        var videoRange = isHDR ? "HLG" : "SDR"
        var codecs = info.codecs
        var supplementCodesc = ""
        // TODO: Need update all codecs with https://developer.apple.com/documentation/http_live_streaming/http_live_streaming_hls_authoring_specification_for_apple_devices/hls_authoring_specification_for_apple_devices_appendixes
        var framerate = info.frame_rate ?? "25"

        // CRITICAL FIX: Convert hev1 to hvc1 for Apple compatibility
        // Apple devices only support hvc1 format, not hev1
        // This conversion is ONLY for HEVC-encoded videos (both SDR and HDR)
        // AVC (avc1) videos are not affected by this conversion
        if codecs.hasPrefix("hev1.") {
            codecs = codecs.replacingOccurrences(of: "hev1.", with: "hvc1.")
            Logger.debug("Converted hev1 to hvc1 for Apple compatibility: \(codecs)")
        }

        if isHDR10 {
            videoRange = "PQ"
            if let value = Double(framerate), value <= 30 {} else {
                framerate = "30"
            }
        }
        // Handle Bilibili Dolby Vision: HEVC Main 10 Profile
        // Bilibili returns hvc1.2.4.L15x.90 format, need to convert to Apple standard format
        if isDolby && codecs.hasPrefix("hvc1.2.4") {
            // Convert to Apple standard: hvc1.Profile.Compatibility.Level.Constraints
            // FIXED: hvc1.2.4.L150.90 -> hvc1.2.4.L150.b0 (not hvc1.2.40000000.L150.B0)
            let levelMatch = codecs.range(of: "L15[0-9]", options: .regularExpression)
            if let range = levelMatch {
                let level = String(codecs[range])
                // Correct format: hvc1.2(Main10).4(compatibility).Level.b0(constraints)
                codecs = "hvc1.2.4.\(level).b0"
                supplementCodesc = "dvh1.08.07/db4h"
                videoRange = "HLG"  // Dolby Vision Profile 8.4 uses HLG
            }
        } else if codecs == "dvh1.08.07" || codecs == "dvh1.08.03" {
            // Dolby Vision Profile 8.4/8.7 - HLG transfer function
            supplementCodesc = codecs + "/db4h"
            codecs = "hvc1.2.4.L153.b0"
            videoRange = "HLG"
        } else if codecs == "dvh1.08.06" {
            // Dolby Vision Profile 8.1 - PQ transfer function
            supplementCodesc = codecs + "/db1p"
            codecs = "hvc1.2.4.L150.b0"  // Fixed: added .b0 constraint
            videoRange = "PQ"
        } else if codecs.hasPrefix("dvh1.05") {
            // Dolby Vision Profile 5 - PQ transfer function
            videoRange = "PQ"
        } else if isHDR {
            Logger.warn("unknown hdr codecs: \(codecs)")
        }

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
        let sidxResult = await segmentInfoCache.sidx(from: info.info)
        let inits = info.info.segment_base.initialization.components(separatedBy: "-")
        guard let moovIdxStr = inits.last,
              let moovIdx = Int(moovIdxStr),
              let moovOffset = inits.first,
              let offsetStr = info.info.segment_base.index_range.components(separatedBy: "-").last,
              var offset = Int(offsetStr),
              let sidxResult = sidxResult
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

        // 使用 sidx 实际下载成功的 URL：它已经验证过 CDN 可达，
        // 首选节点（如 PCDN）连不上时分片请求会整体切到可用的备用线路
        let segment = sidxResult.sidx
        let segmentURL = sidxResult.url
        var playList = """
        #EXTM3U
        #EXT-X-VERSION:7
        #EXT-X-TARGETDURATION:\(segment.maxSegmentDuration() ?? info.duration)
        #EXT-X-MEDIA-SEQUENCE:1
        #EXT-X-INDEPENDENT-SEGMENTS
        #EXT-X-PLAYLIST-TYPE:VOD
        #EXT-X-MAP:URI="\(segmentURL)",BYTERANGE="\(moovIdx + 1)@\(moovOffset)"

        """
        offset += 1
        for segInfo in segment.segments {
            let segStr = """
            #EXTINF:\(Double(segInfo.duration) / Double(segment.timescale)),
            #EXT-X-BYTERANGE:\(segInfo.size)@\(offset)
            \(segmentURL)

            """
            playList.append(segStr)
            offset += (segInfo.size)
        }

        playList.append("\n#EXT-X-ENDLIST")

        return playList
    }

    private func addAudioPlayBackInfo(info: VideoPlayURLInfo.DashInfo.DashMediaInfo, url: String, duration: Int) {
        guard !videoCodecBlackList.contains(info.codecs) else { return }
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
        if Settings.preferAvc {
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
        // PCDN 垫底，其余保持 API 返回顺序（enumerated + offset 实现稳定排序）
        return urls.enumerated()
            .sorted { (tier($0.element), $0.offset) < (tier($1.element), $1.offset) }
            .map(\.element)
    }

    // PCDN 特征：带端口，或已知的 P2P CDN 域名（部分 PCDN 域名不带端口，仅靠端口判断会漏）
    static func isPCDN(_ urlString: String) -> Bool {
        guard let components = URLComponents(string: urlString) else {
            return false
        }
        if components.port != nil {
            return true
        }
        guard let host = components.host?.lowercased() else {
            return false
        }
        return host.hasSuffix("szbdyd.com") || host.hasSuffix("mcdn.bilivideo.cn")
    }

    /// 0 = 普通 CDN，1 = PCDN（仅作最后备援）
    static func tier(_ urlString: String) -> Int {
        isPCDN(urlString) ? 1 : 0
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
        return codecs.starts(with: "hev") || codecs.starts(with: "hvc") || codecs.starts(with: "dvh1")
    }
}

actor SidxDownloader {
    struct SidxResult {
        let sidx: SidxParseUtil.Sidx
        let url: String
    }

    private enum CacheEntry {
        case inProgress(Task<SidxResult?, Never>)
        case ready(SidxResult?)
    }

    // sidx 只有几 KB，用短超时的独立 Session，避免 PCDN 连不上时默认 60s 超时把起播卡死
    private static let session: Session = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 6
        config.timeoutIntervalForResource = 10
        config.headers = HTTPHeaders(["User-Agent": Keys.userAgent])
        return Session(configuration: config)
    }()

    private var cache: [VideoPlayURLInfo.DashInfo.DashMediaInfo: CacheEntry] = [:]

    func sidx(from info: VideoPlayURLInfo.DashInfo.DashMediaInfo) async -> SidxResult? {
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

    // 依次尝试多个 CDN，返回第一个成功下载并解析出 sidx 的 URL，作为后续分片的请求地址
    private func downloadSidx(info: VideoPlayURLInfo.DashInfo.DashMediaInfo) async -> SidxResult? {
        let range = info.segment_base.index_range
        for url in info.playableURLs.prefix(3) {
            if let res = try? await Self.session.request(url,
                                                         headers: ["Range": "bytes=\(range)",
                                                                   "Referer": "https://www.bilibili.com/"])
                .validate()
                .serializingData().result.get(),
                let segment = SidxParseUtil.processIndexData(data: res),
                !segment.segments.isEmpty
            {
                return SidxResult(sidx: segment, url: url)
            }
            Logger.warn("sidx download failed on \(URLComponents(string: url)?.host ?? url), try next url")
        }
        return nil
    }
}
