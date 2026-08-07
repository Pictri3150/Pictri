import SwiftUI

// MARK: - Color Journey Prototype Root
//
// "色づく旅帳"コンセプトプロトタイプの入口。既存ContentView/HomeView/MapView/
// QuestSpotDetailView等の本番画面ツリーには一切依存せず、完全に独立した4画面を
// 切り替えるだけの薄いルート。本番の`-pictriStartTab`等の起動引数とは別名の
// `-pictriPrototypeScreen`を使うため、既存のQA導線と混ざらない。

struct ColorJourneyPrototypeRootView: View {
    let screen: ColorJourneyPrototypeScreen

    var body: some View {
        switch screen {
        case .home:
            ColorJourneyHomeView()

        case .map:
            ColorJourneyMapView(
                prefectureStates: ColorJourneyPreviewData.allPrefectureColorStates,
                nextTarget: ColorJourneyPreviewData.nextColorTarget
            )

        case .spotUnvisited:
            ColorJourneySpotDetailView(
                spot: ColorJourneyPreviewData.spotDetail(id: "senshu_university_ikuta", isVisited: false)
            )

        case .spotVisited:
            ColorJourneySpotDetailView(
                spot: ColorJourneyPreviewData.spotDetail(id: "senshu_university_ikuta", isVisited: true)
            )

        case .flow:
            // 「地図から場所を選ぶ→現地で写真を残す→場所と地図が色づく」を1本の操作で
            // 確認できるインタラクティブフロー。上の4ケースはすべて静的単体表示のまま
            // 変更しておらず、flowは既存のColorJourneyFlowViewへ委譲するだけ。
            // -pictriPrototypeStepが渡された場合のみ、その中間状態で自動遷移を止めて
            // 静止させる(スクリーンショット用)。未指定時は通常通り.mapUnvisitedから
            // タップ操作で進む通常フローになる。
            ColorJourneyFlowView(debugInitialStep: ColorJourneyLaunchArgs.requestedFlowStep)
        }
    }
}

enum ColorJourneyPrototypeScreen: String {
    case home
    case map
    case spotUnvisited
    case spotVisited
    case flow
}

#if DEBUG
/// DEBUGビルド限定・プロトタイプ確認専用の起動引数パーサー。
/// 本番のPictriVisualReview(ContentView.swift)とは独立させ、依存を混ぜない。
enum ColorJourneyLaunchArgs {
    private static var arguments: [String] { ProcessInfo.processInfo.arguments }

    private static func value(for flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    /// `-pictriPrototypeScreen home|map|spotUnvisited|spotVisited|flow` が渡された場合のみ
    /// プロトタイプへ入る。未指定時はnilを返し、既存の本番起動(ContentView)を維持する。
    static var requestedScreen: ColorJourneyPrototypeScreen? {
        value(for: "-pictriPrototypeScreen").flatMap(ColorJourneyPrototypeScreen.init(rawValue:))
    }

    /// `-pictriPrototypeStep <rawValue>` (例: mapSelected, captureReady, spotVisited等)。
    /// flow画面限定のQA用で、指定されたstepへ直接シークし、Store.isDebugFrozenにより
    /// 自動遷移を止めて静止表示する。未指定または無効な文字列の場合はnilを返し、
    /// (このプロパティを消費するColorJourneyPrototypeRootView側で)通常の
    /// .mapUnvisitedからのインタラクティブフローにフォールバックする。無効な値でも
    /// クラッシュしない(Step(rawValue:)がOptionalを返すだけ)。
    static var requestedFlowStep: ColorJourneyPrototypeStore.Step? {
        value(for: "-pictriPrototypeStep").flatMap(ColorJourneyPrototypeStore.Step.init(rawValue:))
    }
}
#endif

#Preview("Prototype Root - Home") {
    ColorJourneyPrototypeRootView(screen: .home)
}

#Preview("Prototype Root - Map") {
    ColorJourneyPrototypeRootView(screen: .map)
}

#Preview("Prototype Root - Spot Unvisited") {
    ColorJourneyPrototypeRootView(screen: .spotUnvisited)
}

#Preview("Prototype Root - Spot Visited") {
    ColorJourneyPrototypeRootView(screen: .spotVisited)
}

#Preview("Prototype Root - Flow") {
    ColorJourneyPrototypeRootView(screen: .flow)
}
