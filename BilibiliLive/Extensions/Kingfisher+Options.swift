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

extension URL {
    /// B 站图床（*.hdslb.com）支持在路径后追加 `@{w}w_{h}h.jpg`，由服务端缩放后返回。
    /// 头像原图可能非常大，下载原图再在本地降采样既费流量又占内存，过大时会解码崩溃（上游 #184 #218）。
    /// 非 B 站图床或已带缩放参数的地址原样返回
    func biliResized(width: Int, height: Int) -> URL {
        guard let host, host.hasSuffix("hdslb.com"), !lastPathComponent.contains("@"),
              var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        else { return self }
        components.path += "@\(width)w_\(height)h.jpg"
        return components.url ?? self
    }

    /// 头像统一请求 240px 缩略图
    var biliAvatarThumbnail: URL {
        biliResized(width: 240, height: 240)
    }
}
