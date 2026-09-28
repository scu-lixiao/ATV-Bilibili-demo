//
//  ColorSystem.swift
//  BilibiliLive
//
//  Premium Dark Theme Color System for tvOS 26
//  Created by AI Assistant on 2025/11/8
//

import UIKit

/// Premium color system optimized for deep dark theme with Liquid Glass
@MainActor
extension UIColor {
    // MARK: - Deep Dark Background System

    /// Pure black base - RGB(0.0, 0.0, 0.0) for maximum depth
    static var premiumBlack: UIColor {
        UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
    }

    /// Near-black with subtle blue tint - RGB(0.08, 0.08, 0.09)
    static var deepDarkBG: UIColor {
        UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1.0)
    }

    // MARK: - Luminous Accent System

    /// Bilibili brand pink with enhanced vibrancy for dark theme
    static var luminousPink: UIColor {
        UIColor(displayP3Red: 1.0, green: 0.42, blue: 0.62, alpha: 1.0)
    }

    /// Bilibili brand blue with glow enhancement
    static var luminousBlue: UIColor {
        UIColor(displayP3Red: 0.0, green: 0.72, blue: 0.95, alpha: 1.0)
    }

    // MARK: - Glass Tint Colors

    /// Neutral glass tint
    static var glassNeutralTint: UIColor {
        UIColor.white.withAlphaComponent(0.08)
    }

    // MARK: - Dark Theme Enhanced Glass Tints

    /// Enhanced pink glass for dark backgrounds (increased visibility)
    static var glassPinkTintDark: UIColor {
        luminousPink.withAlphaComponent(0.25)
    }

    /// Enhanced blue glass for dark backgrounds
    static var glassBlueTintDark: UIColor {
        luminousBlue.withAlphaComponent(0.22)
    }

    /// Enhanced neutral glass with slight warm tint
    static var glassNeutralTintDark: UIColor {
        UIColor(white: 0.15, alpha: 0.18)
    }

    /// Subtle glass stroke for definition in dark theme
    static var glassStrokeBorder: UIColor {
        UIColor.white.withAlphaComponent(0.12)
    }

    /// Inner glow for focused glass elements
    static var glassInnerGlow: UIColor {
        UIColor.white.withAlphaComponent(0.35)
    }

    // MARK: - Shadow Colors for Depth

    /// Colored shadow for pink accents
    static var pinkGlowShadow: UIColor {
        luminousPink.withAlphaComponent(0.3)
    }

    /// Neutral deep shadow
    static var deepShadow: UIColor {
        UIColor(white: 0.0, alpha: 0.6)
    }

    // MARK: - Gradient Helpers

    /// Creates a vertical gradient from dark to darker
    static func createDarkGradient() -> CAGradientLayer {
        let gradient = CAGradientLayer()
        gradient.colors = [
            premiumBlack.cgColor,
            deepDarkBG.cgColor
        ]
        gradient.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1.0)
        return gradient
    }
}

// MARK: - Design Token System

/// Corner radius tokens for consistent UI
enum CornerRadiusToken: CGFloat {
    case medium = 24.0     // Cards, medium buttons
    case large = 44.0      // Large cards, panels
}

/// Shadow elevation system
enum ShadowElevation {
    case level1  // 2pt offset, 4pt radius - subtle lift
    case level2  // 8pt offset, 16pt radius - medium elevation
    case level3  // 16pt offset, 32pt radius - high elevation
    case focused // 12pt offset, 24pt radius + colored shadow
    
    var offset: CGSize {
        switch self {
        case .level1: return CGSize(width: 0, height: 2)
        case .level2: return CGSize(width: 0, height: 8)
        case .level3: return CGSize(width: 0, height: 16)
        case .focused: return CGSize(width: 0, height: 12)
        }
    }
    
    var radius: CGFloat {
        switch self {
        case .level1: return 4
        case .level2: return 16
        case .level3: return 32
        case .focused: return 24
        }
    }
    
    var opacity: Float {
        switch self {
        case .level1: return 0.15
        case .level2: return 0.25
        case .level3: return 0.35
        case .focused: return 0.3
        }
    }
}

/// Animation duration tokens
enum AnimationDuration: TimeInterval {
    case fast = 0.3       // Quick transitions
    case standard = 0.5   // Default animations
    case smooth = 0.7     // Smooth transitions
}

/// Spring animation parameters
struct SpringParams {
    let duration: TimeInterval
    let damping: CGFloat
    let velocity: CGFloat
    
    static let subtle = SpringParams(duration: 0.4, damping: 0.85, velocity: 0.3)
    static let standard = SpringParams(duration: 0.5, damping: 0.75, velocity: 0.6)
}
