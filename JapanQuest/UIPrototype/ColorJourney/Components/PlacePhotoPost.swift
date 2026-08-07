import SwiftUI

// MARK: - Place Photo Post
//
// Home画面のメインコンテンツ。「友達の投稿」ではなく「友達から届いた旅の断片」として
// 見せるため、Instagram型の白カード(アバター+ユーザー名ヘッダー+四角い写真+アクション行)を
// そのまま模倣しない。写真(=単色の面。実写真アセットが無いためプレースホルダーは
// 抽象グラデーションではなく単色+タイポグラフィで構成する)を画面幅に近いサイズで大きく見せ、
// キャプションと操作は写真の外、背景と同じ温かいアイボリーの上に直接置く。

struct PlacePhotoPost: View {
    let fragment: CJTravelFragment
    let isLiked: Bool
    let onLike: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CJTokens.Spacing.sm) {
            photoArea
            captionRow
            interactionRow
        }
    }

    private var photoArea: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: CJTokens.Radius.large, style: .continuous)
                .fill(fragment.accentColor)
                .aspectRatio(4 / 5, contentMode: .fit)

            VStack(alignment: .leading, spacing: 4) {
                Text(fragment.placeName)
                    .font(CJTokens.Typography.placeName)
                    .foregroundStyle(Color.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(fragment.areaName)
                    .font(CJTokens.Typography.caption)
                    .foregroundStyle(Color.white.opacity(0.85))
            }
            .padding(CJTokens.Spacing.md)
        }
    }

    private var captionRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: CJTokens.Spacing.xs) {
            Text(fragment.username)
                .font(CJTokens.Typography.stateLine)
                .foregroundStyle(CJTokens.Color.textPrimary)

            Text("・")
                .font(CJTokens.Typography.caption)
                .foregroundStyle(CJTokens.Color.textSecondary)

            Text(fragment.stateText)
                .font(CJTokens.Typography.body)
                .foregroundStyle(CJTokens.Color.textSecondary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
    }

    private var interactionRow: some View {
        HStack(spacing: CJTokens.Spacing.md) {
            Button(action: onLike) {
                HStack(spacing: 5) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                    Text("\(fragment.likeCount + (isLiked ? 1 : 0))")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isLiked ? CJTokens.Color.coral : CJTokens.Color.textSecondary)
            }
            .accessibilityLabel(isLiked ? "いいねを取り消す" : "いいねする")

            HStack(spacing: 5) {
                Image(systemName: "bubble.left")
                Text("一言そえる")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(CJTokens.Color.textSecondary)

            Spacer(minLength: 0)
        }
    }
}

#Preview("Place Photo Post") {
    ScrollView {
        PlacePhotoPost(
            fragment: ColorJourneyPreviewData.travelFragments[0],
            isLiked: false,
            onLike: {}
        )
        .padding(20)
    }
    .background(CJTokens.Color.backgroundWarm)
}
