import SwiftUI

// MARK: - Color Journey Spot Detail
//
// 未訪問/訪問後を同じ構造(hero + info + 固定CTA)で表現し、
// 撮影前後の「完成した」差分を色の有無だけで作る。紫や青の抽象グラデーションは
// 使わず、実写真アセットが無いため線画(県の輪郭)+地名タイポグラフィで構成する。
// 未訪問=彩度を抑えたアイボリー地に細い輪郭線、訪問後=mutedGreenで塗った輪郭に
// 白い縁取り、という対比だけで「色づいた」ことを伝える。

struct ColorJourneySpotDetailView: View {
    let spot: CJSpotDetail

    /// フロー側からのみ使う追加パラメータ。すべてデフォルト値を持つため、
    /// 静的な`-pictriPrototypeScreen spotUnvisited/spotVisited`単体表示やPreviewの
    /// 見た目・挙動は一切変わらない。
    var justColored: Bool = false
    var kanagawaGeometryNamespace: Namespace.ID? = nil
    var onCaptureTapped: (() -> Void)? = nil
    var onViewMemory: (() -> Void)? = nil
    var onBackToMap: (() -> Void)? = nil

    private var accentColor: Color { CJTokens.Color.mutedGreen }

    var body: some View {
        ZStack(alignment: .bottom) {
            CJTokens.Color.backgroundWarm.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroArea
                    infoSection
                    Spacer(minLength: 140)
                }
            }

            ctaArea

            if let onBackToMap {
                backButton(action: onBackToMap)
            }
        }
    }

    private func backButton(action: @escaping () -> Void) -> some View {
        VStack {
            HStack {
                Button(action: action) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(spot.isVisited ? Color.white : CJTokens.Color.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("地図に戻る")
                Spacer()
            }
            .padding(.horizontal, CJTokens.Spacing.sm)
            .padding(.top, CJTokens.Spacing.xs)
            Spacer()
        }
    }

    private var heroArea: some View {
        ZStack {
            (spot.isVisited ? accentColor : CJTokens.Color.backgroundWarm)

            outline
                // 色づいた直後だけ、ほんの一瞬強調(拡大+不透明度アップ)してから
                // 通常表示へ収まる。常時の点滅・脈動は行わない。
                .scaleEffect(justColored ? 1.04 : 1)
                .animation(.easeOut(duration: 0.5), value: justColored)

            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: 6) {
                    Text(spot.areaName)
                        .font(CJTokens.Typography.caption)
                        .foregroundStyle(spot.isVisited ? Color.white.opacity(0.85) : CJTokens.Color.textSecondary)

                    Text(spot.name)
                        .font(CJTokens.Typography.placeNameLarge)
                        .foregroundStyle(spot.isVisited ? Color.white : CJTokens.Color.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    Text(spot.latinSlug)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(spot.isVisited ? Color.white.opacity(0.7) : CJTokens.Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(CJTokens.Spacing.lg)
            }
        }
        .frame(height: 380)
        .clipped()
    }

    /// Map側のColorJourneyMapView.kanagawaGeometryIDと同じIDを参照することで、
    /// Map上の神奈川ポリゴンとこの輪郭が「同じ要素」としてmatchedGeometryEffectで
    /// つながる。namespaceが渡されない(=静的単体表示/Reduce Motion時)場合は
    /// 通常のShapeとしてそのまま描画するだけで、見た目は変わらない。
    @ViewBuilder
    private var outline: some View {
        let strokeColor = spot.isVisited ? Color.white.opacity(0.55) : CJTokens.Color.textSecondary.opacity(0.32)
        let strokeWidth: CGFloat = spot.isVisited ? 2 : 1.4
        let shape = ColoredPrefectureShape(points: ColorJourneyPreviewData.kanagawaShapePoints)
            .stroke(strokeColor, lineWidth: strokeWidth)
            .frame(width: 220, height: 300)

        if let namespace = kanagawaGeometryNamespace {
            shape.matchedGeometryEffect(id: ColorJourneyMapView.kanagawaGeometryID, in: namespace)
        } else {
            shape
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: CJTokens.Spacing.sm) {
            VisitStateBadge(
                text: spot.isVisited ? "色づきました" : "撮影できます",
                tone: spot.isVisited ? .colored : .ready
            )

            Text(
                spot.isVisited
                    ? "この場所の記憶が、あなたの地図に残りました。"
                    : "現地に着くと、この場所の色が生まれます。"
            )
            .font(CJTokens.Typography.body)
            .foregroundStyle(CJTokens.Color.textPrimary)
            .fixedSize(horizontal: false, vertical: true)

            Text(spot.isVisited ? "訪問済み" : "現在地から \(spot.distanceText)")
                .font(CJTokens.Typography.caption)
                .foregroundStyle(CJTokens.Color.textSecondary)
        }
        .padding(CJTokens.Spacing.lg)
    }

    @ViewBuilder
    private var ctaArea: some View {
        VStack(spacing: CJTokens.Spacing.sm) {
            Rectangle()
                .fill(CJTokens.Color.borderSoft)
                .frame(height: 1)

            if spot.isVisited {
                SpotCaptureCTA(
                    title: "思い出を見る",
                    isPrimary: true,
                    tint: CJTokens.Color.mutedGreen,
                    action: { onViewMemory?() }
                )
                SpotCaptureCTA(title: "友達に共有", isPrimary: false, tint: CJTokens.Color.textSecondary, action: {})
            } else {
                SpotCaptureCTA(
                    title: "ここで写真を残す",
                    isPrimary: true,
                    tint: CJTokens.Color.coral,
                    action: { onCaptureTapped?() }
                )
            }
        }
        .padding(.horizontal, CJTokens.Spacing.md)
        .padding(.top, CJTokens.Spacing.sm)
        .padding(.bottom, CJTokens.Spacing.sm)
        .background(CJTokens.Color.backgroundWarm)
    }
}

#Preview("Spot Detail - Unvisited") {
    ColorJourneySpotDetailView(
        spot: ColorJourneyPreviewData.spotDetail(id: "senshu_university_ikuta", isVisited: false)
    )
}

#Preview("Spot Detail - Visited") {
    ColorJourneySpotDetailView(
        spot: ColorJourneyPreviewData.spotDetail(id: "senshu_university_ikuta", isVisited: true)
    )
}

#Preview("Spot Detail - Narrow") {
    ColorJourneySpotDetailView(
        spot: ColorJourneyPreviewData.spotDetail(id: "senshu_university_ikuta", isVisited: false)
    )
    .frame(width: 375, height: 700)
}
