//
//  UIView+LiquidGlass.swift
//  BilibiliLive
//
//  Liquid Glass effect extensions for tvOS 26
//  Created by AI Assistant on 2025/11/8
//

import UIKit

@MainActor
extension UIView {
    
    // MARK: - Liquid Glass Effects (tvOS 26+)
    
    /// Applies Liquid Glass effect with automatic version checking
    /// - Parameters:
    ///   - style: Glass effect style (.clear for most use cases)
    ///   - tintColor: Optional tint color for the glass
    ///   - cornerRadius: Corner radius for the glass container
    ///   - interactive: Whether glass should respond to interactions
    func applyLiquidGlass(
        style: UIGlassEffect.Style = .clear,
        tintColor: UIColor? = nil,
        cornerRadius: CGFloat = CornerRadiusToken.medium.rawValue,
        interactive: Bool = false
    ) {
        if #available(tvOS 26.0, *) {
            // Remove any existing blur effects
            subviews.first(where: { $0 is UIVisualEffectView })?.removeFromSuperview()
            
            // Create glass effect
            let glassEffect = UIGlassEffect(style: style)
            let effectView = UIVisualEffectView(effect: glassEffect)
            effectView.clipsToBounds = true
            effectView.layer.cornerRadius = cornerRadius
            effectView.isUserInteractionEnabled = interactive
            
            // Apply tint if provided
            if let tint = tintColor {
                effectView.contentView.backgroundColor = tint
            }
            
            // Insert at the bottom of the view hierarchy
            insertSubview(effectView, at: 0)
            effectView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                effectView.topAnchor.constraint(equalTo: topAnchor),
                effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
                effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
                effectView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        } else {
            // Fallback for tvOS 18-25
            applyBlurEffect(style: .extraDark, cornerRadius: cornerRadius)
        }
    }
    
    /// Legacy blur effect for backwards compatibility
    func applyBlurEffect(
        style: UIBlurEffect.Style = .extraDark,
        cornerRadius: CGFloat = CornerRadiusToken.medium.rawValue
    ) {
        let blurEffect = UIBlurEffect(style: style)
        let effectView = UIVisualEffectView(effect: blurEffect)
        effectView.clipsToBounds = true
        effectView.layer.cornerRadius = cornerRadius
        
        insertSubview(effectView, at: 0)
        effectView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    // MARK: - Enhanced Shadow System
    
    /// Applies premium shadow with optional colored glow
    /// - Parameters:
    ///   - elevation: Shadow elevation level
    ///   - glowColor: Optional colored shadow for accents
    func applyPremiumShadow(
        elevation: ShadowElevation = .level2,
        glowColor: UIColor? = nil
    ) {
        layer.shadowOffset = elevation.offset
        layer.shadowRadius = elevation.radius
        layer.shadowOpacity = elevation.opacity
        layer.shadowColor = (glowColor ?? UIColor.deepShadow).cgColor
        layer.masksToBounds = false
        
        // Optimize shadow rendering
        layer.shouldRasterize = true
        layer.rasterizationScale = UIScreen.main.scale
    }
    
    /// Removes all shadow effects
    func removeShadow() {
        layer.shadowOpacity = 0
        layer.shadowOffset = .zero
        layer.shadowRadius = 0
    }
    
    // MARK: - Gradient Background
    
    /// Applies a dark gradient background
    func applyDarkGradient() {
        let gradient = UIColor.createDarkGradient()
        gradient.frame = bounds
        layer.insertSublayer(gradient, at: 0)
    }
    
    /// Applies an ambient glow gradient
    func applyAmbientGlow(color: UIColor) {
        let gradient = UIColor.createAmbientGlow(color: color)
        gradient.frame = bounds
        layer.insertSublayer(gradient, at: 0)
    }
    
    // MARK: - Smooth Animations
    
    /// Animate with spring physics
    func animateSpring(
        _ params: SpringParams = .standard,
        animations: @escaping () -> Void,
        completion: ((Bool) -> Void)? = nil
    ) {
        UIView.animate(
            withDuration: params.duration,
            delay: 0,
            usingSpringWithDamping: params.damping,
            initialSpringVelocity: params.velocity,
            options: [.curveEaseInOut, .allowUserInteraction],
            animations: animations,
            completion: completion
        )
    }
    
    /// Animate focus state with scale and glow
    func animateFocusState(
        isFocused: Bool,
        scale: CGFloat = 1.06,
        glowColor: UIColor? = nil
    ) {
        animateSpring(.standard) {
            if isFocused {
                self.transform = CGAffineTransform(scaleX: scale, y: scale)
                if let color = glowColor {
                    self.applyPremiumShadow(elevation: .focused, glowColor: color)
                } else {
                    self.applyPremiumShadow(elevation: .focused)
                }
            } else {
                self.transform = .identity
                self.applyPremiumShadow(elevation: .level2)
            }
        }
    }
}

// MARK: - Convenient Helpers

@MainActor
extension UIView {
    
    /// Sets corner radius with consistent system tokens
    func setCornerRadius(_ token: CornerRadiusToken) {
        layer.cornerRadius = token.rawValue
        clipsToBounds = true
    }
    
    /// Applies the full premium card style (glass + shadow + corner)
    func applyPremiumCardStyle(
        cornerRadius: CornerRadiusToken = .medium,
        tintColor: UIColor? = nil,
        elevation: ShadowElevation = .level2
    ) {
        applyLiquidGlass(
            tintColor: tintColor,
            cornerRadius: cornerRadius.rawValue
        )
        applyPremiumShadow(elevation: elevation)
        setCornerRadius(cornerRadius)
    }
}

// MARK: - Glass Effect Container Helper

@available(tvOS 26.0, *)
@MainActor
class LiquidGlassContainer: UIView {
    
    private let contentView = UIView()
    private var glassView: UIVisualEffectView?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        // Apply glass background
        let glassEffect = UIGlassEffect(style: .clear)
        let effectView = UIVisualEffectView(effect: glassEffect)
        effectView.clipsToBounds = true
        effectView.layer.cornerRadius = CornerRadiusToken.medium.rawValue
        
        addSubview(effectView)
        effectView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // Add content view
        effectView.contentView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: effectView.contentView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: effectView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: effectView.contentView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: effectView.contentView.bottomAnchor)
        ])
        
        glassView = effectView
    }
    
    /// Override addSubview to add to content view instead
    override func addSubview(_ view: UIView) {
        if view == glassView {
            super.addSubview(view)
        } else {
            contentView.addSubview(view)
        }
    }
}
