//
//  VideoDetailViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2021/4/17.
//

import AVKit
import Combine
import Foundation
import UIKit

import Alamofire
import Kingfisher
import MarqueeLabel
import SnapKit
import TVUIKit

class VideoDetailViewController: UIViewController {
    private var loadingView = UIActivityIndicatorView()
    @IBOutlet var backgroundImageView: UIImageView!
    @IBOutlet var effectContainerView: UIVisualEffectView!

    @IBOutlet var titleLabel: UILabel!

    @IBOutlet var upButton: BLCustomTextButton!
    @IBOutlet var followButton: BLCustomButton!
    @IBOutlet var coverImageView: UIImageView!
    @IBOutlet var playButton: BLCustomButton!
    @IBOutlet var likeButton: BLCustomButton!
    @IBOutlet var coinButton: BLCustomButton!
    @IBOutlet var noteView: NoteDetailView!
    @IBOutlet var dislikeButton: BLCustomButton!

    @IBOutlet var actionButtonSpaceView: UIView!
    @IBOutlet var durationLabel: UILabel!
    @IBOutlet var playCountLabel: UILabel!
    @IBOutlet var danmakuLabel: UILabel!
    @IBOutlet var uploadTimeLabel: UILabel!
    @IBOutlet var bvidLabel: UILabel!
    @IBOutlet var followersLabel: UILabel!
    @IBOutlet var avatarImageView: UIImageView!
    @IBOutlet var favButton: BLCustomButton!
    @IBOutlet var pageCollectionView: UICollectionView!
    @IBOutlet var recommandCollectionView: UICollectionView!
    @IBOutlet var replysCollectionView: UICollectionView!
    @IBOutlet var repliesCollectionViewHeightConstraints: NSLayoutConstraint!
    @IBOutlet var ugcCollectionView: UICollectionView!

    @IBOutlet var pageView: UIView!

    @IBOutlet var ugcLabel: UILabel!
    @IBOutlet var ugcView: UIView!
    private var epid = 0
    private var seasonId = 0
    private var aid = 0
    private var cid = 0
    private var data: VideoDetail?
    @IBOutlet var scrollView: UIScrollView!
    private var didSentCoins = 0 {
        didSet {
            if didSentCoins > 0 {
                coinButton.isOn = true
            }
        }
    }

    private var isBangumi = false
    private var startTime = 0
    private var pages = [VideoPage]()
    private var replys: Replys?
    private var subTitles: [SubtitleData]?

    private var allUgcEpisodes = [VideoDetail.Info.UgcSeason.UgcVideoInfo]()

    private var subscriptions = [AnyCancellable]()

    static func create(aid: Int, cid: Int?, epid: Int? = nil) -> VideoDetailViewController {
        let vc = UIStoryboard(name: "Main", bundle: .main).instantiateViewController(identifier: String(describing: self)) as! VideoDetailViewController
        vc.aid = aid
        vc.cid = cid ?? 0
        vc.epid = epid ?? 0
        return vc
    }

    static func create(epid: Int) -> VideoDetailViewController {
        let vc = UIStoryboard(name: "Main", bundle: .main).instantiateViewController(identifier: String(describing: self)) as! VideoDetailViewController
        vc.epid = epid
        return vc
    }

    static func create(seasonId: Int) -> VideoDetailViewController {
        let vc = UIStoryboard(name: "Main", bundle: .main).instantiateViewController(identifier: String(describing: self)) as! VideoDetailViewController
        vc.seasonId = seasonId
        return vc
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTheme()
        Task { await fetchData() }

        pageCollectionView.register(BLTextOnlyCollectionViewCell.self, forCellWithReuseIdentifier: String(describing: BLTextOnlyCollectionViewCell.self))
        pageCollectionView.collectionViewLayout = makePageCollectionViewLayout()
        recommandCollectionView.register(RelatedVideoCell.self, forCellWithReuseIdentifier: String(describing: RelatedVideoCell.self))
        ugcCollectionView.register(RelatedVideoCell.self, forCellWithReuseIdentifier: String(describing: RelatedVideoCell.self))
        recommandCollectionView.collectionViewLayout = makeRelatedVideoCollectionViewLayout()
        ugcCollectionView.collectionViewLayout = makeRelatedVideoCollectionViewLayout()
        noteView.onPrimaryAction = {
            [weak self] note in
            let detail = ContentDetailViewController.createDesp(content: note.label.text ?? "")
            self?.present(detail, animated: true)
        }

        var focusGuide = UIFocusGuide()
        view.addLayoutGuide(focusGuide)
        NSLayoutConstraint.activate([
            focusGuide.topAnchor.constraint(equalTo: upButton.topAnchor),
            focusGuide.leftAnchor.constraint(equalTo: followButton.rightAnchor),
            focusGuide.rightAnchor.constraint(equalTo: coverImageView.leftAnchor),
            focusGuide.bottomAnchor.constraint(equalTo: upButton.bottomAnchor),
        ])
        focusGuide.preferredFocusEnvironments = [followButton]

        focusGuide = UIFocusGuide()
        view.addLayoutGuide(focusGuide)
        NSLayoutConstraint.activate([
            focusGuide.topAnchor.constraint(equalTo: actionButtonSpaceView.topAnchor),
            focusGuide.leftAnchor.constraint(equalTo: actionButtonSpaceView.leftAnchor),
            focusGuide.rightAnchor.constraint(equalTo: actionButtonSpaceView.rightAnchor),
            focusGuide.bottomAnchor.constraint(equalTo: actionButtonSpaceView.bottomAnchor),
        ])
        focusGuide.preferredFocusEnvironments = [dislikeButton]

        replysCollectionView.publisher(for: \.contentSize).sink { [weak self] newSize in
            self?.repliesCollectionViewHeightConstraints.constant = newSize.height
            self?.view.setNeedsLayout()
        }.store(in: &subscriptions)
        
        // 优化封面图片视觉效果
        enhanceCoverImageView()
    }
    
    // MARK: - Cover Image Enhancement
    
    /// 优化封面图片的视觉效果
    private func enhanceCoverImageView() {
        coverImageView.layer.cornerRadius = 16
        coverImageView.layer.cornerCurve = .continuous
        coverImageView.clipsToBounds = true
        
        // 添加微妙阴影
        coverImageView.layer.shadowColor = UIColor.black.cgColor
        coverImageView.layer.shadowOpacity = 0.3
        coverImageView.layer.shadowOffset = CGSize(width: 0, height: 8)
        coverImageView.layer.shadowRadius = 16
        
        // 背景图片模糊效果增强
        backgroundImageView.alpha = 0.15
    }

    override var preferredFocusedView: UIView? {
        return playButton
    }

    // MARK: - Theme Setup

    private func setupTheme() {
        // 应用深邃纯黑背景
        view.backgroundColor = ThemeManager.shared.backgroundColor

        // 配置模糊效果视图 - 使用主题材质
        if #available(tvOS 26.0, *), ThemeManager.shared.supportsLiquidGlass {
            effectContainerView.effect = ThemeManager.shared.createEffect(style: .surface)
        } else {
            effectContainerView.effect = ThemeManager.shared.createEffect(style: .surface)
        }

        // 文本颜色 - 主要文本
        titleLabel.textColor = ThemeManager.shared.textPrimaryColor

        // 文本颜色 - 次要文本
        playCountLabel.textColor = ThemeManager.shared.textSecondaryColor
        danmakuLabel.textColor = ThemeManager.shared.textSecondaryColor
        followersLabel.textColor = ThemeManager.shared.textSecondaryColor
        durationLabel.textColor = ThemeManager.shared.textSecondaryColor
        ugcLabel.textColor = ThemeManager.shared.textPrimaryColor

        // 文本颜色 - 三级文本
        uploadTimeLabel.textColor = ThemeManager.shared.textTertiaryColor
        bvidLabel.textColor = ThemeManager.shared.textTertiaryColor

        // ScrollView 背景透明，显示底层主题背景
        scrollView.backgroundColor = .clear

        // CollectionViews 背景透明
        pageCollectionView.backgroundColor = .clear
        recommandCollectionView.backgroundColor = .clear
        replysCollectionView.backgroundColor = .clear
        ugcCollectionView.backgroundColor = .clear

        // 视图背景
        pageView.backgroundColor = .clear
        ugcView.backgroundColor = .clear
        
        // 增强按钮视觉效果
        enhanceButtonVisuals()
    }
    
    // MARK: - Button Enhancement
    
    /// 深度优化按钮视觉效果
    private func enhanceButtonVisuals() {
        // 播放按钮 - 添加品牌色渐变
        enhanceActionButton(playButton, useAccentGradient: true, iconScale: 0.55)
        
        // 点赞按钮 - 添加品牌色渐变
        enhanceActionButton(likeButton, useAccentGradient: true)
        
        // 投币按钮 - 添加品牌色渐变
        enhanceActionButton(coinButton, useAccentGradient: true)
        
        // 收藏按钮
        enhanceActionButton(favButton, useAccentGradient: false)
        
        // 不喜欢按钮
        enhanceActionButton(dislikeButton, useAccentGradient: false)
        
        // 关注按钮 - 信息类按钮
        if let followBtn = followButton {
            enhanceInfoButton(followBtn)
        }
        
        // UP主按钮 - 信息类按钮
        if let upBtn = upButton {
            enhanceTextButton(upBtn)
        }
    }
    
    /// 增强动作按钮（播放、点赞等）
    private func enhanceActionButton(_ button: BLCustomButton?, useAccentGradient: Bool, iconScale: CGFloat = 0.5) {
        guard let button = button else { return }
        
        // 优化圆角
        button.effectView.layer.cornerRadius = button.bounds.height * 0.25
        button.layer.cornerRadius = button.bounds.height * 0.25
        
        // 添加渐变层（如果需要）
        if useAccentGradient {
            let gradientLayer = CAGradientLayer()
            gradientLayer.colors = ThemeManager.shared.createButtonGradientColors(useAccent: true)
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
            gradientLayer.frame = button.effectView.bounds
            gradientLayer.cornerRadius = button.effectView.layer.cornerRadius
            gradientLayer.opacity = 0 // 初始隐藏，焦点时显示
            button.effectView.layer.insertSublayer(gradientLayer, at: 0)
            
            // 保存引用以便后续访问
            button.layer.setValue(gradientLayer, forKey: "gradientLayer")
        }
        
        // 优化阴影预设
        ThemeManager.shared.removeShadow(from: button.layer)
    }
    
    /// 增强信息按钮（关注等）
    private func enhanceInfoButton(_ button: BLCustomButton) {
        button.effectView.layer.cornerRadius = button.bounds.height * 0.3
        button.layer.cornerRadius = button.bounds.height * 0.3
        ThemeManager.shared.removeShadow(from: button.layer)
    }
    
    /// 增强文本按钮（UP主等）
    private func enhanceTextButton(_ button: BLCustomTextButton) {
        button.effectView.layer.cornerRadius = button.bounds.height * 0.25
        button.layer.cornerRadius = button.bounds.height * 0.25
        ThemeManager.shared.removeShadow(from: button.layer)
    }

    private func setupLoading() {
        effectContainerView.isHidden = true
        view.addSubview(loadingView)
        loadingView.color = ThemeManager.shared.textPrimaryColor
        loadingView.style = .large
        loadingView.startAnimating()
        loadingView.makeConstraintsBindToCenterOfSuperview()
    }

    func present(from vc: UIViewController, direatlyEnterVideo: Bool = Settings.direatlyEnterVideo) {
        if !direatlyEnterVideo {
            vc.present(self, animated: true)
        } else {
            vc.present(self, animated: false) { [weak self] in
                guard let self else { return }
                let player = VideoPlayerViewController(playInfo: PlayInfo(aid: self.aid, cid: self.cid, epid: self.epid, isBangumi: self.isBangumi))
                self.present(player, animated: true)
            }
        }
    }

    private func exit(with error: Error) {
        Logger.warn(error)
        let alertVC = UIAlertController(title: "获取失败", message: error.localizedDescription, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: { [weak self] action in
            self?.dismiss(animated: true)
        }))
        present(alertVC, animated: true, completion: nil)
    }

    private func fetchData() async {
        scrollView.setContentOffset(.zero, animated: false)
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
        backgroundImageView.alpha = 0
        setupLoading()
        pageView.isHidden = true
        ugcView.isHidden = true
        do {
            if seasonId > 0 {
                isBangumi = true
                let info = try await WebRequest.requestBangumiInfo(seasonID: seasonId)
                if let epi = info.main_section.episodes.first ?? info.section.first?.episodes.first {
                    aid = epi.aid
                    cid = epi.cid
                    epid = epi.id
                }
                pages = info.main_section.episodes.map({ VideoPage(cid: $0.cid, page: $0.aid, epid: $0.id, from: "", part: $0.title + " " + $0.long_title) })
            } else if epid > 0 {
                isBangumi = true
                let info = try await WebRequest.requestBangumiInfo(epid: epid)
                if let epi = info.episodes.first(where: { $0.id == epid }) ?? info.episodes.first {
                    aid = epi.aid
                    cid = epi.cid
                } else {
                    throw NSError(domain: "get epi fail", code: -1)
                }
                pages = info.episodes.map({ VideoPage(cid: $0.cid, page: $0.aid, epid: $0.id, from: "", part: $0.title + " " + $0.long_title) })
            }
            let data = try await WebRequest.requestDetailVideo(aid: aid)
            self.data = data

            if let redirect = data.View.redirect_url?.lastPathComponent, redirect.starts(with: "ep"), let id = Int(redirect.dropFirst(2)), !isBangumi {
                isBangumi = true
                epid = id
                let info = try await WebRequest.requestBangumiInfo(epid: epid)
                pages = info.episodes.map({ VideoPage(cid: $0.cid, page: $0.aid, epid: $0.id, from: "", part: $0.title + " " + $0.long_title) })
            }
            update(with: data)
        } catch let err {
            if case let .statusFail(code, _) = err as? RequestError, code == -404 {
                // 解锁港澳台番剧处理
                if let ok = await fetchAreaLimitBangumiData(), !ok {
                    self.exit(with: err)
                }
            } else {
                self.exit(with: err)
            }
        }

        WebRequest.requestReplys(aid: aid) { [weak self] replys in
            self?.replys = replys
            self?.replysCollectionView.reloadData()
        }

        WebRequest.requestLikeStatus(aid: aid) { [weak self] isLiked in
            self?.likeButton.isOn = isLiked
        }

        WebRequest.requestCoinStatus(aid: aid) { [weak self] coins in
            self?.didSentCoins = coins
        }

        if isBangumi {
            favButton.isHidden = true
            recommandCollectionView.superview?.isHidden = true
            return
        }

        WebRequest.requestFavoriteStatus(aid: aid) { [weak self] isFavorited in
            self?.favButton.isOn = isFavorited
        }
    }

    private func fetchAreaLimitBangumiData() async -> Bool? {
        guard Settings.areaLimitUnlock else { return false }

        do {
            var info: ApiRequest.BangumiInfo?

            if seasonId > 0 {
                info = try await ApiRequest.requestBangumiInfo(seasonID: seasonId)
            } else if epid > 0 {
                info = try await ApiRequest.requestBangumiInfo(epid: epid)
            }
            guard let info = info else { return false }

            let season = try await WebRequest.requestBangumiSeasonView(seasonID: info.season_id)
            isBangumi = true
            if let epi = season.episodes.first(where: { $0.ep_id == epid }) ?? season.episodes.first {
                aid = epi.aid
                cid = epi.cid
                pages = season.episodes.filter { $0.section_type == 0 }.map({ VideoPage(cid: $0.cid, page: $0.aid, epid: $0.ep_id, from: "", part: $0.index + " " + ($0.index_title ?? "")) })

                let userEpisodeInfo = try await WebRequest.requestUserEpisodeInfo(epid: epi.ep_id)

                let data = VideoDetail(View: VideoDetail.Info(aid: aid, cid: cid, title: info.title, videos: nil, pic: epi.cover, desc: info.evaluate, owner: VideoOwner(mid: season.up_info.mid, name: season.up_info.uname, face: season.up_info.avatar), pages: nil, dynamic: nil, bvid: epi.bvid, duration: epi.durationSeconds, pubdate: epi.pubdate, ugc_season: nil, redirect_url: nil, stat: VideoDetail.Info.Stat(favorite: info.stat.favorites, coin: info.stat.coins, like: info.stat.likes, share: info.stat.share, danmaku: info.stat.danmakus, view: info.stat.views)), Related: [], Card: VideoDetail.Owner(following: userEpisodeInfo.related_up.first?.is_follow == 1, follower: season.up_info.follower))

                self.data = data
                update(with: data)
                return true
            }

        } catch let err {
            print(err)
        }

        return false
    }

    private func update(with data: VideoDetail) {
        playCountLabel.text = data.View.stat.view.numberString()
        danmakuLabel.text = data.View.stat.danmaku.numberString()
        followersLabel.text = (data.Card.follower ?? 0).numberString() + "粉丝"
        uploadTimeLabel.text = data.View.date
        bvidLabel.text = data.View.bvid
        coinButton.title = data.View.stat.coin.numberString()
        favButton.title = data.View.stat.favorite.numberString()
        likeButton.title = data.View.stat.like.numberString()

        durationLabel.text = data.View.durationString
        titleLabel.text = data.title
        upButton.title = data.ownerName
        followButton.isOn = data.Card.following

        avatarImageView.kf.setImage(with: data.avatar, options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 80, height: 80))), .processor(RoundCornerImageProcessor(radius: .widthFraction(0.5))), .cacheSerializer(FormatIndicatedCacheSerializer.png)])

        coverImageView.kf.setImage(with: data.pic)
        backgroundImageView.kf.setImage(with: data.pic)
        recommandCollectionView.superview?.isHidden = data.Related.count == 0

        var notes = [String]()
        let status = data.View.dynamic ?? ""
        if status.count > 1, status != data.View.desc {
            notes.append(status)
        }
        notes.append(data.View.desc ?? "")
        noteView.label.text = notes.joined(separator: "\n")
        if !isBangumi {
            pages = data.View.pages ?? []
        }
        if pages.count > 1 {
            pageCollectionView.reloadData()
            pageView.isHidden = false
            let index = pages.firstIndex { $0.cid == cid } ?? 0
            pageCollectionView.scrollToItem(at: IndexPath(row: index, section: 0), at: .left, animated: false)
            if cid == 0 {
                cid = pages.first?.cid ?? 0
            }
        }
        loadingView.stopAnimating()
        loadingView.removeFromSuperview()
        effectContainerView.isHidden = false
        UIView.animate(withDuration: 0.25) {
            self.backgroundImageView.alpha = 1
        }

        if let season = data.View.ugc_season {
            if season.sections.count > 1 {
                if let section = season.sections.first(where: { section in section.episodes.contains(where: { episode in episode.aid == data.View.aid }) }) {
                    allUgcEpisodes = section.episodes
                }
            } else {
                allUgcEpisodes = season.sections.first?.episodes ?? []
            }
            allUgcEpisodes.sort { $0.arc.ctime < $1.arc.ctime }
        }

        ugcCollectionView.reloadData()
        ugcLabel.text = "合集 \(data.View.ugc_season?.title ?? "")  \(data.View.ugc_season?.sections.first?.title ?? "")"
        ugcView.isHidden = allUgcEpisodes.count == 0
        if allUgcEpisodes.count > 0 {
            ugcCollectionView.scrollToItem(at: IndexPath(item: allUgcEpisodes.map { $0.aid }.firstIndex(of: aid) ?? 0, section: 0), at: .left, animated: false)
        }

        recommandCollectionView.reloadData()
    }

    @IBAction func actionShowUpSpace(_ sender: Any) {
        let upSpaceVC = UpSpaceViewController()
        upSpaceVC.mid = data?.View.owner.mid
        present(upSpaceVC, animated: true)
    }

    @IBAction func actionFollow(_ sender: Any) {
        followButton.isOn.toggle()
        if let mid = data?.View.owner.mid {
            WebRequest.follow(mid: mid, follow: followButton.isOn)
        }
    }

    @IBAction func actionPlay(_ sender: Any) {
        let player = VideoPlayerViewController(playInfo: PlayInfo(aid: aid, cid: cid, epid: epid, isBangumi: isBangumi))
        player.data = data
        if pages.count > 0, let index = pages.firstIndex(where: { $0.cid == cid }) {
            let seq = pages.dropFirst(index).map({ PlayInfo(aid: aid, cid: $0.cid, epid: $0.epid, isBangumi: isBangumi) })
            if seq.count > 0 {
                let nextProvider = VideoNextProvider(seq: seq)
                player.nextProvider = nextProvider
            }
        }
        present(player, animated: true, completion: nil)
    }

    @IBAction func actionLike(_ sender: Any) {
        Task {
            if likeButton.isOn {
                likeButton.title? -= 1
            } else {
                likeButton.title? += 1
            }
            likeButton.isOn.toggle()
            let success = await WebRequest.requestLike(aid: aid, like: likeButton.isOn)
            if !success {
                likeButton.isOn.toggle()
            }
        }
    }

    @IBAction func actionCoin(_ sender: Any) {
        guard didSentCoins < 2 else { return }
        let alert = UIAlertController(title: "投币个数", message: nil, preferredStyle: .actionSheet)
        WebRequest.requestTodayCoins { todayCoins in
            alert.message = "今日已投(\(todayCoins / 10)/5)个币"
        }
        let aid = aid
        alert.addAction(UIAlertAction(title: "1", style: .default) { [weak self] _ in
            guard let self else { return }
            self.coinButton.title? += 1
            if !self.likeButton.isOn {
                self.likeButton.title? += 1
                self.likeButton.isOn = true
            }
            self.didSentCoins += 1
            WebRequest.requestCoin(aid: aid, num: 1)
        })
        if didSentCoins == 0 {
            alert.addAction(UIAlertAction(title: "2", style: .default) { [weak self] _ in
                guard let self else { return }
                self.coinButton.title? += 2
                if !self.likeButton.isOn {
                    self.likeButton.title? += 1
                    self.likeButton.isOn = true
                }
                self.likeButton.isOn = true
                self.didSentCoins += 2
                WebRequest.requestCoin(aid: aid, num: 2)
            })
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    @IBAction func actionFavorite(_ sender: Any) {
        Task {
            guard let favList = try? await WebRequest.requestFavVideosList() else {
                return
            }
            if favButton.isOn {
                favButton.title? -= 1
                favButton.isOn = false
                WebRequest.removeFavorite(aid: aid, mid: favList.map { $0.id })
                return
            }
            let alert = UIAlertController(title: "收藏", message: nil, preferredStyle: .actionSheet)
            let aid = aid
            for fav in favList {
                alert.addAction(UIAlertAction(title: fav.title, style: .default) { [weak self] _ in
                    self?.favButton.title? += 1
                    self?.favButton.isOn = true
                    WebRequest.requestFavorite(aid: aid, mid: fav.id)
                })
            }
            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            present(alert, animated: true)
        }
    }

    @IBAction func actionDislike(_ sender: Any) {
        dislikeButton.isOn.toggle()
        ApiRequest.requestDislike(aid: aid, dislike: dislikeButton.isOn)
    }
}

extension VideoDetailViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch collectionView {
        case pageCollectionView:
            let page = pages[indexPath.item]
            let player = VideoPlayerViewController(playInfo: PlayInfo(aid: isBangumi ? page.page : aid, cid: page.cid, epid: page.epid, isBangumi: isBangumi))
            player.data = isBangumi ? nil : data

            let seq = pages.dropFirst(indexPath.item).map({ PlayInfo(aid: aid, cid: $0.cid, isBangumi: isBangumi) })
            if seq.count > 0 {
                let nextProvider = VideoNextProvider(seq: seq)
                player.nextProvider = nextProvider
            }
            present(player, animated: true, completion: nil)
        case replysCollectionView:
            guard let reply = replys?.replies?[indexPath.item] else { return }
            let detail = ReplyDetailViewController(reply: reply)
            present(detail, animated: true)
        case ugcCollectionView:
            let video = allUgcEpisodes[indexPath.item]
            if Settings.showRelatedVideoInCurrentVC {
                aid = video.aid
                cid = video.cid
                Task { await fetchData() }
            } else {
                let detailVC = VideoDetailViewController.create(aid: video.aid, cid: video.cid)
                detailVC.present(from: self)
            }
        case recommandCollectionView:
            if let video = data?.Related[indexPath.item] {
                if Settings.showRelatedVideoInCurrentVC {
                    aid = video.aid
                    cid = video.cid
                    Task { await fetchData() }
                } else {
                    let detailVC = VideoDetailViewController.create(aid: video.aid, cid: video.cid)
                    detailVC.present(from: self)
                }
            }
        default:
            break
        }
    }
}

extension VideoDetailViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch collectionView {
        case pageCollectionView:
            return pages.count
        case replysCollectionView:
            return replys?.replies?.count ?? 0
        case ugcCollectionView:
            return allUgcEpisodes.count
        case recommandCollectionView:
            return data?.Related.count ?? 0
        default:
            return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch collectionView {
        case pageCollectionView:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "BLTextOnlyCollectionViewCell", for: indexPath) as! BLTextOnlyCollectionViewCell
            let page = pages[indexPath.item]
            cell.titleLabel.text = page.part
            return cell
        case replysCollectionView:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: ReplyCell.self), for: indexPath) as! ReplyCell
            if let reply = replys?.replies?[indexPath.item] {
                cell.config(replay: reply)
            }
            return cell
        case ugcCollectionView:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: RelatedVideoCell.self), for: indexPath) as! RelatedVideoCell
            let record = allUgcEpisodes[indexPath.row]
            cell.update(data: record)
            return cell
        case recommandCollectionView:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: RelatedVideoCell.self), for: indexPath) as! RelatedVideoCell
            if let related = data?.Related[indexPath.row] {
                cell.update(data: related)
            }
            return cell
        default:
            return UICollectionViewCell()
        }
    }
}

class BLCardView: TVCardView {
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        subviews.first?.subviews.first?.subviews.last?.subviews.first?.subviews.first?.layer.cornerRadius = 12
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        cardBackgroundColor = ThemeManager.shared.surfaceColor
    }
}

extension VideoDetailViewController {
    func makePageCollectionViewLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout {
            _, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                  heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.14), heightDimension: .fractionalHeight(1))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.orthogonalScrollingBehavior = .continuous
            section.interGroupSpacing = 40
            return section
        }
    }

    func makeRelatedVideoCollectionViewLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout {
            _, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                  heightDimension: .estimated(200))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.18), heightDimension: .estimated(200))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = .init(top: 40, leading: 0, bottom: 0, trailing: 0)
            section.orthogonalScrollingBehavior = .continuous
            section.interGroupSpacing = 40
            return section
        }
    }
}

class RelatedVideoCell: BLMotionCollectionViewCell {
    let titleLabel = MarqueeLabel()
    let imageView = UIImageView()
    private var focusAnimator: UIViewPropertyAnimator?

    override func setup() {
        super.setup()
        contentView.addSubview(imageView)
        contentView.addSubview(titleLabel)
        imageView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.width.equalTo(imageView.snp.height).multipliedBy(14.0 / 9)
        }
        imageView.layer.cornerRadius = 14
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        titleLabel.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.top.equalTo(imageView.snp.bottom).offset(8)
        }
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .medium)
        titleLabel.fadeLength = 60
        titleLabel.textColor = ThemeManager.shared.textPrimaryColor
        stopScroll()

        // 应用主题 - 阴影预设（初始为0）
        ThemeManager.shared.removeShadow(from: imageView.layer)
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        focusAnimator?.stopAnimation(true)
        
        if isFocused {
            coordinator.addCoordinatedAnimations { [weak self] in
                guard let self = self else { return }
                
                // 增强阴影效果
                ThemeManager.shared.applyPremiumShadow(to: self.imageView.layer)
                
                // 轻微缩放
                self.imageView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                
                // 标题颜色强化
                self.titleLabel.textColor = ThemeManager.shared.accentPinkColor
            }
            
            // 开始跑马灯
            startScroll()
        } else {
            coordinator.addCoordinatedAnimations { [weak self] in
                guard let self = self else { return }
                
                // 移除阴影
                ThemeManager.shared.removeShadow(from: self.imageView.layer)
                
                // 恢复大小
                self.imageView.transform = .identity
                
                // 恢复标题颜色
                self.titleLabel.textColor = ThemeManager.shared.textPrimaryColor
            }
            
            // 停止跑马灯
            stopScroll()
        }
    }

    func update(data: any DisplayData) {
        titleLabel.text = data.title
        imageView.kf.setImage(with: data.pic, options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 360, height: 202))), .cacheOriginalImage])
    }

    private func startScroll() {
        titleLabel.restartLabel()
        titleLabel.holdScrolling = false
    }

    private func stopScroll() {
        titleLabel.shutdownLabel()
        titleLabel.holdScrolling = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stopScroll()
    }
}

class DetailLabel: UILabel {
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations {
            if self.isFocused {
                self.backgroundColor = .white
            } else {
                self.backgroundColor = .clear
            }
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        isUserInteractionEnabled = true
    }

    override var canBecomeFocused: Bool {
        return true
    }

    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
        super.drawText(in: rect.inset(by: insets))
    }
}

class NoteDetailView: UIControl {
    let label = UILabel()
    var onPrimaryAction: ((NoteDetailView) -> Void)?
    private let backgroundView = UIView()
    private var focusAnimator: UIViewPropertyAnimator?
    
    init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func setup() {
        addSubview(backgroundView)
        backgroundView.backgroundColor = ThemeManager.shared.surfaceColor
        backgroundView.layer.shadowOffset = CGSizeMake(0, 10)
        backgroundView.layer.shadowOpacity = 0
        backgroundView.layer.shadowRadius = 16.0
        backgroundView.layer.cornerRadius = 24
        backgroundView.layer.cornerCurve = .continuous
        backgroundView.isHidden = !isFocused
        backgroundView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.left.equalToSuperview().offset(-20)
            make.right.equalToSuperview().offset(20)
        }

        addSubview(label)
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 29, weight: .regular)
        label.textColor = ThemeManager.shared.textPrimaryColor
        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(16)
            make.bottom.lessThanOrEqualToSuperview().offset(-16)
        }
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        focusAnimator?.stopAnimation(true)
        
        if isFocused {
            backgroundView.isHidden = false
            coordinator.addCoordinatedAnimations { [weak self] in
                guard let self = self else { return }
                
                // 应用增强阴影
                ThemeManager.shared.applyFocusShadow(to: self.backgroundView.layer)
                
                // 轻微缩放
                self.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
                
                // 文本颜色强化
                self.label.textColor = ThemeManager.shared.accentColor
            }
        } else {
            coordinator.addCoordinatedAnimations { [weak self] in
                guard let self = self else { return }
                
                // 移除阴影
                ThemeManager.shared.removeShadow(from: self.backgroundView.layer)
                
                // 恢复大小
                self.transform = .identity
                
                // 恢复文本颜色
                self.label.textColor = ThemeManager.shared.textPrimaryColor
            } completion: { [weak self] in
                self?.backgroundView.isHidden = true
            }
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)
        if presses.first?.type == .select {
            sendActions(for: .primaryActionTriggered)
            onPrimaryAction?(self)
        }
    }
}

class ContentDetailViewController: UIViewController {
    private let titleLabel = UILabel()
    private let contentTextView = UITextView()

    static func createDesp(content: String) -> ContentDetailViewController {
        let vc = ContentDetailViewController()
        vc.titleLabel.text = "简介"
        vc.contentTextView.text = content
        return vc
    }

    static func createReply(content: String) -> ContentDetailViewController {
        let vc = ContentDetailViewController()
        vc.titleLabel.text = "评论"
        vc.contentTextView.text = content
        return vc
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        [contentTextView]
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // 应用主题
        view.backgroundColor = ThemeManager.shared.backgroundColor

        view.addSubview(titleLabel)
        view.addSubview(contentTextView)

        titleLabel.font = .systemFont(ofSize: 60, weight: .semibold)
        titleLabel.textColor = ThemeManager.shared.textPrimaryColor
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(80)
            make.centerX.equalToSuperview()
        }

        contentTextView.panGestureRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
        contentTextView.isScrollEnabled = true
        contentTextView.isUserInteractionEnabled = true
        contentTextView.isSelectable = true
        contentTextView.backgroundColor = .clear
        contentTextView.textColor = ThemeManager.shared.textSecondaryColor
        contentTextView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom)
            make.centerX.equalToSuperview()
            make.leading.equalToSuperview().offset(60)
            make.trailing.equalToSuperview().inset(60)
            make.bottom.equalToSuperview().inset(80)
        }
    }
}
