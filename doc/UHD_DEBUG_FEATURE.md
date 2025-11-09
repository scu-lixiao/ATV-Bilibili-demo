# UHD/HDR Debug Feature Implementation

## Overview
This document describes the implementation of UHD/HDR video information display in the debug overlay, similar to Apple TV's Developer HUD feature.

## Changes Made

### File Modified
- `BilibiliLive/Component/Player/Plugins/DebugPlugin.swift`

### New Features Added

#### 1. Video Format Information Display
The debug overlay now displays comprehensive video format information including:

- **Resolution**: Actual pixel dimensions and category (4K UHD, 1080p FHD, 720p HD, etc.)
- **Frame Rate**: Nominal frame rate in fps
- **Codec**: Video codec type (H.264, H.265/HEVC, Dolby Vision, VP9, AV1, etc.)
- **Dynamic Range**: HDR type detection (SDR, HDR10, HDR10+, Dolby Vision, HLG)
- **Color Space**: Color primaries, transfer function, and YCbCr matrix
- **Track Bitrate**: Estimated data rate of the video track (tvOS 14.0+)

#### 2. New Methods

##### `extractVideoFormatInfo(from: AVPlayer) -> String?`
Main method that extracts video format information from the current player item.

**Flow:**
1. Gets the video track from AVAsset
2. Extracts resolution and determines category (SD/HD/FHD/QHD/UHD)
3. Gets frame rate from video track
4. Parses CMFormatDescription for codec and HDR info
5. Returns formatted string with emoji icons

##### `formatCodecType(_ codecType: CMVideoCodecType) -> String`
Converts codec type code to human-readable format.

**Supported Codecs:**
- H.264 (AVC)
- H.265 (HEVC)
- HEVC with Alpha
- Dolby Vision HEVC
- VP9
- AV1
- Generic FourCC format for unknown codecs

##### `extractHDRInfo(from: CMFormatDescription) -> String?`
Extracts HDR/dynamic range information.

**Detection Logic:**
1. Checks color primaries for BT.2020 (HDR indicator)
2. Checks transfer function:
   - SMPTE ST 2084 (PQ) → HDR10/HDR10+
   - ITU-R 2100 HLG → HLG (Hybrid Log-Gamma)
   - Linear → Linear HDR
3. Checks codec type for Dolby Vision HEVC
4. Checks for content light level metadata (HDR10+ indicator)

##### `extractColorSpaceInfo(from: CMFormatDescription) -> String?`
Extracts color space components.

**Information Extracted:**
- **Color Primaries**: BT.2020, BT.709, SMPTE-C, P3-D65
- **Transfer Function**: PQ, HLG, sRGB, BT.709
- **YCbCr Matrix**: 2020, 709, 601

### Display Format Example

```
time control status: 0 
player status:1
📺 Video: 3840x2160 (4K UHD)
🎬 Frame Rate: 23.98fps
🎞️  Codec: H.265 (HEVC)
🎆 Dynamic Range: Dolby Vision
🎨 Color Space: BT.2020 / PQ / YCbCr:2020
💾 Track Bitrate: 15.24Mbps

uri:https://..., ip:xxx.xxx.xxx.xxx, change:0
drop:0 stalls:0
bitrate audio:0.13Mbps, video: 12.45Mbps
observedBitrate:12.58Mbps
indicatedAverageBitrate:12.50Mbps
```

## Technical Details

### API Usage

#### AVFoundation APIs
- `AVAsset.tracks(withMediaType:)` - Get video tracks
- `AVAssetTrack.naturalSize` - Get video dimensions
- `AVAssetTrack.nominalFrameRate` - Get frame rate
- `AVAssetTrack.formatDescriptions` - Get format descriptions
- `AVAssetTrack.estimatedDataRate` - Get track bitrate (tvOS 14.0+)

#### CoreMedia APIs
- `CMFormatDescriptionGetMediaSubType()` - Get codec type
- `CMFormatDescriptionGetExtensions()` - Get format extensions

#### CoreVideo Keys
- `kCVImageBufferColorPrimariesKey` - Color primaries
- `kCVImageBufferTransferFunctionKey` - Transfer function (HDR type)
- `kCVImageBufferYCbCrMatrixKey` - YCbCr matrix
- `kCVImageBufferContentLightLevelInfoKey` - HDR metadata

### HDR Type Detection

| Transfer Function | Color Primaries | Result |
|------------------|-----------------|---------|
| SMPTE ST 2084 (PQ) | BT.2020 | HDR10/HDR10+ |
| ITU-R 2100 (HLG) | BT.2020 | HLG |
| Linear | BT.2020 | Linear HDR |
| Any | Non-BT.2020 | SDR |

**Special Cases:**
- Dolby Vision detected via codec type: `kCMVideoCodecType_DolbyVisionHEVC`
- HDR10 vs HDR10+ differentiated by presence of content light level metadata

### Resolution Categories

| Height (pixels) | Label | Description |
|----------------|-------|-------------|
| ≥ 2160 | 4K UHD | Ultra High Definition |
| ≥ 1440 | 2K QHD | Quad High Definition |
| ≥ 1080 | 1080p FHD | Full High Definition |
| ≥ 720 | 720p HD | High Definition |
| < 720 | SD | Standard Definition |

## Usage

### Accessing the Debug View

1. Start video playback
2. Press the Menu button on Apple TV remote
3. Navigate to "Settings" menu
4. Select "Debug" option (shows terminal icon)
5. Debug overlay will appear in top-right corner
6. Updated every 1 second with current info

### Interpreting the Display

#### Emoji Icons
- 📺 - Video resolution information
- 🎬 - Frame rate
- 🎞️ - Codec information
- ☀️ - SDR content
- ✨ - HDR10/HDR10+ content
- 🌟 - HLG content
- 🎆 - Dolby Vision content
- 🎨 - Color space information
- 💾 - Bitrate information

## Testing Recommendations

### Test Cases
1. **SDR 1080p Content** - Should show "1080p FHD", "SDR", "BT.709"
2. **4K HDR10 Content** - Should show "4K UHD", "HDR10", "BT.2020 / PQ"
3. **Dolby Vision Content** - Should show "Dolby Vision", "Dolby Vision HEVC"
4. **HLG Content** - Should show "HLG", "BT.2020 / HLG"

### Expected Bilibili Content Types
- Standard videos: H.264 or HEVC, 1080p, SDR
- 4K videos (VIP): HEVC, 2160p, SDR or HDR10
- Dolby Vision (VIP): Dolby Vision HEVC, 2160p, BT.2020/PQ

## Compatibility

- **Minimum tvOS Version**: 15.0 (project target)
- **Optimal tvOS Version**: 14.0+ (for estimated bitrate feature)
- **Device Support**: Apple TV 4K (2nd gen and later) for full HDR/UHD support

## Limitations

1. **Asset Type**: Only works with `AVURLAsset` (standard case for streaming)
2. **Format Description Availability**: Some streams may not provide complete format descriptions
3. **Dynamic Changes**: If video quality changes during playback (adaptive streaming), display updates on next refresh cycle (1 second)

## Future Enhancements

Potential improvements:
1. Add AVDisplayManager integration to show TV's current display mode
2. Add bit depth information (8-bit, 10-bit, 12-bit)
3. Add audio format information (Dolby Atmos, AAC, etc.)
4. Add network quality indicators
5. Add buffer status visualization

## References

- [Apple Developer - AVDisplayManager](https://developer.apple.com/documentation/avkit/avdisplaycmanager)
- [Apple Developer - AVDisplayCriteria](https://developer.apple.com/documentation/avfoundation/avdisplaycriteria)
- [WWDC21 - Deliver a great playback experience on tvOS](https://developer.apple.com/videos/play/wwdc2021/10191/)
- [Apple - HLS Authoring Specification](https://developer.apple.com/documentation/http_live_streaming/hls_authoring_specification_for_apple_devices)
- [Bilibili Video Resource Loader Implementation](../BilibiliLive/Component/Player/BilibiliVideoResourceLoaderDelegate.swift)

## Changelog

### 2025-11-08
- Initial implementation of UHD/HDR information display
- Added comprehensive codec detection
- Added HDR type detection (SDR/HDR10/HDR10+/Dolby Vision/HLG)
- Added color space information extraction
- Added emoji icons for better readability
