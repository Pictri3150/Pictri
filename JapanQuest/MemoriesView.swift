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
    @State private var viewMode: MemoriesViewMode = .collect

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if viewMode == .collect {
                    collectBody
                } else {
                    exploreBody
                }
            }
        }
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
        VStack(alignment: .leading, spacing: 0) {
            memoriesHeader
                .padding(.horizontal, 16)
                .padding(.top, 18)

            if exploreItems.isEmpty {
                Spacer()
                exploreEmptyState
                Spacer()
            } else {
                Spacer()
                exploreCarousel
                Spacer(minLength: 90)
            }
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

    private var exploreCarousel: some View {
        let cardWidth: CGFloat = 264
        let cardHeight: CGFloat = 390
        let screenWidth = UIScreen.main.bounds.width
        let sidePadding = (screenWidth - cardWidth) / 2

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(exploreItems) { item in
                    ExplorePhotoCard(photo: item.photo, spot: item.spot)
                        .frame(width: cardWidth, height: cardHeight)
                        .scrollTransition(.animated(.spring(response: 0.3, dampingFraction: 0.82))) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1.0 : 0.82)
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

    private var memoriesHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("メモリーズ")
                    .font(.system(size: 30, weight: .bold))

                Text("現地で撮った写真が記録になる")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
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
        .background(.white.opacity(0.08))
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
                .background(viewMode == mode ? .white : .clear)
                .foregroundStyle(viewMode == mode ? .black : .white.opacity(0.55))
                .clipShape(Capsule())
        }
    }

    // MARK: - Collect subviews

    private var prefectureChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(mockQuestPrefectures) { prefecture in
                    Text(prefecture.name)
                        .font(.system(size: 14, weight: .bold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(prefecture.id == "kanagawa" ? .white : .white.opacity(0.08))
                        .foregroundStyle(prefecture.id == "kanagawa" ? .black : .white)
                        .clipShape(Capsule())
                }

                Text("...")
                    .font(.system(size: 14, weight: .bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.08))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
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

            if let areaName = spot?.areaName {
                Text(areaName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
            }

            Text(formattedDate)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.white.opacity(0.42))
                .padding(.top, 2)
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
        memoryPhotos.count
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

    private var progressBar: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.white.opacity(0.10))
                .frame(height: 2)

            if completedCount > 0 {
                GeometryReader { geo in
                    Capsule()
                        .fill(.white.opacity(isCompleted ? 0.90 : 0.55))
                        .frame(width: geo.size.width * progressRatio, height: 2)
                }
                .frame(height: 2)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(prefecture.name)
                            .font(.system(size: 23, weight: .bold))
                            .foregroundStyle(.white)

                        if isCompleted {
                            Text("all visited")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.75))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.white.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }

                    Text("\(completedCount) / \(prefecture.totalSpotCount) スポット")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                Image(systemName: "bookmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
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

            progressBar
        }
        .padding(14)
        .background(.white.opacity(0.065))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(prefecture.id == "kanagawa" ? .white.opacity(0.65) : .white.opacity(0.06), lineWidth: 1)
        }
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
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(tileBackground)
                    .frame(height: 74)

                if memoryPhoto == nil {
                    Image(systemName: "mappin")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.14))
                }
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

    private var tileBackground: LinearGradient {
        guard let spot, memoryPhoto != nil else {
            return LinearGradient(
                colors: [.white.opacity(0.08), .white.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return MemoryVisualStyle.gradient(for: spot)
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
            AppBackground()

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
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .opacity(0)

            Spacer()

            VStack(spacing: 4) {
                Text(prefecture.name)
                    .font(.system(size: 24, weight: .bold))

                Text("\(completedCount) / \(prefecture.totalSpotCount) スポット")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            Image(systemName: "ellipsis")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.08))
                .clipShape(Circle())
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
    }

    @ViewBuilder
    private var cellVisual: some View {
        if let image = memoryStore.image(for: spot) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 132)
                .clipped()
        } else {
            RoundedRectangle(cornerRadius: 14)
                .fill(cellBackground)
                .frame(height: 132)
                .overlay {
                    if isUnlocked {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.white.opacity(0.025))
                    }
                }
        }
    }

    private var cellBackground: LinearGradient {
        if isUnlocked {
            return MemoryVisualStyle.gradient(for: spot)
        } else {
            return LinearGradient(
                colors: [
                    .white.opacity(0.07),
                    .white.opacity(0.035)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var lockedContent: some View {
        Image(systemName: "mappin")
            .font(.system(size: 24, weight: .regular))
            .foregroundStyle(.white.opacity(0.16))
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

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.055),
                            .white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "mappin")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.white.opacity(0.10))
        }
        .frame(height: 132)
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.045), lineWidth: 1)
        }
    }
}

enum MemoryVisualStyle {
    static func gradient(for spot: QuestSpot) -> LinearGradient {
        switch spot.gridIndex % 9 {
        case 0:
            return LinearGradient(colors: [.blue.opacity(0.55), .black], startPoint: .top, endPoint: .bottom)
        case 1:
            return LinearGradient(colors: [.green.opacity(0.55), .black], startPoint: .top, endPoint: .bottom)
        case 2:
            return LinearGradient(colors: [.red.opacity(0.52), .black], startPoint: .top, endPoint: .bottom)
        case 3:
            return LinearGradient(colors: [.purple.opacity(0.55), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 4:
            return LinearGradient(colors: [.brown.opacity(0.65), .black], startPoint: .top, endPoint: .bottom)
        case 5:
            return LinearGradient(colors: [.cyan.opacity(0.48), .black], startPoint: .top, endPoint: .bottom)
        case 6:
            return LinearGradient(colors: [.orange.opacity(0.55), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 7:
            return LinearGradient(colors: [.mint.opacity(0.52), .black], startPoint: .top, endPoint: .bottom)
        default:
            return LinearGradient(colors: [.gray.opacity(0.55), .black], startPoint: .top, endPoint: .bottom)
        }
    }
}
