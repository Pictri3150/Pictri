import SwiftUI
import Combine

// MARK: - Pictri Appearance (Visual Direction Consolidation)
//
// ユーザーがDark/Lightを選べるようにするための、アプリ全体で共有する最小構成。
// 「Dark = 黒い高級写真集、Light = 白い高級写真集」という同一Design DNAの2面。
//
// 保存はUserDefaultsのみ(新しいpersistence layerを増やさない)。既存の
// QuestMemoryStore等とは無関係の、純粋な表示設定。

enum PictriAppearanceMode: String, CaseIterable {
    case dark
    case light

    var label: String {
        switch self {
        case .dark: return "ダーク"
        case .light: return "ライト"
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .dark: return .dark
        case .light: return .light
        }
    }
}

/// アプリ全体で1つだけ生成し(`ContentView`)、`.environmentObject`で配布する。
/// `PictriDarkTheme`(PictriDarkPremiumTheme.swift)の各tokenはこの
/// `PictriAppearanceStore.shared.mode`を読んで値を切り替える。ViewはこのStoreを
/// `@EnvironmentObject`として購読するだけで、appearance変更時に自動再描画される。
final class PictriAppearanceStore: ObservableObject {
    private static let storageKey = "pictriAppearanceMode"

    /// `PictriDarkTheme`等、View階層の外(static computed property)からも参照できるよう、
    /// 現在のmodeをsharedな場所にも保持する。Source of TruthはこのStoreのインスタンスのみ
    /// (sharedは「今どのmodeか」を読むための窓口であり、書き込みは常にこのStore経由)。
    static var current: PictriAppearanceMode {
        if let raw = UserDefaults.standard.string(forKey: storageKey),
           let mode = PictriAppearanceMode(rawValue: raw) {
            return mode
        }
        return .dark
    }

    @Published var mode: PictriAppearanceMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: Self.storageKey)
        }
    }

    init() {
        #if DEBUG
        if let override = PictriVisualReview.appearanceOverride {
            UserDefaults.standard.set(override.rawValue, forKey: Self.storageKey)
            self.mode = override
            return
        }
        #endif
        self.mode = Self.current
    }

    func toggle() {
        mode = (mode == .dark) ? .light : .dark
    }
}
