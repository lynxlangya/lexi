//
//  ErrorBannerView.swift
//  Lexi
//
//  Created by Codex on 12/15/25.
//

import SwiftUI

struct ErrorBannerView: View {
    let banner: ErrorBanner

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accentColor)
                .padding(.top, 1)

            Text(banner.message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(accentColor.opacity(0.25), lineWidth: 1)
        )
        .accessibilityLabel("Error")
        .accessibilityValue(banner.message)
    }

    private var accentColor: Color {
        banner.style == .warning ? .orange : .red
    }
}

#Preview {
    VStack(spacing: 12) {
        ErrorBannerView(banner: ErrorBanner(message: "Please check your network connection.", style: .warning))
        ErrorBannerView(banner: ErrorBanner(message: "API Key is invalid or expired.", style: .error))
    }
    .padding()
    .frame(width: 360)
}

