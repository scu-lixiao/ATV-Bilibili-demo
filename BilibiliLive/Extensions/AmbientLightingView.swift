//
//  AmbientLightingView.swift
//  BilibiliLive
//
//  Content-aware ambient lighting that adapts to video covers
//

import UIKit

// MARK: - Color Extraction

extension UIImage {
    /// 提取主色调：降采样到 50×50，取中等亮度像素的平均值并适度提高饱和度。
    /// 可在后台线程调用。
    ///
    /// 使用显式 RGBA 字节序的 CGContext。原先用 `UIGraphicsBeginImageContext` 创建的上下文在内存中是 BGRA，
    /// 却按 RGBA 读取，红蓝通道互换，取到的颜色色相是错的。
    func extractDominantColor() -> UIColor? {
        guard let cgImage else { return nil }

        let width = 50
        let height = 50
        let bytesPerPixel = 4
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * bytesPerPixel,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ) else { return false }
            context.interpolationQuality = .low
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        var redSum: CGFloat = 0
        var greenSum: CGFloat = 0
        var blueSum: CGFloat = 0
        var pixelCount: CGFloat = 0

        // Sample pixels and calculate average
        for y in stride(from: 0, to: height, by: 2) {
            for x in stride(from: 0, to: width, by: 2) {
                let offset = (y * width + x) * bytesPerPixel

                let red = CGFloat(pixels[offset]) / 255.0
                let green = CGFloat(pixels[offset + 1]) / 255.0
                let blue = CGFloat(pixels[offset + 2]) / 255.0

                // Ignore very dark and very bright pixels
                let brightness = (red + green + blue) / 3.0
                guard brightness > 0.15 && brightness < 0.85 else { continue }

                redSum += red
                greenSum += green
                blueSum += blue
                pixelCount += 1
            }
        }

        guard pixelCount > 0 else { return nil }

        let avgRed = redSum / pixelCount
        let avgGreen = greenSum / pixelCount
        let avgBlue = blueSum / pixelCount

        // Boost saturation for more vibrant glow
        let maxChannel = max(avgRed, max(avgGreen, avgBlue))
        let boostedRed = avgRed + (maxChannel - avgRed) * 0.3
        let boostedGreen = avgGreen + (maxChannel - avgGreen) * 0.3
        let boostedBlue = avgBlue + (maxChannel - avgBlue) * 0.3

        return UIColor(
            red: min(boostedRed, 1.0),
            green: min(boostedGreen, 1.0),
            blue: min(boostedBlue, 1.0),
            alpha: 1.0
        )
    }

    /// 以主色调为基础生成一组配色（主色、浅色、深色）。可在后台线程调用。
    func extractColorPalette(count: Int = 3) -> [UIColor] {
        guard let dominant = extractDominantColor() else { return [] }

        var colors: [UIColor] = [dominant]

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        dominant.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // Add lighter variant
        colors.append(UIColor(
            hue: hue,
            saturation: saturation * 0.7,
            brightness: min(brightness * 1.3, 1.0),
            alpha: alpha
        ))

        // Add darker variant
        colors.append(UIColor(
            hue: hue,
            saturation: min(saturation * 1.2, 1.0),
            brightness: brightness * 0.7,
            alpha: alpha
        ))

        return Array(colors.prefix(count))
    }
}

// MARK: - Ambient Lighting System

class AmbientLightingView: UIView {
    private let gradientLayer = CAGradientLayer()
    private var currentColors: [UIColor] = []
    /// 取色是异步的，用于丢弃过期结果（例如在详情页内快速切换相关视频）
    private var lightingRequestID = 0

    var lightingIntensity: CGFloat = 0.3 {
        didSet {
            updateGradient()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradient()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradient()
    }

    private func setupGradient() {
        isUserInteractionEnabled = false
        gradientLayer.type = .radial
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        layer.insertSublayer(gradientLayer, at: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    /// Update ambient lighting based on image. 取色在后台线程完成，不阻塞封面加载完成时的主线程
    func updateLighting(from image: UIImage?, animated: Bool = true) {
        lightingRequestID += 1
        let requestID = lightingRequestID

        guard let image = image else {
            clearLighting(animated: animated)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let colors = image.extractColorPalette(count: 3)
            DispatchQueue.main.async {
                guard let self, self.lightingRequestID == requestID, !colors.isEmpty else { return }
                self.updateLighting(with: colors, animated: animated)
            }
        }
    }

    /// Update ambient lighting with specific colors
    func updateLighting(with colors: [UIColor], animated: Bool = true) {
        currentColors = colors

        let gradientColors = (colors.map { $0.withAlphaComponent(lightingIntensity) } + [UIColor.clear]).map(\.cgColor)

        if animated {
            let animation = CABasicAnimation(keyPath: "colors")
            animation.fromValue = gradientLayer.presentation()?.colors ?? gradientLayer.colors
            animation.toValue = gradientColors
            animation.duration = 0.35
            animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0)
            gradientLayer.add(animation, forKey: "colorChange")
        }
        // 关闭隐式动画，否则它会覆盖上面的显式动画
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.colors = gradientColors
        CATransaction.commit()
    }

    /// Clear ambient lighting
    func clearLighting(animated: Bool = true) {
        updateLighting(with: [.clear], animated: animated)
    }

    private func updateGradient() {
        guard !currentColors.isEmpty else { return }
        updateLighting(with: currentColors, animated: true)
    }
}
