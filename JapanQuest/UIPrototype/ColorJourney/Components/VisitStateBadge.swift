import SwiftUI

// MARK: - Visit State Badge
//
// 「まだ」「撮影できます」「色づきました」のような状態を、色付きドット+短い文言だけで
// 伝える小さなピル。本番のPictriStatusBadge/PictriAccentChipとは別実装
// (プロトタイプはPictriDesignSystemに依存させない方針のため)。

struct VisitStateBadge: View {
    enum Tone {
        case notYet
        case ready
        case colored

        var color: Color {
            switch self {
            case .notYet: return CJTokens.Color.textSecondary
            case .ready: return CJTokens.Color.coral
            case .colored: return CJTokens.Color.mutedGreen
            }
        }
    }

    let text: String
    let tone: Tone

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tone.color)
                .frame(width: 7, height: 7)

            Text(text)
                .font(CJTokens.Typography.stateLine)
                .foregroundStyle(tone.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(tone.color.opacity(0.12))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
    }
}

#Preview("Visit State Badge") {
    VStack(spacing: 12) {
        VisitStateBadge(text: "まだ", tone: .notYet)
        VisitStateBadge(text: "撮影できます", tone: .ready)
        VisitStateBadge(text: "色づきました", tone: .colored)
    }
    .padding(40)
    .background(CJTokens.Color.backgroundWarm)
}
