import Foundation
import CoreGraphics
import SwiftUI

// MARK: - Pictri Circular Carousel — Render State(v16 DETERMINISTIC ENGINE)
//
// v15までの重大バグ(中央投稿がSide投稿の背面へ落ちる)は、`zIndex`を
// `ScrollView`の`onScrollGeometryChange`(`visibleRect.midX`)から求めた
// `continuousPage`という値から算出していたことに起因していた。実機/
// Simulator双方で計測した結果、`scrollTargetLayout` + `.viewAligned` +
// 大きく複製されたCircular List(virtual item)という組み合わせでは、
// `visibleRect.midX`が実際に画面中央へ来ているvirtualIndexと**一致しない**
// (計測値: `continuousPage`が9.25の時、実際に中央へ表示されていたのは
// virtualIndex 19〜20 — ScrollViewの`viewAligned`が内部的にどのcontent
// 座標へjumpしたかを、`visibleRect`だけから逆算することができない)ことが
// 判明した。今回は`ScrollView`のcontentOffset/visibleRectに一切依存せず、
// `centerVirtualIndex`(Int、確定した「今どのvirtual itemが中央か」)と
// `dragTranslation`(CGFloat、`DragGesture`から直接得る値)だけを入力とする
// 決定論的な`PictriCircularCarouselEngine`に置き換えた。
//
// この型はその決定論的な計算の**結果**を保持する、副作用のない値型。
// scale・rotation・opacity・zIndex・Hero/Side判定・画面上のx座標の
// すべてがこの1つの型に集約されており、Viewの各modifierは必ずこの型の
// フィールドを参照するだけにする(基準の混在を構造的に禁止する)。

/// 中央から見て、そのcardが左右どちらにあるか(Hero自身は`.hero`)。
enum PictriCarouselSide: Equatable {
    case hero
    case left
    case right
}

struct PictriCarouselRenderState: Equatable {
    var virtualIndex: Int
    /// (virtualIndex - centerVirtualIndex) + dragTranslation/itemStep。
    /// 0.0 = 画面中央、-1.0 = 左Side、+1.0 = 右Side。ScrollViewのcontentOffset
    /// を一切経由しない、`centerVirtualIndex`と`dragTranslation`だけから
    /// 求めた値(`PictriCircularCarouselEngine.relativePosition`参照)。
    var relativePosition: CGFloat
    /// |relativePosition|。clampなし(zIndex/Hero判定用)。
    var absoluteDistance: CGFloat
    var side: PictriCarouselSide
    /// side == .heroのショートハンド。
    var isVisualHero: Bool
    var zIndex: Double
    var scale: CGFloat
    var opacity: Double
    var rotationDegrees: Double
    var rotationAnchor: UnitPoint
    /// ZStack内でのこのcardの中心x座標(viewport座標系)。
    var cardCenterX: CGFloat
}
