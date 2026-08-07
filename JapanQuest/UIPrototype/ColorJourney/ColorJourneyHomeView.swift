import SwiftUI

// MARK: - Color Journey Home
//
// 「色づく旅帳」コンセプトのHome。通常の大きなNavigationTitleは使わず、
// 控えめなロゴ+右上のアカウントアイコンだけの静かなヘッダーにする。
// その下に「最近色づいた場所」を表すTravelColorRibbonを1つだけ置き、
// 以降は白カードの繰り返しではなく、写真(単色プレースホルダー)を主役にした
// PlacePhotoPostを縦に並べる。投稿詳細への遷移は前提にせず、
// いいね/コメントは写真の外にある操作行で直接完結させる。

struct ColorJourneyHomeView: View {
    @State private var fragments: [CJTravelFragment]
    @State private var likedIds: Set<String> = []

    /// フロー側からのみ使う。指定が無ければ従来通りの固定文言/色のまま
    /// (静的な`-pictriPrototypeScreen home`単体表示・Previewの見た目は変わらない)。
    private let ribbonOverride: (stateText: String, accentColor: Color)?

    init(
        fragments: [CJTravelFragment] = ColorJourneyPreviewData.travelFragments,
        extraFragment: CJTravelFragment? = nil,
        ribbonOverride: (stateText: String, accentColor: Color)? = nil
    ) {
        if let extraFragment {
            _fragments = State(initialValue: [extraFragment] + fragments)
        } else {
            _fragments = State(initialValue: fragments)
        }
        self.ribbonOverride = ribbonOverride
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: CJTokens.Spacing.lg) {
                header
                ribbon
                fragmentsList
            }
            .padding(.horizontal, CJTokens.Spacing.md)
            .padding(.top, CJTokens.Spacing.sm)
            .padding(.bottom, CJTokens.Spacing.xl)
        }
        .background(CJTokens.Color.backgroundWarm.ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            Text("PicTri")
                .font(CJTokens.Typography.wordmark)
                .foregroundStyle(CJTokens.Color.textPrimary)

            Spacer()

            Button(action: {}) {
                Circle()
                    .fill(CJTokens.Color.surface)
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(CJTokens.Color.textSecondary)
                    }
                    .overlay {
                        Circle().stroke(CJTokens.Color.borderSoft, lineWidth: 1)
                    }
            }
            .accessibilityLabel("アカウント")
        }
    }

    private var ribbon: some View {
        TravelColorRibbon(
            prefectureName: "神奈川",
            points: ColorJourneyPreviewData.kanagawaShapePoints,
            accentColor: ribbonOverride?.accentColor ?? CJTokens.Color.mutedGreen,
            stateText: ribbonOverride?.stateText ?? "神奈川が少しずつ色づいてきた"
        )
    }

    private var fragmentsList: some View {
        VStack(spacing: CJTokens.Spacing.lg) {
            ForEach(fragments) { fragment in
                PlacePhotoPost(
                    fragment: fragment,
                    isLiked: likedIds.contains(fragment.id),
                    onLike: { toggleLike(fragment.id) }
                )
            }
        }
    }

    private func toggleLike(_ id: String) {
        if likedIds.contains(id) {
            likedIds.remove(id)
        } else {
            likedIds.insert(id)
        }
    }
}

#Preview("Color Journey Home") {
    ColorJourneyHomeView()
}

#Preview("Color Journey Home - Narrow") {
    ColorJourneyHomeView()
        .frame(width: 375)
}
