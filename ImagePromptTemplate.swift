//
//  ImagePromptTemplate.swift
//  CalorieAI
//
//  The single place that decides what a food photo looks like. Every image
//  in the app — no matter which provider generated it — is built from this
//  same art-direction scaffold with only the food description swapped in,
//  so the timeline reads as one consistent, styled "set" rather than a
//  grab-bag of random AI images.
//

import Foundation

enum ImagePromptTemplate {
    /// `foodDescription` should be short and concrete — e.g. "a grilled
    /// chicken breast sliced over rice with steamed broccoli" — the agent
    /// supplies this when it calls `log_food_entry`.
    static func prompt(for foodDescription: String) -> String {
        """
        Studio food photograph of \(foodDescription), shot for a minimalist \
        editorial nutrition catalog. Overhead-45-degree angle, centered, on a \
        seamless warm light-grey backdrop (#EDE7DD). Single large diffused \
        softbox key light from upper left, soft natural shadow to lower right, \
        no harsh specular hotspots. Shallow depth of field with the food in \
        crisp focus. Natural color, appetizing, true-to-life texture. No \
        hands, no cutlery in use, no plates with patterns, no packaging, no \
        text, no logos, no watermark, no border. Clean, premium, quiet, \
        consistent with a high-end recipe magazine.
        """
    }

    /// A short, deterministic fallback description for the (rare) case the
    /// agent doesn't supply one — built straight from the logged name.
    static func fallbackDescription(entryName: String, quantityDescription: String) -> String {
        "\(quantityDescription) of \(entryName)"
    }
}
