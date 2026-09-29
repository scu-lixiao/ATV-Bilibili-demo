//
// Created by Yam on 2024/6/9.
//

import Kingfisher
import UIKit

class ReplyCell: UICollectionViewCell {
    class var identifier: String {
        return String(describing: Self.self)
    }

    /// 未聚焦时的卡片背景
    private static let cardColor = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.1) : UIColor(white: 0, alpha: 0.06)
    }

    @IBOutlet var avatarImageView: UIImageView!
    @IBOutlet var userNameLabel: UILabel!
    @IBOutlet var contenLabel: UILabel!
    /// 卡片是普通 UIView，背景由这里绘制。不能用 TVCardView：真机上它的背景层画在内容之上，
    /// 聚焦变白后头像和文字都被盖住（模拟器上背景在内容下面，复现不出来）
    @IBOutlet var cardView: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
        updateAppearance(focused: false)
    }

    func config(replay: Replys.Reply) {
        avatarImageView.kf.setImage(
            with: URL(string: replay.member.avatar),
            options: .roundAvatar
        )
        userNameLabel.text = replay.member.uname
        if let attr = replay.createAttributedString(displayView: contenLabel) {
            contenLabel.attributedText = attr
        } else {
            contenLabel.text = replay.content.message
        }
        // 复用的 cell 按当前焦点状态设置外观（设置 attributedText 后也需要重新应用文字颜色）
        let focusedView = UIFocusSystem.focusSystem(for: self)?.focusedItem as? UIView
        updateAppearance(focused: focusedView?.isDescendant(of: self) ?? false)
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        // 焦点一般落在 cell 自身，按下一个焦点是否位于 cell 内判断，内部视图获得焦点时同样生效
        let focused = context.nextFocusedView?.isDescendant(of: self) ?? false
        coordinator.addCoordinatedAnimations {
            self.updateAppearance(focused: focused)
        }
    }

    /// 卡片背景和文字颜色总是一起切换：聚焦为白底黑字，未聚焦为半透明底配默认文字颜色
    private func updateAppearance(focused: Bool) {
        cardView.backgroundColor = focused ? .white : Self.cardColor
        let textColor: UIColor = focused ? .black : UIColor(named: "label3") ?? .label
        userNameLabel.textColor = textColor
        contenLabel.textColor = textColor
    }
}
