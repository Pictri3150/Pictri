import SwiftUI

@main
struct JapanQuestApp: App {
    var body: some Scene {
        WindowGroup {
            rootView
        }
    }

    /// `-pictriPrototypeScreen`未指定時は常にContentView()のみ(本番と完全に同じ挙動)。
    /// "色づく旅帳"コンセプトプロトタイプ確認用にDEBUGビルド限定で分岐を追加しているが、
    /// 既存のHome/Map/SpotDetail等の本番画面ツリーは一切変更していない。
    @ViewBuilder
    private var rootView: some View {
        #if DEBUG
        if let screen = ColorJourneyLaunchArgs.requestedScreen {
            ColorJourneyPrototypeRootView(screen: screen)
        } else {
            ContentView()
        }
        #else
        ContentView()
        #endif
    }
}
