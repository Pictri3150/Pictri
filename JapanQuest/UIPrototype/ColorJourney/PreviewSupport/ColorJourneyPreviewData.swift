import SwiftUI
import CoreGraphics

// MARK: - Color Journey Preview Data
//
// "色づく旅帳"プロトタイプ専用のモック/プレビュー用データ。
// 地名・実在スポットの「事実」だけは既存の本番データ(questPrefectureShapes/mockQuestSpots、
// どちらもモジュール内グローバル定数)から読み取り専用で借りる。これらの定数自体は
// 一切変更しない。色・文言などプロトタイプ独自の演出はすべてこのファイル内で完結する。

enum ColorJourneyPreviewData {

    static var kanagawaShapePoints: [CGPoint] {
        questPrefectureShapes.first(where: { $0.id == "kanagawa" })?.points ?? []
    }

    /// Map overviewで色づけて見せる県の状態。神奈川=一番色濃く(完了に近い)、
    /// 東京=軽く色づき始め、それ以外=まだ、という3段階でナラティブを作る。
    static var allPrefectureColorStates: [CJPrefectureColorState] {
        questPrefectureShapes.map { shape in
            let accent: Color?
            switch shape.id {
            case "kanagawa": accent = CJTokens.Color.mutedGreen
            case "tokyo": accent = CJTokens.Color.softAmber
            default: accent = nil
            }
            return CJPrefectureColorState(
                id: shape.id,
                name: shape.name,
                points: shape.points,
                accentColor: accent
            )
        }
    }

    /// インタラクティブフロー(ColorJourneyFlowView)専用。神奈川の色づき状態を
    /// 実際の訪問結果(kanagawaVisited)に連動させる。既存のallPrefectureColorStates
    /// (常に神奈川が色づいている静的デモ用)はそのまま残し、この関数は新規追加のみ。
    static func prefectureColorStates(kanagawaVisited: Bool) -> [CJPrefectureColorState] {
        questPrefectureShapes.map { shape in
            let accent: Color?
            switch shape.id {
            case "kanagawa": accent = kanagawaVisited ? CJTokens.Color.mutedGreen : nil
            case "tokyo": accent = CJTokens.Color.softAmber
            default: accent = nil
            }
            return CJPrefectureColorState(
                id: shape.id,
                name: shape.name,
                points: shape.points,
                accentColor: accent
            )
        }
    }

    static var nextColorTarget: CJNextColorTarget {
        CJNextColorTarget(
            prefectureName: "神奈川",
            spotName: "専修大学",
            areaName: "生田"
        )
    }

    /// SpotDetail用の1件。本番mockQuestSpotsに一致するidがあれば実際の地名を借り、
    /// 無ければ最低限のフォールバック値を使う(プロトタイプがmockQuestSpotsの
    /// 将来的な変更に対して壊れないようにするための安全弁)。
    static func spotDetail(id: String, isVisited: Bool) -> CJSpotDetail {
        guard let match = mockQuestSpots.first(where: { $0.id == id }) else {
            return CJSpotDetail(
                id: id,
                name: "専修大学",
                areaName: "生田",
                latinSlug: "senshu",
                distanceText: "320m",
                isVisited: isVisited
            )
        }
        return CJSpotDetail(
            id: match.id,
            name: match.name,
            areaName: match.areaName,
            latinSlug: match.englishName.lowercased(),
            distanceText: "320m",
            isVisited: isVisited
        )
    }

    static var travelFragments: [CJTravelFragment] {
        [
            CJTravelFragment(
                id: "fragment_enoshima",
                username: "haruka",
                placeName: "江の島海岸",
                areaName: "湘南・神奈川",
                stateText: "海沿いで少し歩いた",
                accentColor: CJTokens.Color.mutedGreen,
                likeCount: 6
            ),
            CJTravelFragment(
                id: "fragment_yamashita",
                username: "sota",
                placeName: "山下公園",
                areaName: "横浜・神奈川",
                stateText: "夕方の風が気持ちよかった",
                accentColor: CJTokens.Color.softAmber,
                likeCount: 3
            )
        ]
    }
}
