import CoreGraphics

// MARK: - Pictri Home Floating Bar Metrics
//
// 下部バーの寸法・余白をView本体から分離した専用定数群。固定機種判定
// (UIScreen.main.bounds・機種名分岐)は行わず、呼び出し側が渡す
// container幅(GeometryReaderの実測値)だけから算出する。
//
// v18: バーを薄くし、カメラボタンを拡大した際も「バー幅・バー高さ・
// カメラ直径がそれぞれ勝手な比率で動いて破綻する」ことがないよう、
// 3つとも同一の進行度`t(containerWidth:)`から導出する。カメラの
// 突出量(`cameraTopProtrusion`)・Homeが確保すべき余白
// (`reservedContentHeight`)も、個別のマジックナンバーではなく
// `height`・`cameraDiameter`・`cameraLift`から計算する(View本体の
// 実際の配置式と完全に一致させるため)。
enum PictriHomeFloatingBarMetrics {
    // MARK: バー幅
    // v1.5 REFERENCE FIDELITY: 新Reference実測(バー本体をカメラボタンの影響が
    // 無い中段y=1700行で横方向scan、850×1850canvas上でleft47/right803px)。
    // pt換算(×402/850)でbarWidth ≈ 358pt。旧305.5pt(widthRatio0.76 ×
    // containerWidth402、clamp後)から+17%の明確なズレのため変更する。
    static let widthRatio: CGFloat = 0.89
    static let minWidth: CGFloat = 330
    static let maxWidth: CGFloat = 365

    // MARK: バー高さ(v17の84ptより薄くする)
    // v1.5: 同实測(x=130列でtop1624/bottom1785px)からbarHeight ≈ 76pt
    // (旧70.6ptから+7.6%)。
    static let heightMin: CGFloat = 72
    static let heightMax: CGFloat = 78

    // MARK: カメラボタン(最外周)の直径。CameraをUIの主役にするため拡大。
    static let cameraDiameterMin: CGFloat = 82
    static let cameraDiameterMax: CGFloat = 88

    /// バー中心から、カメラボタン中心を上へ持ち上げる量。
    static let cameraLift: CGFloat = 14

    /// バー下端から、bottom Safe Areaの上端までの黒い隙間。
    /// v3 TASK6 PAGINATION→DOCK RESIDUAL: Round2で残ったpagination→Dock間の
    /// 狭さを、Hero width/height(Freeze)には触れずDock側だけで緩和する
    /// (Option B採用、8〜12pt許容範囲の中央値付近10pt分をbottomGapから差し引く)。
    /// Dock自体のwidth/height/Camera diameter/liftは無変更。
    static let bottomGap: CGFloat = 8

    /// カプセル内側の余白(カメラ直径を差し引いた残りをマップ/アルバムへ
    /// 均等配分する際の、カプセル左右端からの最小余白)。
    static let horizontalInsets: CGFloat = 18

    static let strokeWidth: CGFloat = 0.75

    /// container幅に対する進行度(0=minWidth相当、1=maxWidth相当)。
    /// バー幅・バー高さ・カメラ直径はすべてこの同じtから導出するため、
    /// 画面幅が変わっても各部の比率関係が崩れない。
    private static func t(containerWidth: CGFloat) -> CGFloat {
        guard containerWidth.isFinite, containerWidth > 0 else { return 0 }
        let span = max(maxWidth - minWidth, 1)
        return min(max((containerWidth * widthRatio - minWidth) / span, 0), 1)
    }

    /// バー本体の横幅(container幅から算出。極端なサイズにならないようclamp)。
    static func barWidth(containerWidth: CGFloat) -> CGFloat {
        guard containerWidth.isFinite, containerWidth > 0 else { return minWidth }
        return min(max(containerWidth * widthRatio, minWidth), maxWidth)
    }

    /// バー本体の高さ。cornerRadiusはこの半分(完全なCapsule)。
    static func barHeight(containerWidth: CGFloat) -> CGFloat {
        heightMin + (heightMax - heightMin) * t(containerWidth: containerWidth)
    }

    /// 中央カメラボタン(最外周リング)の直径。
    static func cameraDiameter(containerWidth: CGFloat) -> CGFloat {
        cameraDiameterMin + (cameraDiameterMax - cameraDiameterMin) * t(containerWidth: containerWidth)
    }

    /// カメラボタン最外周が、バー本体の上端からどれだけ上へ突出するか。
    /// `barHeight`・`cameraDiameter`・`cameraLift`だけから導出する
    /// (概念: cameraDiameter/2 - (barHeight/2 - cameraLift))。
    /// View側の実配置(`.offset(y: -cameraLift)`をバー中心基準で適用)と
    /// 必ず一致させる。
    static func cameraTopProtrusion(containerWidth: CGFloat) -> CGFloat {
        let height = barHeight(containerWidth: containerWidth)
        let diameter = cameraDiameter(containerWidth: containerWidth)
        return diameter / 2 - (height / 2 - cameraLift)
    }

    /// バー本体の下端から、カメラボタン最上部までの合計視覚的高さ。
    static func totalVisualHeight(containerWidth: CGFloat) -> CGFloat {
        barHeight(containerWidth: containerWidth) + cameraTopProtrusion(containerWidth: containerWidth)
    }

    /// Homeのメインコンテンツ(Carousel/Pagination)がバー・突出ボタンと
    /// 重ならないよう確保すべき、画面下方向の合計余白。
    static func reservedContentHeight(containerWidth: CGFloat) -> CGFloat {
        totalVisualHeight(containerWidth: containerWidth) + bottomGap
    }

    /// マップ/アルバムそれぞれに割り当てる列幅(バー幅からカメラ直径と
    /// 左右insetsを差し引いた残りを2等分)。44pt未満にはしない。
    static func sideItemWidth(containerWidth: CGFloat) -> CGFloat {
        let width = barWidth(containerWidth: containerWidth)
        let diameter = cameraDiameter(containerWidth: containerWidth)
        return max((width - diameter - horizontalInsets * 2) / 2, 44)
    }
}
