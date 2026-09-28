//
//  ParticleEffects.swift
//  BilibiliLive
//
//  Particle feedback for like / coin / favorite actions
//

import UIKit

// MARK: - Particle Configuration

/// Particle effect types for different interactions
enum ParticleEffectType {
    case like // Pink hearts for likes
    case favorite // Golden stars for favorites
    case coin // Shimmering coins for coin throwing

    var emitterConfig: ParticleEmitterConfig {
        switch self {
        case .like:
            return ParticleEmitterConfig(
                particleImage: Self.heartImage(),
                colors: [
                    UIColor(red: 1.0, green: 0.4, blue: 0.7, alpha: 1.0), // luminousPink
                    .systemPink,
                    UIColor(red: 1.0, green: 0.7, blue: 0.5, alpha: 1.0), // warmGlow
                ],
                birthRate: 15,
                lifetime: 2.0,
                velocity: 150,
                velocityRange: 50,
                emissionRange: .pi * 2,
                scale: 0.6,
                scaleRange: 0.3,
                spin: 3,
                alphaSpeed: -0.8
            )
        case .favorite:
            return ParticleEmitterConfig(
                particleImage: Self.starImage(),
                colors: [.systemYellow, .systemOrange, UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)],
                birthRate: 20,
                lifetime: 1.8,
                velocity: 120,
                velocityRange: 40,
                emissionRange: .pi / 3,
                scale: 0.5,
                scaleRange: 0.25,
                spin: 4,
                alphaSpeed: -0.9
            )
        case .coin:
            return ParticleEmitterConfig(
                particleImage: Self.circleImage(),
                colors: [UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0), UIColor(red: 1.0, green: 0.71, blue: 0.0, alpha: 1.0)],
                birthRate: 25,
                lifetime: 2.5,
                velocity: 180,
                velocityRange: 60,
                emissionRange: .pi / 4,
                scale: 0.4,
                scaleRange: 0.2,
                spin: 6,
                alphaSpeed: -0.7
            )
        }
    }

    // MARK: - Particle Shape Generators

    private static func heartImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { _ in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 10, y: 18))
            path.addCurve(to: CGPoint(x: 2, y: 8),
                          controlPoint1: CGPoint(x: 6, y: 14),
                          controlPoint2: CGPoint(x: 2, y: 11))
            path.addCurve(to: CGPoint(x: 10, y: 4),
                          controlPoint1: CGPoint(x: 2, y: 5),
                          controlPoint2: CGPoint(x: 6, y: 4))
            path.addCurve(to: CGPoint(x: 18, y: 8),
                          controlPoint1: CGPoint(x: 14, y: 4),
                          controlPoint2: CGPoint(x: 18, y: 5))
            path.addCurve(to: CGPoint(x: 10, y: 18),
                          controlPoint1: CGPoint(x: 18, y: 11),
                          controlPoint2: CGPoint(x: 14, y: 14))
            path.close()
            UIColor.white.setFill()
            path.fill()
        }
    }

    private static func starImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { _ in
            let path = UIBezierPath()
            let center = CGPoint(x: 10, y: 10)
            let outerRadius: CGFloat = 9
            let innerRadius: CGFloat = 4

            for i in 0..<10 {
                let angle = CGFloat(i) * .pi / 5 - .pi / 2
                let radius = i % 2 == 0 ? outerRadius : innerRadius
                let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                if i == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.close()
            UIColor.white.setFill()
            path.fill()
        }
    }

    private static func circleImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).image { _ in
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: 2, y: 2, width: 12, height: 12)).fill()
        }
    }
}

// MARK: - Particle Emitter Configuration

struct ParticleEmitterConfig {
    let particleImage: UIImage
    let colors: [UIColor]
    let birthRate: Float
    let lifetime: Float
    let velocity: CGFloat
    let velocityRange: CGFloat
    let emissionRange: CGFloat
    let scale: CGFloat
    let scaleRange: CGFloat
    let spin: CGFloat
    let alphaSpeed: Float
}

// MARK: - ParticlePool

/// 复用 CAEmitterLayer，避免每次点赞 / 投币都新建发射层
@MainActor
private final class ParticlePool {
    static let shared = ParticlePool()

    private var availableLayers: [CAEmitterLayer] = []
    private var activeLayers: Set<ObjectIdentifier> = []
    private let maxPoolSize = 10

    private init() {}

    func acquire() -> CAEmitterLayer {
        let layer = availableLayers.popLast() ?? {
            let layer = CAEmitterLayer()
            layer.renderMode = .additive
            return layer
        }()
        activeLayers.insert(ObjectIdentifier(layer))
        return layer
    }

    func release(_ layer: CAEmitterLayer) {
        guard activeLayers.remove(ObjectIdentifier(layer)) != nil else { return }

        layer.removeFromSuperlayer()
        layer.emitterCells = nil
        layer.birthRate = 0

        if availableLayers.count < maxPoolSize {
            availableLayers.append(layer)
        }
    }
}

// MARK: - UIView + Particle Effects

extension UIView {
    /// Emit particles from a specific point in the view
    /// - Parameters:
    ///   - type: The particle effect type
    ///   - point: Emission point in view's coordinate system
    ///   - duration: Duration of emission
    func emitParticles(type: ParticleEffectType, at point: CGPoint, duration: TimeInterval = 0.8) {
        let config = type.emitterConfig

        let emitterLayer = ParticlePool.shared.acquire()
        emitterLayer.emitterPosition = point
        emitterLayer.emitterShape = .point
        emitterLayer.emitterSize = CGSize(width: 1, height: 1)

        let cells = config.colors.map { color -> CAEmitterCell in
            let cell = CAEmitterCell()
            cell.contents = config.particleImage.cgImage
            cell.birthRate = config.birthRate / Float(config.colors.count)
            cell.lifetime = config.lifetime
            cell.velocity = config.velocity
            cell.velocityRange = config.velocityRange
            cell.emissionRange = config.emissionRange
            cell.spin = config.spin
            cell.spinRange = config.spin / 2
            cell.scale = config.scale
            cell.scaleRange = config.scaleRange
            cell.scaleSpeed = -0.1
            cell.alphaSpeed = config.alphaSpeed
            cell.color = color.cgColor
            cell.beginTime = CACurrentMediaTime()
            return cell
        }

        emitterLayer.emitterCells = cells
        emitterLayer.birthRate = 1.0
        layer.addSublayer(emitterLayer)

        // Stop emission, then release to pool after particles die
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak emitterLayer] in
            guard let emitterLayer else { return }
            emitterLayer.birthRate = 0

            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(config.lifetime)) { [weak emitterLayer] in
                guard let emitterLayer else { return }
                ParticlePool.shared.release(emitterLayer)
            }
        }
    }
}
