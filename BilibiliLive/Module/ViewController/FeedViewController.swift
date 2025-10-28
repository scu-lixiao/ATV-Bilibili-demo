//
//  FeedViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2021/5/19.
//

import UIKit

class FeedViewController: StandardVideoCollectionViewController<ApiRequest.FeedResp.Items> {
    override func setupCollectionView() {
        super.setupCollectionView()
        collectionVC.pageSize = 1
    }

    override func request(page: Int) async throws -> [ApiRequest.FeedResp.Items] {
        let items: [ApiRequest.FeedResp.Items]
        if page == 1 {
            items = try await ApiRequest.getFeeds()
        } else if let last = (collectionVC.displayDatas.last as? ApiRequest.FeedResp.Items)?.idx {
            items = try await ApiRequest.getFeeds(lastIdx: last)
        } else {
            throw NSError(domain: "", code: -1)
        }
        
        // 调试日志：检查 player_args 是否返回
        if let first = items.first {
            Logger.debug("Feed item player_args: \(String(describing: first.player_args))")
            Logger.debug("Feed item viewCount: \(String(describing: first.viewCount))")
        }
        
        return items
    }
}

extension ApiRequest.FeedResp.Items: PlayableData {
    var aid: Int { Int(param) ?? 0 }
    var cid: Int { 0 }
}
