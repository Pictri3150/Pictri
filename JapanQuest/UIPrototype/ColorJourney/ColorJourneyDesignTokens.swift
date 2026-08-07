import SwiftUI

// MARK: - Color Journey Design Tokens
//
// "色づく旅帳"コンセプトプロトタイプ専用のデザイントークン。
// 既存のPictriTheme/PictriLightTheme(白カード中心の本番デザインシステム)とは
// 意図的に分離する。プロトタイプの目的は「本番と違う体験の当たりを取る」ことなので、
// ここで本番の色・角丸トークンを流用すると、評価対象が結局本番と同じ見た目に
// 寄ってしまい比較にならない。
//
// 座標データ(questPrefectureShapes等)のような「地理的な事実」は
// PreviewSupport/ColorJourneyPreviewData.swift 経由で本番から読み取り専用で借りるが、
// 色・角丸・余白・書体の思想はこのファイルだけで完結させる。
//
// このファイル自体は本番の型を一切importせず、SwiftUIのみに依存する。

enum CJTokens {

    enum Color {
        static let backgroundWarm = hex(0xF7F4EE)
        static let surface = hex(0xFFFFFF)
        static let textPrimary = hex(0x242321)
        static let textSecondary = hex(0x77736D)
        static let coral = hex(0xE97863)
        static let mutedGreen = hex(0x7FA38F)
        static let softAmber = hex(0xDEAE59)
        static let lavender = hex(0xA99BC4)
        static let sand = hex(0xD9C8AA)
        static let borderSoft = hex(0xE8E1D7)

        /// 訪問済み県の色づけに使う、意味を持たせた配色ローテーション。
        /// ランダムではなく、県idの決定論的なハッシュで安定して同じ色を割り当てる
        /// (呼び出し側はColorJourneyPreviewData.paletteIndex(for:)を使う)。
        static let visitedPalette: [SwiftUI.Color] = [mutedGreen, softAmber, coral, lavender]

        private static func hex(_ value: UInt32) -> SwiftUI.Color {
            SwiftUI.Color(
                red: Double((value >> 16) & 0xFF) / 255,
                green: Double((value >> 8) & 0xFF) / 255,
                blue: Double(value & 0xFF) / 255
            )
        }
    }

    enum Radius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }

    enum Spacing {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 12
        static let md: CGFloat = 20
        static let lg: CGFloat = 28
        static let xl: CGFloat = 40
    }

    enum Typography {
        static let wordmark = Font.system(size: 16, weight: .bold, design: .rounded)
        static let screenLabel = Font.system(size: 12, weight: .semibold)
        static let placeName = Font.system(size: 26, weight: .heavy)
        static let placeNameLarge = Font.system(size: 34, weight: .heavy)
        static let body = Font.system(size: 14, weight: .medium)
        static let caption = Font.system(size: 12, weight: .medium)
        static let stateLine = Font.system(size: 13, weight: .semibold)
        static let cta = Font.system(size: 16, weight: .bold)
    }
}
