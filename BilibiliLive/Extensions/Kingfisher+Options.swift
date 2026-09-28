//
//  Kingfisher+Options.swift
//  BilibiliLive
//

import Kingfisher
import UIKit

extension Array where Element == KingfisherOptionsInfoItem {
    /// 圆形头像：降采样到 80pt 后再裁圆。
    /// 注意 Kingfisher 的多个 `.processor` 选项只有最后一个生效，降采样和圆角必须用 `|>` 串成一个处理器，
    /// 否则降采样被丢弃，头像会以原图尺寸解码并做圆角处理。
    static var roundAvatar: KingfisherOptionsInfo {
        [
            .processor(DownsamplingImageProcessor(size: CGSize(width: 80, height: 80)) |> RoundCornerImageProcessor(radius: .widthFraction(0.5))),
            .cacheSerializer(FormatIndicatedCacheSerializer.png),
        ]
    }
}
