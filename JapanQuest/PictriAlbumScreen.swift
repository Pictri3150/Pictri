import SwiftUI

// MARK: - ALBUM REFERENCE MIGRATION — Album Root Screen
//
// Reference: local design mockup (pictriimagealbum.png)
//
// 目的は「写真一覧」ではなく「県ごとの達成の振り返り」(spec)。Round 8の
// `PrefectureProgress`/`PrefectureAlbumSummary`(QuestMemoryStore.swift)を
// そのまま使い、Viewは進捗を再計算しない。Home/Map共通のDesign System
// (`PictriScreenBackground`/`PictriScreenHeader`/`PictriSectionTitleBlock`/
// `PictriHomeControlDock`)でHome/Mapと「同じアプリ」に見えるようにする。
//
// 県詳細(`PrefectureMemoryDetailView`)は今回変更しない(次Round)。ここは
// Albumのoverview(=`MemoriesView`の`.collect`モード)だけを置き換える。

enum PictriAlbumFilter: Hashable {
    case all
    /// spec「名前が誤解を生む場合は文言だけ改善案を報告してよい」に基づく決定:
    /// 「訪問済み県すべて」ではなく「1件以上おすすめSpotを達成した県」を採用した。
    /// 理由: Referenceの意図は「おすすめSpot達成をhighlightする」ことであり、
    /// 「訪問済み」は`すべて`側で既に表現されているため、`おすすめ達成`フィルタが
    /// 単なる`すべて`の部分集合(訪問済み=true)にしかならないのを避けた。
    /// `completedCount > 0`(進行中/コンプリートの両方を含む)を条件にすることで、
    /// フィルタ名と実際の絞り込み結果が一致するようにしている。詳細はFinal Reportへ。
    case recommendedAchieved
}

struct PictriAlbumScreen: View {
    let rows: [(prefecture: QuestPrefecture, summary: PrefectureAlbumSummary)]
    let completedPrefectureCount: Int
    let inProgressPrefectureCount: Int
    let totalPrefectureCount: Int
    let completedSpotCount: Int
    let totalSpotCatalogCount: Int
    let notificationBadgeCount: Int
    let onAccountTap: () -> Void
    let onSelectPrefecture: (QuestPrefecture) -> Void
    let onCameraTap: () -> Void
    let onMapTap: () -> Void
    /// Round「WORLD INTERACTIVE MAP / DIRECT HOME NAVIGATION」: Adaptive
    /// 3-slot Dockの「ホームへ戻る」slot用。
    let onHomeTap: () -> Void

    @EnvironmentObject var memoryStore: QuestMemoryStore
    @State private var filter: PictriAlbumFilter = .all

    private var filteredRows: [(prefecture: QuestPrefecture, summary: PrefectureAlbumSummary)] {
        switch filter {
        case .all: return rows
        case .recommendedAchieved: return rows.filter { $0.summary.progress.completedCount > 0 }
        }
    }

    var body: some View {
        GeometryReader { screen in
            ZStack {
                PictriScreenBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        PictriTopBrandHeader(badgeCount: notificationBadgeCount, onAccountTap: onAccountTap)
                            .padding(.horizontal, PictriFinalTheme.screenPadding)
                            .padding(.top, 8)
                            .padding(.bottom, 10)

                        PictriSectionTitleBlock(title: "アルバム", subtitle: "県ごとの思い出と達成状況")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, PictriFinalTheme.screenPadding)
                            .padding(.bottom, 16)

                        summaryRow
                            .padding(.horizontal, PictriFinalTheme.screenPadding)
                            .padding(.bottom, 14)

                        filterControl
                            .padding(.horizontal, PictriFinalTheme.screenPadding)
                            .padding(.bottom, 16)

                        if rows.isEmpty {
                            emptyState
                                .padding(.horizontal, PictriFinalTheme.screenPadding)
                                .padding(.top, 24)
                        } else if filteredRows.isEmpty {
                            filteredEmptyState
                                .padding(.horizontal, PictriFinalTheme.screenPadding)
                                .padding(.top, 24)
                        } else {
                            VStack(spacing: 14) {
                                ForEach(filteredRows, id: \.prefecture.id) { row in
                                    Button {
                                        onSelectPrefecture(row.prefecture)
                                    } label: {
                                        PictriAlbumPrefectureCard(prefecture: row.prefecture, summary: row.summary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, PictriFinalTheme.screenPadding)
                        }

                        Spacer(minLength: PictriHomeFloatingBarMetrics.reservedContentHeight(containerWidth: screen.size.width))
                    }
                }

                PictriHomeControlDock(
                    containerWidth: screen.size.width,
                    onMapTap: onMapTap,
                    onCameraTap: onCameraTap,
                    onAlbumTap: {},
                    onHomeTap: onHomeTap,
                    currentScreen: .album
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, PictriHomeFloatingBarMetrics.bottomGap)
            }
        }
        .navigationBarHidden(true)
    }

    private var summaryRow: some View {
        HStack(spacing: 0) {
            summaryItem(icon: "mappin.circle.fill", tint: PictriHomeBrandAccent.accent, label: "達成県", current: completedPrefectureCount, total: totalPrefectureCount)
            Divider().overlay(Color.white.opacity(0.10)).frame(height: 34)
            summaryItem(icon: "arrow.triangle.2.circlepath", tint: PictriHomeBrandAccent.accent, label: "進行中", current: inProgressPrefectureCount, total: totalPrefectureCount)
            Divider().overlay(Color.white.opacity(0.10)).frame(height: 34)
            summaryItem(icon: "star.fill", tint: PictriPrefectureProgressTheme.completionGold, label: "おすすめ達成", current: completedSpotCount, total: totalSpotCatalogCount)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(PictriDarkTheme.surfaceOverlay.opacity(0.55))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }
        }
    }

    private func summaryItem(icon: String, tint: Color, label: String, current: Int, total: Int) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
                Text(label)
                    .font(PictriTypography.body(11, weight: .semibold))
                    .foregroundStyle(PictriDarkTheme.textFaint)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(current)")
                    .font(PictriTypography.display(18))
                    .foregroundStyle(PictriFinalTheme.ink)
                Text("/ \(total)")
                    .font(PictriTypography.body(11, weight: .semibold))
                    .foregroundStyle(PictriDarkTheme.textFaint)
            }
            .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var filterControl: some View {
        HStack(spacing: 2) {
            filterSegment(title: "すべて", value: .all)
            filterSegment(title: "おすすめ達成", value: .recommendedAchieved)
        }
        .padding(3)
        .background {
            Capsule()
                .fill(PictriDarkTheme.surfaceOverlay.opacity(0.85))
                .overlay {
                    Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                }
        }
    }

    private func filterSegment(title: String, value: PictriAlbumFilter) -> some View {
        let isActive = filter == value
        return Button {
            guard filter != value else { return }
            withAnimation(.easeInOut(duration: 0.2)) { filter = value }
        } label: {
            Text(title)
                .font(PictriTypography.body(13, weight: .bold))
                .foregroundStyle(isActive ? PictriHomeBrandAccent.onAccent : PictriDarkTheme.textFaint)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background {
                    if isActive {
                        Capsule().fill(PictriHomeBrandAccent.accent)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    private var emptyState: some View {
        PictriEmptyState(
            systemImage: "map",
            title: "まだ写真がありません",
            message: "Mapでスポットを訪れて\n最初の記録を残しましょう",
            isLight: true
        )
        .padding(.horizontal, 8)
    }

    private var filteredEmptyState: some View {
        VStack(spacing: 6) {
            Text("おすすめSpotの達成はまだありません")
                .font(PictriTypography.body(13, weight: .bold))
                .foregroundStyle(PictriFinalTheme.inkSoft)
            Text("おすすめSpotで撮ると、ここに表示されます")
                .font(PictriTypography.body(12, weight: .medium))
                .foregroundStyle(PictriFinalTheme.inkFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Prefecture Card

private struct PictriAlbumPrefectureCard: View {
    let prefecture: QuestPrefecture
    let summary: PrefectureAlbumSummary

    @EnvironmentObject var memoryStore: QuestMemoryStore

    private var isComplete: Bool { summary.progress.collectionLevel == .complete }
    private var completedCount: Int { summary.progress.completedCount }
    private var totalCount: Int { summary.progress.totalRecommendedSpotCount }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            representativePhoto
                .frame(width: 118)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    if totalCount > 0 {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("おすすめ \(completedCount)/\(totalCount)")
                                .font(PictriTypography.body(12.5, weight: .bold))
                                .foregroundStyle(PictriFinalTheme.ink)
                                .lineLimit(1)
                            progressDots
                        }
                    } else {
                        Text("おすすめSpot準備中")
                            .font(PictriTypography.body(12, weight: .semibold))
                            .foregroundStyle(PictriDarkTheme.textFaint)
                    }

                    Spacer(minLength: 6)

                    statusBadge
                }

                if !summary.recentRecommendedMemories.isEmpty {
                    thumbnailsRow
                }

                HStack {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PictriDarkTheme.textFaint)
                    Text("思い出 \(summary.memoryCount)枚")
                        .font(PictriTypography.body(11.5, weight: .semibold))
                        .foregroundStyle(PictriDarkTheme.textFaint)

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PictriDarkTheme.textFaint.opacity(0.7))
                }
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PictriDarkTheme.surfaceOverlay.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        // ALBUM COMPLETION CARD: Goldは「県コンプリート」の意味だけ。giant glow/
        // yellow card/casino UIは禁止(spec)、thin border(1.25pt)だけに留める。
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(isComplete ? PictriPrefectureProgressTheme.completionGold.opacity(0.85) : Color.white.opacity(0.08), lineWidth: isComplete ? 1.25 : 1)
        }
    }

    @ViewBuilder
    private var representativePhoto: some View {
        ZStack(alignment: .bottomLeading) {
            if let memory = summary.representativeMemory, let image = memoryStore.image(for: memory) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                // Round 6で確立した「giant black rectangle」対策と同じ処方
                // (PictriHomeCardTheme.placeholderTop/Bottom + 中心寄りのsheen)。
                // 単なるsurfaceRaised→surfaceOverlayの2色だけだとdark themeでは
                // ほぼ黒一色に沈み、「巨大な黒い矩形」に見えてしまう実害があった。
                ZStack {
                    LinearGradient(
                        colors: [PictriHomeCardTheme.placeholderTop, PictriHomeCardTheme.placeholderBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    RadialGradient(
                        colors: [Color.white.opacity(0.05), Color.clear],
                        center: UnitPoint(x: 0.5, y: 0.36),
                        startRadius: 4,
                        endRadius: 140
                    )
                }
            }

            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )

            HStack(spacing: 3) {
                Image(systemName: "mappin")
                    .font(.system(size: 9, weight: .bold))
                Text(prefecture.name)
                    .font(PictriTypography.body(12, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(8)
        }
        .frame(maxHeight: .infinity)
        .clipped()
    }

    /// 常に5個の固定dot(Referenceの「おすすめ 3/5」表現に合わせる)。
    /// 実データの`totalCount`は県によって1〜30以上とバラつくため、1 spot=1 dotに
    /// すると桁数の多い県(神奈川など)でdotsが数十個並んでlabelを圧迫し折り返す
    /// 実害があった(実機確認済み)。Round 8の`collectionLevel`(ratioベースの
    /// 5段階抽象化)をそのまま再利用し、dot数ではなくfillされるdot数で段階を表す。
    private var filledDotCount: Int {
        switch summary.progress.collectionLevel {
        case .unvisited, .visitedNoSpots: return 0
        case .level1: return 1
        case .level2: return 2
        case .level3: return 3
        case .level4: return 4
        case .complete: return 5
        }
    }

    private var progressDots: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index < filledDotCount ? dotColor : Color.white.opacity(0.16))
                    .frame(width: 5, height: 5)
            }
        }
    }

    private var dotColor: Color {
        isComplete ? PictriPrefectureProgressTheme.completionGold : PictriHomeBrandAccent.accent
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isComplete {
            HStack(spacing: 3) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 9, weight: .bold))
                Text("コンプリート")
                    .font(PictriTypography.body(10.5, weight: .bold))
            }
            .foregroundStyle(PictriPrefectureProgressTheme.completionGold)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background {
                Capsule().strokeBorder(PictriPrefectureProgressTheme.completionGold.opacity(0.7), lineWidth: 1)
            }
        } else if completedCount > 0 {
            Text("進行中")
                .font(PictriTypography.body(10.5, weight: .bold))
                .foregroundStyle(PictriHomeBrandAccent.accent)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background {
                    Capsule().strokeBorder(PictriHomeBrandAccent.accent.opacity(0.6), lineWidth: 1)
                }
        } else if totalCount > 0 {
            Text("あと\(totalCount)スポット")
                .font(PictriTypography.body(10, weight: .semibold))
                .foregroundStyle(PictriDarkTheme.textFaint)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background {
                    Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                }
        }
    }

    /// Recommended Spot達成の写真だけを並べる(Anywhere写真は混ぜない、
    /// spec「Recommended achievementがAlbumで目立つ」G13対応)。各サムネイルは
    /// 1.0-1.5pt程度のlavender micro edgeで「Recommended」を示す
    /// (Round 8のCard rimと同じ語彙、太枠/発光にはしない)。
    private var thumbnailsRow: some View {
        HStack(spacing: 6) {
            ForEach(summary.recentRecommendedMemories, id: \.id) { memory in
                ZStack {
                    if let image = memoryStore.image(for: memory) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        PictriDarkTheme.surfaceRaised
                    }
                }
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(PictriHomeBrandAccent.accent.opacity(0.55), lineWidth: 1.25)
                }
            }
        }
    }
}
