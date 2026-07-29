//
//  ShaderModifiers.swift
//  CalorieAI
//
//  Thin, typed wrappers around Shaders.metal. Views call `.liquidGlass(...)`,
//  `.shimmerReveal(...)`, etc. — nothing outside this file constructs a
//  `Shader` or touches `ShaderLibrary` directly. Each modifier falls back to
//  plain content on OS versions that predate stitchable shaders.
//

import SwiftUI

enum ShaderModifiers {
    /// Stitchable shaders (colorEffect/distortionEffect/layerEffect) require
    /// iOS 17+. The app's deployment target is 17, so this is effectively
    /// always true on-device — kept as an explicit, honest guard rather than
    /// assuming.
    static var isSupported: Bool {
        if #available(iOS 17.0, *) { return true }
        return false
    }
}

// MARK: - 1. Liquid glass distortion

private struct LiquidGlassDistortionModifier: ViewModifier {
    var touch: CGPoint
    var intensity: Double

    func body(content: Content) -> some View {
        if ShaderModifiers.isSupported {
            TimelineView(.animation(paused: intensity <= 0.001)) { timeline in
                content.visualEffect { view, proxy in
                    view.distortionEffect(
                        ShaderLibrary.liquidGlassDistortion(
                            .float2(proxy.size),
                            .float2(touch),
                            .float(intensity),
                            .float(timeline.date.timeIntervalSinceReferenceDate)
                        ),
                        maxSampleOffset: CGSize(width: 14, height: 14),
                        isEnabled: intensity > 0.001
                    )
                }
            }
        } else {
            content
        }
    }
}

extension View {
    /// Apply while a glass surface is being actively touched/dragged.
    /// `touch` is in the view's local coordinate space; `intensity` should
    /// ease to 0 on release so the glass "settles."
    func liquidGlassDistortion(touch: CGPoint, intensity: Double) -> some View {
        modifier(LiquidGlassDistortionModifier(touch: touch, intensity: intensity))
    }
}

// MARK: - 2. Shimmer reveal

private struct ShimmerRevealModifier: ViewModifier {
    var progress: Double

    func body(content: Content) -> some View {
        if ShaderModifiers.isSupported {
            content.visualEffect { view, proxy in
                view.colorEffect(
                    ShaderLibrary.shimmerReveal(
                        .float2(proxy.size),
                        .float(progress)
                    )
                )
            }
        } else {
            content
        }
    }
}

extension View {
    /// Drive `progress` from 0 to 1 (e.g. with `MotionSpring.snappy`) each
    /// time a fresh chunk of streamed text lands, so the bubble reads as
    /// "alive" rather than a static typewriter.
    func shimmerReveal(progress: Double) -> some View {
        modifier(ShimmerRevealModifier(progress: progress))
    }
}

// MARK: - 3. Photo develop

private struct PhotoDevelopModifier: ViewModifier {
    var progress: Double

    func body(content: Content) -> some View {
        if ShaderModifiers.isSupported {
            content.visualEffect { view, proxy in
                view.layerEffect(
                    ShaderLibrary.photoDevelop(
                        .float2(proxy.size),
                        .float(progress)
                    ),
                    maxSampleOffset: CGSize(width: 8, height: 8)
                )
            }
        } else {
            content.opacity(progress)
        }
    }
}

extension View {
    /// Plays once, driven by a 0→1 value animated with `MotionSpring.gentle`
    /// over ~900ms, the moment a generated food photo is ready to reveal.
    func photoDevelop(progress: Double) -> some View {
        modifier(PhotoDevelopModifier(progress: progress))
    }
}

// MARK: - 4. Ripple zoom

private struct RippleZoomModifier: ViewModifier {
    var progress: Double
    var focal: CGPoint

    func body(content: Content) -> some View {
        if ShaderModifiers.isSupported {
            content.visualEffect { view, proxy in
                view.layerEffect(
                    ShaderLibrary.rippleZoom(
                        .float2(proxy.size),
                        .float2(focal),
                        .float(progress)
                    ),
                    maxSampleOffset: CGSize(width: 32, height: 32),
                    isEnabled: progress > 0.001 && progress < 0.999
                )
            }
        } else {
            content
        }
    }
}

extension View {
    /// Used for the thread↔timeline zoom transition and the day-paging
    /// settle moment. `focal` is the pinch/tap origin in local coordinates.
    func rippleZoom(progress: Double, focal: CGPoint) -> some View {
        modifier(RippleZoomModifier(progress: progress, focal: focal))
    }
}
