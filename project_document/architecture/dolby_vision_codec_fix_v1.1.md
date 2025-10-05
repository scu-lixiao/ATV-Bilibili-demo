# 杜比视界编解码器修复架构分析

**文档版本:** v1.1  
**创建时间:** 2025-06-08 15:46:43 (通过mcp-server-time获得) +08:00  
**更新时间:** 2025-06-08 15:48:27 (通过mcp-server-time获得) +08:00  
**创建者:** AR (架构师)  
**关联任务:** ATV-Bilibili-DolbyVision-Fix-2025

## 更新日志
| 时间 | 版本 | 修改原因 | 修改者 |
|------|------|----------|--------|
| 2025-06-08 15:46:43 +08:00 | v1.0 | 初始架构分析文档创建 | AR |
| 2025-06-08 15:48:27 +08:00 | v1.1 | 添加详细修复计划和API设计 | AR |

## 当前架构问题分析

### 问题定位
在`BilibiliVideoResourceLoaderDelegate`类的视频播放信息处理流程中，存在编解码器强制替换逻辑：

```
用户请求杜比视界内容 
    ↓
BilibiliVideoResourceLoaderDelegate.addVideoPlayBackInfo()
    ↓
检测到杜比视界编解码器 (dvh1.xx.xx)
    ↓
❌ 强制替换为HEVC编解码器 (hvc1.xx.xx)
    ↓
生成HLS播放列表
    ↓
AVPlayer接收到错误的编解码器信息
    ↓
降级为HDR播放而非杜比视界
```

### 架构影响评估
1. **播放质量降级：** 杜比视界→HDR→用户体验受损
2. **元数据丢失：** 杜比视界动态元数据无法正确传递
3. **设备能力浪费：** 支持杜比视界的Apple TV无法发挥全部能力

## 核心设计原则应用
- **KISS原则：** 移除不必要的编解码器替换逻辑
- **SOLID原则：** 单一职责 - 编解码器处理应该保持原始信息
- **DRY原则：** 避免重复的兼容性处理逻辑

## 修复方案A详细设计

### 目标架构
```
用户请求杜比视界内容 
    ↓
BilibiliVideoResourceLoaderDelegate.addVideoPlayBackInfo()
    ↓
检测到杜比视界编解码器 (dvh1.xx.xx)
    ↓
✅ 保持原始杜比视界编解码器
    ↓
正确设置VIDEO-RANGE=PQ
    ↓
生成符合苹果标准的HLS播放列表
    ↓
AVPlayer正确识别杜比视界内容
    ↓
原生杜比视界播放
```

### 具体修改点
**文件:** `BilibiliLive/Component/Player/BilibiliVideoResourceLoaderDelegate.swift`
**方法:** `addVideoPlayBackInfo(info:url:duration:)`
**行数:** 89-97行

**当前错误逻辑:**
```swift
if codecs == "dvh1.08.07" || codecs == "dvh1.08.03" {
    supplementCodesc = codecs + "/db4h"
    codecs = "hvc1.2.4.L153.b0"  // ❌ 错误替换
    videoRange = "PQ"
} else if codecs == "dvh1.08.06" {
    supplementCodesc = codecs + "/db1p"
    codecs = "hvc1.2.4.L150"     // ❌ 错误替换
    videoRange = "PQ"
}
```

**修复后正确逻辑:**
```swift
if codecs == "dvh1.08.07" || codecs == "dvh1.08.03" {
    supplementCodesc = "db4h"
    videoRange = "PQ"
    // ✅ 保持原始杜比视界编解码器
} else if codecs == "dvh1.08.06" {
    supplementCodesc = "db1p"
    videoRange = "PQ"
    // ✅ 保持原始杜比视界编解码器
}
```

### 兼容性考虑
1. **向后兼容:** 不支持杜比视界的设备会自动降级为HEVC播放
2. **错误处理:** 保持现有的错误处理逻辑
3. **日志记录:** 保持现有的日志记录功能

### 测试验证点
1. **杜比视界识别:** 验证AVPlayer能正确识别杜比视界内容
2. **播放质量:** 确认播放质量为杜比视界而非HDR
3. **设备兼容性:** 测试不同Apple TV设备的兼容性
4. **降级机制:** 验证不支持设备的正确降级

## 架构修复方向
保持现有架构框架，重点修复编解码器处理逻辑，确保杜比视界信息的正确传递。 