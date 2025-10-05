# SIGTERM Debugging Guide

**Last Updated:** 2025-10-06 07:50:00 +08:00

---

## Problem Description

You encountered: `Thread 1: signal SIGTERM` during app execution.

**SIGTERM** is a termination signal sent by the system or Xcode, usually indicating:
1. App was forcibly terminated (not a crash)
2. Memory pressure warning ignored
3. Watchdog timeout (app took too long to respond)
4. Xcode debugger restart/reattach

---

## Possible Causes

### 1. Memory Pressure (Most Likely)

**Symptoms:**
- App terminates after scrolling through many items
- Happens more frequently on older Apple TV models
- Console shows memory warnings before termination

**Diagnosis:**
```swift
// Add to AppDelegate or FeedCollectionViewController
NotificationCenter.default.addObserver(
    forName: UIApplication.didReceiveMemoryWarningNotification,
    object: nil,
    queue: .main
) { _ in
    Logger.warn("[Memory] ⚠️ Memory warning received!")
    // Log current memory usage
    let memory = BLPremiumPerformanceMonitor.shared.memoryUsage
    Logger.warn("[Memory] Current usage: \(memory)MB")
}
```

**Solution:**
1. Clear shadow cache on memory warning:
   ```swift
   BLShadowRenderer.clearAllCaches()
   ```

2. Reduce shadow cache limits in `BLShadowRenderer.swift:36-37`:
   ```swift
   cache.countLimit = 10 // Reduce from 20
   cache.totalCostLimit = 25 * 1024 * 1024 // Reduce from 50MB
   ```

3. Check for retain cycles (use Instruments > Leaks)

---

### 2. Watchdog Timeout

**Symptoms:**
- App freezes for several seconds
- Then receives SIGTERM
- Happens during heavy operations (large snapshot applications, image loading)

**Diagnosis:**
- Check if `applySnapshotSafely()` takes > 3 seconds
- Monitor main thread blocking in Instruments > Time Profiler

**Solution:**
- Already implemented: `isApplyingSnapshot` prevents concurrent operations
- Consider moving heavy operations to background thread (but be careful with UIKit)

---

### 3. Xcode Debugger Issues

**Symptoms:**
- SIGTERM happens randomly
- More frequent in Debug builds
- Doesn't happen in Release builds

**Solution:**
- Build in Release mode: `xcodebuild -configuration Release`
- Disable "Debug executable" in scheme settings
- Test on physical Apple TV (not simulator)

---

### 4. UIKit State Corruption

**Symptoms:**
- SIGTERM after specific user action (e.g., rapid scrolling, focus changes)
- Console shows UIKit warnings before termination

**Already Fixed:**
- `isApplyingSnapshot` prevents concurrent snapshot applications
- Removed `UIView.animate` wrapper around `dataSource.apply()`
- Added `defer` blocks for cleanup

---

## Debugging Steps

### Step 1: Enable Memory Monitoring

Add to `AppDelegate.swift` in `application(didFinishLaunchingWithOptions:)`:

```swift
// Memory warning observer
NotificationCenter.default.addObserver(
    forName: UIApplication.didReceiveMemoryWarningNotification,
    object: nil,
    queue: .main
) { [weak self] _ in
    Logger.warn("[Memory] ⚠️ MEMORY WARNING - App may be terminated soon!")

    // Emergency cleanup
    BLShadowRenderer.clearAllCaches()

    // Log state
    let memory = BLPremiumPerformanceMonitor.shared.memoryUsage
    let quality = BLPremiumPerformanceMonitor.shared.currentQualityLevel
    Logger.warn("[Memory] Usage: \(memory)MB, Quality: \(quality)")

    // Force lowest quality
    BLPremiumPerformanceMonitor.shared.setQualityLevel(.minimal)
}
```

### Step 2: Check Console Logs

Look for these patterns **before** SIGTERM:

```
[Memory] ⚠️ MEMORY WARNING
[FeedCollection] Snapshot application in progress, skipping  (← Good, prevents overlap)
Snapshot request 0x... complete with error  (← Bad, indicates UIKit issue)
```

### Step 3: Use Instruments

1. **Allocations:**
   - Check if memory grows unbounded
   - Look for large allocations (> 10MB)
   - Check if deinit is called for FeedCollectionViewController

2. **Leaks:**
   - Run Leaks instrument
   - Check for retain cycles in closures
   - Verify `[weak self]` is used in all closures

3. **Time Profiler:**
   - Check if main thread is blocked for > 1s
   - Look for expensive operations in `applySnapshotSafely()`

### Step 4: Test on Physical Device

Simulators have different memory characteristics than physical devices:
- Apple TV 4K (3rd gen): 4GB RAM
- Simulator: Uses Mac's RAM (unlimited)

**Test on real device:**
```bash
# Build for device
xcodebuild -project BilibiliLive.xcodeproj \
  -scheme BilibiliLive \
  -configuration Release \
  -destination 'platform=tvOS,name=Your Apple TV' \
  build
```

---

## Quick Fixes to Try

### Fix 1: Reduce Shadow Cache (Immediate)

Edit `BilibiliLive/Component/View/Aurora/BLShadowRenderer.swift:36-37`:

```swift
cache.countLimit = 10 // ← Reduce from 20
cache.totalCostLimit = 25 * 1024 * 1024 // ← Reduce from 50MB
```

### Fix 2: Disable Batch Coordinator (Temporary Test)

Edit `BilibiliLive/Component/Settings.swift`:

```swift
@UserDefault("Settings.enableScrollOptimization", defaultValue: false) // ← Change to false
static var enableScrollOptimization: Bool
```

Or in runtime:
```swift
Settings.enableScrollOptimization = false
```

### Fix 3: Force Lower Quality (Temporary Test)

In `AppDelegate.swift` after `startMonitoring()`:

```swift
BLPremiumPerformanceMonitor.shared.startMonitoring()
BLPremiumPerformanceMonitor.shared.setQualityLevel(.medium) // ← Force medium quality
```

---

## Expected Behavior

### Normal Operation:
```
[Performance] Performance monitoring started
[FeedCollection] appendData called with 12 items, after filtering: 12 items, current total: 0
[FeedCollection] Applying incremental snapshot with 12 items
[FeedCollection] Incremental snapshot applied: +12 -0 ~0
[Aurora Premium] Quality level changed: ultra → high (FPS: 52.3)
[Aurora Premium] Entered scrolling mode, quality: low
[Aurora Premium] Exited scrolling mode, quality: high
```

### Memory Warning (Recoverable):
```
[Memory] ⚠️ MEMORY WARNING
[Memory] Usage: 87.3MB, Quality: high
[Aurora Premium] Quality level changed: high → minimal
Shadow cache hit rate: 92.1%
[Memory] Emergency cleanup complete
```

### Critical Failure (Leads to SIGTERM):
```
[Memory] ⚠️ MEMORY WARNING
[Memory] Usage: 143.7MB, Quality: ultra  (← Too high!)
[FeedCollection] Snapshot application in progress, skipping
[FeedCollection] Snapshot application in progress, skipping  (← Multiple failures)
Thread 1: signal SIGTERM
```

---

## Long-Term Solutions

### 1. Implement Intelligent Cache Eviction

```swift
// In BLShadowRenderer.swift, add to prerenderedShadow():
if memoryUsage > 80.0 { // MB
    memoryCache.removeAllObjects()
    Logger.debug("[Shadow] Cache cleared due to memory pressure")
}
```

### 2. Lazy Shadow Loading

```swift
// Only load shadows for visible cells
func applyShadowImage(for level: BLPerformanceQualityLevel) {
    guard isVisible else { return } // ← Add visibility check
    // ... rest of code
}
```

### 3. Progressive Quality Degradation

```swift
// In BLPremiumPerformanceMonitor, modify checkQualityAdaptation():
if memoryUsage > 90.0 {
    setQualityLevel(.minimal) // Emergency mode
} else if memoryUsage > 70.0 {
    setQualityLevel(.low)
}
```

---

## When to Report a Bug

If SIGTERM persists after trying all fixes:

1. **Collect Information:**
   - Console logs (entire session)
   - Memory usage graph
   - Steps to reproduce
   - Device model (Apple TV 4K 3rd gen, etc.)

2. **Check for Patterns:**
   - Does it happen after N items loaded?
   - Does it happen during specific actions?
   - Is it reproducible?

3. **Create Minimal Reproduction:**
   - Disable all optimizations
   - Enable one at a time
   - Identify which optimization causes SIGTERM

---

## Current Status

✅ **Fixed Issues:**
- BSActionErrorDomain response-not-possible (mutual exclusion guard)
- Initial load delay (progressive enhancement)
- Memory leaks in focus animations (weak self)

⚠️ **Investigating:**
- SIGTERM during normal operation
- Possible memory pressure from shadow cache

📋 **Next Steps:**
1. Monitor memory usage in console logs
2. Test with reduced shadow cache limits
3. Use Instruments to identify memory growth
4. Test on physical Apple TV device

---

## Contact & Support

If you need further assistance:
- Check console logs for `[Memory]`, `[FeedCollection]`, `[Aurora Premium]` tags
- Use Instruments (Allocations, Leaks, Time Profiler)
- Test in Release configuration
- Test on physical device

**Remember:** SIGTERM is usually **recoverable** - it's the system protecting itself from resource exhaustion.
