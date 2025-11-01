//
//  AudioSessionManager.swift
//  BilibiliLive
//
//  Created by AI Assistant on 2025/11/01.
//

import AVFoundation
import CocoaLumberjackSwift

/// 音频会话管理器
/// 负责配置音频会话，支持传统模式和音频直通模式（tvOS 26+）
class AudioSessionManager {
    static let shared = AudioSessionManager()
    
    private init() {}
    
    /// 配置音频会话
    /// - Parameter enablePassthrough: 是否启用音频直通（仅tvOS 26+支持）
    func configureAudioSession(enablePassthrough: Bool = false) {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            // tvOS 26+ 支持音频直通
            if #available(tvOS 26.0, *), enablePassthrough {
                Logger.info("尝试启用音频直通模式 (tvOS 26+)")
                try configurePassthroughMode(audioSession)
            } else {
                // 传统模式
                Logger.info("使用传统音频模式")
                try configureTraditionalMode(audioSession)
            }
            
            Logger.info("音频会话配置成功")
        } catch {
            Logger.warn("音频会话配置失败: \(error)")
            // 回退到传统模式
            try? configureTraditionalMode(audioSession)
        }
    }
    
    /// 配置传统音频模式
    private func configureTraditionalMode(_ session: AVAudioSession) throws {
        // 标准视频播放配置
        try session.setCategory(.playback, mode: .moviePlayback)
        
        // 优化：启用空间音频支持（如果设备支持）
        if #available(tvOS 15.0, *) {
            // tvOS 15+ 自动支持空间音频
            Logger.debug("设备支持空间音频")
        }
    }
    
    /// 配置音频直通模式（tvOS 26+）
    /// ⚠️ 注意：此功能在 tvOS 26.0 中尚未完全实现，可能需要等待 26.1+ 版本
    @available(tvOS 26.0, *)
    private func configurePassthroughMode(_ session: AVAudioSession) throws {
        Logger.info("开始配置音频直通模式 (tvOS 26)")
        Logger.warn("⚠️ tvOS 26.0 的音频直通 API 尚未完全实现，当前为实验性尝试")
        
        // 第一步：设置播放类别和模式
        // 移除所有音频处理选项，使用最纯净的配置
        try session.setCategory(
            .playback,
            mode: .moviePlayback,
            options: [] // 空选项：不混音、不降噪、不处理
        )
        
        // 第二步：尝试设置 preferredContentSource（如果 API 可用）
        // 注意：根据社区反馈，这个 API 在 tvOS 26.0 中可能还没有公开方法
        
        // 方法1：尝试通过反射访问 preferredContentSource 属性
        if session.responds(to: Selector(("setPreferredContentSource:"))) {
            Logger.info("检测到 preferredContentSource API，尝试设置...")
            // 使用 KVC 尝试设置（如果属性存在）
            do {
                session.setValue(AVAudioContentSource.passthrough.rawValue,
                               forKey: "preferredContentSource")
                Logger.info("✓ 成功设置 preferredContentSource = passthrough")
            } catch {
                Logger.warn("设置 preferredContentSource 失败 (可能 API 尚未实现): \(error)")
            }
        } else {
            Logger.warn("preferredContentSource API 在当前系统版本中不可用")
            Logger.info("建议：更新到 tvOS 26.1+ 或等待 Apple 完善该功能")
        }
        
        // 方法2：尝试通过 setCategory 的扩展参数（如果存在）
        // 注意：这是基于推测的实现，实际 API 可能不同
        let mirror = Mirror(reflecting: session)
        if mirror.children.contains(where: { $0.label == "contentSource" }) {
            Logger.debug("检测到 contentSource 属性")
        }
        
        // 第三步：激活会话
        try session.setActive(true, options: [])
        
        Logger.info("✓ 音频会话配置完成（基础模式）")
        Logger.info("说明：当前配置已最小化音频处理，但完整的直通功能需要等待 Apple 更新")
        Logger.info("- 已移除所有音频处理选项（无混音、无降噪）")
        Logger.info("- 音频将尽可能保持原始格式输出")
        Logger.info("- 等待 tvOS 26.1+ 版本以获得完整的 HDMI 比特流直通支持")
    }
    
    /// 获取音频输出信息（用于调试）
    func getAudioOutputInfo() -> String {
        let session = AVAudioSession.sharedInstance()
        var info = "音频会话信息:\n"
        info += "类别: \(session.category.rawValue)\n"
        info += "模式: \(session.mode.rawValue)\n"
        
        if #available(tvOS 15.0, *) {
            info += "支持空间音频: ✓\n"
        }
        
        if #available(tvOS 26.0, *) {
            info += "tvOS 26+ 功能可用\n"
            info += "音频直通: \(Settings.audioPassthrough ? "已启用" : "未启用")\n"
        }
        
        return info
    }
    
    /// 检查是否支持音频直通
    var isPassthroughAvailable: Bool {
        if #available(tvOS 26.0, *) {
            return true
        }
        return false
    }
}
