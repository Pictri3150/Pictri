import SwiftUI
import UIKit

// MARK: - View Mode

enum MemoriesViewMode {
    case collect
    case explore
}

private struct ExploreItem: Identifiable {
    let id: String
    let photo: QuestMemoryPhoto
    let spot: QuestSpot?
}

// MARK: - Memories

struct MemoriesView: View {
    @EnvironmentObject var memoryStore: QuestMemoryStore
    @Binding var pendingExploreSpotId: String?
    @State private var viewMode: MemoriesViewMode = MemoriesView.resolveInitialMode()
    @State private var selectedExploreItem: ExploreItem?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `-pictriMemoriesMode collect|explore` でExploreを直接スクショ確認できるようにする。
    /// DEBUG限定。Releaseでは常にcollectから始まる(既存の通常操作は無変更)。
    private static func resolveInitialMode() -> MemoriesViewMode {
        #if DEBUG
        return PictriVisualReview.memoriesMode ?? .collect
        #else
        return .collect
        #endif
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // CollectはMapと同じ白基調、Exploreは写真が主役の深いindigo基調のまま維持する。
                // 2つのモードで背景トーンが違うのは意図的("記録棚"と"写真ビューア"の切り替え)。
                if viewMode == .collect {
                    PictriLightTheme.background.ignoresSafeArea()
                } else {
                    AppBackground()
                }

                if viewMode == .collect {
                    collectBody
                } else {
                    exploreBody
                }
            }
        }
        .sheet(item: $selectedExploreItem) { item in
            ExplorePhotoDetailSheet(item: item, viewMode: $viewMode)
        }
        .onAppear {
            openPendingExploreEntryIfNeeded()
            openDebugExploreDetailIfRequested()
        }
    }

    /// Camera保存直後の「メモリーで確認する」から来た時だけ、Collectの一覧を経由させず
    /// 今保存した記憶をExplore Detailで直接開く。DEBUG限定ではなく通常のユーザー導線。
    /// 一度開いたら`pendingExploreSpotId`をnilに戻し、以後のタブバー操作に影響させない。
    private func openPendingExploreEntryIfNeeded() {
        guard let spotId = pendingExploreSpotId else { return }
        pendingExploreSpotId = nil

        guard let match = exploreItems.first(where: { $0.spot?.id == spotId }) else { return }

        viewMode = .explore
        selectedExploreItem = match
    }

    /// `-pictriExploreDetail <spotId>` でExplore detail sheetを直接スクショ確認できるようにする。
    /// DEBUG限定。該当するmemory itemが無ければ何もしない(通常のExplore表示のまま)。
    /// 既存のカードタップ(selectedExploreItemへの代入)と同じ経路を使うため、
    /// Explore側の操作・シートのpresentation構造は一切変更しない。
    private func openDebugExploreDetailIfRequested() {
        #if DEBUG
        guard selectedExploreItem == nil,
              let spotId = PictriVisualReview.exploreDetailSpotId,
              let match = exploreItems.first(where: { $0.spot?.id == spotId }) else {
            return
        }
        selectedExploreItem = match
        #endif
    }

    // MARK: - Collect

    private var collectBody: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                memoriesHeader
                prefectureChips
                prefectureCards
                Spacer(minLength: 90)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
        }
    }

    // MARK: - Explore

    private var exploreBody: some View {
        // GeometryReaderで実測した高さをVStackへ明示frameで渡す。こうしないと
        // 内部のSpacerがVStackの「内容に応じた高さ」基準で解決され、意図した
        // 余白配分にならず、下部がタブバーに潜り込むことがあるため。
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                memoriesHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 18)

                if exploreItems.isEmpty {
                    Spacer()
                    exploreEmptyState
                    Spacer()
                } else {
                    exploreCaption
                        .padding(.horizontal, 16)
                        .padding(.top, 26)
                        .padding(.bottom, 22)

                    exploreCarousel(cardWidth: 288, cardHeight: 424)
                    Spacer(minLength: JQUI.bottomBarReserve)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
    }

    /// カルーセル上の大きな空白を、意味のある一言(記憶の枚数)で埋める。
    /// 単なる横スクロール写真一覧ではなく「記憶をめくる」体験だと伝える役割も兼ねる。
    private var exploreCaption: some View {
        HStack(spacing: 7) {
            Image(systemName: "hand.draw.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PictriTheme.teal)

            Text("スワイプして記憶をめくる ・ \(exploreItems.count)枚")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var exploreItems: [ExploreItem] {
        memoryStore.memoryPhotos.map { photo in
            ExploreItem(
                id: photo.id,
                photo: photo,
                spot: mockQuestSpots.first { $0.id == photo.spotId }
            )
        }
    }

    private func exploreCarousel(cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        let screenWidth = UIScreen.main.bounds.width
        let sidePadding = (screenWidth - cardWidth) / 2
        let isMotionReduced = reduceMotion

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(exploreItems) { item in
                    Button {
                        selectedExploreItem = item
                    } label: {
                        ExplorePhotoCard(photo: item.photo, spot: item.spot)
                            .frame(width: cardWidth, height: cardHeight)
                    }
                    .buttonStyle(ExploreCardButtonStyle())
                    .scrollTransition(.animated(.spring(response: 0.3, dampingFraction: 0.82))) { content, phase in
                        content
                            .scaleEffect(phase.isIdentity ? 1.0 : 0.82)
                            .rotation3DEffect(
                                .degrees(isMotionReduced ? 0 : Double(phase.value) * -10),
                                axis: (x: 0, y: 1, z: 0),
                                perspective: 0.4
                            )
                            .opacity(phase.isIdentity ? 1.0 : 0.72)
                    }
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, sidePadding)
        }
        .scrollTargetBehavior(.viewAligned)
        .frame(height: cardHeight + 20)
    }

    private var exploreEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(.white.opacity(0.28))

            VStack(spacing: 8) {
                Text("まだ写真がありません")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))

                Text("Mapでスポットを訪れて\n最初の記録を残しましょう")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.42))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 90)
    }

    // MARK: - Header (shared between modes)
    //
    // CollectモードとExploreモードで背景トーンが違う(白基調/深いindigo基調)ため、
    // ヘッダー自体もisCollectで配色を切り替える。

    private var isCollectMode: Bool { viewMode == .collect }

    private var memoriesHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("メモリーズ")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(isCollectMode ? PictriLightTheme.textPrimary : .white)

                Text("現地で撮った写真が記録になる")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isCollectMode ? PictriLightTheme.textSecondary : .white.opacity(0.48))
            }

            Spacer()

            modeToggle
        }
    }

    private var modeToggle: some View {
        HStack(spacing: 2) {
            modeButton("コレクト", mode: .collect)
            modeButton("探索", mode: .explore)
        }
        .padding(3)
        .background(isCollectMode ? PictriLightTheme.unvisitedFill : .white.opacity(0.08))
        .clipShape(Capsule())
    }

    private func modeButton(_ label: String, mode: MemoriesViewMode) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                viewMode = mode
            }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(viewMode == mode ? PictriTheme.teal : .clear)
                .foregroundStyle(
                    viewMode == mode
                        ? Color.black
                        : (isCollectMode ? PictriLightTheme.textFaint : .white.opacity(0.55))
                )
                .clipShape(Capsule())
        }
    }

    // MARK: - Collect subviews

    /// `-pictriColorScenario multiPrefecture` のDEBUGプレビュー値があればそれを優先する。
    /// PrefectureMemorySummaryCard.completedCountと同じ注入点に揃えることで、
    /// チップのドットとカードの色づきが常に同じ状態を指すようにする。
    private func visibleCompletedCount(for prefecture: QuestPrefecture) -> Int {
        #if DEBUG
        if let override = PictriVisualReview.prefectureCountOverride(for: prefecture.id) {
            return override
        }
        #endif
        return memoryStore.completedCount(prefectureId: prefecture.id)
    }

    private var prefectureChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(mockQuestPrefectures) { prefecture in
                    HStack(spacing: 6) {
                        // 1つでも訪れたスポットがある県には、小さなtealのドットで
                        // 「そこはもう色づいている」ことを地図に頼らず一目で示す。
                        if visibleCompletedCount(for: prefecture) > 0 {
                            Circle()
                                .fill(PictriLightTheme.teal)
                                .frame(width: 5, height: 5)
                        }

                        Text(prefecture.name)
                            .font(.system(size: 14, weight: .bold))
                    }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(prefecture.id == "kanagawa" ? PictriLightTheme.accent : PictriLightTheme.surface)
                        .foregroundStyle(prefecture.id == "kanagawa" ? .white : PictriLightTheme.textPrimary)
                        .clipShape(Capsule())
                        .overlay {
                            if prefecture.id != "kanagawa" {
                                Capsule().stroke(PictriLightTheme.surfaceBorder, lineWidth: 1)
                            }
                        }
                }

                Text("...")
                    .font(.system(size: 14, weight: .bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(PictriLightTheme.surface)
                    .foregroundStyle(PictriLightTheme.textSecondary)
                    .clipShape(Capsule())
                    .overlay {
                        Capsule().stroke(PictriLightTheme.surfaceBorder, lineWidth: 1)
                    }
            }
        }
    }

    private var prefectureCards: some View {
        VStack(spacing: 14) {
            ForEach(mockQuestPrefectures) { prefecture in
                NavigationLink {
                    PrefectureMemoryDetailView(prefecture: prefecture)
                } label: {
                    PrefectureMemorySummaryCard(prefecture: prefecture)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Explore Photo Card

struct ExplorePhotoCard: View {
    let photo: QuestMemoryPhoto
    let spot: QuestSpot?
    @EnvironmentObject var memoryStore: QuestMemoryStore

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            cardBackground

            LinearGradient(
                colors: [.clear, .black.opacity(0.72)],
                startPoint: .center,
                endPoint: .bottom
            )

            cardCaption

            // 「外カメ+内カメで残した記憶」であることを、Exploreでも静かに思い出させる。
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.black.opacity(0.30))
                .frame(width: 30, height: 40)
                .overlay {
                    Image(systemName: "person.crop.rectangle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(PictriTheme.accent.opacity(0.5), lineWidth: 1)
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.32), radius: 14, y: 6)
    }

    @ViewBuilder
    private var cardBackground: some View {
        if let spot, let image = memoryStore.image(for: spot) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if let spot {
            Rectangle()
                .fill(MemoryVisualStyle.gradient(for: spot))
        } else {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.10), .white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }

    private var formattedDate: String {
        let input = DateFormatter()
        input.dateFormat = "yyyy/MM/dd HH:mm"
        let output = DateFormatter()
        output.dateFormat = "M月d日"
        return input.date(from: photo.createdAtText).map { output.string(from: $0) } ?? photo.createdAtText
    }

    private var cardCaption: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(spot?.name ?? "—")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text([spot?.areaName, formattedDate].compactMap { $0 }.joined(separator: " ・ "))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.52))
        }
        .padding(16)
    }
}

// MARK: - Prefecture Summary Card

struct PrefectureMemorySummaryCard: View {
    let prefecture: QuestPrefecture
    @EnvironmentObject var memoryStore: QuestMemoryStore

    private var spots: [QuestSpot] {
        mockQuestSpots
            .filter { $0.prefectureId == prefecture.id }
            .sorted { $0.gridIndex < $1.gridIndex }
    }

    private var memoryPhotos: [QuestMemoryPhoto] {
        memoryStore.memoryPhotos.filter { $0.prefectureId == prefecture.id }
    }

    private var completedCount: Int {
        #if DEBUG
        if let override = PictriVisualReview.prefectureCountOverride(for: prefecture.id) {
            return override
        }
        #endif
        return memoryPhotos.count
    }

    private var remainingPreviewCount: Int {
        max(completedCount - 4, 0)
    }

    private var progressRatio: Double {
        guard prefecture.totalSpotCount > 0 else { return 0 }
        return min(1.0, Double(completedCount) / Double(prefecture.totalSpotCount))
    }

    private var isCompleted: Bool {
        completedCount > 0 && completedCount >= prefecture.totalSpotCount
    }

    private var remainingSpotCount: Int {
        max(prefecture.totalSpotCount - completedCount, 0)
    }

    /// 「達成率」ではなく「自分の旅がじわっと染まっていく」感覚を出すための一言。
    /// 数字やパーセンテージではなく、県の色づき具合を言葉にする。
    private var achievementText: String {
        if completedCount == 0 {
            return "まだ余白ばかり。最初の一枚を残そう"
        }
        if isCompleted {
            return "\(prefecture.name)が色で満ちた"
        }
        if progressRatio >= 0.5 {
            return "\(prefecture.name)の色が濃くなってきた"
        }
        return "\(prefecture.name)が少し色づいてきた"
    }

    private var achievementTextColor: Color {
        guard completedCount > 0 else { return PictriLightTheme.textFaint }
        return isCompleted ? PictriLightTheme.teal : PictriLightTheme.teal.opacity(0.80)
    }

    /// 訪問スポットが増えるほど、カード面にteal(PicTriの「達成・完了」色)がじわっと重なる。
    /// 達成率バーのような数値表現ではなく、色の濃さそのものを進捗として使う。
    private var visitedTintOpacity: Double {
        guard completedCount > 0 else { return 0 }
        return 0.05 + 0.09 * progressRatio
    }

    private var borderColor: Color {
        if isCompleted { return PictriLightTheme.teal.opacity(0.45) }
        return prefecture.id == "kanagawa" ? PictriLightTheme.accent.opacity(0.5) : PictriLightTheme.surfaceBorder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(prefecture.name)
                            .font(.system(size: 23, weight: .bold))
                            .foregroundStyle(PictriLightTheme.textPrimary)

                        if isCompleted {
                            Text("all visited")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(PictriLightTheme.teal)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(PictriLightTheme.teal.opacity(0.14))
                                .clipShape(Capsule())
                        }
                    }

                    Text("\(completedCount) / \(prefecture.totalSpotCount) スポット")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PictriLightTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "bookmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PictriLightTheme.textFaint)
            }

            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { index in
                    PrefecturePreviewTile(
                        prefecture: prefecture,
                        spots: spots,
                        index: index,
                        extraCount: index == 4 ? remainingPreviewCount : 0
                    )
                }
            }

            Text(achievementText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(achievementTextColor)
        }
        .padding(14)
        .background {
            ZStack {
                PictriLightTheme.surface
                PictriLightTheme.teal.opacity(visitedTintOpacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(borderColor, lineWidth: 1)
        }
        .shadow(color: PictriLightTheme.shadow, radius: 12, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(prefecture.name)。\(completedCount)/\(prefecture.totalSpotCount)スポット。\(achievementText)")
    }
}

struct PrefecturePreviewTile: View {
    let prefecture: QuestPrefecture
    let spots: [QuestSpot]
    let index: Int
    let extraCount: Int
    @EnvironmentObject var memoryStore: QuestMemoryStore

    private var spot: QuestSpot? {
        guard index < spots.count else { return nil }
        return spots[index]
    }

    private var memoryPhoto: QuestMemoryPhoto? {
        guard let spot else { return nil }
        return memoryStore.memoryPhotos.first { $0.spotId == spot.id }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let spot, let image = memoryStore.image(for: spot) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 74)
            } else if memoryPhoto != nil, let spot {
                RoundedRectangle(cornerRadius: 10)
                    .fill(MemoryVisualStyle.gradient(for: spot))
                    .frame(height: 74)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(PictriLightTheme.unvisitedFill)
                    .frame(height: 74)

                Image(systemName: "mappin")
                    .font(.system(size: 18))
                    .foregroundStyle(PictriLightTheme.textFaint)
            }

            if extraCount > 0 {
                Text("+\(extraCount)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(8)
            }
        }
        .frame(height: 74)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct PrefectureMemoryDetailView: View {
    let prefecture: QuestPrefecture
    @EnvironmentObject var memoryStore: QuestMemoryStore

    private let columns = [
        GridItem(.flexible(), spacing: 7),
        GridItem(.flexible(), spacing: 7),
        GridItem(.flexible(), spacing: 7)
    ]

    private var spots: [QuestSpot] {
        mockQuestSpots
            .filter { $0.prefectureId == prefecture.id }
            .sorted { $0.gridIndex < $1.gridIndex }
    }

    private var completedCount: Int {
        memoryStore.memoryPhotos
            .filter { $0.prefectureId == prefecture.id }
            .count
    }

    var body: some View {
        ZStack {
            PictriLightTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 15) {
                    detailHeader

                    LazyVGrid(columns: columns, spacing: 7) {
                        ForEach(spots) { spot in
                            FixedMemorySpotCell(
                                spot: spot,
                                memoryPhoto: memoryPhoto(for: spot)
                            )
                        }

                        ForEach(0..<remainingPlaceholderCount, id: \.self) { index in
                            FixedEmptySpotCell(index: index)
                        }
                    }

                    Spacer(minLength: 90)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var detailHeader: some View {
        HStack(alignment: .top) {
            Button {} label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(PictriLightTheme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(PictriLightTheme.surface)
                    .clipShape(Circle())
            }
            .opacity(0)

            Spacer()

            VStack(spacing: 4) {
                Text(prefecture.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(PictriLightTheme.textPrimary)

                Text("\(completedCount) / \(prefecture.totalSpotCount) スポット")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PictriLightTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "ellipsis")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(PictriLightTheme.textPrimary)
                .frame(width: 36, height: 36)
                .background(PictriLightTheme.surface)
                .clipShape(Circle())
                .shadow(color: PictriLightTheme.shadow, radius: 6, x: 0, y: 2)
        }
        .padding(.bottom, 4)
    }

    private var remainingPlaceholderCount: Int {
        max(prefecture.totalSpotCount - spots.count, 0)
    }

    private func memoryPhoto(for spot: QuestSpot) -> QuestMemoryPhoto? {
        memoryStore.memoryPhotos.first { $0.spotId == spot.id }
    }
}

struct FixedMemorySpotCell: View {
    let spot: QuestSpot
    let memoryPhoto: QuestMemoryPhoto?

    @EnvironmentObject var memoryStore: QuestMemoryStore

    private var isUnlocked: Bool {
        memoryPhoto != nil
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            cellVisual

            if isUnlocked {
                miniFrontCameraOverlay
            } else {
                lockedContent
            }

            LinearGradient(
                colors: [
                    .black.opacity(0),
                    .black.opacity(0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Text(spot.name)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .shadow(color: .black.opacity(0.6), radius: 5, x: 0, y: 2)
                .padding(9)
        }
        .frame(height: 132)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isUnlocked ? "\(spot.name)、撮影済み" : "\(spot.name)、未訪問")
    }

    @ViewBuilder
    private var cellVisual: some View {
        if let image = memoryStore.image(for: spot) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 132)
                .clipped()
        } else if isUnlocked {
            RoundedRectangle(cornerRadius: 14)
                .fill(MemoryVisualStyle.gradient(for: spot))
                .frame(height: 132)
        } else {
            RoundedRectangle(cornerRadius: 14)
                .fill(PictriLightTheme.unvisitedFill)
                .frame(height: 132)
        }
    }

    private var lockedContent: some View {
        Image(systemName: "mappin")
            .font(.system(size: 24, weight: .regular))
            .foregroundStyle(PictriLightTheme.textFaint)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var miniFrontCameraOverlay: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(.black.opacity(0.25))
            .frame(width: 33, height: 43)
            .overlay {
                Image(systemName: "person.crop.rectangle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(.white.opacity(0.5), lineWidth: 1)
            }
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct FixedEmptySpotCell: View {
    let index: Int

    /// 余白セルの濃淡をわずかに変えて、単調な繰り返しに見えないようにする。
    private var glowOpacity: Double {
        index % 3 == 0 ? 0.10 : 0.05
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            PictriLightTheme.accent.opacity(glowOpacity),
                            PictriLightTheme.unvisitedFill
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "mappin")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(PictriLightTheme.textFaint)
        }
        .frame(height: 132)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1, dash: [4, 5])
                )
                .foregroundStyle(PictriLightTheme.accent.opacity(0.30))
        }
        .accessibilityLabel("未訪問のスポット")
        .accessibilityHint("現地で撮影すると、ここが写真で埋まります")
    }
}

// MARK: - Explore Photo Detail Sheet

private struct ExplorePhotoDetailSheet: View {
    let item: ExploreItem
    @Binding var viewMode: MemoriesViewMode
    @EnvironmentObject var memoryStore: QuestMemoryStore
    @Environment(\.dismiss) private var dismiss
    @State private var captionVisible = false

    #if DEBUG
    /// 実写真が無いデモ/シードデータでも内カメラサムネイルの見た目を確認できるように、
    /// DEBUGビルド限定でその場限りの合成画像を作る。memoryStore/UserDefaults/Documentsには
    /// 一切書き込まない(CameraViewのapplyDebugScenarioIfRequestedと同じ「表示専用」方針)。
    @State private var debugDemoImage: UIImage?
    #endif

    private var displayImage: UIImage? {
        if let spot = item.spot, let real = memoryStore.image(for: spot) {
            return real
        }
        #if DEBUG
        return debugDemoImage
        #else
        return nil
        #endif
    }

    private var formattedDate: String {
        let input = DateFormatter()
        input.dateFormat = "yyyy/MM/dd HH:mm"
        let output = DateFormatter()
        output.dateFormat = "yyyy年M月d日"
        return input.date(from: item.photo.createdAtText)
            .map { output.string(from: $0) } ?? item.photo.createdAtText
    }

    /// 「日付だけ」より「記憶感」を出すための相対表現。
    private var relativeDateText: String? {
        let input = DateFormatter()
        input.dateFormat = "yyyy/MM/dd HH:mm"
        guard let date = input.date(from: item.photo.createdAtText) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        switch days {
        case ..<1: return "今日の記憶"
        case 1: return "1日前の記憶"
        default: return "\(days)日前の記憶"
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            photoLayer

            LinearGradient(
                // 写真自体に焼き込み済みの日付/地名ラベル(下部左寄り)が、
                // ここで重ねるキャプション(MEMORYラベル+ボタン)と衝突しないよう、
                // 画面下部を早めに・より濃く暗転させて完全に覆い隠す。
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 0.36),
                    .init(color: .black.opacity(0.60), location: 0.58),
                    .init(color: .black.opacity(0.97), location: 0.80),
                    .init(color: .black, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            closeButton

            captionLayer
                .opacity(captionVisible ? 1 : 0)
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
        .presentationBackground(.black)
        .onAppear {
            withAnimation(.easeIn(duration: 0.28).delay(0.08)) {
                captionVisible = true
            }
            #if DEBUG
            if debugDemoImage == nil, let spot = item.spot, memoryStore.image(for: spot) == nil {
                let back = QuestDemoPhotoMaker.makePhoto(spot: spot, isFrontCamera: false)
                let front = QuestDemoPhotoMaker.makePhoto(spot: spot, isFrontCamera: true)
                debugDemoImage = QuestDualPhotoComposer.compose(backImage: back, frontImage: front, spot: spot)
            }
            #endif
        }
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.80))
                        .frame(width: 34, height: 34)
                        .background(.black.opacity(0.30))
                        .clipShape(Circle())
                }
                .padding(.top, 12)
                .padding(.trailing, 20)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var photoLayer: some View {
        if let image = displayImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()
        } else if let spot = item.spot {
            ZStack {
                Rectangle()
                    .fill(MemoryVisualStyle.gradient(for: spot))
                    .ignoresSafeArea()

                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 52, weight: .thin))
                    .foregroundStyle(.white.opacity(0.22))
            }
        }
    }

    /// 外カメ写真に焼き込み済みの内カメ画像を、同じ比率でそのまま切り出して見せる。
    /// BeRealの「写真上に浮かぶ大きな自撮りバブル」を避けるため、写真面には浮かせず、
    /// 暗転済みキャプション領域の右端に検証バッジ等と同格の小さなカードとして置く。
    @ViewBuilder
    private var innerCameraThumbnail: some View {
        Group {
            if let image = displayImage, let crop = QuestDualPhotoComposer.cropInnerCamera(from: image) {
                Image(uiImage: crop)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [PictriTheme.accent.opacity(0.28), .black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .overlay {
                    VStack(spacing: 5) {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.65))

                        Text("この時の表情")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.50))
                    }
                }
            }
        }
        .frame(width: 64, height: 84)
        .clipShape(RoundedRectangle(cornerRadius: PictriTheme.cornerSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PictriTheme.cornerSmall, style: .continuous)
                .stroke(PictriTheme.accent.opacity(0.40), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
    }

    private var captionLayer: some View {
        HStack(alignment: .top, spacing: 12) {
            captionTextColumn

            if item.spot != nil {
                Spacer(minLength: 12)
                innerCameraThumbnail
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, 52)
    }

    private var captionTextColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("MEMORY")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.44))

            Text(item.spot?.name ?? "—")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .padding(.top, 6)

            if let areaName = item.spot?.areaName {
                Text(areaName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
                    .padding(.top, 4)
            }

            HStack(spacing: 8) {
                QuestProofBadge(
                    status: item.photo.proofStatus,
                    distanceMeters: item.photo.verifiedDistanceMeters,
                    style: .dark
                )

                if let relativeDateText {
                    Text(relativeDateText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.52))
                }
            }
            .padding(.top, 12)

            Text(formattedDate)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.white.opacity(0.36))
                .padding(.top, 6)

            if item.spot != nil {
                Button {
                    viewMode = .collect
                    dismiss()
                } label: {
                    Text("この県のコレクトで見る")
                }
                .buttonStyle(.pictriSecondary)
                .frame(maxWidth: 220)
                .padding(.top, 18)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Explore Card Button Style

private struct ExploreCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.86 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// スポットごとの写真プレースホルダー配色。以前はシステム標準色(.blue/.green/.red等)を
/// そのまま使っており、PictriThemeのindigo/teal/warmと無関係な「サンプルアプリ」的な
/// 見た目になっていたため、全パターンをブランドカラーの組み合わせへ差し替えた。
enum MemoryVisualStyle {
    static func gradient(for spot: QuestSpot) -> LinearGradient {
        switch spot.gridIndex % 9 {
        case 0:
            return LinearGradient(colors: [PictriTheme.accent.opacity(0.62), .black], startPoint: .top, endPoint: .bottom)
        case 1:
            return LinearGradient(colors: [PictriTheme.teal.opacity(0.58), .black], startPoint: .top, endPoint: .bottom)
        case 2:
            return LinearGradient(colors: [PictriTheme.warm.opacity(0.58), .black], startPoint: .top, endPoint: .bottom)
        case 3:
            return LinearGradient(
                colors: [PictriTheme.accent.opacity(0.55), Color(red: 0.28, green: 0.19, blue: 0.42), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 4:
            return LinearGradient(
                colors: [PictriTheme.teal.opacity(0.46), Color(red: 0.09, green: 0.26, blue: 0.24), .black],
                startPoint: .top,
                endPoint: .bottom
            )
        case 5:
            return LinearGradient(
                colors: [PictriTheme.warm.opacity(0.5), Color(red: 0.40, green: 0.17, blue: 0.19), .black],
                startPoint: .top,
                endPoint: .bottom
            )
        case 6:
            return LinearGradient(
                colors: [PictriTheme.accent.opacity(0.48), PictriTheme.teal.opacity(0.32), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 7:
            return LinearGradient(
                colors: [PictriTheme.warm.opacity(0.46), PictriTheme.accent.opacity(0.28), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [Color(red: 0.28, green: 0.32, blue: 0.44), .black],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
