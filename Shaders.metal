//
//  Shaders.metal
//  CalorieAI
//
//  Four [[ stitchable ]] shaders consumed by SwiftUI's colorEffect /
//  distortionEffect / layerEffect modifiers (see ShaderModifiers.swift —
//  views never touch these directly). Keep these fast: they run per-pixel,
//  per-frame, on real devices, so no unbounded loops.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// MARK: - 1. Liquid glass distortion (distortionEffect)
//
// Subtle radial refraction centered on a touch point, decaying with
// distance and time. Used on glass panels (composer, day header) while
// being actively dragged — makes glass feel like it's reacting to touch
// rather than being a static blurred rectangle.

[[ stitchable ]]
float2 liquidGlassDistortion(float2 position, float2 size, float2 touch, float intensity, float time) {
    float2 uv = position - touch;
    float dist = length(uv);
    float radius = max(size.x, size.y) * 0.55;
    float falloff = 1.0 - clamp(dist / radius, 0.0, 1.0);
    falloff = falloff * falloff; // smoother taper toward the edge

    // A gentle ripple ring travels outward from the touch point over time.
    float ring = sin(dist * 0.08 - time * 6.0) * 0.5 + 0.5;
    float push = falloff * intensity * (0.6 + 0.4 * ring);

    float2 dir = dist > 0.0001 ? uv / dist : float2(0.0, 0.0);
    return position - dir * push * 10.0;
}

// MARK: - 2. Shimmer reveal (colorEffect)
//
// A soft diagonal highlight band sweeps across a view once per invocation
// of `progress` going 0→1 (retriggered each time new streamed text lands).
// Reads as "this content is alive," rather than plain fade-in.

[[ stitchable ]]
half4 shimmerReveal(float2 position, half4 color, float2 size, float progress) {
    if (color.a <= 0.001) {
        return color;
    }
    float diag = (position.x + position.y) / max(size.x + size.y, 1.0);
    // Band travels from -0.3 to 1.3 across the diagonal as progress goes 0→1.
    float bandCenter = mix(-0.3, 1.3, progress);
    float dist = abs(diag - bandCenter);
    float band = smoothstep(0.22, 0.0, dist);

    half4 lifted = color;
    lifted.rgb += half3(band * 0.35);
    lifted.rgb = min(lifted.rgb, half3(1.0));
    return lifted;
}

// MARK: - 3. Photo develop (layerEffect)
//
// Plays once when a generated food photo finishes loading: starts
// desaturated / low-contrast / softly blurred and resolves to full clarity,
// with one light-leak sweeping across near the end. `progress` 0 = just
// arrived, 1 = fully developed.

[[ stitchable ]]
half4 photoDevelop(float2 position, SwiftUI::Layer layer, float2 size, float progress) {
    float clarity = clamp(progress, 0.0, 1.0);

    // Cheap 5-tap blur, radius shrinks to 0 as clarity approaches 1.
    float blurRadius = (1.0 - clarity) * 6.0;
    half4 sum = layer.sample(position);
    if (blurRadius > 0.05) {
        const float2 offsets[4] = { float2(1, 0), float2(-1, 0), float2(0, 1), float2(0, -1) };
        for (int i = 0; i < 4; i++) {
            sum += layer.sample(position + offsets[i] * blurRadius);
        }
        sum /= 5.0;
    }

    // Desaturate toward luminance at low clarity.
    float luma = dot(sum.rgb, half3(0.299, 0.587, 0.114));
    half3 desat = mix(half3(luma), sum.rgb, half3(0.35 + 0.65 * clarity));

    // Low contrast -> full contrast as it develops.
    half3 graded = (desat - half3(0.5)) * (0.55 + 0.45 * half(clarity)) + half3(0.5);

    // One light-leak diagonal sweep, brightest around progress ~0.55-0.8.
    float diag = (position.x - position.y) / max(size.x, 1.0);
    float leakCenter = mix(-0.6, 1.2, clamp(progress * 1.3, 0.0, 1.0));
    float leak = smoothstep(0.28, 0.0, abs(diag - leakCenter)) * smoothstep(1.0, 0.45, progress);
    graded += half3(leak * 0.5, leak * 0.38, leak * 0.22);

    return half4(clamp(graded, 0.0, 1.0), sum.a);
}

// MARK: - 4. Ripple zoom (layerEffect)
//
// Shared by the thread<->timeline zoom transition and the day-paging
// "settle" moment. Warps the layer radially around a focal point and adds
// a thin bright rim that travels outward as `progress` advances 0→1, like
// a pane of glass catching light as it swings.

[[ stitchable ]]
half4 rippleZoom(float2 position, SwiftUI::Layer layer, float2 size, float2 focal, float progress) {
    float2 uv = position - focal;
    float dist = length(uv);
    float maxDist = length(size) * 0.5;
    float normDist = maxDist > 0.0001 ? dist / maxDist : 0.0;

    // Radial displacement wave that expands outward with progress.
    float wave = sin((normDist * 14.0) - progress * 10.0);
    float envelope = smoothstep(0.0, 0.5, progress) * smoothstep(1.0, 0.55, progress);
    float displacement = wave * envelope * 6.0 * (1.0 - normDist);

    float2 dir = dist > 0.0001 ? uv / dist : float2(0.0, 0.0);
    half4 sample = layer.sample(position + dir * displacement);

    // Bright rim traveling outward.
    float rimRadius = progress * 1.15;
    float rim = smoothstep(0.06, 0.0, abs(normDist - rimRadius)) * (1.0 - progress);
    sample.rgb += half3(rim * 0.5);

    return half4(clamp(sample.rgb, 0.0, 1.0), sample.a);
}
