//
//  Settings.swift
//  BilibiliLive
//
//  Created by whw on 2022/10/19.
//

import Combine
import Foundation
import SwiftUI

enum FeedDisplayStyle: Codable, CaseIterable {
    case large
    case normal
    case sideBar

    var hideInSetting: Bool {
        self == .sideBar
    }
}

class Defaults {
    static let shared = Defaults()
    private init() {}

    @Published(key: "Settings.danmuStatus") var showDanmu = true
}

enum Settings {
    @UserDefaultCodable("Settings.displayStyle", defaultValue: .normal)
    static var displayStyle: FeedDisplayStyle

    @UserDefault("Settings.direatlyEnterVideo", defaultValue: false)
    static var direatlyEnterVideo: Bool

    @UserDefaultCodable("Settings.mediaQuality", defaultValue: .quality_1080p)
    static var mediaQuality: MediaQualityEnum

    @UserDefaultCodable("Settings.mediaPlayerSpeed", defaultValue: PlaySpeed.default)
    static var mediaPlayerSpeed: PlaySpeed

    @UserDefaultCodable("Settings.danmuArea", defaultValue: .style_75)
    static var danmuArea: DanmuArea

    @UserDefaultCodable("Settings.danmuSize", defaultValue: .size_36)
    static var danmuSize: DanmuSize

    @UserDefaultCodable("Settings.danmuAILevel", defaultValue: 1)
    static var danmuAILevel: Int32

    @UserDefaultCodable("Settings.danmuDuration", defaultValue: 8)
    static var danmuDuration: Double

    @UserDefault("Settings.losslessAudio", defaultValue: false)
    static var losslessAudio: Bool
    
    @UserDefault("Settings.audioPassthrough", defaultValue: false)
    static var audioPassthrough: Bool

    @UserDefault("Settings.preferAvc", defaultValue: false)
    static var preferAvc: Bool
    
    @UserDefaultCodable("Settings.codecPreference", defaultValue: .auto)
    static var codecPreference: CodecPreference

    @UserDefault("Settings.danmuMask", defaultValue: true)
    static var danmuMask: Bool

    @UserDefault("Settings.vnMask", defaultValue: false)
    static var vnMask: Bool

    @UserDefault("Settings.loadHighestVideoOnly", defaultValue: false)
    static var loadHighestVideoOnly: Bool

    @UserDefault("Settings.contentMatch", defaultValue: true)
    static var contentMatch: Bool

    @UserDefault("Settings.contentMatchOnlyInHDR", defaultValue: true)
    static var contentMatchOnlyInHDR: Bool

    @UserDefault("Settings.continuePlay", defaultValue: true)
    static var continuePlay: Bool

    @UserDefault("DLNA.uuid", defaultValue: "")
    static var uuid: String

    @UserDefault("DLNA.enable", defaultValue: true)
    static var enableDLNA: Bool

    @UserDefault("Settings.continouslyPlay", defaultValue: true)
    static var continouslyPlay: Bool

    @UserDefault("Settings.loopPlay", defaultValue: false)
    static var loopPlay: Bool

    @UserDefault("Settings.play.autoSkip", defaultValue: true)
    static var autoSkip: Bool

    @UserDefault("Settings.showRelatedVideoInCurrentVC", defaultValue: true)
    static var showRelatedVideoInCurrentVC: Bool

    @UserDefault("Settings.requestHotWithoutCookie", defaultValue: false)
    static var requestHotWithoutCookie: Bool

    @UserDefault("Settings.arealimit.unlock", defaultValue: false)
    static var areaLimitUnlock: Bool

    @UserDefault("Settings.arealimit.customServer", defaultValue: "")
    static var areaLimitCustomServer: String

    @UserDefault("Settings.ui.sideMenuAutoSelectChange", defaultValue: false)
    static var sideMenuAutoSelectChange: Bool

    @UserDefaultCodable("Settings.SponsorBlockType", defaultValue: SponsorBlockType.none)
    static var enableSponsorBlock: SponsorBlockType

    @UserDefault("Settings.danmuFilter", defaultValue: false)
    static var enableDanmuFilter: Bool

    @UserDefault("Settings.danmuRemoveDup", defaultValue: false)
    static var enableDanmuRemoveDup: Bool

    @UserDefaultCodable("Settings.danmuAlpha", defaultValue: .alpha_10)
    static var danmuAlpha: DanmuAlpha

    @UserDefaultCodable("Settings.danmuStrokeWidth", defaultValue: .width_20)
    static var danmuStrokeWidth: DanmuStrokeWidth

    @UserDefaultCodable("Settings.danmuStrokeAlpha", defaultValue: .alpha_08)
    static var danmuStrokeAlpha: DanmuStrokeAlpha

    @UserDefaultCodable("Settings.danmuRenderMode", defaultValue: .cgImageCache)
    static var danmuRenderMode: DanmakuRenderMode
}

enum DanmakuRenderMode: String, Codable, CaseIterable {
    case none           // 不使用缓存，每次实时渲染
    case cgImageCache   // 使用 CGImage 缓存（推荐）
    
    var title: String {
        switch self {
        case .none:
            return "无缓存"
        case .cgImageCache:
            return "CGImage 缓存"
        }
    }
    
    var description: String {
        switch self {
        case .none:
            return "每次实时渲染，CPU 占用高"
        case .cgImageCache:
            return "缓存弹幕图片，性能提升 15-50 倍"
        }
    }
}

struct MediaQuality {
    var qn: Int
    var fnval: Int
}

enum SponsorBlockType: String, Codable, CaseIterable {
    case none
    case jump
    case tip

    var title: String {
        switch self {
        case .none:
            return "关"
        case .jump:
            return "自动跳过"
        case .tip:
            return "手动跳过"
        }
    }
}

enum DanmuArea: Codable, CaseIterable {
    case style_75
    case style_50
    case style_25
    case style_0
}

enum DanmuSize: String, Codable, CaseIterable {
    case size_25
    case size_31
    case size_36
    case size_42
    case size_48
    case size_57

    var title: String {
        return "\(Int(size)) pt"
    }

    var size: CGFloat {
        switch self {
        case .size_25:
            return 25
        case .size_31:
            return 31
        case .size_36:
            return 36
        case .size_42:
            return 42
        case .size_48:
            return 48
        case .size_57:
            return 57
        }
    }
}

enum DanmuAlpha: Double, Codable, CaseIterable {
    case alpha_03 = 0.3
    case alpha_04 = 0.4
    case alpha_05 = 0.5
    case alpha_06 = 0.6
    case alpha_07 = 0.7
    case alpha_08 = 0.8
    case alpha_09 = 0.9
    case alpha_10 = 1.0

    var title: String {
        return String(format: "%.1f", rawValue)
    }
}

enum DanmuStrokeWidth: Double, Codable, CaseIterable {
    case width_0 = 0.0
    case width_05 = 0.5
    case width_10 = 1.0
    case width_15 = 1.5
    case width_20 = 2.0

    var title: String {
        return String(format: "%.1f", rawValue)
    }
}

enum DanmuStrokeAlpha: Double, Codable, CaseIterable {
    case alpha_00 = 0.0
    case alpha_01 = 0.1
    case alpha_02 = 0.2
    case alpha_03 = 0.3
    case alpha_04 = 0.4
    case alpha_05 = 0.5
    case alpha_06 = 0.6
    case alpha_07 = 0.7
    case alpha_08 = 0.8
    case alpha_09 = 0.9
    case alpha_10 = 1.0

    var title: String {
        return String(format: "%.1f", rawValue)
    }
}

extension DanmuArea {
    var title: String {
        switch self {
        case .style_75:
            return "3/4屏"
        case .style_50:
            return "半屏"
        case .style_25:
            return "1/4屏"
        case .style_0:
            return "不限制"
        }
    }

    var percent: CGFloat {
        switch self {
        case .style_75:
            return 0.75
        case .style_50:
            return 0.5
        case .style_25:
            return 0.25
        case .style_0:
            return 1
        }
    }
}

enum CodecPreference: String, Codable, CaseIterable {
    case auto       // Automatic selection based on quality
    case preferAV1  // Prefer AV1 when available
    case preferHEVC // Prefer HEVC/H.265
    case preferAVC  // Prefer AVC/H.264 (for compatibility)
    
    var desp: String {
        switch self {
        case .auto:
            return "自动"
        case .preferAV1:
            return "优先 AV1"
        case .preferHEVC:
            return "优先 HEVC"
        case .preferAVC:
            return "优先 AVC/H.264"
        }
    }
}

enum MediaQualityEnum: Codable, CaseIterable {
    case quality_1080p
    case quality_2160p
    case quality_hdr10
    case quality_hdr10plus
    case quality_hdr_dolby
    case quality_hlg
}

extension MediaQualityEnum {
    var desp: String {
        switch self {
        case .quality_1080p:
            return "1080p"
        case .quality_2160p:
            return "4K"
        case .quality_hdr10:
            return "HDR10"
        case .quality_hdr10plus:
            return "HDR10+"
        case .quality_hdr_dolby:
            return "杜比视界"
        case .quality_hlg:
            return "HLG"
        }
    }

    var qn: Int {
        switch self {
        case .quality_1080p:
            return 116
        case .quality_2160p:
            return 120
        case .quality_hdr10:
            return 125 // HDR10 quality number
        case .quality_hdr10plus:
            return 127 // HDR10+ quality number (may need verification from Bilibili API)
        case .quality_hdr_dolby:
            return 126
        case .quality_hlg:
            return 121 // HLG quality number (may need verification)
        }
    }

    var fnval: Int {
        switch self {
        case .quality_1080p:
            return 16  // 0b10000: DASH
        case .quality_2160p:
            return 144 // 0b10010000: DASH + 4K
        case .quality_hdr10:
            return 976 // 0b1111010000: DASH + 4K + HDR + Dolby (添加512位以请求杜比视界格式)
        case .quality_hdr10plus:
            return 976 // 添加512位以请求杜比视界格式，与HDR10+共存
        case .quality_hdr_dolby:
            return 976 // 0b1111010000: DASH + 4K + HDR + Dolby
        case .quality_hlg:
            return 976 // 添加512位以请求杜比视界格式，与HLG共存
        }
    }
}
