import SwiftUI
import CoreGraphics

// MARK: - Travel Color Ribbon
//
// Home画面の最上部、ロゴのすぐ下に一度だけ置く細い帯。
// 「最近色づいた場所」を、県の輪郭+短い状態文だけで伝える。
// 白カードの繰り返しパターンにならないよう、Home内で唯一のこの形の要素として扱う。

struct TravelColorRibbon: View {
    let prefectureName: String
    let points: [CGPoint]
    let accentColor: Color
    let stateText: String

    var body: some View {
        HStack(spacing: CJTokens.Spacing.sm) {
            ColoredPrefectureShape(points: points)
                .fill(accentColor.opacity(0.22))
                .overlay {
                    ColoredPrefectureShape(points: points)
                        .stroke(accentColor, lineWidth: 1.5)
                }
                .frame(width: 44, height: 58)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("最近色づいた場所")
                    .font(CJTokens.Typography.caption)
                    .foregroundStyle(CJTokens.Color.textSecondary)

                Text(stateText)
                    .font(CJTokens.Typography.stateLine)
                    .foregroundStyle(CJTokens.Color.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
            }

            Spacer(minLength: CJTokens.Spacing.xs)

            Text(prefectureName)
                .font(CJTokens.Typography.caption)
                .foregroundStyle(accentColor)
        }
        .padding(CJTokens.Spacing.sm)
        .background(CJTokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: CJTokens.Radius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CJTokens.Radius.medium, style: .continuous)
                .stroke(CJTokens.Color.borderSoft, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Travel Color Ribbon") {
    TravelColorRibbon(
        prefectureName: "神奈川",
        points: ColorJourneyPreviewData.kanagawaShapePoints,
        accentColor: CJTokens.Color.mutedGreen,
        stateText: "神奈川が少しずつ色づいてきた"
    )
    .padding(20)
    .background(CJTokens.Color.backgroundWarm)
}
