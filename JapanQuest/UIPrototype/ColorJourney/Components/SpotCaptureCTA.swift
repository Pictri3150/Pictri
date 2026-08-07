import SwiftUI

// MARK: - Spot Capture CTA
//
// SpotDetail画面下部に固定するCTAボタン。青色を使わず、
// 文脈色(coral=これから撮る、mutedGreen=完了/次のアクション)だけで意味を伝える。
// primary=塗り、secondary=枠線のみ、という最小限の2パターンだけ持つ。

struct SpotCaptureCTA: View {
    let title: String
    let isPrimary: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(CJTokens.Typography.cta)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .background(isPrimary ? tint : Color.clear)
        .foregroundStyle(isPrimary ? Color.white : tint)
        .overlay {
            if !isPrimary {
                RoundedRectangle(cornerRadius: CJTokens.Radius.medium, style: .continuous)
                    .stroke(tint, lineWidth: 1.5)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CJTokens.Radius.medium, style: .continuous))
    }
}

#Preview("Spot Capture CTA") {
    VStack(spacing: 12) {
        SpotCaptureCTA(title: "ここで写真を残す", isPrimary: true, tint: CJTokens.Color.coral, action: {})
        SpotCaptureCTA(title: "思い出を見る", isPrimary: true, tint: CJTokens.Color.mutedGreen, action: {})
        SpotCaptureCTA(title: "友達に共有", isPrimary: false, tint: CJTokens.Color.textSecondary, action: {})
    }
    .padding(20)
    .background(CJTokens.Color.backgroundWarm)
}
