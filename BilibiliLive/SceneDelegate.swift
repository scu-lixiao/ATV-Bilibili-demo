//
//  SceneDelegate.swift
//  BilibiliLive
//

import UIKit

/// tvOS 27 SDK 起必须使用 UIScene 生命周期，否则启动即崩溃
/// （"UIScene life cycle is required for apps built with this SDK"），窗口由这里管理
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window

        if ApiRequest.isLogin() {
            if let expireDate = ApiRequest.getToken()?.expireDate {
                let now = Date()
                if expireDate.timeIntervalSince(now) < 60 * 60 * 30 {
                    ApiRequest.refreshToken()
                }
            } else {
                ApiRequest.refreshToken()
            }
            window.rootViewController = MenusViewController.create()
        } else {
            window.rootViewController = LoginViewController.create()
        }
        window.makeKeyAndVisible()
    }

    func showLogin() {
        window?.rootViewController = LoginViewController.create()
    }

    func showTabBar() {
        window?.rootViewController = MenusViewController.create()
    }
}
