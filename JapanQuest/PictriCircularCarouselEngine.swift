import Foundation
import CoreGraphics

// MARK: - Pictri Circular Carousel Engine(v16 DETERMINISTIC ENGINE)
//
// ScrollView(contentOffset/contentInsets/visibleRect)に一切依存しない、
// 副作用のない純粋な計算だけを集めた型。実機/Simulator計測で判明した
// 「`onScrollGeometryChange`のvisibleRect.midXが、ScrollViewが実際に
// centerしているvirtualIndexと一致しない」というバグクラス自体を、
// 入力からScrollViewを取り除くことで構造的に無くす。
//
// 単一の状態源:
// - `centerVirtualIndex`(Int) — 現在「中央」として確定しているvirtual item。
//   Drag中も、snapが完了するまでは変化しない。
// - `dragTranslation`(CGFloat) — `DragGesture.translation.width`由来の値
//   (snapアニメーション中は、そのアニメーションが動かす値)。
//
// 全カードの`relativePosition`はこの2つの値と、そのカード自身の固定
// `virtualIndex`だけから求まる。SwiftUIのViewとテスト(自己検証)は常に
// 同じこの関数を呼ぶため、「テストは通るが実画面は違う値を見ている」
// という状態不一致がそもそも発生し得ない。
enum PictriCircularCarouselEngine {
    /// centerVirtualIndexを中心に、前後何枚まで実際にViewを生成するか。
    /// パフォーマンスのための上限であり、drag 1回でcenterVirtualIndexが
    /// 動きうる最大幅(`maxPageDeltaPerGesture`)と同じにすることで、
    /// snapアニメーション中に必要なカードが常に事前マウント済みになる。
    static let visibleIndexRadius = 3
    /// 1回のgestureでcenterVirtualIndexを何ページ分動かすかの閾値
    /// (itemStepに対する比率)。
    static let snapThresholdRatio: CGFloat = 0.225
    /// 1回のgestureで動かせる最大ページ数(高速flickでも暴走しないための上限)。
    static let maxPageDeltaPerGesture = 3
    /// Circular wrapのための安全マージン(lap数)。centerVirtualIndexの
    /// lapがこのマージン以内まで端へ近づいたら、中央lapへrecenterする。
    static let recenterSafeMarginLaps = 3

    // MARK: - relativePosition

    /// 0.0 = 画面中央、-1.0 = 左Side、+1.0 = 右Side、-0.5/+0.5 = 中間。
    /// ScrollViewのcontentOffsetを一切経由しない — `centerVirtualIndex`と
    /// `DragGesture.translation`だけから算出する。
    static func relativePosition(virtualIndex: Int, centerVirtualIndex: Int, dragTranslation: CGFloat, itemStep: CGFloat) -> CGFloat {
        guard itemStep > 0, dragTranslation.isFinite else {
            return CGFloat(virtualIndex - centerVirtualIndex)
        }
        return CGFloat(virtualIndex - centerVirtualIndex) + dragTranslation / itemStep
    }

    /// 「今、画面中央に最も近い連続位置」。旧`continuousPage`と同じ意味を
    /// 持つが、ScrollViewのcontentOffsetではなく`centerVirtualIndex`と
    /// `dragTranslation`だけから求める。
    static func page(centerVirtualIndex: Int, dragTranslation: CGFloat, itemStep: CGFloat) -> CGFloat {
        guard itemStep > 0, dragTranslation.isFinite else { return CGFloat(centerVirtualIndex) }
        return CGFloat(centerVirtualIndex) - dragTranslation / itemStep
    }

    /// `page`に最も近いvirtualIndex(=Visual Hero)。四捨五入(ちょうど.5は
    /// 0から遠い方)で必ずちょうど1つのvirtualIndexだけがHeroと判定される。
    static func nearestVirtualIndex(centerVirtualIndex: Int, dragTranslation: CGFloat, itemStep: CGFloat) -> Int {
        let p = page(centerVirtualIndex: centerVirtualIndex, dragTranslation: dragTranslation, itemStep: itemStep)
        guard p.isFinite else { return centerVirtualIndex }
        return Int(p.rounded())
    }

    // MARK: - Rendering window

    /// 実際にViewを生成する範囲(centerVirtualIndexの前後`visibleIndexRadius`枚)。
    static func visibleVirtualIndexRange(centerVirtualIndex: Int) -> ClosedRange<Int> {
        (centerVirtualIndex - visibleIndexRadius)...(centerVirtualIndex + visibleIndexRadius)
    }

    // MARK: - Snap decision

    /// drag終了時、centerVirtualIndexをどれだけ進めるか(±1が基本、高速flick
    /// では最大±maxPageDeltaPerGeneration)。0 = 現在位置へ戻る。
    static func pageDelta(translation: CGFloat, predictedTranslation: CGFloat, itemStep: CGFloat) -> Int {
        guard itemStep > 0 else { return 0 }
        let effective = abs(predictedTranslation) > abs(translation) ? predictedTranslation : translation
        guard effective.isFinite else { return 0 }
        // 正のtranslation(右へ引く=前のcardが中央へ来る)は負のpageDelta、
        // 負のtranslation(左へ引く=次のcardが中央へ来る)は正のpageDelta。
        let normalized = -effective / itemStep
        guard abs(normalized) >= snapThresholdRatio else { return 0 }
        var delta = Int(normalized.rounded())
        if delta == 0 { delta = normalized > 0 ? 1 : -1 }
        return max(-maxPageDeltaPerGesture, min(maxPageDeltaPerGesture, delta))
    }

    // MARK: - Circular wrap / recenter

    /// centerVirtualIndexが端のlapへ近づいたら、**同じsource item**を指す
    /// 中央lap上のindexを返す(近づいていなければnil)。見た目のcontent
    /// (投稿そのもの)は完全に同一のため、この移動はピクセル上は何も
    /// 変化しない。
    static func recenteredVirtualIndex(centerVirtualIndex: Int, sourceCount: Int, laps: Int) -> Int? {
        guard sourceCount > 0, laps > 0 else { return nil }
        let lapIndex = flooredDivide(centerVirtualIndex, sourceCount)
        guard lapIndex < recenterSafeMarginLaps || lapIndex >= laps - recenterSafeMarginLaps else { return nil }
        let realIndexInLap = realIndex(virtualIndex: centerVirtualIndex, sourceCount: sourceCount)
        let middleLapStart = (laps / 2) * sourceCount
        let target = middleLapStart + realIndexInLap
        return target == centerVirtualIndex ? nil : target
    }

    /// 初期表示用のcenterVirtualIndex(中央lap上の、targetRealIndexに対応する位置)。
    static func initialCenterVirtualIndex(sourceCount: Int, laps: Int, targetRealIndex: Int) -> Int {
        guard sourceCount > 0 else { return 0 }
        let middleLapStart = (laps / 2) * sourceCount
        let clampedRealIndex = ((targetRealIndex % sourceCount) + sourceCount) % sourceCount
        return middleLapStart + clampedRealIndex
    }

    /// virtualIndexが指す実データ(posts配列)側のindex。負数のvirtualIndexにも
    /// 安全(実運用では発生しないが、防御的に扱う)。
    static func realIndex(virtualIndex: Int, sourceCount: Int) -> Int {
        guard sourceCount > 0 else { return 0 }
        return ((virtualIndex % sourceCount) + sourceCount) % sourceCount
    }

    private static func flooredDivide(_ value: Int, _ divisor: Int) -> Int {
        guard divisor > 0 else { return 0 }
        return Int((Double(value) / Double(divisor)).rounded(.down))
    }
}
