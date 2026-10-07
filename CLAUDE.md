# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

An unofficial, non-commercial tvOS-only Bilibili client. It is a fork of `yichengchen/ATV-Bilibili-demo` with an Apple TV+ style redesign. It is built with UIKit and AVKit (no SwiftUI) as one app target, `BilibiliLive`. The deployment target is **tvOS 26.0**, and the code calls tvOS 26 APIs such as `UIGlassEffect`. The project uses Swift 5 language mode. UI strings, code comments and commit messages are mostly in Chinese. Commits use a conventional prefix with a Chinese summary, for example `fix: 杜比视界 ...`.

A local, gitignored `.github/copilot-instructions.md` may exist with a longer overview, but some of it is out of date. It claims tvOS 15, format-on-build, and a `WebRequest.req` signing helper. Where it disagrees with this file, trust the code.

## Build

There is **no test target**. To verify a change, build it, then check it by hand in the simulator or on a device. Real HDR and Dolby Vision output needs a physical Apple TV.

```bash
# Debug build for the simulator (fastest compile check)
xcodebuild -project BilibiliLive.xcodeproj -scheme BilibiliLive -configuration Debug \
  -destination 'generic/platform=tvOS Simulator' build -quiet

# Fastlane lanes (run `bundle install` first)
bundle exec fastlane build_simulator     # destination "Apple TV" simulator
bundle exec fastlane build_unsign_ipa    # Release, unsigned → ./BilbiliAtvDemo.ipa
```

- If `xcodebuild` says the active developer directory is CommandLineTools, prefix the command with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- With `-quiet`, xcodebuild prints spurious `error: the following command failed with exit code 0` lines. Go by the exit status instead.
- The project uses an Xcode file-system synchronized root group. New files under `BilibiliLive/` are picked up automatically, so don't edit `project.pbxproj` to add sources.
- CI (`.github/workflows/build.yml`) runs `fastlane build_unsign_ipa` on pushes and PRs to `main`. It uses the `macos-26` runner with the newest Xcode 26.x, and it must stay on Xcode 26 or later for the tvOS 26 SDK. Each run uploads the unsigned `BilbiliAtvDemo.ipa` as a workflow artifact. The workflow's `nightly` release step is skipped because this repo is a fork. Everything else in `.github/` is gitignored.
- **Formatting:** the "Swift formate" build phase is commented out, so nothing formats on build, and much of the existing code is unformatted. To format by hand, run from `BuildTools/`: `swift run -c release swiftformat --disable unusedArguments,numberFormatting,redundantReturn,andOperator,anyObjectProtocol,trailingClosures,redundantFileprivate --ranges nospace --swiftversion 5 <paths>`. Pass only the files you touched, or you will reformat the whole repo.

## Architecture

### Startup and navigation
The app uses the UIScene life cycle, which the tvOS 27 SDK requires (without it the app crashes at launch).

- **`AppDelegate`** sets up `Logger`, caps the Kingfisher disk cache, restores cookies (`CookieHandler`) and starts the cast receiver (`BiliBiliUpnpDMR.shared.start()`). Its `window` forwards to the scene's window, and `showLogin`/`showTabBar` forward to `SceneDelegate`.
- **`SceneDelegate`** creates the window, refreshes the TV login token if it expires within 30 hours, and sets the root view controller to `MenusViewController` (from the storyboard) or to `LoginViewController`.

`MenusViewController` is the Apple TV+ style side menu. Its `cellModels` list defines the top-level pages, and `setViewController` swaps the content. Remote buttons are handled centrally in its `pressesEnded`:
- **Menu, with the side menu hidden:** forwarded to the current page.
- **Menu, with the side menu shown:** passed to the system, which exits the app.
- **Play/Pause:** calls `reloadData()` on the topmost view controller that conforms to `BLTabBarContentVCProtocol`.

Handle the Menu button with `pressesBegan`/`pressesEnded`, not with a `UITapGestureRecognizer`. Gesture recognizers were unreliable here and have been removed.

Most list pages subclass `StandardVideoCollectionViewController<T: PlayableData>` and override `request(page:) async throws -> [T]`. The grid is `FeedCollectionViewController`, which works on any `DisplayData`.

### Networking (`BilibiliLive/Request/`)
There are two separate stacks:

- **`WebRequest`** calls web APIs and authenticates with cookies. `request<T>` calls `requestJSON`, which calls `requestData`. Most calls also have an `async` wrapper.
  - `requestData` adds `csrf`/`biliCSRF` to non-GET requests and sets a default `User-Agent`/`Referer` from `Keys`.
  - `requestData` **WBI-signs every GET automatically** (`WebRequest+WbiSign.swift`, via `addWbiSign`). Never pre-sign a URL. Double signing produced broken URLs and the `-352` errors seen on live endpoints.
  - A non-zero `code` in the response envelope becomes `RequestError.statusFail(code:message:)`. The payload is read from the `data` key; override that with `dataObj:`.
  - Codable response models are defined next to their request functions.
- **`ApiRequest`** calls TV-app APIs. It signs with appkey/appsec via `sign(for:)` and uses an `access_key` token. It covers QR login, token refresh and the recommendation feed.

`dm.pb.swift` and `dmView.pb.swift` are generated SwiftProtobuf code for danmaku (bullet comments). Don't edit them by hand.

`String` conforms to `Error` (see `String+Error.swift`), so `throw "message"` is an accepted idiom.

### Player: plugin architecture
`CommonPlayerViewController` wraps `AVPlayerViewController`. It forwards lifecycle events (load, player/item change, start, pause, end, fail, dismiss) to every attached `CommonPlayerPlugin`, and each plugin can add overlay views and menu items. Every protocol method has a default no-op, so plugins implement only the hooks they need. Player features should be written as plugins added with `addPlugin`/`removePlugin`, not written into the view controller.

Plugin cleanup rules:
- Removing a plugin calls `playerWillCleanUp(playerVC:)` and then `playerDidCleanUp(player:)`. Use the first to cancel pending loads and remove the plugin's own overlay views; use the second to remove time observers.
- A time observer can only be removed from the `AVPlayer` it was added to. Clear stored observers after removing them, or the next player change throws.
- Dismissing the player (unless Picture in Picture is running) pauses and releases the `AVPlayer` and removes every plugin.

- **On-demand video:** `VideoPlayerViewController(playInfo:)` owns a `VideoPlayerViewModel`, which is defined in `NewVideoPlayerViewModel.swift`.
  - The view model resolves the `cid` if it is missing, then fetches playurl, player info and detail concurrently. Bangumi (anime and other licensed shows) goes through the PGC endpoints, with an optional HK/TW area-unlock retry.
  - `generatePlayerPlugin` then builds the plugin set. It always includes play, danmaku, speed, UPnP, debug and playlist. It adds clips, SponsorBlock and the danmaku mask based on settings and data.
  - "Play next" reloads the data and rebuilds the whole plugin set; `VideoPlayerViewController` calls `removeAllPlugins()` before adding the new set. Clips, SponsorBlock, the mask and the info plugin all depend on the video.
- **Live streams:** `LivePlayerViewModel` uses `URLPlayPlugin` and `LiveDanMuProvider`. The provider reads live danmaku from a WebSocket feed with a custom binary header and brotli compression.

### DASH to HLS (how video plays)
Bilibili serves DASH, but AVPlayer only plays HLS. `BVideoPlayPlugin` bridges the two. It creates an `AVURLAsset` for `atv://list/play` and sets `BilibiliVideoResourceLoaderDelegate` as its resource loader. The delegate builds the HLS playlists on the fly:

- **Master playlist:** one `EXT-X-STREAM-INF` per video stream per CDN URL, the audio renditions (including Dolby and FLAC when lossless audio is on), the subtitles and an I-frame stream.
- **Media playlists** (`atv://dash/<n>`): byte-range segments built from each stream's `sidx` box. `SidxDownloader` in `BilibiliVideoResourceLoaderDelegate.swift` fetches the box, and `SidxParseUtil` parses it. The playlist uses whichever CDN URL successfully served the sidx, so an unreachable PCDN node falls back to a backup URL.
- **Subtitles** (`atv://subtitle/`): converted to WebVTT and served from a local Swifter HTTP server through a 302 redirect.

### HDR and Dolby Vision
The `codecs` field in Bilibili's API is too coarse. It cannot tell PQ from HLG, and it omits the Dolby Vision base-layer compatibility ID.

`VideoFormatParser.swift` solves this by parsing the stream's DASH init segment: `hvcC`, the SPS colour info, and `dvcC`/`dvvC`. `HLSVideoFormat.resolve` turns the result into exact `CODECS`, `SUPPLEMENTAL-CODECS` and `VIDEO-RANGE` values.

- Only HDR/DV candidates are probed (`needsProbe`), with a deadline. If probing fails, the format is inferred from the quality number (`qn`) and the codecs.
- The probe downloads are cached, and the media playlists reuse them.
- Do **not** filter streams by `eligibleForHDRPlayback`. When the Apple TV is set to SDR with Match Dynamic Range on, that flag is false before playback starts, so filtering would stop the TV from ever switching to HDR. AVPlayer picks the right stream by `VIDEO-RANGE` on its own.
- `DebugPlugin` shows the resolved format on screen.

### Danmaku (bullet comments)
Providers conform to `DanmuProviderProtocol` and publish `DanmakuTextCellModel`s through Combine. `VideoDanmuProvider` loads protobuf segments lazily, 6 minutes at a time, and handles filtering and duplicate removal. `DanmuViewPlugin` renders them with a **vendored and modified DanmakuKit** in `BilibiliLive/Vendor/`, not the SPM package.

The anti-occlusion mask keeps danmaku from covering people on screen:
- `BMaskProvider` uses Bilibili's server-side mask data.
- `VMaskProvider` falls back to on-device Vision segmentation.

### Casting (`Module/DLNA/`)
`BiliBiliUpnpDMR` implements Bilibili's "云视听小电视" cast target (TV casting from the phone app). It combines SSDP discovery, DLNA description XMLs served over HTTP, and the proprietary NVA socket protocol. The player reports video switches to it (`sendVideoSwitch`), and `BUpnpPlugin` reports playback state.

### Settings
Settings are static properties on the `Settings` enum in `Component/Settings.swift`, declared with `@UserDefault` or `@UserDefaultCodable("Settings.xxx", defaultValue:)`. Settings that other code must observe live on `Defaults.shared` and use the `@Published(key:)` extension, which also saves to UserDefaults.

Existing keys are persisted on users' devices, so keep them unchanged, typos included (for example, `Settings.direatlyEnterVideo`).

### Other conventions
- Log with `Logger.debug`, `.info` or `.warn`. These wrap CocoaLumberjack and also write to a file. There is no `Logger.error`.
- Use SnapKit for layout and Kingfisher for images. Glass styling helpers are in `Extensions/UIView+LiquidGlass.swift` and `GlassNavigationHelper.swift`.
- `doc/` is gitignored and holds local write-ups of past fixes: Dolby Vision, the Menu button, the WBI signature and the UHD debug overlay. Read them if they exist, but don't expect them in a fresh clone.
