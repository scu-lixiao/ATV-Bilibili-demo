//
//  GlassNavigationHelper.swift
//  BilibiliLive
//
//  Unified Glass Navigation System for tvOS 26
//  Created by AI Assistant on 2025/11/11
//

import UIKit

// MARK: - Glass Navigation Style Protocol

/// Protocol for views that adopt glass navigation styling
@MainActor
protocol GlassNavigationStyle {
    /// Applies the glass navigation style with optional configuration
    func applyGlassNavigation(config: GlassLayerConfig)
    
    /// Animates glass intensity for focus changes
    func animateGlassFocus(isFocused: Bool)
}

// MARK: - Glass Layer Configuration

/// Configuration for multi-layer glass effects
struct GlassLayerConfig {
    let cornerRadius: CGFloat
    let baseTint: UIColor
    let focusedTint: UIColor
    let strokeEnabled: Bool
    let glowEnabled: Bool
    let shadowElevation: ShadowElevation
    
    /// Preset for menu navigation items
    @MainActor
    static var menuItem: GlassLayerConfig {
        GlassLayerConfig(
            cornerRadius: 30.0,
            baseTint: .glassNeutralTintDark,
            focusedTint: .glassPinkTintDark,
            strokeEnabled: true,
            glowEnabled: true,
            shadowElevation: .level2
        )
    }
    
    /// Preset for main navigation container
    @MainActor
    static var mainContainer: GlassLayerConfig {
        GlassLayerConfig(
            cornerRadius: CornerRadiusToken.large.rawValue,
            baseTint: .glassPinkTint,
            focusedTint: .glassPinkTintDark,
            strokeEnabled: false,
            glowEnabled: true,
            shadowElevation: .level3
        )
    }
    
    /// Preset for sub-navigation headers
    @MainActor
    static var subNavigation: GlassLayerConfig {
        GlassLayerConfig(
            cornerRadius: CornerRadiusToken.medium.rawValue,
            baseTint: .glassBlueTintDark,
            focusedTint: .glassBlueTintDark,
            strokeEnabled: true,
            glowEnabled: false,
            shadowElevation: .level1
        )
    }
}

// MARK: - Glass Navigation Helper

/// Helper class for applying advanced glass effects to navigation elements
@MainActor
class GlassNavigationHelper {
    
    /// Applies multi-layer glass effect with all enhancements
    /// - Parameters:
    ///   - view: Target view to apply glass effect
    ///   - config: Glass layer configuration
    ///   - isFocused: Whether the element is currently focused
    static func applyMultiLayerGlass(
        to view: UIView,
        config: GlassLayerConfig,
        isFocused: Bool = false
    ) {
        // 🚀 Performance: Only remove layers if necessary
        if isFocused {
            view.layer.sublayers?.removeAll(where: { $0.name == "glass-layer" })
            view.subviews.filter { $0.tag == 9999 }.forEach { $0.removeFromSuperview() }
        }
        
        if #available(tvOS 26.0, *) {
            // Layer 1: Base glass effect
            applyBaseGlass(to: view, config: config, isFocused: isFocused)
            
            // Layer 2: Glossy highlight overlay (top portion) - only when focused
            if isFocused && config.glowEnabled {
                applyGlossyHighlight(to: view, config: config)
            }
            
            // Layer 3: Stroke border
            if config.strokeEnabled {
                applyGlassStroke(to: view, config: config, isFocused: isFocused)
            }
            
            // Layer 4: Inner glow (focused state) - only when focused
            if config.glowEnabled && isFocused {
                applyInnerGlow(to: view, config: config)
            }
            
            // Shadow enhancement
            view.applyPremiumShadow(
                elevation: isFocused ? .focused : config.shadowElevation,
                glowColor: isFocused ? .pinkGlowShadow : nil
            )
        } else {
            // Fallback for older tvOS versions
            view.applyBlurEffect(style: .extraDark, cornerRadius: config.cornerRadius)
            if config.strokeEnabled {
                view.layer.borderWidth = 0.5
                view.layer.borderColor = UIColor.glassStrokeBorder.cgColor
            }
        }
    }
    
    // MARK: - Private Layer Methods
    
    private static func applyBaseGlass(to view: UIView, config: GlassLayerConfig, isFocused: Bool) {
        let tint = isFocused ? config.focusedTint : config.baseTint
        view.applyLiquidGlass(
            style: .clear,
            tintColor: tint,
            cornerRadius: config.cornerRadius,
            interactive: false
        )
    }
    
    private static func applyGlossyHighlight(to view: UIView, config: GlassLayerConfig) {
        let highlightView = UIView()
        highlightView.tag = 9999 // Mark for removal
        highlightView.isUserInteractionEnabled = false
        highlightView.layer.cornerRadius = config.cornerRadius
        highlightView.clipsToBounds = true
        
        // Create gradient from white to transparent
        let gradient = CAGradientLayer()
        gradient.name = "glass-layer"
        gradient.colors = [
            UIColor.white.withAlphaComponent(0.25).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradient.endPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.frame = view.bounds
        
        highlightView.layer.addSublayer(gradient)
        view.addSubview(highlightView)
        highlightView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            highlightView.topAnchor.constraint(equalTo: view.topAnchor),
            highlightView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            highlightView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            highlightView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5)
        ])
    }
    
    private static func applyGlassStroke(to view: UIView, config: GlassLayerConfig, isFocused: Bool) {
        let strokeWidth: CGFloat = isFocused ? 1.5 : 1.0
        let strokeColor = isFocused ? UIColor.glassInnerGlow : UIColor.glassStrokeBorder
        
        view.layer.borderWidth = strokeWidth
        view.layer.borderColor = strokeColor.cgColor
    }
    
    private static func applyInnerGlow(to view: UIView, config: GlassLayerConfig) {
        // Create a subtle inner shadow effect
        let innerGlowLayer = CALayer()
        innerGlowLayer.name = "glass-layer"
        innerGlowLayer.frame = view.bounds
        innerGlowLayer.cornerRadius = config.cornerRadius
        innerGlowLayer.borderWidth = 2.0
        innerGlowLayer.borderColor = UIColor.glassInnerGlow.cgColor
        innerGlowLayer.shadowColor = UIColor.white.cgColor
        innerGlowLayer.shadowOffset = .zero
        innerGlowLayer.shadowRadius = 8.0
        innerGlowLayer.shadowOpacity = 0.3
        
        view.layer.insertSublayer(innerGlowLayer, at: 0)
    }
    
    // MARK: - Animation Helpers
    
    /// Animates glass transition between focused and unfocused states
    /// - Parameters:
    ///   - view: Target view
    ///   - config: Glass configuration
    ///   - isFocused: Target focus state
    ///   - duration: Animation duration
    static func animateGlassFocus(
        view: UIView,
        config: GlassLayerConfig,
        isFocused: Bool,
        duration: TimeInterval = AnimationDuration.fast.rawValue
    ) {
        // 🎯 Optimized animation with easeInOut curve
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.5,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            applyMultiLayerGlass(to: view, config: config, isFocused: isFocused)
            view.layoutIfNeeded()
        }
    }
    
    /// Animates glass intensity change with spring physics
    /// - Parameters:
    ///   - view: Target view
    ///   - config: Glass configuration
    ///   - isFocused: Target focus state
    static func animateGlassIntensitySpring(
        view: UIView,
        config: GlassLayerConfig,
        isFocused: Bool
    ) {
        // 🎯 Enhanced spring animation parameters
        let params = isFocused ? SpringParams.standard : SpringParams.subtle
        
        view.animateSpring(params) {
            self.applyMultiLayerGlass(to: view, config: config, isFocused: isFocused)
        }
    }
}

// MARK: - UIView Extension for Convenient Access

@MainActor
extension UIView {
    
    /// Applies glass navigation style with preset configuration
    func applyGlassNavigationStyle(
        preset: GlassLayerConfig? = nil,
        isFocused: Bool = false
    ) {
        let config = preset ?? .menuItem
        GlassNavigationHelper.applyMultiLayerGlass(
            to: self,
            config: config,
            isFocused: isFocused
        )
    }
    
    /// Animates glass focus transition
    func animateGlassNavigationFocus(
        preset: GlassLayerConfig? = nil,
        isFocused: Bool
    ) {
        let config = preset ?? .menuItem
        GlassNavigationHelper.animateGlassFocus(
            view: self,
            config: config,
            isFocused: isFocused
        )
    }
}
