import SwiftUI
import CoreLocation
import Combine

struct ContentView: View {
    @State private var selectedTab: AppTab = ContentView.resolveInitialTab()
    @State private var activeCameraSpotId: String = "enoshima_coast"
    @StateObject private var memoryStore = QuestMemoryStore()
    @StateObject private var friendStore = QuestFriendStore()
    @StateObject private var locationManager = QuestLocationManager()

    /// Camera中はタブバーを没入型に隠す。閉じるボタンと保存後の自動遷移で
    /// 操作性は維持したまま、下部でのタブバーとの衝突を構造的になくす。
    private var isTabBarVisible: Bool {
        selectedTab != .camera
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            activeScreen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppBackground())

            // Camera中は即座に消す。アニメーションを付けると、消えかけのタブバーと
            // 切り替わった直後のCamera UIが一瞬重なって「崩れ」に見えるため、
            // 表示・非表示そのものはアニメーションさせない(中身の押下演出は別途維持)。
            if isTabBarVisible {
                JQFloatingTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)
            }
        }
        .background(AppBackground())
        .environmentObject(memoryStore)
        .environmentObject(friendStore)
        .environmentObject(locationManager)
    }

    /// DEBUGビルド限定・目視QA専用の起動引数対応。
    /// `-pictriStartTab home|map|camera|memories` でSimulator起動時に
    /// 直接そのタブを開けるようにし、自動タップに頼らずスクリーンショットを取得できるようにする。
    /// Releaseビルドでは常にhomeから始まる(このstatic funcごと存在しない)。
    private static func resolveInitialTab() -> AppTab {
        #if DEBUG
        configureDevUnlockFromLaunchArguments()

        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-pictriStartTab"),
              arguments.indices.contains(flagIndex + 1) else {
            return .home
        }

        switch arguments[flagIndex + 1] {
        case "home": return .home
        case "map": return .map
        case "camera": return .camera
        case "memories": return .memories
        default: return .home
        }
        #else
        return .home
        #endif
    }

    #if DEBUG
    /// `-pictriDevUnlock true` でCameraの「撮影可能」状態を自動スクショ確認できるようにする。
    /// 既存のCamera内DEBUGトグルと同じ `@AppStorage("developerUnlockMode")` キーに書き込むだけなので、
    /// 挙動は「起動時に手動トグルを事前にオンにしておく」のと完全に同じ(=QA後は手動でオフにする想定)。
    private static func configureDevUnlockFromLaunchArguments() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-pictriDevUnlock"),
              arguments.indices.contains(flagIndex + 1) else {
            return
        }

        if arguments[flagIndex + 1].lowercased() == "true" {
            UserDefaults.standard.set(true, forKey: "developerUnlockMode")
        }
    }
    #endif

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

    private var isCameraTab: Bool { tab == .camera }

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: tab.iconName)
                .font(.system(size: isCameraTab ? 24 : 22, weight: .bold))
                .symbolRenderingMode(.hierarchical)

            Text(tab.title)
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(foregroundStyle)
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(isCameraTab ? PictriTheme.accent : .white)
                    .shadow(color: (isCameraTab ? PictriTheme.accent : .white).opacity(0.24), radius: 10, x: 0, y: 0)
            } else {
                Color.clear
            }
        }
        .contentShape(Rectangle())
    }

    private var foregroundStyle: Color {
        if isSelected {
            return .black
        }
        return isCameraTab ? PictriTheme.accent.opacity(0.85) : .white.opacity(0.78)
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
    static let panelHeight: CGFloat = 430
    static let panelCornerRadius: CGFloat = 34
    static let bottomBarReserve: CGFloat = 116
}

// MARK: - Shared

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                PictriTheme.backgroundTop,
                PictriTheme.backgroundBottom
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
