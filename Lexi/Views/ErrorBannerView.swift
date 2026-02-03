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

            #if os(macOS)
            if let action = banner.action {
                Button(actionTitle(for: action)) {
                    handleAction(action)
                }
                .buttonStyle(.borderless)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accentColor)
            }
            #endif
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(accentColor.opacity(0.25), lineWidth: 1)
        )
        .accessibilityLabel("错误")
        .accessibilityValue(banner.message)
    }

    private var accentColor: Color {
        banner.style == .warning ? .orange : .red
    }

    #if os(macOS)
    private func actionTitle(for action: ErrorBanner.Action) -> String {
        switch action {
        case .openAccessibilitySettings:
            return "打开设置"
        }
    }

    private func handleAction(_ action: ErrorBanner.Action) {
        switch action {
        case .openAccessibilitySettings:
            AppKitHelpers.openAccessibilitySettings()
        }
    }
    #endif
}

#Preview {
    VStack(spacing: 12) {
        ErrorBannerView(banner: ErrorBanner(message: "网络不可用，请检查连接。", style: .warning, action: nil))
        ErrorBannerView(banner: ErrorBanner(message: "API Key 无效或已过期。", style: .error, action: nil))
    }
    .padding()
    .frame(width: 360)
}
