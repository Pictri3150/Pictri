import Foundation
import SwiftUI

// MARK: - Pictri Home Carousel Layout Metrics(v16 DETERMINISTIC ENGINE)
//
// 目的: Hero/Side Cardのgeometry計算(幅・高さ・間隔・scale・rotation・
// anchor・zIndex)を、View本体(PictriHomeCarousel.swift)から完全に分離し、
// 副作用のない純粋なSwift型へ集約する。
//
// v16: v15までは`continuousPage`をScrollViewの`onScrollGeometryChange`
// (`visibleRect.midX`)から求めていたが、実機/Simulator計測の結果、
// `scrollTargetLayout` + `.viewAligned`という組み合わせでは、この値が
// ScrollViewが実際に中央表示しているvirtualIndexと一致しないことが
// 判明した(詳細は`PictriCarouselRenderState.swift`冒頭コメント参照)。
// 今回`renderState`はScrollViewの値を一切受け取らず、
// `PictriCircularCarouselEngine.relativePosition(virtualIndex:
// centerVirtualIndex:dragTranslation:itemStep:)`だけを入力とする。
struct PictriHomeCarouselLayoutMetrics: Equatable {
    /// Carousel自身のGeometryReaderで実測した、画面に実際に描画されている
    /// viewportの横幅。
    let viewportWidth: CGFloat
    /// Hero Cardの最終表示幅が`viewportWidth`に対して占める比率。
    var cardWidthRatio: CGFloat = PictriHomeCarouselLayoutMetrics.defaultCardWidthRatio
    /// HeroとSideの最終的なgap(pt)。
    var sideGap: CGFloat = PictriHomeCarouselLayoutMetrics.defaultSideGap
    /// Hero写真自体の縦横比(実測値、Reference由来)。
    var cardAspect: CGFloat = PictriHomeCarouselLayoutMetrics.defaultCardAspect
    /// cardHeightの算出だけに使う専用比率。
    var heroHeightLockWidthRatio: CGFloat = PictriHomeCarouselLayoutMetrics.defaultHeroHeightLockWidthRatio
    /// 端末ごとの安全上限(HomeView側で算出済みの値をそのまま受け取る)。
    var heroMaxHeight: CGFloat = .greatestFiniteMagnitude

    // v1.5 REFERENCE FIDELITY: 新Reference(imagepictrinew2.png、850×1850canvas、
    // iPhone 17 Pro相当)を実測。Hero bbox実測値(left88/right754/top358/bottom1382px)
    // からcardWidth比 = (754-88)/850 ≈ 0.784(旧0.72から+8.9%)、side gap実測
    // (Hero右端〜右Side左端 ≈44px、canvas→pt換算 ×402/850)≈20.8pt(旧12ptから拡大)。
    // cardAspect/heroHeightLockWidthRatioは実測結果が現行値(±2%程度)と近く、
    // 「明確なズレ」に該当しないため据え置き(Freeze対象ではないが今回は不要と判断)。
    static let defaultCardWidthRatio: CGFloat = 0.78
    static let defaultSideGap: CGFloat = 20
    static let defaultCardAspect: CGFloat = 0.517
    static let defaultHeroHeightLockWidthRatio: CGFloat = 0.600

    // CAMERA / POST IMAGING ROUND「PART 1 — 縦だけ若干大きく」。widthの算出
    // (cardWidth = viewportWidth * cardWidthRatio)には一切触れず、heightの
    // 算出だけに掛ける倍率。値はSimulator実測比較(+4%/+6%/+8%)を経て決定
    // (最終値・比較結果はscratchpad/camera_imaging_round/03_POST_GEOMETRY.txt
    // 参照)。この値はCameraView.swift/PictriCameraStyle.swiftの表示比率にも
    // 同じ倍率でリテラル反映している(Home本体ファイルは不変・値だけをCamera
    // 側で再現、という既存の方針を維持)。
    static let heroHeightBoost: CGFloat = 1.06

    /// Side Cardの最大回転角(度)。
    static let maxRotationDegrees: Double = 15
    /// rotation3DEffectのperspective。
    static let perspective: CGFloat = 0.22
    /// Side Cardのscale下限に対応するfalloff。1.0 - falloff = 0.93。
    static let sideScaleFalloff: CGFloat = 0.07
    static let sideOpacityFalloff: CGFloat = 0.22

    var cardWidth: CGFloat {
        guard viewportWidth.isFinite, viewportWidth > 0 else { return 0 }
        return viewportWidth * cardWidthRatio
    }

    private var heroHeightLockWidth: CGFloat {
        guard viewportWidth.isFinite, viewportWidth > 0 else { return 0 }
        return viewportWidth * heroHeightLockWidthRatio
    }

    var cardHeight: CGFloat {
        guard cardAspect > 0 else { return 0 }
        let byWidth = heroHeightLockWidth / cardAspect
        guard byWidth.isFinite else { return 0 }
        // CAMERA / POST IMAGING ROUND「PART 1 — 縦だけ若干大きく」。実機計測の
        // 結果、この端末クラスでは`byWidth`(aspect由来の理論値)ではなく
        // `heroMaxHeight`(HomeView側のheroCap、pageArea.size.heightの72%)が
        // 実際の表示heightを決めるconstraintになっていた
        // (byWidth=466.5pt、実測cardHeight=408.3pt=heroMaxHeightと一致)。
        // widthはcardWidthRatio経由のみで決まり(ここでは一切変更しない)、
        // heightだけを「どちらが効いていたとしても」確実に持ち上げるため、
        // aspect側/cap側どちらの項にも先掛けせず、min()で最終的に確定した
        // 値そのものに対してheroHeightBoostを掛ける(単一のsource of truthで
        // 「最終表示heightをX%持ち上げる」という意図をそのまま表現できる)。
        return min(byWidth, heroMaxHeight) * Self.heroHeightBoost
    }

    /// 中央カードの中心から、隣のカードの中心までの距離(pt)。
    var itemStep: CGFloat { max(cardWidth + sideGap, 1) }

    /// viewportの水平中央(Hero centerXの目標値)。
    var viewportCenterX: CGFloat { viewportWidth / 2 }

    private static let zIndexBase: Double = 10_000
    private static let zIndexDistanceWeight: Double = 100
    /// 完全な同値を避けるための、virtualIndexベースの極小tie-break。
    private static let zIndexTieBreakStep: Double = 0.0001
    /// Heroへ必ず加算するbonus。浮動小数点誤差の大きさに関係なく、
    /// 「Hero判定(side)」と「zIndex最大」が常に同じcardを指すことを保証する
    /// (v15 Phase 7自己検証で発見した、tie-break stepが近接距離差を
    /// 上回ってしまう問題への対策を継続採用)。
    private static let zIndexHeroBonus: Double = 1
    /// drag進行方向に近づいているSide Cardへわずかに加算する(cosmetic)。
    /// Hero判定そのものには影響しない(zIndexHeroBonusが優先される)。
    private static let zIndexIncomingBonus: Double = 0.01

    /// 1枚のcardの最終描画状態をまとめて返す。scale・rotation・opacity・
    /// zIndex・Hero/Side判定・画面上のx座標を、すべて`centerVirtualIndex`と
    /// `dragTranslation`(=`PictriCircularCarouselEngine`が扱う共有state)
    /// だけから導出する。ScrollViewのcontentOffset/visibleRectは一切
    /// 参照しない。
    func renderState(virtualIndex: Int, centerVirtualIndex: Int, dragTranslation: CGFloat, reduceMotion: Bool) -> PictriCarouselRenderState {
        let step = itemStep
        let rawRelative = PictriCircularCarouselEngine.relativePosition(
            virtualIndex: virtualIndex,
            centerVirtualIndex: centerVirtualIndex,
            dragTranslation: dragTranslation,
            itemStep: step
        )
        let relativePosition = rawRelative.isFinite ? rawRelative : CGFloat(virtualIndex - centerVirtualIndex)
        let nearestIndex = PictriCircularCarouselEngine.nearestVirtualIndex(
            centerVirtualIndex: centerVirtualIndex,
            dragTranslation: dragTranslation,
            itemStep: step
        )

        let absoluteDistance = abs(relativePosition)
        let visualMagnitude = min(absoluteDistance, 1.0)

        let scale = 1.0 - visualMagnitude * Self.sideScaleFalloff
        let opacity = 1.0 - visualMagnitude * Self.sideOpacityFalloff

        let clampedForRotation = min(max(relativePosition, -1.0), 1.0)
        let rotation = reduceMotion ? 0 : Double(clampedForRotation) * Self.maxRotationDegrees

        // Hero側の辺をanchorにする: 中央より右(relativePosition > 0)のcardは
        // 自分の左辺(.leading)がHero側、中央より左のcardは自分の右辺
        // (.trailing)がHero側。relativePosition == 0(Hero自身)は
        // scale=1/rotation=0のためanchorは結果に影響しない。
        let anchor: UnitPoint
        if relativePosition > 0 {
            anchor = .leading
        } else if relativePosition < 0 {
            anchor = .trailing
        } else {
            anchor = .center
        }

        let isHero = virtualIndex == nearestIndex
        let side: PictriCarouselSide
        if isHero {
            side = .hero
        } else if relativePosition > 0 {
            side = .right
        } else {
            side = .left
        }

        var incomingBonus: Double = 0
        if dragTranslation < 0, side == .right {
            incomingBonus = Self.zIndexIncomingBonus * Double(max(0, 1 - min(absoluteDistance, 1)))
        } else if dragTranslation > 0, side == .left {
            incomingBonus = Self.zIndexIncomingBonus * Double(max(0, 1 - min(absoluteDistance, 1)))
        }

        let zIndex = Self.zIndexBase
            - Double(absoluteDistance) * Self.zIndexDistanceWeight
            + (isHero ? Self.zIndexHeroBonus : 0)
            + incomingBonus
            + Double(virtualIndex) * Self.zIndexTieBreakStep

        let cardCenterX = viewportCenterX + relativePosition * step

        return PictriCarouselRenderState(
            virtualIndex: virtualIndex,
            relativePosition: relativePosition,
            absoluteDistance: absoluteDistance,
            side: side,
            isVisualHero: isHero,
            zIndex: zIndex,
            scale: scale,
            opacity: opacity,
            rotationDegrees: rotation,
            rotationAnchor: anchor,
            cardCenterX: cardCenterX
        )
    }
}
