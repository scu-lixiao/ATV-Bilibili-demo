//
//  HDRDisplaySwitcher.swift
//  BilibiliLive
//
//  起播前把电视切换到 HDR / 杜比视界显示模式。
//  主播放列表里只有最高画质是 HDR 档位，其余都是 SDR。Apple TV 输出设为 SDR 并开启「匹配动态范围」时，
//  AVPlayer 起播那一刻 HDR 档位不可用，会先选 SDR 档位；AVKit 随后才把电视切到 HDR，
//  但同一个 AVPlayerItem 不会再从 SDR 档位升到 HDR 档位，结果电视进入了 HDR 模式，画面仍是 SDR。
//  连播时电视已处于 HDR 模式，AVPlayer 起播就会选 HDR 档位，所以在创建 AVPlayerItem 之前先完成切换。
//

import AVKit
import CoreMedia

enum HDRDisplaySwitcher {
    /// 是否由这里设置了 preferredDisplayCriteria，退出播放或连播到其他视频时需要还原
    private static var isCriteriaApplied = false

    private static let dolbyVisionAtomTypes: Set<String> = ["dvcC", "dvvC", "dvwC"]

    /// 显示模式的标准刷新率。B 站接口的帧率是按时间戳算出的均值（如 59.995、62.5、24.390），
    /// 原样传给 AVDisplayCriteria 时系统找不到对应的显示模式，连动态范围也不会切换
    private static let standardRefreshRates: [Float] = [24000 / 1001, 24, 25, 30000 / 1001, 30, 50, 60000 / 1001, 60]

    /// 按 HDR / 杜比视界流生成显示模式要求，SDR 流返回 nil
    static func criteria(for format: HLSVideoFormat, probe: VideoFormatInfo?, width: Int, height: Int, frameRate: Double) -> AVDisplayCriteria? {
        guard format.isHDR else { return nil }
        // 与 AVPlayer 从初始化分段得到的格式描述保持一致：BT.2020 色彩 + PQ / HLG 传输特性，
        // 杜比视界再带上 dvcC / dvvC，系统据此选择杜比视界模式
        var extensions: [CFString: Any] = [
            kCMFormatDescriptionExtension_ColorPrimaries: kCMFormatDescriptionColorPrimaries_ITU_R_2020,
            kCMFormatDescriptionExtension_TransferFunction: format.videoRange == .hlg
                ? kCMFormatDescriptionTransferFunction_ITU_R_2100_HLG
                : kCMFormatDescriptionTransferFunction_SMPTE_ST_2084_PQ,
            kCMFormatDescriptionExtension_YCbCrMatrix: kCMFormatDescriptionYCbCrMatrix_ITU_R_2020,
        ]
        var atoms = [String: Data]()
        if let hvcC = probe?.configurationAtoms["hvcC"] {
            atoms["hvcC"] = hvcC
        }
        if let dolbyVision = format.dolbyVision {
            let atom = dolbyVisionAtom(dolbyVision, probe: probe)
            atoms[atom.type] = atom.record
        }
        if !atoms.isEmpty {
            extensions[kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms] = atoms
        }
        // Profile 5 在播放列表中声明为 dvh1，其余以 HEVC 基础层声明
        let codecType = format.dolbyVision?.profile == 5 ? kCMVideoCodecType_DolbyVisionHEVC : kCMVideoCodecType_HEVC
        var description: CMVideoFormatDescription?
        let status = CMVideoFormatDescriptionCreate(allocator: kCFAllocatorDefault,
                                                    codecType: codecType,
                                                    width: Int32(width),
                                                    height: Int32(height),
                                                    extensions: extensions as CFDictionary,
                                                    formatDescriptionOut: &description)
        guard status == noErr, let description else {
            Logger.warn("[display] create format description failed: \(status)")
            return nil
        }
        let refreshRate = standardRefreshRates.min { abs($0 - Float(frameRate)) < abs($1 - Float(frameRate)) }!
        Logger.debug("[display] HDR criteria: \(format.dynamicRangeDescription) \(width)x\(height)@\(frameRate) -> \(refreshRate)Hz atoms: \(atoms.keys.sorted())")
        return AVDisplayCriteria(refreshRate: refreshRate, formatDescription: description)
    }

    /// 初始化分段中有杜比视界配置时原样使用；按接口推断时自行生成 DOVIDecoderConfigurationRecord
    private static func dolbyVisionAtom(_ dolbyVision: VideoFormatInfo.DolbyVision, probe: VideoFormatInfo?) -> (type: String, record: Data) {
        if probe?.dolbyVision == dolbyVision,
           let atom = probe?.configurationAtoms.first(where: { dolbyVisionAtomTypes.contains($0.key) })
        {
            return (atom.key, atom.value)
        }
        // version 1.0；dv_profile(7) dv_level(6) rpu_present(1) el_present(1) bl_present(1)；
        // dv_bl_signal_compatibility_id(4)，其余为保留位
        var record = Data(count: 24)
        record[0] = 1
        record[2] = UInt8(dolbyVision.profile << 1 | (dolbyVision.level >> 5) & 0x01)
        record[3] = UInt8((dolbyVision.level & 0x1F) << 3 | 0b101)
        record[4] = UInt8(dolbyVision.compatibilityID << 4)
        // Profile 7 及以下用 dvcC，8~10 用 dvvC
        return (dolbyVision.profile > 7 ? "dvvC" : "dvcC", record)
    }

    /// 请求切换显示模式，并等待切换完成。电视已经是目标模式、不支持或用户设置不允许时不会切换，等待约 1 秒后返回
    @MainActor
    static func apply(_ criteria: AVDisplayCriteria, on manager: AVDisplayManager) async throws {
        let clock = ContinuousClock()
        let begin = clock.now
        var startedAt: ContinuousClock.Instant?
        var endedAt: ContinuousClock.Instant?
        let observers = [
            NotificationCenter.default.addObserver(forName: .AVDisplayManagerModeSwitchStart, object: nil, queue: .main) { _ in
                startedAt = clock.now
            },
            NotificationCenter.default.addObserver(forName: .AVDisplayManagerModeSwitchEnd, object: nil, queue: .main) { _ in
                endedAt = clock.now
            },
        ]
        defer { observers.forEach { NotificationCenter.default.removeObserver($0) } }

        isCriteriaApplied = true
        manager.preferredDisplayCriteria = criteria

        // 切换是异步开始的
        try await wait(upTo: .seconds(1)) { startedAt != nil || manager.isDisplayModeSwitchInProgress }
        guard startedAt != nil || manager.isDisplayModeSwitchInProgress else {
            Logger.info("[display] no mode switch, HDR eligible: \(AVPlayer.eligibleForHDRPlayback), modes: \(AVPlayer.availableHDRModes.rawValue)")
            return
        }
        try await wait(upTo: .seconds(8)) { endedAt != nil || !manager.isDisplayModeSwitchInProgress }
        // 切换结束后 HDR 可用状态可能稍晚才更新，AVPlayer 起播选档位依据的是它
        try await wait(upTo: .seconds(1)) { AVPlayer.eligibleForHDRPlayback }
        Logger.info("[display] mode switch done in \(begin.duration(to: clock.now)), start: \(startedAt.map { begin.duration(to: $0).description } ?? "nil"), end: \(endedAt.map { begin.duration(to: $0).description } ?? "nil"), HDR eligible: \(AVPlayer.eligibleForHDRPlayback), modes: \(AVPlayer.availableHDRModes.rawValue)")
    }

    /// 还原为系统默认显示模式（只还原这里设置过的）
    static func reset(on manager: AVDisplayManager?) {
        guard isCriteriaApplied else { return }
        isCriteriaApplied = false
        manager?.preferredDisplayCriteria = nil
    }

    @MainActor
    private static func wait(upTo timeout: Duration, until condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + timeout
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
    }
}
