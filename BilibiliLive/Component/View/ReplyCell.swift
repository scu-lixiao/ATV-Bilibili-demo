//
// Created by Yam on 2024/6/9.
//

import Kingfisher
import UIKit

class ReplyCell: UICollectionViewCell {
    class var identifier: String {
        return String(describing: Self.self)
    }

    @IBOutlet var avatarImageView: UIImageView!
    @IBOutlet var userNameLabel: UILabel!
    @IBOutlet var contenLabel: UILabel!

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
        // 复用的 cell 按当前焦点状态设置文字颜色（设置 attributedText 后也需要重新应用）
        let focusedView = UIFocusSystem.focusSystem(for: self)?.focusedItem as? UIView
        updateTextColor(focused: focusedView?.isDescendant(of: self) ?? false)
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        // 获得焦点的是 cell 内的 TVCardView 而不是 cell 本身，cell.isFocused 始终为 false，
        // 因此按下一个焦点是否位于 cell 内判断。卡片聚焦后背景变为白色，文字需切换为黑色
        let focused = context.nextFocusedView?.isDescendant(of: self) ?? false
        coordinator.addCoordinatedAnimations {
            self.updateTextColor(focused: focused)
        }
    }

    private func updateTextColor(focused: Bool) {
        let color: UIColor = focused ? .black : UIColor(named: "label3") ?? .label
        userNameLabel.textColor = color
        contenLabel.textColor = color
    }
}
