import SwiftUI

// MARK: - Pictri Cinematic Opening (v13 — SIGNATURE FOCUS HANDOFF)
//
// PicTri Opening Signature Focus Handoff(2026-08-24)。前ラウンド(No Peel
// Signature Final、内部自己評価88/100)のFocus Transferを10倍
// slow-motionで実機監査した結果、「PicTriが完全にsharpなまま長時間
// 保持され、Homeだけが先に大きくblur解除され、PicTriは最後にほぼ
// 一括で消える」という非対称な体感になっていたと判明した
// (`/tmp/pictri_opening_focus_signature/baseline_audit.md`)。
//
// 今回は「PicTriが先に手放し始め、Homeが追いかけて合焦し、両者が同じ
// 終着点で完了する」という明確なchoreographyへ再設計した:
// PicTriの変化がstillness終了と同時に始まり(lead)、Homeの変化は
// 130ms遅れて始まる(follow)。PicTri側のopacityは3乗カーブで終盤に
// だけ効く「最後の整理」とし、blur/contrastを主体に据えることで
// 「opacity fadeで消えた」という印象を避けた。
//
// PRECISION RACK FOCUS(blurのみ、露出変化最小)/ LATENT FOCUS HANDOFF
// (contrast/saturationも動く)/ DEPTH BREATH HANDOFF(微小scaleを追加)
// の3 choreographyを比較(詳細: `/tmp/pictri_opening_focus_signature/
// concept_comparison.md`)し、Clarity・Simplicity・Focus Physicalityの
// 基準(各14/14/13点以上)を唯一満たしたPRECISION RACK FOCUSを採用。
// 10x slow-motionで実際にcrossoverの瞬間(PicTriが視認できるほど
// soft化し、同時にHomeが明確にsharpになっていく瞬間)を確認済み。
//
// Peel関連実装、および前ラウンドのFocus Transfer実装
// (`PictriNoPeelConcept_Focus`等)はDEBUG比較Labとしてそのまま残すが、
// Production経路には一切接続しない。
//
// 実装は`PictriOpeningNoPeel.swift`の`PictriFocusHandoffConcept_Rack`に
// そのまま委譲する。
struct PictriOpeningView: View {
    /// タイムライン完了時に1度だけ呼ばれる。呼び出し側はこれを見てOpeningをroot階層から
    /// 取り除く。Opening自身はここで自分を消したりしない。
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            PictriFocusHandoffReducedFallback(onComplete: onComplete)
        } else {
            PictriFocusHandoffConcept_Rack(onComplete: onComplete)
        }
    }
}
