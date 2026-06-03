import SwiftUI
import UIKit

// MARK: - Memories

struct MemoriesView: View {
    @EnvironmentObject var memoryStore: QuestMemoryStore

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

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
        }
    }

    private var memoriesHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("メモリーズ")
                    .font(.system(size: 30, weight: .bold))

                Text("撮った場所だけが埋まる")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
            }

            Spacer()

            Button {} label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.08))
                    .clipShape(Circle())
            }
        }
    }

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

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(prefecture.name)
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(.white)

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
            RoundedRectangle(cornerRadius: 10)
                .fill(tileBackground)
                .frame(height: 74)

            if memoryPhoto == nil {
                Image(systemName: "flag")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.12))
            }

            if extraCount > 0 {
                Text("+\(extraCount)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(8)
            }
        }
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
        Image(systemName: "flag")
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

            Image(systemName: "flag")
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
