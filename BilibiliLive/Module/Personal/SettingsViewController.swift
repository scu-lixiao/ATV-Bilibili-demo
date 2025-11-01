//
//  SettingsViewController.swift
//  BilibiliLive
//
//  Created by whw on 2022/10/19.
//

import UIKit

class SettingsViewController: UIViewController {
    class SectionModel: Hashable, Equatable {
        let title: String
        let items: [CellModel]

        init(title: String, @ArrayBuilder<CellModel> items: () -> [CellModel]) {
            self.title = title
            self.items = items()
        }

        static func == (lhs: SectionModel, rhs: SectionModel) -> Bool {
            lhs.title == rhs.title && lhs.items == rhs.items
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(title)
            hasher.combine(items)
        }
    }

    class CellModel: Hashable, Equatable {
        let title: String
        let desp: () -> String
        let action: ((@escaping () -> Void) -> Void)?

        var updateAction: (() -> Void)?

        func hash(into hasher: inout Hasher) {
            hasher.combine(title)
        }

        static func == (lhs: CellModel, rhs: CellModel) -> Bool {
            lhs.title == rhs.title
        }

        init(title: String, desp: @autoclosure @escaping () -> String, action: ((@escaping () -> Void) -> Void)?) {
            self.title = title
            self.desp = desp
            self.action = action
        }
    }

    let collectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, environment -> NSCollectionLayoutSection? in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(68))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(68))
            let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
            group.interItemSpacing = .fixed(10)

            let section = NSCollectionLayoutSection(group: group)
            let headerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .estimated(44)
            )

            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: "header",
                alignment: .top
            )
            header.pinToVisibleBounds = false
            section.boundarySupplementaryItems = [header]
            section.interGroupSpacing = 10
            return section
        }
        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }()

    var dataSource: UICollectionViewDiffableDataSource<SectionModel, CellModel>!

    override func viewDidLoad() {
        super.viewDidLoad()

        // 应用深邃暗黑主题
        setupDarkTheme()

        view.addSubview(collectionView)
        collectionView.remembersLastFocusedIndexPath = false
        collectionView.snp.makeConstraints { make in
            make.top.right.bottom.equalToSuperview()
            make.left.equalToSuperview().offset(20)
        }

        collectionView.delegate = self
        collectionView.register(SettingsSwitchCell.self, forCellWithReuseIdentifier: String(describing: SettingsSwitchCell.self))
        collectionView.register(SettingsHeaderView.self, forSupplementaryViewOfKind: "header", withReuseIdentifier: "HeaderView")

        configureDataSource()
        setupData()
    }

    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<SectionModel, CellModel>(collectionView: collectionView) { collectionView, indexPath, cellModel -> UICollectionViewCell? in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: SettingsSwitchCell.self), for: indexPath) as! SettingsSwitchCell
            cell.set(with: cellModel)
            return cell
        }
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "HeaderView", for: indexPath) as! SettingsHeaderView
            let title = self?.dataSource.snapshot().sectionIdentifiers[indexPath.section].title ?? UUID().uuidString

            header.label.text = title
            return header
        }
    }

    private func setupData() {
        createSnapshot {
            SectionModel(title: "通用") {
                Toggle(title: "启用投屏", setting: Settings.enableDLNA, onChange: Settings.enableDLNA.toggle()) {
                    _ in
                    BiliBiliUpnpDMR.shared.start()
                }

                Toggle(title: "热门个性化推荐", setting: Settings.requestHotWithoutCookie, onChange: Settings.requestHotWithoutCookie.toggle())
            }

            SectionModel(title: "音视频") {
                Actions(title: "最高画质", message: "4k以上需要大会员",
                        current: Settings.mediaQuality.desp,
                        options: MediaQualityEnum.allCases,
                        optionString: MediaQualityEnum.allCases.map({ $0.desp }))
                {
                    Settings.mediaQuality = $0
                }
                Actions(title: "默认播放速度", message: "默认设置为1.0",
                        current: Settings.mediaPlayerSpeed.name,
                        options: PlaySpeed.blDefaults,
                        optionString: PlaySpeed.blDefaults.map({ $0.name }))
                {
                    Settings.mediaPlayerSpeed = $0
                }
                Toggle(title: "Avc优先(卡顿尝试开启)", setting: Settings.preferAvc, onChange: Settings.preferAvc.toggle())
                Toggle(title: "无损音频和杜比全景声", setting: Settings.losslessAudio, onChange: Settings.losslessAudio.toggle())
                
                // 音频直通模式（tvOS 26+）
                if AudioSessionManager.shared.isPassthroughAvailable {
                    Toggle(title: "音频直通模式 (实验性)", 
                           setting: Settings.audioPassthrough, 
                           onChange: Settings.audioPassthrough.toggle()) { enabled in
                        // 切换后重新配置音频会话
                        AudioSessionManager.shared.configureAudioSession(enablePassthrough: enabled)
                        
                        // 显示详细提示信息
                        let message = enabled ? 
                            """
                            已启用音频直通模式（实验性）。
                            
                            ⚠️ 重要说明：
                            • tvOS 26.0 的音频直通 API 尚未完全实现
                            • 当前配置已最小化音频处理，但完整的 HDMI 比特流直通可能需要等待 tvOS 26.1+ 更新
                            • 音频将尽可能以原始格式输出，保留 Dolby Atmos 元数据
                            • 如遇到声音问题，请关闭此选项
                            
                            建议：保持关注 tvOS 系统更新
                            """ :
                            "已关闭音频直通模式。音频将由 tvOS 处理后以 LPCM 格式输出。"
                        
                        let alert = UIAlertController(title: "音频直通模式", message: message, preferredStyle: .alert)
                        alert.addAction(.init(title: "了解", style: .default))
                        self.present(alert, animated: true)
                    }
                    
                    // 音频信息按钮
                    AudioInfoButton(title: "查看音频信息", currentInfo: "点击查看") {
                        let info = AudioSessionManager.shared.getAudioOutputInfo()
                        let alert = UIAlertController(title: "音频会话信息", message: info, preferredStyle: .alert)
                        alert.addAction(.init(title: "关闭", style: .default))
                        alert.addAction(.init(title: "查看指南", style: .default) { _ in
                            // 这里可以打开音频指南文档
                            let guideAlert = UIAlertController(
                                title: "音频处理指南", 
                                message: "详细的音频设置说明请参考项目文档：\n\ndoc/AUDIO_PROCESSING_GUIDE.md\n\n或在GitHub查看完整文档。",
                                preferredStyle: .alert
                            )
                            guideAlert.addAction(.init(title: "知道了", style: .default))
                            self.present(guideAlert, animated: true)
                        })
                        self.present(alert, animated: true)
                    }
                }
                
                Toggle(title: "匹配视频内容", setting: Settings.contentMatch, onChange: Settings.contentMatch.toggle())
                Toggle(title: "仅在HDR视频匹配视频内容", setting: Settings.contentMatchOnlyInHDR, onChange: Settings.contentMatchOnlyInHDR.toggle())
            }

            SectionModel(title: "界面") {
                Actions(title: "视频每行显示个数", message: "重启app生效",
                        current: Settings.displayStyle.desp,
                        options: FeedDisplayStyle.allCases.filter({ !$0.hideInSetting }),
                        optionString: FeedDisplayStyle.allCases.filter({ !$0.hideInSetting }).map({ $0.desp }))
                {
                    Settings.displayStyle = $0
                }
                Toggle(title: "侧边栏菜单自动切换", setting: Settings.sideMenuAutoSelectChange, onChange: Settings.sideMenuAutoSelectChange.toggle())

                Toggle(title: "不显示详情页直接进入视频",
                       setting: Settings.direatlyEnterVideo,
                       onChange: Settings.direatlyEnterVideo.toggle())

                Actions(title: "视频详情相关推荐加载模式", message: "4k以上需要大会员",
                        current: Settings.showRelatedVideoInCurrentVC ? "页面刷新" : "新页面中打开",
                        options: [true, false],
                        optionString: ["页面刷新", "新页面中打开"])
                {
                    Settings.showRelatedVideoInCurrentVC = $0
                }
            }

            SectionModel(title: "进度控制") {
                Toggle(title: "从上次退出的位置继续播放", setting: Settings.continuePlay, onChange: Settings.continuePlay.toggle())
                Toggle(title: "自动跳过片头片尾", setting: Settings.autoSkip, onChange: Settings.autoSkip.toggle())
                Toggle(title: "连续播放", setting: Settings.continouslyPlay, onChange: Settings.continouslyPlay.toggle())
                Actions(title: "空降助手广告屏蔽", message: "",
                        current: Settings.enableSponsorBlock.title,
                        options: SponsorBlockType.allCases,
                        optionString: SponsorBlockType.allCases.map({ $0.title }))
                {
                    Settings.enableSponsorBlock = $0
                }
            }

            SectionModel(title: "弹幕") {
                Toggle(title: "用户自定义弹幕屏蔽", setting: Settings.enableDanmuFilter, onChange: Settings.enableDanmuFilter.toggle()) {
                    enable in
                    if enable {
                        Task {
                            let toast = await VideoDanmuFilter.shared.update()
                            let alert = UIAlertController(title: "同步结果", message: toast, preferredStyle: .alert)
                            alert.addAction(.init(title: "Ok", style: .cancel))
                            self.present(alert, animated: true)
                        }
                    }
                }
                Toggle(title: "移除重复弹幕", setting: Settings.enableDanmuRemoveDup, onChange: Settings.enableDanmuRemoveDup.toggle())
                Actions(title: "弹幕大小", message: "默认为36", current: Settings.danmuSize.title, options: DanmuSize.allCases, optionString: DanmuSize.allCases.map({ $0.title })) {
                    Settings.danmuSize = $0
                }
                Actions(title: "弹幕显示区域", message: "设置弹幕显示区域",
                        current: Settings.danmuArea.title,
                        options: DanmuArea.allCases,
                        optionString: DanmuArea.allCases.map({ $0.title }))
                {
                    Settings.danmuArea = $0
                }
                Toggle(title: "智能防档弹幕", setting: Settings.danmuMask, onChange: Settings.danmuMask.toggle())
                Toggle(title: "按需本地运算智能防档弹幕(Exp)", setting: Settings.vnMask, onChange: Settings.vnMask.toggle())

                // 添加弹幕透明度设置
                Actions(title: "弹幕透明度", message: "调整弹幕的透明度",
                        current: Settings.danmuAlpha.title,
                        options: DanmuAlpha.allCases,
                        optionString: DanmuAlpha.allCases.map({ $0.title }))
                { value in
                    Settings.danmuAlpha = value
                }

                // 添加弹幕描边宽度设置
                Actions(title: "弹幕描边宽度", message: "调整弹幕描边的粗细",
                        current: Settings.danmuStrokeWidth.title,
                        options: DanmuStrokeWidth.allCases,
                        optionString: DanmuStrokeWidth.allCases.map({ $0.title }))
                { value in
                    Settings.danmuStrokeWidth = value
                }

                // 添加弹幕描边透明度设置
                Actions(title: "弹幕描边透明度", message: "调整弹幕描边的透明度",
                        current: Settings.danmuStrokeAlpha.title,
                        options: DanmuStrokeAlpha.allCases,
                        optionString: DanmuStrokeAlpha.allCases.map({ $0.title }))
                { value in
                    Settings.danmuStrokeAlpha = value
                }
            }

            SectionModel(title: "港澳台解锁") {
                Toggle(title: "解锁港澳台番剧限制", setting: Settings.areaLimitUnlock, onChange: Settings.areaLimitUnlock.toggle())
                TextField(title: "设置港澳台解析服务器", message: "为了安全考虑建议自建服务器，公共服务器可用性难保证，请多尝试几个。\n公共服务器请参考：http://985.so/mjq9u", current: Settings.areaLimitCustomServer, placeholder: "api.example.com") {
                    Settings.areaLimitCustomServer = $0 ?? ""
                }
            }
        }
    }
}

extension SettingsViewController {
    func Toggle(title: String, setting: @autoclosure @escaping () -> Bool,
                onChange: @autoclosure @escaping () -> Void,
                extraAction: ((Bool) -> Void)? = nil) -> CellModel
    {
        return CellModel(title: title, desp: setting() ? "开" : "关") {
            update in
            onChange()
            extraAction?(setting())
            update()
        }
    }
    
    func AudioInfoButton(title: String, currentInfo: String, onTap: @escaping () -> Void) -> CellModel {
        return CellModel(title: title, desp: currentInfo) { _ in
            onTap()
        }
    }

    func Actions<T>(title: String,
                    message: String?,
                    current: @autoclosure @escaping () -> String,
                    options: [T],
                    optionString: [String],
                    onSelect: ((T) -> Void)? = nil) -> CellModel
    {
        return CellModel(title: title, desp: current()) { [weak self] update in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)

            for (idx, string) in optionString.enumerated() {
                let action = UIAlertAction(title: string, style: .default) { _ in
                    onSelect?(options[idx])
                    update()
                }
                alert.addAction(action)
            }
            let cancelAction = UIAlertAction(title: nil, style: .cancel)
            alert.addAction(cancelAction)
            self?.present(alert, animated: true)
        }
    }

    func TextField(title: String,
                   message: String?,
                   current: String,
                   placeholder: String?,
                   isSecureTextEntry: Bool = false,
                   onSubmit: ((String?) -> Void)? = nil) -> CellModel
    {
        return CellModel(title: title, desp: current) { [weak self] update in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addTextField { textField in
                textField.text = current
                textField.keyboardType = .URL
                textField.placeholder = placeholder
                textField.isSecureTextEntry = isSecureTextEntry
            }

            let action = UIAlertAction(title: "确定", style: .default) { _ in
                onSubmit?(alert.textFields![0].text)
                update()
            }
            alert.addAction(action)

            let cancelAction = UIAlertAction(title: nil, style: .cancel)
            alert.addAction(cancelAction)
            self?.present(alert, animated: true)
        }
    }
}

extension SettingsViewController: UICollectionViewDelegate {
    private func createSnapshot(@ArrayBuilder<SectionModel> builder: () -> [SectionModel]) {
        var snapshot = NSDiffableDataSourceSnapshot<SectionModel, CellModel>()
        for section in builder() {
            snapshot.appendSections([section])
            snapshot.appendItems(section.items, toSection: section)
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cellModel = dataSource.itemIdentifier(for: indexPath)!
        cellModel.action?() { [weak cellModel] in
            cellModel?.updateAction?()
        }
    }
}

class SettingsSwitchCell: BLMotionCollectionViewCell {
    private let titleLabel = UILabel()
    private let descLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func set(with model: SettingsViewController.CellModel) {
        titleLabel.text = model.title
        descLabel.text = model.desp()
        model.updateAction = { [weak self] in
            self?.descLabel.text = model.desp()
        }
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        updateColor()
    }

    func setupView() {
        contentView.addSubview(titleLabel)
        contentView.addSubview(descLabel)
        contentView.layer.cornerRadius = 10

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(descLabel.snp.leading).offset(-10)
        }

        descLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
        }

        descLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        updateColor()
    }

    func updateColor() {
        if traitCollection.userInterfaceStyle == .dark {
            if isFocused {
                contentView.backgroundColor = UIColor.white
                titleLabel.textColor = UIColor.black
                descLabel.textColor = UIColor.black
            } else {
                contentView.backgroundColor = UIColor.clear
                titleLabel.textColor = UIColor.white
                descLabel.textColor = UIColor.secondaryLabel
            }
        } else {
            contentView.backgroundColor = isFocused ? UIColor.white : UIColor.clear
            titleLabel.textColor = .black
            descLabel.textColor = UIColor.secondaryLabel
        }
    }
}

class SettingsHeaderView: UICollectionReusableView {
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setup() {
        addSubview(label)
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = UIColor.secondaryLabel
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(20)
            make.bottom.equalToSuperview().offset(-20)
        }
    }
}

extension SettingsViewController {
    // MARK: - Theme Setup

    private func setupDarkTheme() {
        // 深邃纯黑背景
        view.backgroundColor = ThemeManager.shared.backgroundColor

        // CollectionView 透明背景,显示底层渐变
        collectionView.backgroundColor = .clear

        // tvOS 26 Liquid Glass 背景优化
        setupLiquidGlassBackground()
    }
    
    /// 配置 Liquid Glass 背景（tvOS 26 优化）
    private func setupLiquidGlassBackground() {
        if #available(tvOS 26.0, *), ThemeManager.shared.supportsLiquidGlass {
            // 为设置面板添加精细化 Liquid Glass 背景
            let glassBackground = LiquidGlassView.surface(
                tintColor: GlassEffectConfiguration.settingsPanel
            )
            view.insertSubview(glassBackground, at: 0)
            glassBackground.snp.makeConstraints { $0.edges.equalToSuperview() }
            
            // 添加 materialize 入场动画
            glassBackground.materialize(duration: 0.35)
        }
    }
}

extension FeedDisplayStyle {
    var desp: String {
        switch self {
        case .large:
            return "3个"
        case .normal:
            return "4个"
        case .sideBar:
            return "-"
        }
    }
}
