# Dolby Vision 播放修复文档

## 问题描述

项目无法播放 Bilibili 的杜比视界 (Dolby Vision) 视频，会回退到 SDR 格式播放。

### 错误表现

- 日志显示: `unknown hdr codecs: hvc1.2.4.L150.90`
- AVPlayer 报错: `err=-12860` (视频解码失败)
- 播放器自动回退到 SDR 格式 (avc1/hev1 编码)

## 根本原因

Bilibili 返回的杜比视界视频使用 codec `hvc1.2.4.L150.90`，但代码在 DASH 到 HLS 转换过程中：

1. **未添加 SUPPLEMENTAL-CODECS**: 缺少 `dvh1.08.07/db4h` 声明
2. **codec 格式不规范**: `.90` 后缀应改为 `.b0` (Apple HLS 规范)
3. **处理逻辑缺失**: 只匹配 `dvh1` 开头的 codec，未处理 Bilibili 的 `hvc1` 格式

导致 AVPlayer 无法识别这是 Dolby Vision 内容，按普通 HEVC 解码时因 HDR 元数据格式不匹配而失败。

## 技术细节

### Bilibili Dolby Vision 格式

- **Quality ID**: 126 (`MediaQualityEnum.quality_hdr_dolby`)
- **Codec**: `hvc1.2.4.L150.90` (HEVC Main 10 Profile, Level 5.0)
- **Transfer Function**: HLG (Hybrid Log-Gamma)
- **Dolby Vision Profile**: 8.4 (HLG 兼容模式)

### Apple HLS 规范要求

根据 [Apple HLS Authoring Specification](https://developer.apple.com/documentation/http_live_streaming/hls-authoring-specification-for-apple-devices-appendixes):

```
#EXT-X-STREAM-INF:
  CODECS="hvc1.2.4.L150.b0",
  SUPPLEMENTAL-CODECS="dvh1.08.07/db4h",
  VIDEO-RANGE=HLG
```

**说明**:
- `hvc1.2.4.L150.b0`: 基础 HEVC 编码层
  - `hvc1`: HEVC 标识符
  - `2`: Main 10 Profile (10-bit)
  - `4`: Profile compatibility flags
  - `L150`: Level 5.0 (支持 4K@30fps)
  - `b0`: Constraint flags (Apple 规范格式)
- `dvh1.08.07/db4h`: Dolby Vision 增强层
  - `dvh1.08.07`: Profile 8.4
  - `db4h`: HLG backward-compatible mode
- `VIDEO-RANGE=HLG`: Hybrid Log-Gamma transfer function

## 修复方案

### 实施的修复 (方案 2 - 优化型)

在 `BilibiliVideoResourceLoaderDelegate.swift` 第 94-100 行添加处理逻辑:

```swift
// Handle Bilibili Dolby Vision: HEVC Main 10 Profile with HLG
// Bilibili returns hvc1.2.4.L15x.90 format, need to convert to Apple HLS standard
if isDolby && codecs.hasPrefix("hvc1.2.4.L15") {
    // Standardize codec string: .90 -> .b0 (Apple HLS specification)
    supplementCodesc = "dvh1.08.07/db4h"
    codecs = codecs.replacingOccurrences(of: ".90", with: ".b0")
    videoRange = "HLG"
} else if codecs == "dvh1.08.07" || codecs == "dvh1.08.03" {
    // 原有 dvh1 处理逻辑...
```

### 修复要点

1. **添加 Dolby Vision 分支**: 在原有 `dvh1` 判断之前插入新分支
2. **双重条件验证**:
   - `isDolby`: 确保 quality ID = 126 (杜比视界)
   - `codecs.hasPrefix("hvc1.2.4.L15")`: 验证 HEVC Main 10 编码
3. **标准化处理**:
   - 添加 `SUPPLEMENTAL-CODECS="dvh1.08.07/db4h"`
   - 将 `.90` 后缀替换为 `.b0`
   - 设置 `VIDEO-RANGE=HLG`

### HDR10 兼容性保证

修复方案**不会影响 HDR10 视频**，因为:

| 格式 | Quality ID | isDolby | VIDEO-RANGE | 处理分支 |
|------|-----------|---------|-------------|---------|
| **Dolby Vision** | 126 | true | HLG | 新增分支 ✅ |
| **HDR10** | 125 | false | PQ | isHDR10 分支 ✅ |
| **SDR** | 其他 | false | SDR | 无 HDR 处理 |

**互斥性保证**: `isDolby` 和 `isHDR10` 基于不同的 quality ID，绝对互斥。

## 测试验证

### 测试步骤

1. **启动应用并登录**
2. **搜索杜比视界视频**: 
   - 例如: "4K 杜比视界"
   - 查找标有 "杜比视界" 标签的视频
3. **选择最高画质**: 在设置中选择 "杜比视界"
4. **播放并观察**:
   - 检查视频是否正常播放
   - 在 Debug Plugin 中查看格式信息
   - 确认显示 "Dolby Vision" 而非 "SDR"

### 预期日志输出

**修复前**:
```
unknown hdr codecs: hvc1.2.4.L150.90
<<<< PlayerRemoteXPC >>>> signalled err=-12860
```

**修复后**:
```
masterPlaylist: 
#EXT-X-STREAM-INF:AUDIO="audio",CODECS="hvc1.2.4.L150.b0",SUPPLEMENTAL-CODECS="dvh1.08.07/db4h",RESOLUTION=3840x2160,FRAME-RATE=29.970,BANDWIDTH=9612522,VIDEO-RANGE=HLG
...
send status: playing
```

### 验证要点

- ✅ 不再有 "unknown hdr codecs" 警告
- ✅ 不再有 `-12860` 错误
- ✅ HLS manifest 包含 `SUPPLEMENTAL-CODECS`
- ✅ codec 后缀为 `.b0` 而非 `.90`
- ✅ 视频正常播放，不回退到 SDR

## 技术参考

### HEVC Level 定义

| Level | 代码 | 最大分辨率 | 最大帧率 | 最大码率 |
|-------|------|-----------|---------|---------|
| 5.0 | L150 | 4096x2304 | 30fps | 12 Mbps |
| 5.1 | L153 | 4096x2304 | 60fps | 20 Mbps |
| 5.2 | L156 | 4096x2304 | 120fps | 25 Mbps |

### Dolby Vision Profiles

| Profile | 描述 | VIDEO-RANGE | SUPPLEMENTAL-CODECS |
|---------|-----|-------------|---------------------|
| 5 | IPTPQc2 (HDR10 兼容) | PQ | dvh1.05.xx |
| 8.1 | HEVC + PQ (HDR10 兼容) | PQ | dvh1.08.06/db1p |
| 8.4 | HEVC + HLG (HLG 兼容) | HLG | dvh1.08.07/db4h |

### 相关文档

- [Apple HLS Authoring Specification - Dolby Vision](https://developer.apple.com/documentation/http_live_streaming/hls-authoring-specification-for-apple-devices-appendixes)
- [MPEG-DASH to HLS Conversion](https://github.com/thmatuza/MPEGDASHAVPlayerDemo)
- [Apple - Support HDR video playback](https://developer.apple.com/news/?id=rwbholxw)
- [Dolby Vision Profile 8.4 Technical Details](https://professionalsupport.dolby.com/s/article/What-is-Dolby-Vision-Profile-8-1-and-8-4)

## 代码结构说明

### 相关文件

1. **BilibiliVideoResourceLoaderDelegate.swift** (修改)
   - 第 94-100 行: 添加 Dolby Vision 处理分支
   - 负责 DASH 到 HLS 的转换
   
2. **Settings.swift** (无修改)
   - `MediaQualityEnum.quality_hdr_dolby`: qn=126, fnval=976
   
3. **WebRequest.swift** (无修改)
   - `VideoPlayURLInfo.DashInfo.DashMediaInfo`: 包含 codec、segment_base 等信息

### 转换流程

```
Bilibili API (JSON)
    ↓
VideoPlayURLInfo.dash.video
    ↓ (含 id=126, codecs="hvc1.2.4.L150.90")
BilibiliVideoResourceLoaderDelegate
    ↓
addVideoPlayBackInfo()
    ↓ (检测 isDolby && hvc1.2.4.L15)
生成 HLS Manifest
    ↓ (添加 SUPPLEMENTAL-CODECS)
#EXT-X-STREAM-INF
    ↓
AVPlayer 播放
    ✅ 识别 Dolby Vision
```

## 注意事项

1. **设备要求**: 需要支持 Dolby Vision 的 Apple TV 4K (2021 或更新款)
2. **tvOS 版本**: 建议 tvOS 14.0+
3. **显示设备**: 需要支持 HLG 的电视或显示器
4. **会员要求**: Bilibili 大会员才能观看杜比视界内容

## 后续优化建议

1. **支持更多 Level**: 当前支持 L15x (Level 5.0-5.2)，可扩展到 L12x (Level 4.x)
2. **Profile 8.1 支持**: 添加 PQ 模式的 Dolby Vision (dvh1.08.06/db1p)
3. **自动降级**: 当设备不支持 Dolby Vision 时，自动选择 HDR10 或 SDR
4. **日志优化**: 为 Dolby Vision 播放添加专门的调试日志

## 更新记录

- **2025-11-09**: 
  - ✅ 修复 Dolby Vision HLG (Profile 8.4) 播放问题
  - ✅ 添加 `hvc1.2.4.L15x` 格式支持
  - ✅ 标准化 codec 字符串 (.90 → .b0)
  - ✅ 确保与 HDR10 处理互不干扰
