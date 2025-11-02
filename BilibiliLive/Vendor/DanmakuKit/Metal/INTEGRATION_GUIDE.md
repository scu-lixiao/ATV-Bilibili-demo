# Metal 4 弹幕渲染优化集成指南

## ⚠️ 重要通知（2025-01-02）

**Metal 4 弹幕渲染功能已从项目中移除。**

### 移除原因

1. **架构不兼容**: DanmakuKit 使用 `DanmakuAsyncLayer`（CGContext 渲染），Metal 需要 `CAMetalLayer`（GPU 直接渲染），两者无法兼容
2. **性能问题**: GPU→CPU 数据传输（`texture.getBytes()`）导致程序卡死，性能比原方案慢 10-20 倍
3. **开发成本高**: 完全适配 Metal 需要重写整个 DanmakuKit 渲染层（1-2 周工作量）
4. **收益有限**: CGImage 缓存已提供 15-50x 性能提升，Metal 理论最多再提升 2-3x（边际收益递减）

### 当前解决方案

项目现在使用 **CGImage LRU 缓存** 方案：
- ✅ 性能提升 15-50 倍（缓存命中时 0.1-0.2 ms vs 原始 3-5 ms）
- ✅ 稳定可靠，无崩溃、无卡顿
- ✅ 兼容所有 iOS/tvOS 版本
- ✅ 用户可选择"无缓存"或"CGImage 缓存"两种渲染模式

### 用户设置

在 `Settings.swift` 中提供了渲染模式设置：

```swift
enum DanmakuRenderMode: String, Codable, CaseIterable {
    case none           // 不使用缓存，每次实时渲染
    case cgImageCache   // 使用 CGImage 缓存（推荐，默认）
}

@UserDefaultCodable("Settings.danmuRenderMode", defaultValue: .cgImageCache)
static var danmuRenderMode: DanmakuRenderMode
```

用户可在设置界面选择渲染模式，无需重启应用。

### 技术细节

详见：`doc/DANMAKU_CGIMAGE_CACHE_OPTIMIZATION_REPORT.md`

---

## 历史参考（Metal 4 原始设计）

以下内容仅作为历史参考，代码已不存在。

---

## 概述

本文档介绍如何在 ATV-Bilibili-demo 项目中启用和使用 Metal 4 弹幕渲染优化。

---

## 架构设计

### 核心组件

```
┌─────────────────────────────────────────────────────────┐
│                    DanmakuView                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │  DanmakuTextCellModel (选择渲染引擎)               │  │
│  │  ├─ MetalDanmakuTextCell (tvOS 26+)               │  │
│  │  └─ DanmakuTextCell (降级)                        │  │
│  └───────────────────────────────────────────────────┘  │
│                          │                               │
│                          ▼                               │
│  ┌───────────────────────────────────────────────────┐  │
│  │         MetalDanmakuLayer (CAMetalLayer)          │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  MetalTextureCache (LRU, 500 条)            │  │  │
│  │  │  ├─ 缓存命中 → 直接返回 MTLTexture          │  │  │
│  │  │  └─ 缓存未命中 → CoreText 生成纹理          │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  MetalBatchRenderer                         │  │  │
│  │  │  ├─ Vertex Shader (位置变换)                │  │  │
│  │  │  └─ Fragment Shader (纹理采样)              │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### 文件结构

```
BilibiliLive/Vendor/DanmakuKit/Metal/
├── MetalTextureCache.swift       # LRU 纹理缓存
├── MetalShaders.metal            # Metal Shader 代码
├── MetalBatchRenderer.swift      # 批量渲染器
├── MetalDanmakuLayer.swift       # Metal 渲染层
├── MetalDanmakuTextCell.swift    # Metal 弹幕 Cell
└── MetalDanmakuConfig.swift      # 配置管理
```

---

## 启用 Metal 渲染

### 方式 1：全局启用（推荐）

在 `AppDelegate.swift` 或应用启动时：

```swift
if #available(tvOS 26.0, *) {
    // 启用 Metal 4 弹幕渲染
    Settings.danmuMetalRenderingEnabled = true
    
    // 设置性能模式（可选）
    Settings.danmuMetalPerformanceMode = .balanced
    
    // 启用性能监控（开发时）
    MetalDanmakuConfig.enablePerformanceLogging = true
    MetalDanmakuConfig.startPerformanceMonitoring()
    
    // 打印设备信息
    Logger.debug(MetalDanmakuConfig.getDeviceInfo())
}
```

### 方式 2：用户设置项

在设置界面添加开关：

```swift
Toggle("启用 Metal 4 渲染", isOn: $Settings.danmuMetalRenderingEnabled)

Picker("性能模式", selection: $Settings.danmuMetalPerformanceMode) {
    Text("低功耗").tag(MetalPerformanceMode.lowPower)
    Text("平衡").tag(MetalPerformanceMode.balanced)
    Text("高性能").tag(MetalPerformanceMode.highPerformance)
}
```

---

## 性能监控

### 实时统计

```swift
// 打印缓存统计信息
if #available(tvOS 26.0, *) {
    MetalDanmakuTextCell.printMetalCacheStats()
}

// 输出示例：
// Metal Texture Cache Stats:
// - Size: 342/500
// - Hit Rate: 87.32%
// - Hits: 8234, Misses: 1198
```

### Instruments 分析

1. **Metal System Trace**
   - 检查 draw call 数量（应显著减少）
   - 查看 GPU 时间线

2. **Allocations**
   - 监控纹理内存占用（~25MB）
   - 检查是否有内存泄漏

3. **Time Profiler**
   - 对比 CPU 使用率（应降低 80%）
   - 分析 CoreText 生成纹理的时间

---

## 性能优化建议

### 1. 缓存大小调整

根据实际情况调整缓存大小：

```swift
// 内存充足时
Settings.danmuMetalPerformanceMode = .highPerformance  // 1000 条缓存

// 内存受限时
Settings.danmuMetalPerformanceMode = .lowPower  // 200 条缓存
```

### 2. 预热缓存

在视频加载时预渲染高频弹幕：

```swift
if #available(tvOS 26.0, *) {
    let commonTexts = ["666", "哈哈哈", "前排"]
    for text in commonTexts {
        let _ = MetalTextureCache.shared.getTexture(
            for: text,
            font: UIFont.systemFont(ofSize: Settings.danmuSize.size),
            color: .white,
            size: CGSize(width: 100, height: 30)
        )
    }
}
```

### 3. 降级策略

Metal 不可用时自动降级到 Core Graphics：

```swift
// 系统自动处理，无需手动干预
// MetalDanmakuLayer 内部会检测并降级
```

---

## 已知限制

### 1. 兼容性
- ✅ 仅支持 tvOS 26+（Apple TV 4K 2nd Gen 及以上）
- ✅ 需要 Metal 支持的设备
- ⚠️ 旧设备自动降级到 Core Graphics

### 2. 性能特性
- ✅ 缓存命中率 >80% 时性能提升最显著
- ⚠️ 首次渲染仍需 CPU 生成纹理
- ✅ 适合弹幕重复率高的场景

### 3. 功能限制
- ✅ 支持任意 Unicode 字符
- ✅ 支持描边、透明度、颜色
- ⚠️ 当前版本不支持特殊字体效果（渐变、阴影等）

---

## 故障排除

### 问题 1: Metal 渲染不生效

**检查步骤**：
```swift
// 1. 检查设备支持
if #available(tvOS 26.0, *) {
    print("Metal Available: \(MetalDanmakuConfig.isMetalAvailable)")
}

// 2. 检查配置
print("Metal Rendering Enabled: \(Settings.danmuMetalRenderingEnabled)")

// 3. 检查日志
// 查找 "Metal not available" 或 "Failed to initialize" 警告
```

### 问题 2: 性能未提升

**可能原因**：
- 缓存命中率过低（<50%）→ 增加缓存大小
- 弹幕数量过少（<100）→ Metal 优势不明显
- GPU 瓶颈（多个视频同时播放）→ 减少并发数

**解决方案**：
```swift
// 调整性能模式
Settings.danmuMetalPerformanceMode = .highPerformance

// 检查缓存统计
MetalDanmakuTextCell.printMetalCacheStats()
```

### 问题 3: 内存占用过高

**解决方案**：
```swift
// 降低缓存大小
Settings.danmuMetalPerformanceMode = .lowPower

// 手动清理缓存
MetalTextureCache.shared.clearCache()
```

---

## 性能测试

### 测试场景

1. **轻量场景**（50-100 条弹幕）
   - 预期提升：100-150%
   - CPU 降低：50-60%

2. **中等场景**（200-500 条弹幕）
   - 预期提升：200%
   - CPU 降低：70-80%

3. **重负载**（1000+ 条弹幕）
   - 预期提升：200-250%
   - CPU 降低：80%+

### 测试命令

```bash
# 使用 Instruments 性能测试
xcrun xctrace record \
  --template 'Metal System Trace' \
  --device 'Apple TV' \
  --launch BilibiliLive

# 分析结果
open *.trace
```

---

## 未来优化方向

### 短期（可选）
- [ ] 纹理数组支持（减少 draw call 到 1 个）
- [ ] 预加载高频弹幕
- [ ] 自适应缓存大小

### 长期（实验性）
- [ ] SDF 文本渲染（极致性能）
- [ ] MetalFX 后处理特效
- [ ] GPU 弹幕碰撞检测

---

## 参考资源

- [Metal 4 官方文档](https://developer.apple.com/documentation/metal)
- [WWDC25: Discover Metal 4](https://developer.apple.com/videos/play/wwdc2025/205/)
- [tvOS 26 Release Notes](https://developer.apple.com/documentation/tvos-release-notes/tvos-26-release-notes)
- [项目文档: TVOS_26_OPTIMIZATION_REPORT.md](../doc/TVOS_26_OPTIMIZATION_REPORT.md)

---

**最后更新**: 2025-11-01  
**版本**: 1.0.0  
**维护者**: AI Assistant
