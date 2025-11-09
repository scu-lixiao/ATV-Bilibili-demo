# ATV-Bilibili-demo AI Coding Agent Instructions

## Project Overview
A tvOS (Apple TV) client for Bilibili video platform. This is an **unofficial, open-source, non-commercial** project that implements Bilibili's features including video playback, live streaming, danmu (bullet comments), and cloud-projection protocols.

**Critical**: This project is designed specifically for **tvOS**, not iOS. All UI/UX decisions follow Apple TV interaction patterns (focus engine, remote control, spatial navigation).

## Architecture & Core Components

### 1. Plugin-Based Video Player System
The player architecture uses a modular plugin system centered around `CommonPlayerPlugin` protocol:

```swift
// Plugin lifecycle hooks
protocol CommonPlayerPlugin: NSObject {
    func playerDidLoad(playerVC: AVPlayerViewController)
    func playerDidChange(player: AVPlayer)
    func addViewToPlayerOverlay(container: UIView)
    func addMenuItems(current: inout [UIMenuElement]) -> [UIMenuElement]
    // ... lifecycle methods
}
```

**Key plugins** (in `BilibiliLive/Component/Player/Plugins/` and `Component/Video/Plugins/`):
- `BVideoPlayPlugin`: Manages video playback, DASH/HLS handling
- `DanmuViewPlugin`: Renders bullet comments overlay using `DanmakuKit`
- `BVideoInfoPlugin`: Shows video metadata UI
- `SponsorSkipPlugin`: Auto-skip sponsored segments
- `MaskViewPugin`: Implements danmu occlusion prevention
- `BUpnpPlugin`: Handles cloud-projection (投屏) via DLNA/UPnP

**Pattern**: Plugins are added dynamically to `CommonPlayerViewController` via `addPlugin(plugin:)`. Each plugin can:
1. Add overlay views to `playerVC.contentOverlayView`
2. Contribute custom menu items
3. React to player lifecycle events

### 2. API Layer Architecture

**Two request systems with distinct purposes**:

- **`ApiRequest`** (BilibiliLive/Request/ApiRequest.swift): TV-specific APIs using `appkey`/`appsec` signing
  - Uses `sign(for:)` to add MD5 signatures with hardcoded app credentials
  - Handles OAuth token management (refresh, SSO cookies)
  - Endpoints: QR login, token refresh, TV-optimized feeds

- **`WebRequest`** (BilibiliLive/Request/WebRequest.swift): Web APIs with WBI signing
  - Implements Bilibili's anti-scraping WBI signature via `WebRequest+WbiSign.swift`
  - Manages CSRF tokens via `CookieHandler.shared.csrf()`
  - Uses custom `User-Agent` and `Referer` headers from `Keys.swift`
  - Supports area-unlock proxy for region-restricted content

**Authentication flow**: QR code → poll endpoint → receive token → save via `ApiRequest.save(token:)` → auto-refresh when expires in <30h

### 3. Settings & State Management

**Custom property wrappers** (BilibiliLive/Extensions/):
```swift
@UserDefault("Settings.key", defaultValue: false) static var someSetting: Bool
@UserDefaultCodable("Settings.key", defaultValue: .normal) static var complexSetting: EnumType
@Published(key: "Settings.key") var observableSetting = true  // Auto-syncs to UserDefaults
```

All settings centralized in `Settings.swift` with structured enums (e.g., `MediaQualityEnum`, `DanmuArea`, `SponsorBlockType`). Settings persist automatically via UserDefaults.

### 4. Danmu (Bullet Comment) System

**Provider pattern**: `VideoDanmuProvider` implements `DanmuProviderProtocol`
- Fetches danmu in 6-minute segments on-demand (lazy loading)
- Parses protobuf format (`dm.pb.swift`, `dmView.pb.swift`)
- Supports AI-based filtering (智能防挡), duplicate removal, mask protection
- Streams danmu via Combine's `onSendTextModel` publisher

**Integration**: `DanmuViewPlugin` subscribes to danmu provider and renders using `DanmakuKit` library with configurable area, size, opacity, and stroke.

### 5. DLNA/UPnP Cloud-Projection Protocol

`BiliBiliUpnpDMR` (BilibiliLive/Module/DLNA/) implements Bilibili's proprietary "云视听小电视" (cloud-projection) protocol:
- Runs UPnP SSDP server for device discovery
- HTTP server serving DLNA device description XMLs
- Custom "NVA" WebSocket protocol for control commands
- Handles projection events: play/pause/seek/switch video

**Start**: Called in `AppDelegate.didFinishLaunchingWithOptions` → `BiliBiliUpnpDMR.shared.start()`

## Critical Development Patterns

### Navigation & View Controllers
- **MenusViewController**: Apple TV+ style main menu with side navigation (see `BilibiliLive/Component/Menu/`)
- **Tab persistence**: Selected tab saved via `selectedIndexKey` in UserDefaults
- **Focus management**: Override `preferredFocusEnvironments` for custom focus behavior
- **Remote button handling**: Use `pressesEnded(_:with:)` to capture Play/Pause button for refresh actions

### Video ID Handling
- **BV/AV conversion**: Use `BvidConvertor.bv2av()` / `av2bv()` (BilibiliLive/Request/BvidConvertor.swift)
- **PlayInfo struct**: Central model carrying `aid`, `cid`, `epid` (for bangumi), `isBangumi` flag
- **CID resolution**: If missing, call `WebRequest.requestCid(aid:)` before playback

### Color & Theming
- Use named colors from Assets.xcassets (e.g., `"mainBgColor"`, `"tint"`)
- Bilibili brand colors available: `UIColor.biliblue`, `UIColor.bilipink`
- Dark mode is implicit via named color variants

### Async/Await & Combine Hybrid
- **Networking**: Modern code uses `async/await` (e.g., `WebRequest.requestData`)
- **Reactive state**: Use Combine publishers for UI bindings (danmu stream, player state)
- **Pattern**: ViewModels expose `PassthroughSubject` for event streams (e.g., `onPluginReady`, `onSendTextModel`)

## Build & Development Workflow

### Build Commands
```bash
# Install dependencies (Fastlane)
bundle install

# Build for simulator (testing)
bundle exec fastlane build_simulator

# Build unsigned IPA for sideloading
bundle exec fastlane build_unsign_ipa  # Output: BilbiliAtvDemo.ipa
```

### Xcode Configuration
- **Target**: BilibiliLive (tvOS 15.0+)
- **SPM dependencies**: Alamofire, SwiftyJSON, Kingfisher, SnapKit, DanmakuKit (custom), SwiftProtobuf, CocoaLumberjack
- **Swift format**: Auto-runs via Build Phase → `Swift formate` script using BuildTools/Package.swift
- **Signing**: For development, use automatic signing. For distribution, generate unsigned IPA via Fastlane

### Logging
Use CocoaLumberjack via custom `Logger.swift`:
```swift
Logger.debug("message")  // Development logs
Logger.info("message")   // Important events
Logger.error("message")  // Errors
```

### Debugging tvOS
- **Simulator**: Fastest for layout/logic testing. Use `bundle exec fastlane build_simulator`
- **Physical device**: Required for playback codec testing (HDR, Dolby Vision)
- **Focus debugging**: Enable "Show focus" in Simulator → Debug menu

## Project-Specific Conventions

### File Organization
- **Component/**: UI components organized by feature (Feed, Player, Video, Menu)
- **Module/**: High-level feature modules (Live, Personal, DLNA)
- **Request/**: All API/network code + protobuf definitions
- **Extensions/**: Swift extensions (follow `TargetType+..swift` naming)
- **Vendor/**: Third-party code not available via SPM (e.g., custom DanmakuKit fork)

### Naming Patterns
- **View controllers**: Descriptive + `ViewController` suffix (e.g., `VideoDetailViewController`)
- **ViewModels**: Match VC name + `ViewModel` (e.g., `VideoPlayerViewModel`)
- **Plugins**: Feature + `Plugin` suffix (e.g., `SponsorSkipPlugin`)
- **Settings keys**: Dot-notation namespace: `"Settings.category.name"` (e.g., `"Settings.danmuMask"`)

### Code Style
- **SwiftFormat**: Runs on build. Follow existing style for consistency
- **Avoid force unwrapping**: Use optional chaining or guard statements
- **Async context**: Prefer `Task {}` over `DispatchQueue.main.async` for modern code
- **Error handling**: Use custom `RequestError` enum for network errors

## Common Tasks

### Adding a new player plugin
1. Create class conforming to `CommonPlayerPlugin` in appropriate Plugins/ directory
2. Implement required lifecycle methods (default implementations available)
3. Add to `VideoPlayerViewModel.generatePlayerPlugin()` or similar factory
4. Call `addPlugin(plugin:)` on `CommonPlayerViewController`

### Adding a new API endpoint
1. Add endpoint URL to `WebRequest.EndPoint` or `ApiRequest.EndPoint`
2. Create request method using `WebRequest.requestData()` or `ApiRequest.requestJSON()`
3. Add WBI signature if required via `WebRequest.req(url:parameters:)` extension
4. Handle authentication via `auth: true` parameter

### Adding a new setting
1. Add property to `Settings` enum with `@UserDefault` or `@UserDefaultCodable`
2. Use namespaced key: `"Settings.category.settingName"`
3. Create enum for complex settings with `Codable` conformance
4. Access anywhere via `Settings.settingName`

### Handling video playback
1. Create `PlayInfo` with `aid` and optionally `cid`
2. Initialize `VideoPlayerViewController(playInfo:)`
3. Present modally (standard tvOS pattern)
4. ViewModel handles CID resolution, plugin initialization, and playback setup

## External Dependencies & Integration

### Key SPM Packages
- **Alamofire**: HTTP networking (session management, encoding)
- **SwiftyJSON**: JSON parsing (legacy pattern, consider Codable for new code)
- **Kingfisher**: Image loading/caching
- **SnapKit**: Auto Layout DSL
- **SwiftProtobuf**: Danmu protobuf parsing
- **CocoaAsyncSocket**: TCP/UDP for DLNA
- **Swifter**: Embedded HTTP server for DLNA

### Bilibili API Quirks
- **WBI signing**: Required for most web APIs. Auto-handled by `WebRequest.req()`
- **CSRF tokens**: Must include `biliCSRF` and `csrf` params for POST requests
- **Cookies**: Managed by `CookieHandler.shared`. Persisted across launches
- **User-Agent spoofing**: Required to avoid detection. Use `Keys.userAgent`
- **Area limits**: Some content region-locked. Support via `Settings.areaLimitUnlock` + proxy

### Protobuf Definitions
Generated from Bilibili's proto files:
- `dm.pb.swift`: Danmu content and metadata
- `dmView.pb.swift`: Danmu view configuration (mask data, special danmu)

Regenerate if Bilibili updates schema (unlikely, stable for years).

## Testing & Quality

### Manual Testing Checklist
- Login/logout flow (QR code)
- Video playback (1080p, 4K, HDR/Dolby Vision)
- Danmu rendering (top, scroll, bottom types)
- Live streaming + live danmu
- Cloud-projection (send from mobile app)
- Settings persistence (change settings, restart app)
- Focus navigation (ensure all UI elements focusable)

### Known Limitations
- No AppStore distribution (personal sideload only)
- Requires Bilibili account for full functionality
- Some premium content may require VIP membership
- DLNA protocol reverse-engineered, may break with Bilibili updates

## Resources

- **Original Project**: https://github.com/yichengchen/ATV-Bilibili-demo
- **Telegram Group**: https://t.me/appletvbilibilidemo
- **Bilibili API Collection**: https://github.com/SocialSisterYi/bilibili-API-collect
- **Cloud-Projection Protocol**: https://xfangfang.github.io/028
