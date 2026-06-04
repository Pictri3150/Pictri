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

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    mapHeader

                    mapPanel

                    Spacer(minLength: JQUI.bottomBarReserve)
                }
                .padding(.horizontal, JQUI.sidePadding)
                .padding(.top, JQUI.screenTopPadding)
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

    private var mapHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Map")
                    .font(.system(size: 44, weight: .black))
                    .foregroundStyle(.white)

                Text("県を開くと、すべてのスポットが現れる")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.46))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text(mapZoomLevel.label)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.white)
                    .clipShape(Capsule())

                Text("\(completedCount) / 24")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white.opacity(0.52))
            }
            .padding(.top, 4)
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

    private var mapPanelBadge: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Kanagawa")
                .font(.system(size: 23, weight: .black))
                .foregroundStyle(.black)

            Text("\(completedCount) / 24 spots")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.black.opacity(0.52))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.white.opacity(0.94))
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
    }
}

struct QuestSpotDetailView: View {
    let spot: QuestSpot
    @Binding var selectedTab: AppTab
    @Binding var activeCameraSpotId: String

    @EnvironmentObject var memoryStore: QuestMemoryStore
    @EnvironmentObject var locationManager: QuestLocationManager

    @AppStorage("developerUnlockMode") private var developerUnlockMode = true

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

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    hero
                    statusCard
                    actionButton
                    memoryPreview
                    Spacer(minLength: 80)
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

                    if isCompleted {
                        Text("撮影済み")
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.white)
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                    }
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
                        .foregroundStyle(.black.opacity(0.48))

                    Text(statusText)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.black)
                }

                Spacer()

                Image(systemName: isUnlocked ? "camera.fill" : "lock.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isUnlocked ? .white : .black.opacity(0.4))
                    .frame(width: 46, height: 46)
                    .background(isUnlocked ? .black : .black.opacity(0.06))
                    .clipShape(Circle())
            }

            Divider()
                .background(.black.opacity(0.08))
            
            HStack {
                statusItem(
                    title: "現在地から",
                    value: locationManager.distanceText(to: spot)
                )

                Spacer()

                statusItem(
                    title: "解放範囲",
                    value: "\(Int(spot.unlockRadiusMeters))m"
                )

                Spacer()

                statusItem(
                    title: "メモリー",
                    value: isCompleted ? "保存済み" : "未撮影"
                )
            }
        }
        .padding(16)
        .background(.black.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func statusItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.black.opacity(0.42))

            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
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
            .background(isUnlocked ? .black : .black.opacity(0.12))
            .foregroundStyle(isUnlocked ? .white : .black.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
        .disabled(!isUnlocked)
    }

    private var memoryPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("メモリー")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black)

            if let image = memoryStore.image(for: spot) {
                ZStack(alignment: .bottomLeading) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 260)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 24))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentDateText())
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))

                        Text(spot.englishName.lowercased())
                            .font(.system(size: 23, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.white.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(14)
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.black.opacity(0.035))
                        .frame(height: 220)

                    VStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 32, weight: .regular))
                            .foregroundStyle(.black.opacity(0.28))

                        Text("ここで最初の一枚を残そう")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.black.opacity(0.55))
                    }
                }
            }
        }
    }

    private func currentDateText() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: Date())
    }
}

