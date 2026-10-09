//
//  VideoFormatParser.swift
//  BilibiliLive
//
//  从 DASH 初始化分段（moov）中解析视频的真实编码与色彩信息，
//  用于给 HLS 主播放列表生成准确的 CODECS / SUPPLEMENTAL-CODECS / VIDEO-RANGE。
//  B 站接口返回的 codecs 字段只有粗略的 profile/level，无法区分 PQ 与 HLG，
//  杜比视界也只给出 dvh1.PP.LL（不含基础层兼容 ID），仅凭它推断很容易出错。
//  音频轨同理：杜比音轨只给出 ec-3，声道布局与是否为全景声要从 dec3 中解析，用于生成 CHANNELS。
//

import Foundation

/// 从视频初始化分段中解析出的格式信息
struct VideoFormatInfo: Hashable {
    struct DolbyVision: Hashable {
        let profile: Int
        let level: Int
        /// 基础层兼容 ID：0 无兼容（Profile 5），1 HDR10，2 SDR，4 HLG，6 UHD Blu-ray
        let compatibilityID: Int
        let hasEnhancementLayer: Bool
    }

    /// stsd 里的 sample entry 类型，如 hvc1 / hev1 / dvh1 / dvhe / avc1
    var sampleEntry = ""
    /// 由 hvcC 生成的完整 HEVC codec 字符串（RFC 6381），如 hvc1.2.4.L153.B0
    var hevcCodec: String?
    var bitDepth: Int?
    /// ITU-T H.273 取值：colour_primaries 9 = BT.2020；transfer 16 = PQ、18 = HLG
    var colourPrimaries: Int?
    var transferCharacteristics: Int?
    var matrixCoefficients: Int?
    var dolbyVision: DolbyVision?
    /// 是否带有 mdcv / clli（HDR10 静态元数据）
    var hasMasteringDisplayInfo = false
    var hasContentLightLevel = false
    /// sample entry 中的 hvcC / dvcC / dvvC 等配置 box（不含 box 头），键为 box 类型。
    /// 起播前切换电视显示模式时用它们构造 CMFormatDescription，与 AVPlayer 从初始化分段得到的一致
    var configurationAtoms: [String: Data] = [:]
}

/// 从音频初始化分段中解析出的格式信息
struct AudioFormatInfo: Hashable {
    /// stsd 里的 sample entry 类型，如 mp4a / ec-3 / ac-3 / fLaC
    var sampleEntry = ""
    /// 声道数（含 LFE）。E-AC-3 按 dec3 计算，其余取 AudioSampleEntry 的 channelcount
    var channelCount = 0
    /// E-AC-3 JOC（杜比全景声）的 complexity_index_type_a，即对象数；非全景声为 nil
    var jocComplexityIndex: Int?

    /// HLS EXT-X-MEDIA 的 CHANNELS 属性。Apple HLS 规范：全景声写 "<complexity_index_type_a>/JOC"，如 "16/JOC"
    var hlsChannels: String {
        if let jocComplexityIndex {
            return "\(jocComplexityIndex > 0 ? jocComplexityIndex : 16)/JOC"
        }
        return String(channelCount)
    }
}

enum MP4FormatParser {
    /// 解析 ftyp + moov（DASH initialization 范围）中第一个视频轨的格式
    static func parseVideoFormat(initSegment data: Data) -> VideoFormatInfo? {
        for entry in sampleEntries(initSegment: data) {
            if let info = parseVisualSampleEntry(type: entry.type, payload: entry.payload) {
                return info
            }
        }
        return nil
    }

    /// 解析 ftyp + moov 中第一个音频轨的格式
    static func parseAudioFormat(initSegment data: Data) -> AudioFormatInfo? {
        for entry in sampleEntries(initSegment: data) {
            if let info = parseAudioSampleEntry(type: entry.type, payload: entry.payload) {
                return info
            }
        }
        return nil
    }

    /// moov 中各轨道 stsd 里的 sample entry
    private static func sampleEntries(initSegment data: Data) -> [Box] {
        let bytes = [UInt8](data)
        guard let moov = boxes(in: bytes).first(where: { $0.type == "moov" })?.payload else {
            return []
        }
        var entries = [Box]()
        for trak in boxes(in: moov) where trak.type == "trak" {
            guard let stsd = findBox(path: ["mdia", "minf", "stbl", "stsd"], in: trak.payload),
                  stsd.count > 8
            else { continue }
            // stsd 是 FullBox：version(1) + flags(3) + entry_count(4)
            entries += boxes(in: Array(stsd[8...]))
        }
        return entries
    }

    // MARK: - Box

    struct Box {
        let type: String
        let payload: [UInt8]
    }

    static func boxes(in bytes: [UInt8]) -> [Box] {
        var result = [Box]()
        var offset = 0
        while offset + 8 <= bytes.count {
            var size = Int(readUInt32(bytes, offset))
            let type = fourCC(bytes, offset + 4)
            var headerSize = 8
            if size == 1 {
                guard offset + 16 <= bytes.count else { break }
                let largeSize = (UInt64(readUInt32(bytes, offset + 8)) << 32) | UInt64(readUInt32(bytes, offset + 12))
                guard largeSize <= UInt64(Int.max) else { break }
                size = Int(largeSize)
                headerSize = 16
            } else if size == 0 {
                size = bytes.count - offset
            }
            guard size >= headerSize else { break }
            // 初始化分段可能被截断，截断的 box 只保留已有部分
            let end = size > bytes.count - offset ? bytes.count : offset + size
            result.append(Box(type: type, payload: Array(bytes[(offset + headerSize)..<end])))
            offset = end
        }
        return result
    }

    private static func findBox(path: [String], in bytes: [UInt8]) -> [UInt8]? {
        var current = bytes
        for type in path {
            guard let box = boxes(in: current).first(where: { $0.type == type }) else {
                return nil
            }
            current = box.payload
        }
        return current
    }

    // MARK: - Sample Entry

    private static let visualSampleEntryHeaderSize = 78

    private static func parseVisualSampleEntry(type: String, payload: [UInt8]) -> VideoFormatInfo? {
        guard ["hvc1", "hev1", "dvh1", "dvhe", "avc1", "avc3", "dva1", "dvav"].contains(type),
              payload.count >= visualSampleEntryHeaderSize
        else {
            return nil
        }
        var info = VideoFormatInfo()
        info.sampleEntry = type
        var spsColour: (primaries: Int, transfer: Int, matrix: Int)?

        for child in boxes(in: Array(payload[visualSampleEntryHeaderSize...])) {
            switch child.type {
            case "hvcC":
                info.configurationAtoms[child.type] = Data(child.payload)
                if let hvcc = parseHVCC(child.payload) {
                    info.hevcCodec = hvcc.codec
                    info.bitDepth = hvcc.bitDepth
                    spsColour = hvcc.spsColour
                }
            case "dvcC", "dvvC", "dvwC":
                info.configurationAtoms[child.type] = Data(child.payload)
                info.dolbyVision = parseDolbyVisionConfig(child.payload)
            case "colr":
                if let colour = parseColr(child.payload) {
                    info.colourPrimaries = colour.primaries
                    info.transferCharacteristics = colour.transfer
                    info.matrixCoefficients = colour.matrix
                }
            case "mdcv", "SmDm":
                info.hasMasteringDisplayInfo = true
            case "clli", "CoLL":
                info.hasContentLightLevel = true
            default:
                break
            }
        }

        // colr 缺失或为 unspecified(2) 时，回退到 SPS 的 VUI 信息
        if let spsColour, info.transferCharacteristics == nil || info.transferCharacteristics == 2 {
            info.colourPrimaries = spsColour.primaries
            info.transferCharacteristics = spsColour.transfer
            info.matrixCoefficients = spsColour.matrix
        }
        return info
    }

    private static func parseColr(_ p: [UInt8]) -> (primaries: Int, transfer: Int, matrix: Int)? {
        guard p.count >= 10 else { return nil }
        let colourType = fourCC(p, 0)
        guard colourType == "nclx" || colourType == "nclc" else { return nil }
        return (Int(readUInt16(p, 4)), Int(readUInt16(p, 6)), Int(readUInt16(p, 8)))
    }

    /// DOVIDecoderConfigurationRecord（dvcC / dvvC / dvwC）
    static func parseDolbyVisionConfig(_ p: [UInt8]) -> VideoFormatInfo.DolbyVision? {
        guard p.count >= 5 else { return nil }
        let profile = Int(p[2] >> 1)
        let level = Int((p[2] & 0x01) << 5 | (p[3] >> 3))
        let elPresent = (p[3] >> 1) & 0x01 == 1
        let compatibilityID = Int(p[4] >> 4)
        return .init(profile: profile, level: level, compatibilityID: compatibilityID, hasEnhancementLayer: elPresent)
    }

    // MARK: - HEVC

    struct HVCCInfo {
        let codec: String
        let bitDepth: Int
        let spsColour: (primaries: Int, transfer: Int, matrix: Int)?
    }

    /// HEVCDecoderConfigurationRecord（ISO/IEC 14496-15 8.3.3）
    static func parseHVCC(_ p: [UInt8]) -> HVCCInfo? {
        guard p.count >= 23 else { return nil }
        let profileSpace = Int(p[1] >> 6)
        let tierFlag = Int((p[1] >> 5) & 0x01)
        let profileIdc = Int(p[1] & 0x1F)
        let compatibilityFlags = readUInt32(p, 2)
        let constraintFlags = Array(p[6..<12])
        let levelIdc = Int(p[12])
        let bitDepth = Int(p[17] & 0x07) + 8

        // 播放列表里统一声明为 hvc1：tvOS 同样能解码 hev1，但 HLS 规范要求写 hvc1
        let codec = hevcCodecString(prefix: "hvc1",
                                    profileSpace: profileSpace,
                                    profileIdc: profileIdc,
                                    compatibilityFlags: compatibilityFlags,
                                    tierFlag: tierFlag,
                                    levelIdc: levelIdc,
                                    constraintFlags: constraintFlags)

        var spsColour: (primaries: Int, transfer: Int, matrix: Int)?
        var offset = 23
        let numOfArrays = Int(p[22])
        arrays: for _ in 0..<numOfArrays {
            guard offset + 3 <= p.count else { break }
            let nalType = p[offset] & 0x3F
            let numNalus = Int(readUInt16(p, offset + 1))
            offset += 3
            for _ in 0..<numNalus {
                guard offset + 2 <= p.count else { break arrays }
                let length = Int(readUInt16(p, offset))
                offset += 2
                guard offset + length <= p.count else { break arrays }
                if nalType == 33, spsColour == nil {
                    spsColour = HEVCSPSParser.colourDescription(nal: Array(p[offset..<(offset + length)]))
                }
                offset += length
            }
        }
        return HVCCInfo(codec: codec, bitDepth: bitDepth, spsColour: spsColour)
    }

    /// 生成 RFC 6381 / ISO/IEC 14496-15 Annex E 格式的 HEVC codec 字符串
    static func hevcCodecString(prefix: String, profileSpace: Int, profileIdc: Int, compatibilityFlags: UInt32,
                                tierFlag: Int, levelIdc: Int, constraintFlags: [UInt8]) -> String
    {
        let space = ["", "A", "B", "C"][profileSpace & 0x03]
        // 兼容性标志按位逆序后以十六进制输出（省略前导 0）
        var reversed: UInt32 = 0
        for bit in 0..<32 where compatibilityFlags & (1 << bit) != 0 {
            reversed |= 1 << (31 - bit)
        }
        var codec = "\(prefix).\(space)\(profileIdc).\(String(reversed, radix: 16, uppercase: true)).\(tierFlag == 0 ? "L" : "H")\(levelIdc)"
        // 约束标志逐字节输出，省略末尾的 0 字节
        var constraints = constraintFlags
        while constraints.last == 0 {
            constraints.removeLast()
        }
        for byte in constraints {
            codec += "." + String(byte, radix: 16, uppercase: true)
        }
        return codec
    }

    // MARK: - Audio

    /// SampleEntry(8) + reserved(8) + channelcount(2) + samplesize(2) + pre_defined(2) + reserved(2) + samplerate(4)
    private static let audioSampleEntryHeaderSize = 28

    private static func parseAudioSampleEntry(type: String, payload: [UInt8]) -> AudioFormatInfo? {
        guard ["mp4a", "ec-3", "ac-3", "fLaC", "alac", "Opus"].contains(type),
              payload.count >= audioSampleEntryHeaderSize,
              // 只处理 ISO 格式（version 0），QuickTime v1 / v2 声音描述的字段布局不同
              readUInt16(payload, 8) == 0
        else {
            return nil
        }
        var info = AudioFormatInfo()
        info.sampleEntry = type
        info.channelCount = Int(readUInt16(payload, 16))
        for child in boxes(in: Array(payload[audioSampleEntryHeaderSize...])) where child.type == "dec3" {
            if let ec3 = parseEC3Config(child.payload) {
                info.channelCount = ec3.channelCount
                info.jocComplexityIndex = ec3.jocComplexityIndex
            }
        }
        return info
    }

    /// acmod 对应的主声道数（不含 LFE），acmod 0 为双单声道 1+1
    private static let ec3AcmodChannels = [2, 1, 2, 3, 3, 4, 4, 5]

    /// EC3SpecificBox（dec3，ETSI TS 102 366 附录 F.6）。
    /// 只统计第一个独立子流及其依赖子流（主节目）的声道；其后可选的 flag_ec3_extension_type_a 标记 JOC（杜比全景声）
    static func parseEC3Config(_ p: [UInt8]) -> (channelCount: Int, jocComplexityIndex: Int?)? {
        guard p.count >= 5 else { return nil }
        // data_rate(13) + num_ind_sub(3)
        let independentSubstreams = Int(p[1] & 0x07) + 1
        var channelCount = 0
        var offset = 2
        for index in 0..<independentSubstreams {
            guard offset + 3 <= p.count else { return nil }
            // fscod(2) bsid(5) reserved(1) asvc(1) bsmod(3) acmod(3) lfeon(1) reserved(3) num_dep_sub(4) + 1 bit
            let bits = Int(p[offset]) << 16 | Int(p[offset + 1]) << 8 | Int(p[offset + 2])
            let acmod = (bits >> 9) & 0x07
            let lfeon = (bits >> 8) & 0x01
            let dependentSubstreams = (bits >> 1) & 0x0F
            offset += 3
            var chanLoc = 0
            if dependentSubstreams > 0 {
                guard offset < p.count else { return nil }
                chanLoc = (bits & 0x01) << 8 | Int(p[offset])
                offset += 1
            }
            if index == 0 {
                channelCount = ec3AcmodChannels[acmod] + lfeon + ec3ChanLocChannels(chanLoc)
            }
        }
        // reserved(7) + flag_ec3_extension_type_a(1) + complexity_index_type_a(8)
        guard offset + 2 <= p.count, p[offset] & 0x01 == 1 else {
            return (channelCount, nil)
        }
        return (channelCount, Int(p[offset + 1]))
    }

    /// 依赖子流 chan_loc 中各位（bit 0 为最高位）新增的声道数：
    /// Lc/Rc、Lrs/Rrs、Cs、Ts、Lsd/Rsd、Lw/Rw、Lvh/Rvh、Cvh、LFE2
    private static func ec3ChanLocChannels(_ chanLoc: Int) -> Int {
        let channelsPerBit = [2, 2, 1, 1, 2, 2, 2, 1, 1]
        return channelsPerBit.enumerated().reduce(0) { sum, item in
            chanLoc & (1 << (8 - item.offset)) != 0 ? sum + item.element : sum
        }
    }

    // MARK: - Utils

    private static func readUInt32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16 | UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3])
    }

    private static func readUInt16(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
        UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
    }

    private static func fourCC(_ bytes: [UInt8], _ offset: Int) -> String {
        String(decoding: bytes[offset..<(offset + 4)], as: UTF8.self)
    }
}

// MARK: - HEVC SPS

/// 只解析到 VUI 的 video_signal_type 为止，用于取得 colour_primaries / transfer_characteristics / matrix_coeffs
enum HEVCSPSParser {
    private struct EndOfData: Error {}

    private struct BitReader {
        let bytes: [UInt8]
        var position = 0

        init(_ bytes: [UInt8]) {
            self.bytes = bytes
        }

        mutating func bits(_ count: Int) throws -> Int {
            var value = 0
            for _ in 0..<count {
                let index = position >> 3
                guard index < bytes.count else { throw EndOfData() }
                let bit = (bytes[index] >> (7 - UInt8(position & 7))) & 1
                value = (value << 1) | Int(bit)
                position += 1
            }
            return value
        }

        mutating func flag() throws -> Bool {
            try bits(1) == 1
        }

        mutating func skip(_ count: Int) throws {
            guard position + count <= bytes.count * 8 else { throw EndOfData() }
            position += count
        }

        /// ue(v)
        mutating func ue() throws -> Int {
            var leadingZeros = 0
            while try bits(1) == 0 {
                leadingZeros += 1
                guard leadingZeros < 32 else { throw EndOfData() }
            }
            let suffix = try bits(leadingZeros)
            return (1 << leadingZeros) - 1 + suffix
        }

        /// se(v)
        mutating func se() throws -> Int {
            let value = try ue()
            return value & 1 == 1 ? (value + 1) / 2 : -(value / 2)
        }
    }

    /// 去除防竞争字节（00 00 03 -> 00 00）
    private static func removeEmulationPrevention(_ nal: [UInt8]) -> [UInt8] {
        var result = [UInt8]()
        result.reserveCapacity(nal.count)
        var zeros = 0
        for byte in nal {
            if zeros >= 2 && byte == 0x03 {
                zeros = 0
                continue
            }
            zeros = byte == 0 ? zeros + 1 : 0
            result.append(byte)
        }
        return result
    }

    static func colourDescription(nal: [UInt8]) -> (primaries: Int, transfer: Int, matrix: Int)? {
        let rbsp = removeEmulationPrevention(nal)
        // NAL header 2 字节，type 33 = SPS
        guard rbsp.count > 2, (rbsp[0] >> 1) & 0x3F == 33 else { return nil }
        var r = BitReader(Array(rbsp[2...]))
        do {
            try r.skip(4) // sps_video_parameter_set_id
            let maxSubLayersMinus1 = try r.bits(3)
            try r.skip(1) // sps_temporal_id_nesting_flag
            try skipProfileTierLevel(&r, maxSubLayersMinus1: maxSubLayersMinus1)
            _ = try r.ue() // sps_seq_parameter_set_id
            let chromaFormatIdc = try r.ue()
            if chromaFormatIdc == 3 {
                try r.skip(1) // separate_colour_plane_flag
            }
            _ = try r.ue() // pic_width_in_luma_samples
            _ = try r.ue() // pic_height_in_luma_samples
            if try r.flag() { // conformance_window_flag
                for _ in 0..<4 { _ = try r.ue() }
            }
            _ = try r.ue() // bit_depth_luma_minus8
            _ = try r.ue() // bit_depth_chroma_minus8
            let log2MaxPocLsbMinus4 = try r.ue()
            let subLayerOrderingInfoPresent = try r.flag()
            for _ in (subLayerOrderingInfoPresent ? 0 : maxSubLayersMinus1)...maxSubLayersMinus1 {
                _ = try r.ue() // sps_max_dec_pic_buffering_minus1
                _ = try r.ue() // sps_max_num_reorder_pics
                _ = try r.ue() // sps_max_latency_increase_plus1
            }
            for _ in 0..<6 { _ = try r.ue() } // coding block / transform block sizes & hierarchy depths
            if try r.flag() { // scaling_list_enabled_flag
                if try r.flag() { // sps_scaling_list_data_present_flag
                    try skipScalingListData(&r)
                }
            }
            try r.skip(2) // amp_enabled_flag, sample_adaptive_offset_enabled_flag
            if try r.flag() { // pcm_enabled_flag
                try r.skip(8) // pcm_sample_bit_depth_luma/chroma_minus1
                _ = try r.ue()
                _ = try r.ue()
                try r.skip(1) // pcm_loop_filter_disabled_flag
            }
            try skipShortTermRefPicSets(&r)
            if try r.flag() { // long_term_ref_pics_present_flag
                let count = try r.ue()
                for _ in 0..<count {
                    try r.skip(log2MaxPocLsbMinus4 + 4) // lt_ref_pic_poc_lsb_sps
                    try r.skip(1) // used_by_curr_pic_lt_sps_flag
                }
            }
            try r.skip(2) // sps_temporal_mvp_enabled_flag, strong_intra_smoothing_enabled_flag
            guard try r.flag() else { return nil } // vui_parameters_present_flag

            if try r.flag() { // aspect_ratio_info_present_flag
                if try r.bits(8) == 255 { // aspect_ratio_idc == EXTENDED_SAR
                    try r.skip(32)
                }
            }
            if try r.flag() { // overscan_info_present_flag
                try r.skip(1)
            }
            guard try r.flag() else { return nil } // video_signal_type_present_flag
            try r.skip(4) // video_format, video_full_range_flag
            guard try r.flag() else { return nil } // colour_description_present_flag
            let primaries = try r.bits(8)
            let transfer = try r.bits(8)
            let matrix = try r.bits(8)
            return (primaries, transfer, matrix)
        } catch {
            return nil
        }
    }

    private static func skipProfileTierLevel(_ r: inout BitReader, maxSubLayersMinus1: Int) throws {
        // general_profile_space ~ general_level_idc，共 96 bit
        try r.skip(96)
        var profilePresent = [Bool]()
        var levelPresent = [Bool]()
        for _ in 0..<maxSubLayersMinus1 {
            profilePresent.append(try r.flag())
            levelPresent.append(try r.flag())
        }
        if maxSubLayersMinus1 > 0 {
            try r.skip(2 * (8 - maxSubLayersMinus1)) // reserved_zero_2bits
        }
        for i in 0..<maxSubLayersMinus1 {
            if profilePresent[i] { try r.skip(88) }
            if levelPresent[i] { try r.skip(8) }
        }
    }

    private static func skipScalingListData(_ r: inout BitReader) throws {
        for sizeId in 0..<4 {
            var matrixId = 0
            while matrixId < 6 {
                if try r.flag() == false { // scaling_list_pred_mode_flag
                    _ = try r.ue() // scaling_list_pred_matrix_id_delta
                } else {
                    let coefNum = min(64, 1 << (4 + (sizeId << 1)))
                    if sizeId > 1 {
                        _ = try r.se() // scaling_list_dc_coef_minus8
                    }
                    for _ in 0..<coefNum {
                        _ = try r.se() // scaling_list_delta_coef
                    }
                }
                matrixId += sizeId == 3 ? 3 : 1
            }
        }
    }

    private static func skipShortTermRefPicSets(_ r: inout BitReader) throws {
        let numSets = try r.ue()
        guard numSets <= 64 else { throw EndOfData() }
        var numDeltaPocs = [Int](repeating: 0, count: numSets)
        for idx in 0..<numSets {
            let interRefPicSetPrediction = try idx != 0 ? r.flag() : false
            if interRefPicSetPrediction {
                // SPS 中 delta_idx_minus1 不出现，参考集固定为前一个
                try r.skip(1) // delta_rps_sign
                _ = try r.ue() // abs_delta_rps_minus1
                var count = 0
                for _ in 0...numDeltaPocs[idx - 1] {
                    let usedByCurrPic = try r.flag()
                    let useDelta = try usedByCurrPic ? true : r.flag()
                    if useDelta { count += 1 }
                }
                numDeltaPocs[idx] = count
            } else {
                let negative = try r.ue()
                let positive = try r.ue()
                guard negative + positive <= 32 else { throw EndOfData() }
                for _ in 0..<(negative + positive) {
                    _ = try r.ue() // delta_poc_s0/s1_minus1
                    try r.skip(1) // used_by_curr_pic_s0/s1_flag
                }
                numDeltaPocs[idx] = negative + positive
            }
        }
    }
}

// MARK: - HLS

/// 视频流在 HLS 主播放列表中的声明
struct HLSVideoFormat: Equatable {
    enum VideoRange: String {
        case sdr = "SDR"
        case pq = "PQ"
        case hlg = "HLG"
    }

    var codecs: String
    var supplementalCodecs: String?
    var videoRange: VideoRange
    /// 按杜比视界声明时的 Profile / level / 基础层兼容 ID
    var dolbyVision: VideoFormatInfo.DolbyVision?
    /// 是否由初始化分段解析得到（否则为按接口字段推断）
    var isProbed = false

    /// 用于调试显示的杜比视界 Profile，如 "5"、"8.4"
    var dolbyVisionProfile: String? {
        guard let dolbyVision else { return nil }
        return dolbyVision.profile == 5 ? "5" : "\(dolbyVision.profile).\(dolbyVision.compatibilityID)"
    }

    var isHDR: Bool {
        videoRange != .sdr || dolbyVisionProfile != nil
    }

    /// 主播放列表按 30fps 声明 HDR 档位时，杜比视界 level 也换成同分辨率 30fps 对应的 level；
    /// dolbyVision 中保留实际 level，切换显示模式时使用
    func declaredAt30fps(width: Int?, height: Int?) -> HLSVideoFormat {
        guard let dolbyVision else { return self }
        let level = min(dolbyVision.level, Self.dolbyVisionLevel(width: width, height: height, frameRate: 30))
        var result = self
        if dolbyVision.profile == 5 {
            result.codecs = String(format: "dvh1.05.%02d", level)
        } else if let brand = supplementalCodecs?.split(separator: "/").last {
            result.supplementalCodecs = String(format: "dvh1.%02d.%02d/", dolbyVision.profile, level) + brand
        }
        return result
    }

    var dynamicRangeDescription: String {
        if let dolbyVisionProfile {
            return "Dolby Vision \(dolbyVisionProfile)"
        }
        switch videoRange {
        case .sdr: return "SDR"
        case .pq: return "HDR10"
        case .hlg: return "HLG"
        }
    }

    enum Quality {
        static let hdr = 125
        static let dolbyVision = 126
    }

    /// 是否可能是 HDR / 杜比视界流，需要解析初始化分段确认格式
    static func needsProbe(qn: Int, codecs: String) -> Bool {
        if qn == Quality.hdr || qn == Quality.dolbyVision {
            return true
        }
        let lower = codecs.lowercased()
        // 杜比视界，或 HEVC Main 10（profile 2）
        return lower.hasPrefix("dvh") || lower.hasPrefix("hev1.2.") || lower.hasPrefix("hvc1.2.")
    }

    static func resolve(qn: Int, codecs apiCodecs: String, width: Int?, height: Int?, frameRate: Double?,
                        format: VideoFormatInfo?) -> HLSVideoFormat
    {
        if let format, let resolved = resolve(format: format, qn: qn, apiCodecs: apiCodecs, width: width, height: height, frameRate: frameRate) {
            return resolved
        }
        return infer(qn: qn, codecs: apiCodecs, width: width, height: height, frameRate: frameRate)
    }

    /// 根据初始化分段中的真实信息生成声明
    private static func resolve(format: VideoFormatInfo, qn: Int, apiCodecs: String, width: Int?, height: Int?, frameRate: Double?) -> HLSVideoFormat? {
        let isHEVC = ["hvc1", "hev1", "dvh1", "dvhe"].contains(format.sampleEntry)
        guard isHEVC else { return nil }
        let baseCodec = format.hevcCodec ?? normalize(codecs: apiCodecs)

        var range: VideoRange?
        switch format.transferCharacteristics ?? -1 {
        case 16: range = .pq
        case 18: range = .hlg
        case 1, 6, 14, 15: range = .sdr
        default: range = nil
        }

        var dolbyVision = format.dolbyVision
        if dolbyVision == nil {
            dolbyVision = dolbyVisionHint(qn: qn, codecs: apiCodecs, width: width, height: height, frameRate: frameRate, range: range)
        }

        if let dv = dolbyVision, dv.hasEnhancementLayer == false {
            switch dv.profile {
            case 5:
                // Profile 5 没有可兼容的基础层，只能以杜比视界播放
                return HLSVideoFormat(codecs: String(format: "dvh1.05.%02d", dv.level),
                                      supplementalCodecs: nil,
                                      videoRange: .pq,
                                      dolbyVision: dv,
                                      isProbed: true)
            case 8:
                // Profile 8 基础层可按 HDR10 / SDR / HLG 独立播放，杜比视界通过 SUPPLEMENTAL-CODECS 声明
                let compatibleRange: VideoRange? = switch dv.compatibilityID {
                case 1, 6: .pq
                case 2: .sdr
                case 4: .hlg
                default: nil
                }
                // 以兼容 ID 为准：HLG 基础层的 colr / VUI 可能按 BT.2100 的兼容做法写成 14（BT.2020），
                // 再用 alternative transfer characteristics SEI 标记 HLG，只看传输特性会误判为 SDR
                let finalRange = compatibleRange ?? range ?? .pq
                let brand: String = switch finalRange {
                case .pq: "db1p"
                case .sdr: "db2g"
                case .hlg: "db4h"
                }
                let dvCodec = String(format: "dvh1.08.%02d", dv.level)
                // 缺少 hvcC 时接口 codecs 可能是 dvh1.08.LL，基础层声明需要换成对应 level 的 HEVC Main 10
                let hevcCodec = baseCodec.hasPrefix("hvc1.") ? dolbyVisionBaseCodec(baseCodec) : hevcBaseCodec(forDolbyVisionLevel: dv.level)
                return HLSVideoFormat(codecs: hevcCodec,
                                      supplementalCodecs: "\(dvCodec)/\(brand)",
                                      videoRange: finalRange,
                                      dolbyVision: dv,
                                      isProbed: true)
            default:
                break
            }
        }

        // Profile 7 等 Apple 不支持的杜比视界，退回按基础层（HDR10）播放
        guard let baseRange = range ?? (dolbyVision != nil ? .pq : nil) else {
            return nil
        }
        return HLSVideoFormat(codecs: baseCodec, supplementalCodecs: nil, videoRange: baseRange, dolbyVision: nil, isProbed: true)
    }

    /// 初始化分段里没有 dvcC / dvvC，但接口标明是杜比视界时（B 站 126 常返回 hvc1.2.4.L150.90），
    /// 仍按杜比视界声明，否则只会以 HLG / HDR10 播放。Profile / level 取自接口 codecs，缺失时按 Profile 8 与分辨率估算；
    /// 兼容 ID 按实际传输特性确定，PQ 为 8.1，其余按 B 站杜比视界的 8.4（HLG）处理
    private static func dolbyVisionHint(qn: Int, codecs: String, width: Int?, height: Int?, frameRate: Double?,
                                        range: VideoRange?) -> VideoFormatInfo.DolbyVision?
    {
        let parts = normalize(codecs: codecs).split(separator: ".").map(String.init)
        let isAPIDolbyVision = parts.first == "dvh1"
        guard isAPIDolbyVision || qn == Quality.dolbyVision else { return nil }
        let profile = isAPIDolbyVision && parts.count >= 2 ? Int(parts[1]) ?? 8 : 8
        guard profile == 5 || profile == 8 else { return nil }
        let apiLevel = isAPIDolbyVision && parts.count >= 3 ? Int(parts[2]) : nil
        let level = apiLevel ?? dolbyVisionLevel(width: width, height: height, frameRate: frameRate)
        let compatibilityID = profile == 5 ? 0 : range == .pq ? 1 : 4
        return .init(profile: profile, level: level, compatibilityID: compatibilityID, hasEnhancementLayer: false)
    }

    /// 杜比视界基础层的约束标志统一声明为 B0（Apple HLS 规范示例的写法）。
    /// B 站流里是 90，此前按 hvc1.2.4.L150.90 声明时报 -12860，改为 B0 并加上 SUPPLEMENTAL-CODECS 后可正常播放
    private static func dolbyVisionBaseCodec(_ codec: String) -> String {
        let parts = codec.split(separator: ".")
        guard parts.count >= 4 else { return codec }
        return parts.prefix(4).joined(separator: ".") + ".B0"
    }

    /// 初始化分段下载/解析失败时，按接口返回的 qn 与 codecs 推断
    private static func infer(qn: Int, codecs apiCodecs: String, width: Int?, height: Int?, frameRate: Double?) -> HLSVideoFormat {
        let codecs = normalize(codecs: apiCodecs)
        let parts = codecs.split(separator: ".").map(String.init)

        if parts.first == "dvh1", parts.count >= 3, let profile = Int(parts[1]) {
            let level = Int(parts[2]) ?? dolbyVisionLevel(width: width, height: height, frameRate: frameRate)
            if profile == 5 {
                return HLSVideoFormat(codecs: String(format: "dvh1.05.%02d", level), supplementalCodecs: nil,
                                      videoRange: .pq, dolbyVision: .init(profile: 5, level: level, compatibilityID: 0, hasEnhancementLayer: false))
            }
            if profile == 8 {
                // dvh1.08.LL 中的 LL 是杜比视界 level 而不是 8.x 的兼容 ID；
                // B 站的杜比视界为 Profile 8.4（HLG 基础层），无法解析时按此处理
                return HLSVideoFormat(codecs: hevcBaseCodec(forDolbyVisionLevel: level),
                                      supplementalCodecs: String(format: "dvh1.08.%02d/db4h", level),
                                      videoRange: .hlg, dolbyVision: .init(profile: 8, level: level, compatibilityID: 4, hasEnhancementLayer: false))
            }
        }

        if qn == Quality.dolbyVision, parts.first == "hvc1", parts.count >= 4, parts[1] == "2" {
            // 杜比视界以 HEVC Main 10 形式返回（如 hev1.2.4.L153.90），同样按 Profile 8.4 处理
            let level = dolbyVisionLevel(width: width, height: height, frameRate: frameRate)
            return HLSVideoFormat(codecs: "hvc1.2.4.\(parts[3]).B0",
                                  supplementalCodecs: String(format: "dvh1.08.%02d/db4h", level),
                                  videoRange: .hlg, dolbyVision: .init(profile: 8, level: level, compatibilityID: 4, hasEnhancementLayer: false))
        }

        if qn == Quality.hdr {
            return HLSVideoFormat(codecs: codecs, supplementalCodecs: nil, videoRange: .pq, dolbyVision: nil)
        }
        return HLSVideoFormat(codecs: codecs, supplementalCodecs: nil, videoRange: .sdr, dolbyVision: nil)
    }

    /// hev1 / dvhe 在 HLS 中统一声明为 hvc1 / dvh1
    static func normalize(codecs: String) -> String {
        if codecs.hasPrefix("hev1.") {
            return "hvc1." + codecs.dropFirst(5)
        }
        if codecs.hasPrefix("dvhe.") {
            return "dvh1." + codecs.dropFirst(5)
        }
        return codecs
    }

    /// 按分辨率与帧率估算杜比视界 level（Dolby Vision Profiles and Levels 规范）
    static func dolbyVisionLevel(width: Int?, height: Int?, frameRate: Double?) -> Int {
        let pixels = (width ?? 3840) * (height ?? 2160)
        let fps = frameRate ?? 30
        if pixels <= 1280 * 720 {
            return fps <= 24 ? 1 : fps <= 30 ? 2 : 4
        }
        if pixels <= 1920 * 1080 {
            return fps <= 24 ? 3 : fps <= 30 ? 4 : 5
        }
        if pixels <= 3840 * 2160 {
            return fps <= 24 ? 6 : fps <= 30 ? 7 : fps <= 48 ? 8 : fps <= 60 ? 9 : 10
        }
        return fps <= 60 ? 11 : 12
    }

    private static func hevcBaseCodec(forDolbyVisionLevel level: Int) -> String {
        // level 1~5 为 1080p 及以下，HEVC level 4.1(L123) 即可；4K 60fps 以内用 5.1(L153)，4K 120fps 用 5.2(L156)，8K 用 6.1(L183)
        switch level {
        case ...5: return "hvc1.2.4.L123.B0"
        case 6...9: return "hvc1.2.4.L153.B0"
        case 10: return "hvc1.2.4.L156.B0"
        default: return "hvc1.2.4.L183.B0"
        }
    }
}
