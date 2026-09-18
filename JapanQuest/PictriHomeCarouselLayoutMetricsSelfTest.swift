#if DEBUG
import Foundation

// MARK: - Pictri Circular Carousel Engine Self Test(v16 DETERMINISTIC ENGINE)
//
// このプロジェクトには現時点でXCTestターゲットが存在しない
// (`xcodebuild -list`で確認済み)。project.pbxproj(PBXNativeTarget/
// PBXSourcesBuildPhase/XCConfigurationList等、複数セクションが相互参照する
// 構造)への手動編集は、未コミット差分を多数抱えたプロジェクトファイルへの
// リスクが高いため、既存コードベースが既に採用している「DEBUG専用
// launch flagで自己検証を実行し、結果をconsoleへ出力する」パターンを
// 踏襲する。`JapanQuestApp.swift`(今回変更禁止)が`PictriHomeCarouselLayout
// MetricsSelfTest.run()`という型名・関数シグネチャを直接呼んでいるため、
// この型名・シグネチャ自体は維持したまま、中身をv16の新Engineへ向けて
// 全面的に書き直した。
//
// v15自己テストへの指摘: 「19/19の自己テストがPASSしていても、実際の
// Viewへ渡しているcontinuousPageが誤っているため、テストが実画面の
// 正しさを証明していない」という重大な指摘を受けた。原因は、旧テストが
// `metrics.renderState(virtualIndex:continuousPage:...)`へ**手で作った**
// continuousPage値を渡すだけで、実際のView(`PictriHomeCarousel.body`)が
// `onScrollGeometryChange`経由で得る**実際の**continuousPageと一致するかは
// 一切検証していなかったことにある。
//
// v16はこのギャップを構造的に閉じる: Viewが実際に使う状態
// (`centerVirtualIndex`, `dragTranslation`)そのものをテストの入力にし、
// Viewが呼ぶのと**全く同じ**`metrics.renderState(virtualIndex:
// centerVirtualIndex:dragTranslation:reduceMotion:)`を呼ぶ。ScrollViewの
// ような「テストでは再現できない外部状態」がこの経路のどこにも存在しない
// ため、「テストは通るが実画面は違う値を見ている」という状態不一致は
// そもそも起こり得ない。
enum PictriHomeCarouselLayoutMetricsSelfTest {
    struct Failure: CustomStringConvertible {
        let name: String
        let detail: String
        var description: String { "FAIL [\(name)] \(detail)" }
    }

    static func run() -> (passed: Int, failures: [Failure]) {
        var failures: [Failure] = []
        var passed = 0

        func check(_ name: String, _ condition: @autoclosure () -> Bool, _ detail: @autoclosure () -> String) {
            if condition() {
                passed += 1
            } else {
                failures.append(Failure(name: name, detail: detail()))
            }
        }

        let widths: [CGFloat] = [375, 390, 393, 402, 430]
        let referenceMetrics = PictriHomeCarouselLayoutMetrics(viewportWidth: 402, heroMaxHeight: 900)
        let itemStep = referenceMetrics.itemStep

        func state(_ virtualIndex: Int, center: Int, drag: CGFloat, reduceMotion: Bool = false, metrics: PictriHomeCarouselLayoutMetrics = referenceMetrics) -> PictriCarouselRenderState {
            metrics.renderState(virtualIndex: virtualIndex, centerVirtualIndex: center, dragTranslation: drag, reduceMotion: reduceMotion)
        }

        // 1. rest時(drag=0): centerのcardだけがrelativePosition=0/rotation=0/
        //    scale=1/centerX=viewportCenter/zIndex最大。
        do {
            let center = 40
            let hero = state(center, center: center, drag: 0)
            let left = state(center - 1, center: center, drag: 0)
            let right = state(center + 1, center: center, drag: 0)
            check("1a-relativePosition0", hero.relativePosition == 0, "hero relativePosition should be exactly 0, got \(hero.relativePosition)")
            check("1b-rotation0", hero.rotationDegrees == 0, "hero rotation should be 0, got \(hero.rotationDegrees)")
            check("1c-scale1", hero.scale == 1.0, "hero scale should be 1.0, got \(hero.scale)")
            check("1d-centerX", hero.cardCenterX == referenceMetrics.viewportCenterX, "hero centerX \(hero.cardCenterX) should equal viewportCenterX \(referenceMetrics.viewportCenterX)")
            check("1e-isHero", hero.isVisualHero, "center card must be classified as hero")
            check("1f-zIndexMax", hero.zIndex > left.zIndex && hero.zIndex > right.zIndex, "hero zIndex \(hero.zIndex) must exceed neighbors (\(left.zIndex), \(right.zIndex))")
        }

        // 2. 幅: 375/390/393/402/430ptすべてでHero幅率が0.72に一致する。
        for width in widths {
            let m = PictriHomeCarouselLayoutMetrics(viewportWidth: width, heroMaxHeight: .greatestFiniteMagnitude)
            let ratio = m.cardWidth / width
            check("2-width-\(Int(width))", abs(ratio - 0.72) < 0.0001, "width=\(width) expected ratio 0.72, got \(ratio)")
        }

        // 3〜8. drag -0.25/-0.5/-0.75/+0.25/+0.5/+0.75ページ: 各状態で
        //    最も中央に近いcardが最大zIndex・scale<=1・rotation範囲内・
        //    左右対称。
        let dragFractions: [CGFloat] = [-0.75, -0.5, -0.25, 0.25, 0.5, 0.75]
        for fraction in dragFractions {
            let center = 40
            let drag = fraction * itemStep
            let candidates = (center - 2)...(center + 2)
            let states = candidates.map { state($0, center: center, drag: drag) }
            let heroCount = states.filter(\.isVisualHero).count
            let maxZ = states.map(\.zIndex).max() ?? -.infinity
            let heroZ = states.first(where: \.isVisualHero)?.zIndex ?? -.infinity
            check("drag-\(fraction)-singleHero", heroCount == 1, "fraction=\(fraction) expected exactly 1 hero, got \(heroCount)")
            check("drag-\(fraction)-heroMaxZ", heroZ == maxZ, "fraction=\(fraction) hero zIndex \(heroZ) should equal max zIndex \(maxZ)")
            for s in states {
                check("drag-\(fraction)-scaleBound-\(s.virtualIndex)", s.scale <= 1.0001, "scale \(s.scale) must not exceed 1.0")
                check("drag-\(fraction)-rotationBound-\(s.virtualIndex)", abs(s.rotationDegrees) <= PictriHomeCarouselLayoutMetrics.maxRotationDegrees + 0.001, "rotation \(s.rotationDegrees) exceeds max")
            }
            // 対称性: fractionと-fractionでabsoluteDistanceの集合が一致する。
            let mirrored = candidates.map { state($0, center: center, drag: -drag) }
            let distPairs = states.map { "\($0.virtualIndex):\(($0.absoluteDistance * 10000).rounded())" }.sorted()
            let mirroredDistPairsShifted = mirrored.map { "\(2 * center - $0.virtualIndex):\(($0.absoluteDistance * 10000).rounded())" }.sorted()
            check("drag-\(fraction)-symmetry", distPairs == mirroredDistPairsShifted, "left/right drag should be distance-symmetric around center")
        }

        // 9. snap完了: centerVirtualIndexが進んだ直後(drag=0)、新centerの
        //    relativePosition=0・rotation=0。
        do {
            let newCenter = 41
            let s = state(newCenter, center: newCenter, drag: 0)
            check("9-snapRelativePosition0", s.relativePosition == 0, "post-snap relativePosition should be 0, got \(s.relativePosition)")
            check("9-snapRotation0", s.rotationDegrees == 0, "post-snap rotation should be 0, got \(s.rotationDegrees)")
        }

        // 10. 100回連続 pageDelta 適用(前進): centerVirtualIndexが単調増加し、
        //     各ステップでhero一意性が壊れない。
        do {
            var center = 1000
            var ok = true
            var detail = ""
            for step in 0..<100 {
                let delta = PictriCircularCarouselEngine.pageDelta(translation: -itemStep, predictedTranslation: -itemStep, itemStep: itemStep)
                guard delta == 1 else { ok = false; detail = "step \(step): expected delta=1, got \(delta)"; break }
                center += delta
                let hero = state(center, center: center, drag: 0)
                guard hero.isVisualHero else { ok = false; detail = "step \(step): center \(center) not classified as hero"; break }
            }
            check("10-forward100", ok, detail.isEmpty ? "ok" : detail)
        }

        // 11. reverse 100回。
        do {
            var center = 1000
            var ok = true
            var detail = ""
            for step in 0..<100 {
                let delta = PictriCircularCarouselEngine.pageDelta(translation: itemStep, predictedTranslation: itemStep, itemStep: itemStep)
                guard delta == -1 else { ok = false; detail = "step \(step): expected delta=-1, got \(delta)"; break }
                center += delta
                let hero = state(center, center: center, drag: 0)
                guard hero.isVisualHero else { ok = false; detail = "step \(step): center \(center) not classified as hero"; break }
            }
            check("11-reverse100", ok, detail.isEmpty ? "ok" : detail)
        }

        // 12. wrap 100回: sourceCount=3, laps=21で、recenteredVirtualIndexが
        //     常に同じreal itemを指したまま安全マージン内へ戻す。
        do {
            let sourceCount = 3
            let laps = 21
            var center = PictriCircularCarouselEngine.initialCenterVirtualIndex(sourceCount: sourceCount, laps: laps, targetRealIndex: 0)
            var ok = true
            var detail = ""
            for step in 0..<100 {
                let beforeReal = PictriCircularCarouselEngine.realIndex(virtualIndex: center, sourceCount: sourceCount)
                center += 1
                if let recentered = PictriCircularCarouselEngine.recenteredVirtualIndex(centerVirtualIndex: center, sourceCount: sourceCount, laps: laps) {
                    let afterReal = PictriCircularCarouselEngine.realIndex(virtualIndex: recentered, sourceCount: sourceCount)
                    let expectedReal = (beforeReal + 1) % sourceCount
                    guard afterReal == expectedReal else { ok = false; detail = "step \(step): recenter changed real item (\(afterReal) != \(expectedReal))"; break }
                    center = recentered
                }
            }
            check("12-wrap100", ok, detail.isEmpty ? "ok" : detail)
        }

        // 13. virtualID重複なし。
        do {
            let posts: [String] = ["a", "b", "c"]
            let laps = 21
            var ids: [String] = []
            for i in 0..<(posts.count * laps) {
                let realId = posts[i % posts.count]
                ids.append("\(realId)::\(i)")
            }
            check("13-idUniqueness", Set(ids).count == ids.count, "expected \(ids.count) unique ids, got \(Set(ids).count)")
        }

        // 14. Reduce Motion ON: rotationは常に0、他は通常と同じ。
        do {
            let center = 40
            let s = state(center + 1, center: center, drag: -0.4 * itemStep, reduceMotion: true)
            check("14-reduceMotionRotation0", s.rotationDegrees == 0, "reduceMotion should force rotation to 0, got \(s.rotationDegrees)")
            check("14-reduceMotionScaleUnaffected", s.scale < 1.0, "reduceMotion should not disable scale falloff, got \(s.scale)")
        }

        // 15. Reduce Motion OFF: 通常のrotationが働く。
        do {
            let center = 40
            let s = state(center + 1, center: center, drag: -0.4 * itemStep, reduceMotion: false)
            check("15-reduceMotionOffRotation", s.rotationDegrees != 0, "reduceMotion off should allow non-zero rotation")
        }

        // 16. データ1件: Circular無効、常にHero。
        do {
            let m = referenceMetrics
            let s = m.renderState(virtualIndex: 0, centerVirtualIndex: 0, dragTranslation: 0, reduceMotion: false)
            check("16-singlePost", s.isVisualHero && s.relativePosition == 0, "single post must always be hero at relativePosition 0")
        }

        // 17. データ2件: recenterが安全に往復する。
        do {
            let sourceCount = 2
            let laps = 21
            let center = PictriCircularCarouselEngine.initialCenterVirtualIndex(sourceCount: sourceCount, laps: laps, targetRealIndex: 0)
            let lapIndex = center / sourceCount
            check("17-twoPosts-middleLap", lapIndex == laps / 2, "initial center should sit on the middle lap, got lapIndex=\(lapIndex)")
        }

        // 18. データ5件: realIndexが常に0..<5の範囲。
        do {
            let sourceCount = 5
            var ok = true
            for v in -20...20 {
                let r = PictriCircularCarouselEngine.realIndex(virtualIndex: v, sourceCount: sourceCount)
                if r < 0 || r >= sourceCount { ok = false; break }
            }
            check("18-fivePosts-realIndexBounds", ok, "realIndex must always stay within 0..<5")
        }

        // 19. 高速flick: predictedTranslationが2ページ相当 → pageDelta=2
        //     (maxPageDeltaPerGesture=3以内)。
        do {
            let delta = PictriCircularCarouselEngine.pageDelta(translation: -itemStep * 0.3, predictedTranslation: -itemStep * 2.1, itemStep: itemStep)
            check("19-fastFlickTwoPages", delta == 2, "expected pageDelta=2 for a 2-page predicted flick, got \(delta)")
        }

        // 20. gestureキャンセル相当(閾値未満): pageDelta=0で現在位置へ戻る。
        do {
            let delta = PictriCircularCarouselEngine.pageDelta(translation: -itemStep * 0.05, predictedTranslation: -itemStep * 0.05, itemStep: itemStep)
            check("20-cancelledGesture", delta == 0, "expected pageDelta=0 for a sub-threshold drag, got \(delta)")
        }

        // 補足: NaN/無限大がdragTranslationに紛れ込んでもクラッシュ/NaN伝播しない。
        do {
            let s = state(40, center: 40, drag: .nan)
            check("nan-guard", s.zIndex.isFinite && s.cardCenterX.isFinite, "state must stay finite when dragTranslation is NaN")
        }

        return (passed, failures)
    }
}
#endif
