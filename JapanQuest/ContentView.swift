import SwiftUI
import CoreLocation
import Combine

#if DEBUG
/// DEBUGビルド限定・目視QA専用の起動引数を1箇所にまとめたもの。
/// 各画面(Map / Camera / Memories)はここだけを見ればよく、
/// `ProcessInfo.processInfo.arguments` を各ファイルで個別にパースしない。
/// Releaseビルドではこの型ごと存在しないため、本番機能として誤って残る心配がない。
enum PictriVisualReview {
    private static var arguments: [String] { ProcessInfo.processInfo.arguments }

    private static func value(for flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    static var startTab: AppTab? {
        switch value(for: "-pictriStartTab") {
        case "home": return .home
        case "map": return .map
        case "camera": return .camera
        case "memories": return .memories
        default: return nil
        }
    }

    /// `-pictriDevUnlock true|false` で developerUnlockMode を明示的に上書きする。
    /// 引数なし(nil)の場合は既存値をそのまま維持する。
    static var devUnlockOverride: Bool? {
        switch value(for: "-pictriDevUnlock")?.lowercased() {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }

    static var memoriesMode: MemoriesViewMode? {
        switch value(for: "-pictriMemoriesMode") {
        case "explore": return .explore
        case "collect": return .collect
        default: return nil
        }
    }

    static var mapSpotId: String? {
        value(for: "-pictriMapSpot")
    }

    /// `-pictriExploreDetail <spotId>` でExplore detail sheetを直接開けるようにする。DEBUG限定。
    static var exploreDetailSpotId: String? {
        value(for: "-pictriExploreDetail")
    }

    /// `-pictriHomeCommentsOpen <postId>` でHomeの指定投稿カードのコメント欄を
    /// 開いた状態で直接スクショ確認できるようにする。DEBUG限定。
    static var homeCommentsOpenPostId: String? {
        value(for: "-pictriHomeCommentsOpen")
    }

    /// `-pictriHomeProfile <username>` でHomeの指定ユーザーのFriendProfileSheetを
    /// 直接開いてスクショ確認できるようにする。DEBUG限定。
    static var homeProfileUsername: String? {
        value(for: "-pictriHomeProfile")
    }

    /// `-pictriColorScenario multiPrefecture` で、未訪問/一部訪問/全達成の3状態を
    /// 複数県で同時にプレビューできるようにする。DEBUG限定。
    /// memoryStore/UserDefaultsへは一切書き込まず、表示上のcompletedCountだけを
    /// 差し替える(PrefectureMemorySummaryCard / prefectureChipsの2箇所のみが参照)。
    /// 数値は各県のtotalSpotCount(kanagawa:24 / tokyo:30 / kyoto:28)の範囲内で
    /// 安全に選んでいる。kyotoはtotalSpotCountと一致させ「全達成」状態を再現する。
    static var prefectureCountOverrides: [String: Int]? {
        guard value(for: "-pictriColorScenario") == "multiPrefecture" else { return nil }
        return [
            "kanagawa": 9,
            "tokyo": 3,
            "kyoto": 28
        ]
    }

    static func prefectureCountOverride(for prefectureId: String) -> Int? {
        prefectureCountOverrides?[prefectureId]
    }

    /// `-pictriAccountSection profile|friends|add|requests` でJQAccountSheetViewを
    /// 指定タブを開いた状態で直接起動できるようにする。DEBUG限定。
    /// 「友達コード」カード(addタブ)など、通常操作では複数タップが必要な領域を
    /// スクショ確認するために追加した。既存のアカウントアイコンタップ導線は無変更。
    static var homeAccountSection: JQAccountSection? {
        switch value(for: "-pictriAccountSection") {
        case "profile": return .profile
        case "friends": return .friends
        case "add": return .add
        case "requests": return .requests
        default: return nil
        }
    }

    static var cameraScenario: PictriCameraVisualScenario? {
        switch value(for: "-pictriCameraScenario") {
        case "ready": return .ready
        case "review": return .review
        case "saved": return .saved
        default: return nil
        }
    }

    /// `-pictriShowCameraDebugControls true` の時だけ、Camera上部にQA用の
    /// developerUnlockModeトグルを表示する。通常のCamera UIには常に隠し、
    /// 見せる用のスクショに機械的なトグルが写り込まないようにする。
    /// 位置認証の解放そのものは引き続き `-pictriDevUnlock true/false` で行える。
    static var showCameraDebugControls: Bool {
        value(for: "-pictriShowCameraDebugControls") == "true"
    }
}

enum PictriCameraVisualScenario: Equatable {
    case ready
    case review
    case saved
}
#endif

struct ContentView: View {
    @State private var selectedTab: AppTab = ContentView.resolveInitialTab()
    @State private var activeCameraSpotId: String = "enoshima_coast"
    /// Camera保存直後に「メモリーで確認する」から遷移した時だけ使う一時的な受け渡し。
    /// MemoriesViewはこれを見て、保存した記憶をExplore Detailで直接開く。
    /// 通常のタブバー操作では常にnilのままなので、既存のCollect/Explore遷移には影響しない。
    @State private var pendingExploreSpotId: String?
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
        if let devUnlockOverride = PictriVisualReview.devUnlockOverride {
            UserDefaults.standard.set(devUnlockOverride, forKey: "developerUnlockMode")
        }
        return PictriVisualReview.startTab ?? .home
        #else
        return .home
        #endif
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
                selectedSpotId: $activeCameraSpotId,
                pendingExploreSpotId: $pendingExploreSpotId
            )

        case .memories:
            MemoriesView(pendingExploreSpotId: $pendingExploreSpotId)
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
