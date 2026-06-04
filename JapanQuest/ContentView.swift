import SwiftUI
import CoreLocation
import Combine

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @State private var activeCameraSpotId: String = "enoshima_coast"
    @StateObject private var memoryStore = QuestMemoryStore()
    @StateObject private var friendStore = QuestFriendStore()
    @StateObject private var locationManager = QuestLocationManager()

    var body: some View {
        ZStack(alignment: .bottom) {
            activeScreen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.ignoresSafeArea())
                .animation(.easeInOut(duration: 0.18), value: selectedTab)

            JQFloatingTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
        }
        .background(Color.black.ignoresSafeArea())
        .environmentObject(memoryStore)
        .environmentObject(friendStore)
        .environmentObject(locationManager)
    }

    @ViewBuilder
    private var activeScreen: some View {
        switch selectedTab {
        case .home:
            HomeView(selectedTab: $selectedTab)

        case .map:
            QuestMapView(
                selectedTab: $selectedTab,
                activeCameraSpotId: $activeCameraSpotId
            )

        case .camera:
            QuestCameraView(
                selectedTab: $selectedTab,
                selectedSpotId: $activeCameraSpotId
            )

        case .memories:
            MemoriesView()
        }
    }
}

struct JQFloatingTabBar: View {
    @Binding var selectedTab: AppTab

    private let tabs: [AppTab] = [
        .home,
        .map,
        .camera,
        .memories
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selectedTab = tab
                    }
                } label: {
                    JQFloatingTabItem(
                        tab: tab,
                        isSelected: selectedTab == tab
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(7)
        .background {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.black.opacity(0.78))
                .background {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 22, x: 0, y: 12)
    }
}

struct JQFloatingTabItem: View {
    let tab: AppTab
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: tab.iconName)
                .font(.system(size: 22, weight: .bold))
                .symbolRenderingMode(.hierarchical)

            Text(tab.title)
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(isSelected ? .black : .white.opacity(0.78))
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(.white)
                    .shadow(color: .white.opacity(0.18), radius: 10, x: 0, y: 0)
            } else {
                Color.clear
            }
        }
        .contentShape(Rectangle())
    }
}

enum AppTab: Hashable, CaseIterable {
    case home
    case map
    case camera
    case memories

    var title: String {
        switch self {
        case .home:
            return "ホーム"
        case .map:
            return "マップ"
        case .camera:
            return "カメラ"
        case .memories:
            return "メモリー"
        }
    }

    var iconName: String {
        switch self {
        case .home:
            return "house.fill"
        case .map:
            return "map.fill"
        case .camera:
            return "camera.fill"
        case .memories:
            return "square.grid.2x2.fill"
        }
    }
}

enum JQUI {
    static let sidePadding: CGFloat = 18
    static let screenTopPadding: CGFloat = 70
    static let panelHeight: CGFloat = 540
    static let panelCornerRadius: CGFloat = 34
    static let bottomBarReserve: CGFloat = 116
}

// MARK: - Shared

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.02, blue: 0.025),
                Color(red: 0.07, green: 0.07, blue: 0.075)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}


#Preview {
    ContentView()
}
