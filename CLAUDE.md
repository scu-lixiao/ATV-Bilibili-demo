# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ATV-Bilibili-demo is a tvOS client for Bilibili (哔哩哔哩), featuring video playback, live streaming, and social features. This is a **demo project** and has never been officially released on the App Store or TestFlight.

**Platform:** tvOS (Apple TV)
**Language:** Swift
**Primary Frameworks:** UIKit, AVKit, TVUIKit
**Xcode:** 16.1+
**tvOS Target:** 18.1+

## Build & Development Commands

### Build
```bash
xcodebuild -project BilibiliLive.xcodeproj \
  -scheme BilibiliLive \
  -destination "platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=18.1" \
  build
```

### Run Tests
```bash
# Run all tests
xcodebuild -project BilibiliLive.xcodeproj \
  -scheme BilibiliLive \
  -destination "platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=18.1" \
  test

# Run Aurora Premium tests only
xcodebuild -project BilibiliLive.xcodeproj \
  -scheme BilibiliLive \
  -destination "platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=18.1" \
  -only-testing:AuroraPremiumTests \
  test
```

### Code Formatting
```bash
# Format code with SwiftFormat (from BuildTools)
cd BuildTools
swift run swiftformat ..
```

### Dependencies
```bash
# Install Ruby dependencies for CI/CD
bundle install
```

## Architecture Overview

### Module Structure

The codebase follows a modular architecture with clear separation of concerns:

```
BilibiliLive/
├── Module/              # Feature modules
│   ├── Video/          # Video playback and detail views
│   ├── Live/           # Live streaming features
│   ├── Personal/       # User profile, history, favorites
│   ├── ViewController/ # Main tab controllers (Feed, Hot, Ranking, etc.)
│   └── DLNA/           # DLNA/UPnP casting support
├── Component/           # Reusable components
│   ├── Player/         # Core player infrastructure
│   ├── Video/          # Video-specific components
│   ├── Feed/           # Feed/list views
│   ├── View/           # Custom UI components
│   │   └── Aurora/     # Aurora Premium visual effects (new)
│   └── Settings.swift  # App settings management
├── Request/            # Network layer
│   ├── ApiRequest.swift      # Bilibili API integration
│   ├── WebRequest.swift      # HTTP request wrapper
│   └── CookieManager.swift   # Authentication management
├── Extensions/         # Swift extensions
└── Vendor/            # Third-party code
    └── DanmakuKit/    # Danmaku (bullet comments) rendering
```

### Key Architectural Patterns

#### 1. Plugin-Based Player System
The video player uses a plugin architecture (`CommonPlayerPlugin`) that allows features to be added modularly:
- **Plugin Interface:** `BilibiliLive/Component/Player/Plugins/CommonPlayerPlugin.swift`
- **Key Plugins:**
  - `DanmuViewPlugin` - Danmaku overlay
  - `MaskViewPugin` - Video mask/overlay effects
  - `SponsorSkipPlugin` - SponsorBlock integration
  - `SpeedChangerPlugin` - Playback speed control
  - `BUpnpPlugin` - UPnP/DLNA casting

**To add a new player plugin:**
1. Implement `CommonPlayerPlugin` protocol
2. Override relevant lifecycle methods (e.g., `playerDidStart`, `playerDidChange`)
3. Add plugin in `CommonPlayerViewController` via `addPlugin(plugin:)`

#### 2. Aurora Premium Visual System (New Feature)
Located in `BilibiliLive/Component/View/Aurora/`, this is a layered visual effects system for enhanced UI animations:

**Core Components:**
- `BLAuroraPremiumCell` - Main cell class with visual enhancements
- `BLVisualLayerManager` - Coordinates multiple visual layers
- `BLVisualLayerFactory` - Creates visual layer instances
- `BLPerformanceMetrics` - Real-time performance monitoring

**Architecture Principles:**
- Protocol-based design (Dependency Inversion Principle)
- Separation of concerns via protocols:
  - `BLAnimationControllerProtocol` - Animation control
  - `BLPerformanceMonitorProtocol` - Performance tracking
  - `BLConfigurationManagerProtocol` - Configuration management
- Quality adaptation based on device capabilities

**Testing:** All Aurora Premium components have comprehensive unit tests in `Tests/AuroraPremiumTests/`

#### 3. Network Layer
- **API Signing:** All requests to Bilibili API require MD5 signature (see `ApiRequest.sign(for:)`)
- **WBI Signing:** Some endpoints require WBI signature (see `WebRequest+WbiSign.swift`)
- **Authentication:** Token-based auth stored in UserDefaults via `ApiRequest`

#### 4. Video Playback Flow
1. **Entry Point:** `VideoDetailViewController` or `LivePlayerViewController`
2. **Player Setup:** `CommonPlayerViewController` initializes `AVPlayerViewController`
3. **Resource Loading:** `BilibiliVideoResourceLoaderDelegate` handles custom URL schemes for DRM/auth
4. **Plugin Activation:** Plugins are added and notified of player lifecycle events
5. **Danmaku:** `VideoDanmuProvider` fetches and `DanmakuView` renders bullet comments

## Bilibili API Integration

### Authentication
- **QR Code Login:** `ApiRequest.EndPoint.loginQR` → `verifyQR`
- **Token Storage:** `ApiRequest.save(token:)` and `getToken()`
- **Cookie Management:** `CookieManager` handles web cookies for authenticated requests

### Key Endpoints
- Feed: `https://app.bilibili.com/x/v2/feed/index`
- Video Info: WebRequest methods in `Request/WebRequest.swift`
- Live Streaming: WebRequest methods for live room data
- Danmaku: Protobuf-based (see `dm.pb.swift`, `dmView.pb.swift`)

## UI Patterns

### TVUIKit Integration
- Uses `TVMonogramView` for user avatars
- Custom focus engine handling in collection views
- Focus-driven animations in `BLMotionCollectionViewCell`

### Collection View Controllers
- `StandardVideoCollectionViewController` - Base class for paginated lists
- `FeedCollectionViewController` - Custom layout for feed items
- Uses async/await for data loading (`request(page:) async throws`)

## Important Conventions

### Focus Behavior
tvOS focus management is critical. Most custom cells handle focus in `didUpdateFocus(in:with:)` with spring animations.

### Danmaku (弹幕) System
- Custom rendering engine in `Vendor/DanmakuKit/`
- Supports different track types (scroll, top, bottom)
- Filter system via `VideoDanmuFilter`
- Mask integration to avoid blocking key UI elements

### DLNA/UPnP Casting
- `BiliBiliUpnpDMR` implements UPnP Digital Media Renderer
- Custom protocol parsing for Bilibili's "哔哩必连" (BiliBili Connect)
- Socket-based communication in `NVASocket`

## CI/CD

GitHub Actions workflow (`.github/workflows/aurora-premium-tests.yml`) runs:
1. Architecture validation (checks required files exist)
2. Build for testing
3. Unit tests (Aurora Premium suite)
4. Performance tests
5. Memory leak detection
6. Code quality analysis (TODO/FIXME checks, file size, documentation)
7. Test coverage report

## Dependencies

### Swift Package Manager
- SwiftFormat (via `BuildTools/Package.swift`)

### CocoaPods/Carthage (Managed via Xcode)
- Alamofire - Networking
- SwiftyJSON - JSON parsing
- Kingfisher - Image loading/caching
- SnapKit - Auto Layout DSL
- MarqueeLabel - Scrolling text labels

## Code Style

- Uses SwiftFormat for consistent formatting
- Protocol-oriented design preferred
- Async/await for asynchronous operations
- Combine for reactive streams
- Extensions for code organization (see `Extensions/` directory)

## Testing Strategy

### Aurora Premium Tests
- **Unit Tests:** Test individual components in isolation
- **Performance Tests:** Measure animation performance and memory usage
- **Memory Safety:** Explicit memory cleanup tests (`testMemoryCleanup`)
- **Backward Compatibility:** Ensure Aurora features don't break existing functionality

### Test Targets
Run specific test classes:
```bash
-only-testing:AuroraPremiumTests/BLAuroraPremiumCellTests
-only-testing:AuroraPremiumTests/BLVisualLayerManagerTests
-only-testing:AuroraPremiumTests/BLPerformanceMetricsTests
```

## Important Notes

1. **No Official Distribution:** This project is not authorized for AppStore/TestFlight distribution
2. **API Keys:** `Keys.swift` contains API credentials - handle with care
3. **tvOS Simulator:** Default testing uses "Apple TV 4K (3rd generation)" simulator
4. **Protobuf Files:** `dm.pb.swift` and `dmView.pb.swift` are generated - do not manually edit
5. **Aurora Premium:** When modifying Aurora components, always run the full Aurora test suite
6. **Plugin System:** When adding player features, use the plugin pattern rather than modifying `CommonPlayerViewController` directly
