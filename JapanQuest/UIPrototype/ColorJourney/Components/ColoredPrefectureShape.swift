import SwiftUI
import CoreGraphics

// MARK: - Colored Prefecture Shapes
//
// 都道府県ポリゴンを描画する2種類のShape。本番のQuestScaledShapePath(MapView.swift内、
// private)とは独立した実装であり、プロトタイプはPictriDesignSystem/MapView側の
// 型に一切依存しない。座標データ(points)だけを既存questPrefectureShapesから
// 読み取り専用で借りる。

/// 単体の県ポリゴンを、渡されたrectへ自動フィットさせて描画する。
/// Home画面の帯やSpotDetailの背景アクセントのように、1つの県だけを
/// 単独で見せたい場面で使う(全体地図の位置関係は無視して、その県の形だけを主役にする)。
struct ColoredPrefectureShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }

        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else {
            return path
        }

        let width = max(maxX - minX, 1)
        let height = max(maxY - minY, 1)
        let scale = min(rect.width / width, rect.height / height)
        let offsetX = rect.minX + (rect.width - width * scale) / 2 - minX * scale
        let offsetY = rect.minY + (rect.height - height * scale) / 2 - minY * scale

        func transformed(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x * scale + offsetX, y: point.y * scale + offsetY)
        }

        path.move(to: transformed(first))
        for point in points.dropFirst() {
            path.addLine(to: transformed(point))
        }
        path.closeSubpath()
        return path
    }
}

/// 47県すべてを1枚の日本地図として正しい位置関係で合成するための、
/// 共有スケール/オフセット指定版。Map overviewのように複数県を同じキャンバス上に
/// 並べて描く場面では、県ごとに個別フィットするColoredPrefectureShapeは使えない
/// (バラバラな縮尺になり地図として破綻するため)、必ずこちらを使う。
struct ColoredPrefectureCanvasShape: Shape {
    let points: [CGPoint]
    var scale: CGFloat
    var offsetX: CGFloat
    var offsetY: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }

        func transformed(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x * scale + offsetX, y: point.y * scale + offsetY)
        }

        path.move(to: transformed(first))
        for point in points.dropFirst() {
            path.addLine(to: transformed(point))
        }
        path.closeSubpath()
        return path
    }
}
