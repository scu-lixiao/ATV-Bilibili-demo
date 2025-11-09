//
//  PremiumAnimations.swift
//  BilibiliLive
//
//  Advanced animation system for premium UI
//  Created by AI Assistant on 2025/11/8
//

import UIKit

/// Premium animation helper for orchestrated sequences
@MainActor
class PremiumAnimations {
    
    // MARK: - Orchestrated Sequences
    
    /// Animates an array of views with staggered timing
    /// - Parameters:
    ///   - views: Array of views to animate
    ///   - stagger: Time delay between each view animation (default 0.05s)
    ///   - params: Spring animation parameters
    ///   - animations: Animation block for each view
    static func staggered(
        views: [UIView],
        stagger: TimeInterval = 0.05,
        params: SpringParams = .standard,
        animations: @escaping (UIView) -> Void
    ) {
        for (index, view) in views.enumerated() {
            let delay = TimeInterval(index) * stagger
            UIView.animate(
                withDuration: params.duration,
                delay: delay,
                usingSpringWithDamping: params.damping,
                initialSpringVelocity: params.velocity,
                options: [.curveEaseOut, .allowUserInteraction],
                animations: {
                    animations(view)
                }
            )
        }
    }
    
    /// Fade in views with orchestrated timing
    static func fadeInSequence(
        views: [UIView],
        stagger: TimeInterval = 0.05,
        duration: TimeInterval = AnimationDuration.standard.rawValue
    ) {
        views.forEach { $0.alpha = 0 }
        
        staggered(views: views, stagger: stagger, params: .standard) { view in
            view.alpha = 1
        }
    }
    
    /// Scale in views from zero with bounce
    static func scaleInSequence(
        views: [UIView],
        stagger: TimeInterval = 0.05
    ) {
        views.forEach {
            $0.alpha = 0
            $0.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }
        
        staggered(views: views, stagger: stagger, params: .bouncy) { view in
            view.alpha = 1
            view.transform = .identity
        }
    }
    
    // MARK: - Focus Animations
    
    /// Premium focus animation with scale, glow, and subtle lift
    static func animateFocus(
        view: UIView,
        isFocused: Bool,
        scale: CGFloat = 1.06,
        glowColor: UIColor? = nil,
        completion: ((Bool) -> Void)? = nil
    ) {
        let params: SpringParams = isFocused ? .standard : .subtle
        
        UIView.animate(
            withDuration: params.duration,
            delay: 0,
            usingSpringWithDamping: params.damping,
            initialSpringVelocity: params.velocity,
            options: [.curveEaseInOut, .allowUserInteraction]
        ) {
            if isFocused {
                // Scale up with slight lift
                view.transform = CGAffineTransform(scaleX: scale, y: scale)
                    .translatedBy(x: 0, y: -4)
                
                // Apply glow shadow
                view.applyPremiumShadow(
                    elevation: .focused,
                    glowColor: glowColor ?? .pinkGlowShadow
                )
            } else {
                // Return to normal
                view.transform = .identity
                view.applyPremiumShadow(elevation: .level2)
            }
        } completion: { finished in
            completion?(finished)
        }
    }
    
    // MARK: - Transition Animations
    
    /// Cinematic push transition (like modal presentation)
    static func cinematicPush(
        from fromVC: UIViewController,
        to toVC: UIViewController,
        duration: TimeInterval = AnimationDuration.cinematic.rawValue,
        completion: (() -> Void)? = nil
    ) {
        // Prepare destination view
        toVC.view.alpha = 0
        toVC.view.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        toVC.view.layer.cornerRadius = 32
        toVC.view.clipsToBounds = true
        
        // Animate transition
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: SpringParams.dramatic.damping,
            initialSpringVelocity: SpringParams.dramatic.velocity,
            options: [.curveEaseInOut]
        ) {
            // Fade out and scale down source
            fromVC.view.alpha = 0.3
            fromVC.view.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            
            // Fade in and scale to normal destination
            toVC.view.alpha = 1
            toVC.view.transform = .identity
        } completion: { _ in
            completion?()
        }
    }
    
    /// Smooth blur transition
    static func blurTransition(
        view: UIView,
        to intensity: CGFloat,
        duration: TimeInterval = AnimationDuration.standard.rawValue
    ) {
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: nil)
        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blurView)
        
        UIView.animate(withDuration: duration) {
            blurView.effect = intensity > 0 ? blurEffect : nil
            blurView.alpha = intensity
        }
    }
    
    // MARK: - Loading States
    
    /// Elegant skeleton loading animation
    static func skeletonPulse(
        view: UIView,
        color: UIColor? = nil
    ) -> CAAnimation {
        let pulseColor = color ?? UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
        
        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.fromValue = 0.3
        pulseAnimation.toValue = 0.7
        pulseAnimation.duration = 1.2
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = view.bounds
        gradientLayer.colors = [
            pulseColor.withAlphaComponent(0.3).cgColor,
            pulseColor.withAlphaComponent(0.7).cgColor,
            pulseColor.withAlphaComponent(0.3).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.locations = [0, 0.5, 1]
        
        view.layer.addSublayer(gradientLayer)
        gradientLayer.add(pulseAnimation, forKey: "shimmer")
        
        return pulseAnimation
    }
    
    // MARK: - Micro-interactions
    
    /// Subtle bounce on tap
    static func tapBounce(view: UIView) {
        UIView.animate(
            withDuration: 0.1,
            delay: 0,
            options: [.curveEaseOut]
        ) {
            view.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { _ in
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: SpringParams.bouncy.damping,
                initialSpringVelocity: SpringParams.bouncy.velocity,
                options: [.curveEaseInOut]
            ) {
                view.transform = .identity
            }
        }
    }
    
    /// Success pulse animation
    static func successPulse(
        view: UIView,
        color: UIColor? = nil
    ) {
        // Use provided color or default pink
        let pulseColor = color ?? UIColor(displayP3Red: 1.0, green: 0.42, blue: 0.62, alpha: 1.0)
        let originalShadow = view.layer.shadowColor
        
        
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: [.curveEaseOut]
        ) {
            view.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            view.layer.shadowColor = pulseColor.cgColor
            view.layer.shadowRadius = 32
            view.layer.shadowOpacity = 0.6
        } completion: { _ in
            UIView.animate(
                withDuration: 0.5,
                delay: 0,
                usingSpringWithDamping: 0.6,
                initialSpringVelocity: 0.8
            ) {
                view.transform = .identity
                view.layer.shadowColor = originalShadow
                view.layer.shadowRadius = 24
                view.layer.shadowOpacity = 0.3
            }
        }
    }
}

// MARK: - Custom CAMediaTimingFunction

extension CAMediaTimingFunction {
    
    /// Premium easing curve - ease out expo
    static let premiumEaseOut = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
    
    /// Smooth ease in-out with subtle acceleration
    static let premiumEaseInOut = CAMediaTimingFunction(controlPoints: 0.65, 0, 0.35, 1)
    
    /// Dramatic entrance curve
    static let dramaticEntrance = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1)
}

// MARK: - UIView Animation Extension

extension UIView {
    
    /// Convenient method for premium spring animation
    func animatePremium(
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
}
