import SwiftUI
import CoreGraphics

// MARK: - Color Journey Models
//
// "色づく旅帳"プロトタイプ専用のモデル群。本番のQuestSpot/QuestPrefecture等とは
// 意図的に型を分離する(依存を混ぜすぎないため)。地名・実在スポットの「事実」は
// PreviewSupport側で既存mockQuestSpots/questPrefectureShapesから読み取って
// 詰め替えるだけで、この型自体は本番モデルに依存しない。

/// Map画面・SpotDetail画面で使う、1スポット分の表示データ。
struct CJSpotDetail: Identifiable {
    let id: String
    let name: String
    let areaName: String
    let latinSlug: String
    let distanceText: String
    let isVisited: Bool
}

/// Home画面の「旅の断片」フィード1件分。
/// 本番のQuestFeedPost/HomeLargePostCardとは別物として扱う
/// (SNS投稿カードの模倣ではなく「友達から旅の断片が届く」体験を作るための型)。
struct CJTravelFragment: Identifiable {
    let id: String
    let username: String
    let placeName: String
    let areaName: String
    let stateText: String
    let accentColor: Color
    let likeCount: Int
}

/// Map overview 1県分の色づき状態。
/// pointsは既存questPrefectureShapesの座標をそのまま借りる(地理的な事実の再利用)。
struct CJPrefectureColorState: Identifiable {
    let id: String
    let name: String
    let points: [CGPoint]
    /// nilは「まだ色づいていない」を表す。
    let accentColor: Color?
}

/// Map overview下部に1件だけ出す「次に色づけられる場所」。
struct CJNextColorTarget {
    let prefectureName: String
    let spotName: String
    let areaName: String
}
