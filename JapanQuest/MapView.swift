import SwiftUI

// MARK: - Map

struct QuestMapView: View {
    @Binding var selectedTab: AppTab
    @Binding var activeCameraSpotId: String

    @EnvironmentObject var memoryStore: QuestMemoryStore

    @State private var mapZoomLevel: QuestMapZoomLevel = .prefecture
    @State private var path = NavigationPath()

    private var kanagawaSpots: [QuestSpot] {
        mockQuestSpots
            .filter { $0.prefectureId == "kanagawa" }
            .sorted { $0.gridIndex < $1.gridIndex }
    }

    private var completedSpotIds: Set<String> {
        Set(memoryStore.memoryPhotos.map { $0.spotId })
    }

    private var completedCount: Int {
        memoryStore.completedCount(prefectureId: "kanagawa")
    }

    private var nextSpotsToCapture: [QuestSpot] {
        kanagawaSpots
            .filter { !completedSpotIds.contains($0.id) }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppBackground()

                VStack(alignment: .leading, spacing: 16) {
                    mapHeader

                    mapPanel

                    if !nextSpotsToCapture.isEmpty {
                        discoverySpotsSection
                    }

                    Spacer(minLength: JQUI.bottomBarReserve)
                }
                .padding(.horizontal, JQUI.sidePadding)
                .padding(.top, JQUI.screenTopPadding)
            }
            .onAppear {
                openDebugSpotIfRequested()
            }
            .navigationDestination(for: QuestSpot.self) { spot in
                QuestSpotDetailView(
                    spot: spot,
                    selectedTab: $selectedTab,
                    activeCameraSpotId: $activeCameraSpotId
                )
            }
        }
    }

    /// `-pictriMapSpot <spotId>` でSpotDetailを直接スクショ確認できるようにする。DEBUG限定。
    /// 不正なspotIdの場合は何もしない(通常のMap表示のまま)。既存のnavigationDestination構造は無変更。
    private func openDebugSpotIfRequested() {
        #if DEBUG
        guard path.isEmpty,
              let spotId = PictriVisualReview.mapSpotId,
              let spot = mockQuestSpots.first(where: { $0.id == spotId }) else {
            return
        }
        path.append(spot)
        #endif
    }

    private var mapHeader: some View {
        PictriScreenHeader(eyebrow: "MAP", title: "スポットを探す") {
            Text(mapZoomLevel.label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.white)
                .clipShape(Capsule())
        }
    }

    private var mapPanel: some View {
        ZStack(alignment: .bottomLeading) {
            QuestMapKitView(
                spots: kanagawaSpots,
                completedSpotIds: completedSpotIds,
                zoomLevel: $mapZoomLevel
            ) { spot in
                path.append(spot)
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: JQUI.panelCornerRadius,
                    style: .continuous
                )
            )

            mapPanelBadge
                .padding(18)
        }
        .frame(height: JQUI.panelHeight)
        .background {
            RoundedRectangle(
                cornerRadius: JQUI.panelCornerRadius + 4,
                style: .continuous
            )
            .fill(.white.opacity(0.055))
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: JQUI.panelCornerRadius + 4,
                style: .continuous
            )
            .stroke(.white.opacity(0.10), lineWidth: 1)
        }
    }

    /// 地図を「貼っただけ」に見せないための、Pictri独自の発見パネル。
    /// 数字ではなく「次に残せる場所」を主役にする。
    private var discoverySpotsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("次に残せるスポット")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(nextSpotsToCapture) { spot in
                        Button {
                            path.append(spot)
                        } label: {
                            discoverySpotCard(spot)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(spot.name)、\(spot.areaName)。スポット詳細を開く")
                    }
                }
            }
        }
    }

    private func discoverySpotCard(_ spot: QuestSpot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(MemoryVisualStyle.gradient(for: spot))
                .frame(width: 128, height: 72)
                .overlay {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(spot.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(spot.areaName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(width: 128, alignment: .leading)
    }

    private var mapPanelBadge: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(PictriTheme.accent)
                    .frame(width: 7, height: 7)

                Text("神奈川")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.black)
            }

            Text("\(completedCount) / 24 スポット撮影済み")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.black.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.white.opacity(0.94))
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
        .shadow(color: .black.opacity(0.14), radius: 14, x: 0, y: 6)
    }
}

struct QuestSpotDetailView: View {
    let spot: QuestSpot
    @Binding var selectedTab: AppTab
    @Binding var activeCameraSpotId: String

    @EnvironmentObject var memoryStore: QuestMemoryStore
    @EnvironmentObject var locationManager: QuestLocationManager

    @AppStorage("developerUnlockMode") private var developerUnlockMode = false

    private var isCompleted: Bool {
        memoryStore.hasMemory(for: spot)
    }

    private var isUnlocked: Bool {
        developerUnlockMode || locationManager.isNear(spot)
    }

    private var statusText: String {
        if developerUnlockMode {
            return "開発モードで撮影できます"
        }

        if isUnlocked {
            return "現地で撮影できます"
        }

        return "現地に近づくと撮影できます"
    }

    // MARK: - SpotDetail theme colors
    private var cardBackground: Color { PictriTheme.surface }
    private var primaryText: Color { .white }
    private var secondaryText: Color { .white.opacity(0.48) }
    private var dividerColor: Color { .white.opacity(0.10) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    hero
                    statusCard
                    actionButton
                    memoryPreview
                    Spacer(minLength: JQUI.bottomBarReserve)
                }
                .padding(16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 34)
                .fill(MemoryVisualStyle.gradient(for: spot))
                .frame(height: 360)

            LinearGradient(
                colors: [
                    .black.opacity(0),
                    .black.opacity(0.68)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 34))

            VStack(alignment: .leading, spacing: 8) {
                Text(spot.areaName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.82))

                Text(spot.name)
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    Text(spot.englishName.lowercased())
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.16))
                        .clipShape(Capsule())

                    heroStatusChip
                }
                .foregroundStyle(.white)
            }
            .padding(24)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("撮影状態")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(secondaryText)

                    Text(statusText)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(primaryText)
                }

                Spacer()

                Image(systemName: isUnlocked ? "camera.fill" : "lock.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isUnlocked ? .black : .white.opacity(0.40))
                    .frame(width: 46, height: 46)
                    .background(isUnlocked ? .white : .white.opacity(0.10))
                    .clipShape(Circle())
            }

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            HStack {
                PictriCompactMetric(label: "現在地から", value: locationManager.distanceText(to: spot))

                Spacer()

                PictriCompactMetric(label: "メモリー", value: isCompleted ? "保存済み" : "未撮影")
            }

            Text("現地に着くと解放。正確な住所は表示されません。")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(secondaryText)
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var heroStatusChip: some View {
        if isCompleted {
            Label("撮影済み", systemImage: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.white)
                .foregroundStyle(.black)
                .clipShape(Capsule())
        } else if isUnlocked {
            Label("撮影可能", systemImage: "camera.fill")
                .font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(PictriTheme.accent)
                .foregroundStyle(.black)
                .clipShape(Capsule())
        } else {
            Label("未撮影", systemImage: "circle")
                .font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.white.opacity(0.13))
                .foregroundStyle(.white.opacity(0.70))
                .clipShape(Capsule())
        }
    }

    private var actionButton: some View {
        Button {
            guard isUnlocked else {
                return
            }

            activeCameraSpotId = spot.id
            selectedTab = .camera
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isUnlocked ? "camera.fill" : "location.fill")
                Text(isUnlocked ? "この場所で撮る" : "現地に行くと撮れます")
            }
            .font(.system(size: 17, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isUnlocked ? .white : .white.opacity(0.10))
            .foregroundStyle(isUnlocked ? .black : .white.opacity(0.38))
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
        .disabled(!isUnlocked)
        .accessibilityLabel(isUnlocked ? "\(spot.name)でカメラを起動" : "\(spot.name)は現地に行くと撮影できます")
    }

    private var memoryPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("メモリー")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(primaryText)

            if let image = memoryStore.image(for: spot) {
                ZStack(alignment: .bottomLeading) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 260)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 24))

                    PictriGlassPill(text: spot.englishName.lowercased(), tone: .muted)
                        .padding(14)
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(cardBackground)
                        .frame(height: 220)

                    VStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 32, weight: .regular))
                            .foregroundStyle(.white.opacity(0.28))

                        Text("ここで最初の一枚を残そう")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
        }
    }

}

