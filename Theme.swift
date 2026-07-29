//
//  Theme.swift
//  CalorieAI
//
//  Single source of truth for color, type, spacing, and radius tokens.
//  Nothing in the view layer should hard-code a color, font, or magic-number
//  spacing value — everything routes through here so the whole app reads as
//  one considered object instead of a pile of screens.
//

import SwiftUI

enum Theme {

    // MARK: - Palette

    /// Warm-neutral, dark-first palette. Food photography reads best against
    /// a quiet, warm backdrop, so the whole app leans into that rather than
    /// stark iOS-default black/white.
    enum Colors {
        static let ink = Color(hex: 0x14110F)          // near-black, warm charcoal
        static let inkSoft = Color(hex: 0x1E1A17)
        static let paper = Color(hex: 0xFBF6EF)         // warm off-white
        static let paperSoft = Color(hex: 0xF1E9DC)

        /// Primary accent — warm amber, evokes appetite/warmth without being
        /// a cliché "health app green."
        static let accent = Color(hex: 0xFF8A3D)
        static let accentSoft = Color(hex: 0xFFB578)

        // Macro ring colors — distinct but harmonious, all warm-family.
        static let calorieRing = Color(hex: 0xFF8A3D)   // amber
        static let proteinRing = Color(hex: 0xFF5C7A)   // coral rose
        static let carbRing = Color(hex: 0x6FCF97)      // sage
        static let fatRing = Color(hex: 0x8C9EFF)       // soft periwinkle

        static let glassStroke = Color.white.opacity(0.14)
        static let glassHighlight = Color.white.opacity(0.35)
        static let textPrimary = Color(hex: 0xFBF6EF)
        static let textSecondary = Color(hex: 0xFBF6EF).opacity(0.62)
        static let textTertiary = Color(hex: 0xFBF6EF).opacity(0.38)

        static let userBubble = Color(hex: 0x2A241F)
        static let agentBubble = Color(hex: 0x211C18)
    }

    /// The living background gradient. Shifts subtly with the hour of day —
    /// a quiet touch nobody has to configure. Always warm, never garish.
    static func backgroundGradient(for date: Date = .init()) -> LinearGradient {
        let hour = Calendar.current.component(.hour, from: date)
        let (top, bottom): (Color, Color)
        switch hour {
        case 5..<9:    (top, bottom) = (Color(hex: 0x241C17), Color(hex: 0x14110F))   // dawn
        case 9..<17:   (top, bottom) = (Color(hex: 0x1D1815), Color(hex: 0x120F0D))   // day
        case 17..<21:  (top, bottom) = (Color(hex: 0x2A1A14), Color(hex: 0x15100D))   // dusk, warmer
        default:       (top, bottom) = (Color(hex: 0x120E0C), Color(hex: 0x0B0908))   // night
        }
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Type

    enum Font {
        /// Rounded design for numbers, headers, macro values — friendly, premium.
        static func display(_ size: CGFloat, weight: SwiftUI.Font.Weight = .semibold) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .rounded)
        }
        /// Default design for conversational text — optimized for reading.
        static func body(_ size: CGFloat = 16, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .default)
        }
        static let bubble = body(16)
        static let caption = body(13)
        static let microCaption = body(11, weight: .medium)
        static let dayTitle = display(28, weight: .bold)
        static let ringValue = display(22, weight: .bold)
        static let cardTitle = display(15, weight: .semibold)
    }

    // MARK: - Spacing

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: - Radius

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
        static let xl: CGFloat = 30
        static let pill: CGFloat = 999
    }

    // MARK: - Shadow

    enum Shadow {
        static let card = SwiftUI.Color.black.opacity(0.35)
        static let cardRadius: CGFloat = 18
        static let cardY: CGFloat = 10
    }
}

extension Color {
    /// Hex-literal convenience so `Theme.Colors` reads cleanly above.
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
