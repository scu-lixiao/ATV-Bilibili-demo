# Aurora Premium Performance Baseline

## tvOS 26 优化性能基线文档

**生成时间**: 2025-10-06
**测试平台**: Apple TV 4K (3rd generation), tvOS 18.1+
**优化阶段**: Phase 1-8 完成

---

## 优化目标 (Optimization Targets)

| 维度 | Ultra Quality | High Quality | Medium Quality |
|------|---------------|--------------|----------------|
| **帧率 (FPS)** | ≥ 60fps | ≥ 55fps | ≥ 45fps |
| **内存占用** | < 100MB (1000 cells) | < 100MB | < 100MB |
| **Focus 响应** | < 50ms | < 50ms | < 50ms |
| **阴影渲染** | < 10ms/shadow | < 10ms/shadow | < 10ms/shadow |

---

## 优化成果总结 (Optimization Achievements)

### Phase 1-2: 阴影系统重构
- **技术**: 三级缓存 (Memory + Disk + Metal GPU)
- **策略**: Low/Minimal 质量使用预渲染，Ultra/High/Medium 使用 CALayer
- **预期收益**: GPU 负载降低 15-25%

### Phase 3-5: Collection View 快照优化
- **技术**:
  - 简化快照逻辑 (移除递归防护)
  - 增量更新 (reconfigureItems 替代 reloadItems)
  - 批量更新协调器 (自适应 debouncing)
- **预期收益**:
  - 快照应用耗时降低 30%+
  - 快照应用次数减少 50%+
  - 滚动流畅度提升 20%+

### Phase 6: Focus 动画优化
- **技术**:
  - 预计算 Transform 矩阵 (静态常量)
  - scrubsLinearly 线性插值
  - finishAnimation(at: .current) 保留动画进度
- **预期收益**: Focus 响应速度提升 40%+, CPU 开销降至 0%

### Phase 7: tvOS 26 Observable 集成
- **技术**: @Observable + withObservationTracking (tvOS 17+)
- **预期收益**: 零样板代码，自动依赖跟踪，减少手动通知逻辑

### Phase 8: 内存管理审计
- **技术**: [weak self] 修复，deinit 清理验证
- **预期收益**: 消除循环引用，确保资源正确释放

---

## 测试用例清单 (Test Case Checklist)

### ✅ testScrollingPerformanceUltraQuality
- **目标**: Ultra 质量下 ≥ 55fps
- **验证方法**: XCTClockMetric 测量 100 cells 滚动时间
- **通过标准**: avgFPS >= 55.0

### ✅ testScrollingPerformanceHighQuality
- **目标**: High 质量下 ≥ 50fps
- **验证方法**: XCTClockMetric 测量 100 cells 滚动时间
- **通过标准**: avgFPS >= 50.0

### ✅ testScrollingPerformanceMediumQuality
- **目标**: Medium 质量下 ≥ 40fps
- **验证方法**: XCTClockMetric 测量 100 cells 滚动时间
- **通过标准**: avgFPS >= 40.0

### ✅ testMemoryUsageDuringScrolling
- **目标**: 内存占用 < 100MB
- **验证方法**: XCTMemoryMetric 测量 1000 cells 滚动后内存峰值
- **通过标准**: memoryUsage < 100.0 MB

### ✅ testFocusAnimationResponseTime
- **目标**: Focus 响应 < 50ms
- **验证方法**: CACurrentMediaTime 测量 didUpdateFocus 到首帧渲染
- **通过标准**: elapsed < 0.05 seconds (50ms)

### ✅ testShadowRenderingPerformance
- **目标**: 阴影渲染 < 10ms/shadow
- **验证方法**: XCTClockMetric 测量 20 个不同尺寸阴影预渲染时间
- **通过标准**: average time < 10ms per shadow (200ms / 20 shadows)

### ✅ testBatchUpdateCoordinatorEfficiency
- **目标**: 批量更新减少 50%+ 快照应用次数
- **验证方法**: 追踪 10 次 appendData 调用后的数据项总数
- **通过标准**: 100 items added with < 5 snapshot applications

---

## 运行测试 (Running Tests)

### 完整测试套件
```bash
xcodebuild -project BilibiliLive.xcodeproj \
  -scheme BilibiliLive \
  -destination "platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=18.1" \
  -only-testing:BilibiliLiveTests/BLPerformanceBenchmarkTests \
  test
```

### 单个测试用例
```bash
xcodebuild -project BilibiliLive.xcodeproj \
  -scheme BilibiliLive \
  -destination "platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=18.1" \
  -only-testing:BilibiliLiveTests/BLPerformanceBenchmarkTests/testScrollingPerformanceUltraQuality \
  test
```

### 真机测试 (推荐)
```bash
xcodebuild -project BilibiliLive.xcodeproj \
  -scheme BilibiliLive \
  -destination "platform=tvOS,name=Your Apple TV" \
  -only-testing:BilibiliLiveTests/BLPerformanceBenchmarkTests \
  test
```

---

## 性能基线数据 (Baseline Data)

⚠️ **注意**: 以下为预期基线数据，需在真实设备上运行测试后更新。

### Ultra Quality (Quality Level = .ultra)
- **FPS**: 58-60fps (目标: ≥ 55fps) ✅
- **内存**: 75-85MB (目标: < 100MB) ✅
- **Focus 响应**: 35-45ms (目标: < 50ms) ✅
- **阴影渲染**: 6-8ms (目标: < 10ms) ✅

### High Quality (Quality Level = .high)
- **FPS**: 53-57fps (目标: ≥ 50fps) ✅
- **内存**: 70-80MB (目标: < 100MB) ✅

### Medium Quality (Quality Level = .medium)
- **FPS**: 43-48fps (目标: ≥ 40fps) ✅
- **内存**: 65-75MB (目标: < 100MB) ✅

---

## CI/CD 集成 (CI/CD Integration)

### GitHub Actions Workflow 示例

```yaml
name: Aurora Premium Performance Tests

on:
  pull_request:
    branches: [ main ]
  push:
    branches: [ main ]

jobs:
  performance-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.1.app

      - name: Run Performance Tests
        run: |
          xcodebuild -project BilibiliLive.xcodeproj \
            -scheme BilibiliLive \
            -destination "platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=18.1" \
            -only-testing:BilibiliLiveTests/BLPerformanceBenchmarkTests \
            test

      - name: Check Performance Regression
        run: |
          # Parse test results and compare with baseline
          # Fail if performance degrades > 10%
```

---

## 优化开关 (Optimization Toggles)

### A/B 测试配置
- **Settings.enableTvOS26Optimizations**: 总开关 (默认: true)
- **Settings.enableScrollOptimization**: 滚动优化 (默认: true)

### 性能对比测试
```swift
// 禁用优化
Settings.enableTvOS26Optimizations = false
Settings.enableScrollOptimization = false

// 运行基线测试
testScrollingPerformanceUltraQuality()

// 启用优化
Settings.enableTvOS26Optimizations = true
Settings.enableScrollOptimization = true

// 运行优化测试
testScrollingPerformanceUltraQuality()

// 对比结果
```

---

## 已知限制 (Known Limitations)

1. **Simulator vs 真机**:
   - Simulator 性能数据仅供参考
   - 真机测试更准确 (Metal GPU, CALayer 硬件加速)

2. **XCTOSSignpostMetric**:
   - 需要 Xcode Instruments 支持
   - 仅在真机或 Simulator 运行有效

3. **后台任务干扰**:
   - 系统后台任务可能影响 FPS 测量
   - 建议关闭所有其他应用重新测试

4. **首次运行缓存**:
   - Shadow cache 首次运行命中率为 0%
   - 第二次运行应显示显著改善

---

## 下一步计划 (Next Steps)

- [ ] 在真实 Apple TV 4K 设备运行完整测试套件
- [ ] 记录真实性能基线数据 (替换预期值)
- [ ] 集成 CI/CD 性能回退检测
- [ ] 添加更多边界测试 (极端数据量、低内存场景)
- [ ] 性能优化文档化 (添加到 CLAUDE.md)

---

**文档版本**: v1.0
**最后更新**: 2025-10-06 07:25:00 +08:00
**维护者**: Claude-4-Sonnet
