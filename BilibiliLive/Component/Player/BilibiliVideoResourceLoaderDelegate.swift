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

    /// HLS 音频组，按编码各放一条音轨，每个视频档位与每个组各组成一个 variant（Apple HLS 规范的做法）。
    /// 各组 NAME 相同，AVPlayer 把它们当作同一条音轨的不同编码，起播时选可播放的最高码率组合，
    /// 所以有杜比 / FLAC 时优先选它们；之后不会在杜比与 AAC 之间切换，FLAC 与 AAC 之间会随带宽切换
    private struct AudioGroup {
        let id: String
        /// 追加到 EXT-X-STREAM-INF CODECS 中的音频编码
        let codecs: String
        let bandwidth: Int
    }

    /// DASH 的 bandwidth 是平均码率，而 HLS 的 BANDWIDTH 要求峰值码率。直接照搬会让 CoreMedia
    /// 每拉一个分片都判定 "Segment exceeds specified bandwidth for variant" (-12318) 并自行上调估计，
    /// ABR 从起播起就依据错误的数值决策。实测 B 站视频分片峰值约为平均的 1.5 倍（上游 #208），
    /// 平均值仍通过 AVERAGE-BANDWIDTH 如实声明，稳态选流依据它
    private static func peakBandwidth(forAverage average: Int) -> Int {
        return Int(Double(average) * 1.5)
    }

    private func reset() {
        playlists.removeAll()
        masterPlaylist = """
        #EXTM3U
        #EXT-X-VERSION:6
        #EXT-X-INDEPENDENT-SEGMENTS


        """
    }

    private func addVideoPlayBackInfo(info: VideoPlayURLInfo.DashInfo.DashMediaInfo, url: String, duration: Int, format: HLSVideoFormat, audioGroups: [AudioGroup]) {
        guard !videoCodecBlackList.contains(info.codecs) else { return }
        let subtitlePlaceHolder = hasSubtitle ? ",SUBTITLES=\"subs\"" : ""
        if format.isHDR {
            isHDR = true
        }
        var framerate = info.frame_rate ?? "25"
        if info.id == HLSVideoFormat.Quality.hdr {
            if let value = Double(framerate), value <= 30 {} else {
                framerate = "30"
            }
        }
        if let value = Double(framerate), value >= 60 {
            framerate = "60"
        }

        var supplementCodecs = ""
        if let supplemental = format.supplementalCodecs {
            supplementCodecs = ",SUPPLEMENTAL-CODECS=\"\(supplemental)\""
        }
        var formatQuery = "&vr=\(format.videoRange.rawValue)"
        if let dvProfile = format.dolbyVisionProfile {
            formatQuery += "&dv=\(dvProfile)"
        }
        if format.isProbed {
            formatQuery += "&probed=1"
        }
        let uri = "\(URLs.customDashPrefix)\(videoInfo.count)?codec=\(info.codecs)&rate=\(info.frame_rate ?? framerate)&width=\(info.width ?? 0)&host=\(URL(string: url)?.host ?? "none")&range=\(info.id)\(formatQuery)"
        // 视频与每个音频组各组成一个 variant，共用同一个子播放列表
        let variants: [AudioGroup?] = audioGroups.isEmpty ? [nil] : audioGroups
        for audio in variants {
            let audioAttribute = audio.map { "AUDIO=\"\($0.id)\"," } ?? ""
            let codecs = audio.map { "\(format.codecs),\($0.codecs)" } ?? format.codecs
            // 音频接近恒定码率，只对视频部分按峰值声明
            let averageBandwidth = info.bandwidth + (audio?.bandwidth ?? 0)
            let bandwidth = Self.peakBandwidth(forAverage: info.bandwidth) + (audio?.bandwidth ?? 0)
            let content = """
            #EXT-X-STREAM-INF:\(audioAttribute)CODECS="\(codecs)"\(supplementCodecs),RESOLUTION=\(info.width ?? 0)x\(info.height ?? 0),FRAME-RATE=\(framerate),BANDWIDTH=\(bandwidth),AVERAGE-BANDWIDTH=\(averageBandwidth),VIDEO-RANGE=\(format.videoRange.rawValue)\(subtitlePlaceHolder)
            \(uri)

            """
            masterPlaylist.append(content)
        }
        videoInfo.append(PlaybackInfo(info: info, url: url, duration: duration))
    }

    /// 解析 HDR / 杜比视界候选流的初始化分段，得到真实的编码与色彩信息。
    /// 下载结果（含 sidx）由 SidxDownloader 缓存，AVPlayer 随后请求子播放列表时直接复用，不会产生额外请求。
    @MainActor
    private func probeVideoFormats(_ videos: [VideoPlayURLInfo.DashInfo.DashMediaInfo]) async -> [VideoPlayURLInfo.DashInfo.DashMediaInfo: VideoFormatInfo] {
        let candidates = Set(videos.filter { HLSVideoFormat.needsProbe(qn: $0.id, codecs: $0.codecs) })
        guard !candidates.isEmpty else { return [:] }
        let cache = segmentInfoCache
        return await withTaskGroup(of: (VideoPlayURLInfo.DashInfo.DashMediaInfo, VideoFormatInfo?).self) { group in
            for video in candidates {
                group.addTask {
                    let format = await withDeadline(seconds: formatProbeTimeout) {
                        await cache.sidx(from: video)?.format
                    }
                    return (video, format)
                }
            }
            var result = [VideoPlayURLInfo.DashInfo.DashMediaInfo: VideoFormatInfo]()
            for await (video, format) in group {
                if let format {
                    Logger.debug("probe video format \(video.id): \(String(describing: format))")
                    result[video] = format
                } else {
                    Logger.warn("probe video format failed: \(video.id) \(video.codecs), fallback to inferred format")
                }
            }
            return result
        }
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

    /// 每条音轨只写一个 rendition：子播放列表由 SidxDownloader 依次尝试各 CDN 生成，不需要按 URL 重复
    private func addAudioPlayBackInfo(info: VideoPlayURLInfo.DashInfo.DashMediaInfo, groupID: String, channels: String, duration: Int) -> AudioGroup? {
        guard let url = info.playableURLs.first else { return nil }
        let content = """
        #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="\(groupID)",NAME="Main",DEFAULT=YES,AUTOSELECT=YES,CHANNELS="\(channels)",URI="\(URLs.customDashPrefix)\(videoInfo.count)?codec=\(info.codecs)"

        """
        masterPlaylist.append(content)
        videoInfo.append(PlaybackInfo(info: info, url: url, duration: duration))
        return AudioGroup(id: groupID, codecs: info.codecs, bandwidth: info.bandwidth)
    }

    /// 杜比音轨的接口 codecs 只有 ec-3，起播前解析 dec3 得到声道布局以及是否为全景声
    @MainActor
    private func probeAudioFormat(_ audio: VideoPlayURLInfo.DashInfo.DashMediaInfo?) async -> AudioFormatInfo? {
        guard let audio else { return nil }
        let cache = segmentInfoCache
        let format = await withDeadline(seconds: formatProbeTimeout) {
            await cache.sidx(from: audio)?.audioFormat
        }
        if let format {
            Logger.debug("probe audio format \(audio.id): \(String(describing: format))")
        } else {
            Logger.warn("probe audio format failed: \(audio.id) \(audio.codecs), fallback to inferred channels")
        }
        return format
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

    @MainActor
    func setBilibili(info: VideoPlayURLInfo, subtitles: [SubtitleData], aid: Int) async {
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

        let dolby = Settings.losslessAudio ? info.dash.dolby : nil
        let dolbyAudio = dolby?.audio?.max(by: { $0.bandwidth < $1.bandwidth })
        async let dolbyFormat = probeAudioFormat(dolbyAudio)

        // 不按 AVPlayer.eligibleForHDRPlayback 过滤 HDR 流：Apple TV 设为 SDR 并开启「匹配动态范围」时，
        // 起播前它为 false，过滤后电视永远不会切换到 HDR。SDR 显示设备由 AVPlayer 按 VIDEO-RANGE 自行选流
        let probedFormats = await probeVideoFormats(videos)
        let videoFormats = videos.map { video in
            let format = HLSVideoFormat.resolve(qn: video.id,
                                                codecs: video.codecs,
                                                width: video.width,
                                                height: video.height,
                                                frameRate: video.frame_rate.flatMap { Double($0) },
                                                format: probedFormats[video])
            Logger.debug("video \(video.id) \(video.codecs) -> \(format.codecs) \(format.supplementalCodecs ?? "") \(format.videoRange.rawValue) (\(format.dynamicRangeDescription), probed: \(format.isProbed))")
            return (video: video, format: format)
        }

        var audios = [(info: VideoPlayURLInfo.DashInfo.DashMediaInfo, groupID: String, channels: String)]()
        if let dolbyAudio {
            var format = await dolbyFormat ?? AudioFormatInfo(sampleEntry: "ec-3", channelCount: 6)
            // dec3 可能没写 JOC 扩展：接口标为全景声（dolby.type 2 / 音质 30250）时按全景声声明
            if format.jocComplexityIndex == nil, dolby?.type == 2 || dolbyAudio.id == 30250 {
                format.jocComplexityIndex = 16
            }
            audios.append((dolbyAudio, "dolby", format.hlsChannels))
        } else if Settings.losslessAudio, let flac = info.dash.flac?.audio {
            // 有杜比时不加 FLAC：AVPlayer 起播选最高码率，FLAC 会压过杜比全景声
            audios.append((flac, "flac", "2"))
        }
        // Apple HLS 规范要求始终提供立体声 AAC，作为兼容兜底
        if let aac = info.dash.audio?.max(by: { $0.bandwidth < $1.bandwidth }) {
            audios.append((aac, "aac", "2"))
        }
        let audioGroups = audios.compactMap {
            addAudioPlayBackInfo(info: $0.info, groupID: $0.groupID, channels: $0.channels, duration: info.dash.duration)
        }

        for (video, format) in videoFormats {
            for url in video.playableURLs {
                addVideoPlayBackInfo(info: video, url: url, duration: info.dash.duration, format: format, audioGroups: audioGroups)
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
            #EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=\(Self.peakBandwidth(forAverage: video.bandwidth)),RESOLUTION=\(video.width!)x\(video.height!),URI="\(URLs.customDashPrefix)\(videoInfo.count)"

            """
            masterPlaylist.append(media)
            videoInfo.append(PlaybackInfo(info: video, url: url, duration: info.dash.duration))
        }

        masterPlaylist.append("\n#EXT-X-ENDLIST\n")

        // 预取 AVPlayer 大概率首选的视频流与默认音轨的 sidx，与 master playlist 的加载并行，缩短起播链路。
        // HDR 候选与杜比音轨在上面已经探测过，SidxDownloader 会直接复用缓存或等待进行中的下载
        let prefetchTargets = [videoFormats.first?.video, audios.first?.info].compactMap { $0 }
        for target in prefetchTargets {
            Task.detached { [segmentInfoCache] in
                _ = await segmentInfoCache.sidx(from: target)
            }
        }

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

        // 直接在 loader 串行队列处理，避免被主线程（弹幕渲染等）阻塞。
        // playlist 相关状态在 setBilibili 中写好，且发生在 setDelegate 之前，这里只读
        handleCustomPlaylistRequest(loadingRequest)
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
        /// 视频流初始化分段中解析出的格式信息（音频流为 nil）
        let format: VideoFormatInfo?
        /// 音频流初始化分段中解析出的格式信息（视频流为 nil）
        let audioFormat: AudioFormatInfo?
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
        let header = DashHeaderRange(segmentBase: info.segment_base)
        let range = header.map { "\($0.requestRange.lowerBound)-\($0.requestRange.upperBound)" } ?? info.segment_base.index_range
        let isVideo = info.mime_type.hasPrefix("video")
        for url in info.playableURLs.prefix(3) {
            if let res = try? await Self.session.request(url,
                                                         headers: ["Range": "bytes=\(range)",
                                                                   "Referer": "https://www.bilibili.com/"])
                .validate()
                .serializingData().result.get(),
                let indexData = header == nil ? res : header?.indexData(in: res),
                let segment = SidxParseUtil.processIndexData(data: indexData),
                !segment.segments.isEmpty
            {
                var format: VideoFormatInfo?
                var audioFormat: AudioFormatInfo?
                if let initData = header?.initData(in: res) {
                    if isVideo {
                        format = MP4FormatParser.parseVideoFormat(initSegment: initData)
                    } else {
                        audioFormat = MP4FormatParser.parseAudioFormat(initSegment: initData)
                    }
                }
                return SidxResult(sidx: segment, url: url, format: format, audioFormat: audioFormat)
            }
            Logger.warn("sidx download failed on \(URLComponents(string: url)?.host ?? url), try next url")
        }
        return nil
    }
}

/// DASH SegmentBase 中初始化分段（ftyp + moov）与 sidx 通常紧挨着，
/// 一次 Range 请求同时取回两者：sidx 用于生成分片列表，moov 用于解析 HDR / 杜比视界格式
struct DashHeaderRange {
    let initRange: ClosedRange<Int>?
    let indexRange: ClosedRange<Int>
    let requestRange: ClosedRange<Int>

    /// 两段之间间隔过大时不合并请求，只下载 sidx
    private static let maxMergeGap = 64 * 1024

    init?(segmentBase: VideoPlayURLInfo.DashInfo.DashSegmentBase) {
        guard let indexRange = Self.parse(segmentBase.index_range) else { return nil }
        self.indexRange = indexRange
        let initRange = Self.parse(segmentBase.initialization)
        if let initRange, initRange.upperBound < indexRange.lowerBound,
           indexRange.lowerBound - initRange.upperBound <= Self.maxMergeGap
        {
            self.initRange = initRange
            requestRange = initRange.lowerBound...indexRange.upperBound
        } else {
            self.initRange = nil
            requestRange = indexRange
        }
    }

    func indexData(in response: Data) -> Data? {
        slice(indexRange, of: response)
    }

    func initData(in response: Data) -> Data? {
        initRange.flatMap { slice($0, of: response) }
    }

    private func slice(_ range: ClosedRange<Int>, of response: Data) -> Data? {
        let lower = range.lowerBound - requestRange.lowerBound
        let upper = range.upperBound - requestRange.lowerBound
        guard lower >= 0, upper < response.count else { return nil }
        let start = response.startIndex
        // 重新生成从 0 开始索引的 Data，SidxParseUtil 按绝对下标读取
        return Data(response[(start + lower)...(start + upper)])
    }

    private static func parse(_ string: String) -> ClosedRange<Int>? {
        let parts = string.split(separator: "-")
        guard parts.count == 2, let lower = Int(parts[0]), let upper = Int(parts[1]), lower <= upper else {
            return nil
        }
        return lower...upper
    }
}

/// HDR 格式探测的最长等待时间，超时后按接口字段推断格式，不阻塞起播
private let formatProbeTimeout: TimeInterval = 3

/// 等待 operation 的结果，超过 seconds 秒返回 nil。
/// 超时后 operation 仍会在后台执行完毕（SidxDownloader 会缓存结果供后续复用）
private func withDeadline<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async -> T?) async -> T? {
    await withCheckedContinuation { continuation in
        let once = ResumeOnce<T?>(continuation)
        let timer = Task {
            try? await Task.sleep(for: .seconds(seconds))
            once.resume(nil)
        }
        Task {
            let value = await operation()
            once.resume(value)
            timer.cancel()
        }
    }
}

private final class ResumeOnce<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Never>?

    init(_ continuation: CheckedContinuation<T, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: T) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: value)
    }
}
