import SwiftUI

@main
struct JapanQuestApp: App {
    init() {
        #if DEBUG
        if PictriVisualReview.carouselMetricsSelfTestRequested {
            let (passed, failures) = PictriHomeCarouselLayoutMetricsSelfTest.run()
            print("[CarouselMetricsSelfTest] passed=\(passed) failed=\(failures.count)")
            for failure in failures {
                print("[CarouselMetricsSelfTest] \(failure)")
            }
            print(failures.isEmpty ? "[CarouselMetricsSelfTest] ALL PASS" : "[CarouselMetricsSelfTest] FAILURES PRESENT")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            rootView
        }
    }

    /// `-pictriPrototypeScreen`未指定時は常にContentView()のみ(本番と完全に同じ挙動)。
    /// "色づく旅帳"コンセプトプロトタイプ確認用にDEBUGビルド限定で分岐を追加しているが、
    /// 既存のHome/Map/SpotDetail等の本番画面ツリーは一切変更していない。
    @ViewBuilder
    private var rootView: some View {
        #if DEBUG
        if let screen = ColorJourneyLaunchArgs.requestedScreen {
            ColorJourneyPrototypeRootView(screen: screen)
        } else if PictriVisualReview.openingPreviewRequested {
            PictriOpeningPreviewHarness()
        } else {
            PictriRootWithOpening()
        }
        #else
        PictriRootWithOpening()
        #endif
    }
}

/// NO PEEL SIGNATURE FINALの本接続。ContentView()自体は無変更のまま、
/// `PictriNoPeelRoot`がOpeningと同じ時間軸でHomeへfocus/exposure/depthの
/// 光学的な変化を適用しつつ、上にOpeningをoverlayとして重ねる。
/// Status Barの非表示/復帰は`PictriNoPeelRoot`内で`isOpeningActive`に
/// bindingして行う(Opening subview側にだけ付けると復帰しない不具合が
/// 過去ラウンドで見つかっているため)。
private struct PictriRootWithOpening: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // v16 P1: Reduce Motion時は`PictriOpeningView`側が
    // `PictriFocusHandoffReducedFallback`へ切り替わるが、v16以降は
    // そちらのtimeline定数(stillnessEnd/revealDuration/totalDuration)を
    // フル尺(`pictriNoPeel*`)と完全に同じ値へ揃えたため、Home側の
    // optical stateだけ計算式が異なる(blur/brightnessの動かし方が違う)
    // 別関数を使う一方、totalDurationは両方とも`pictriNoPeelTotalDuration`
    // で揃うようになった。
    private var homeState: (Double) -> PictriHomeOpticalState {
        if reduceMotion {
            return { elapsed in pictriHandoffHomeStateReduced(elapsed: elapsed) }
        } else {
            return { elapsed in pictriHandoffHomeState(elapsed: elapsed, style: .rack) }
        }
    }

    private var openingTotalDuration: Double {
        pictriNoPeelTotalDuration
    }

    var body: some View {
        PictriNoPeelRoot(homeState: homeState, totalDuration: openingTotalDuration) { onComplete in
            PictriOpeningView(onComplete: onComplete)
        }
    }
}

#if DEBUG
/// `-pictriOpening true`専用のQAハーネス。Openingが1回完了するたびに`cycle`を進め、
/// `.id(cycle)`でPictriOpeningViewの識別子を切り替えることで@Stateを完全にリセットし、
/// プロセスを再起動せずに何度でもタイムラインを確認できるようにする。本番の
/// PictriRootWithOpeningには一切影響しない。
private struct PictriOpeningPreviewHarness: View {
    @State private var cycle = 0

    /// Opening Motion Lab(Phase 7)。`-pictriOpeningConcept a|b|c`が指定されている間だけ
    /// 該当conceptを表示し、無指定なら本番のPictriOpeningView(採用版)のまま再生する。
    @ViewBuilder
    private var openingBody: some View {
        switch PictriVisualReview.openingConcept {
        case "a": PictriOpeningConceptA_LensFocus { cycle += 1 }
        case "b": PictriOpeningConceptB_DarkroomTray { cycle += 1 }
        case "c": PictriOpeningConceptC_ApertureIris { cycle += 1 }
        case "d": PictriOpeningConceptD_Hybrid { cycle += 1 }
        case "e": PictriOpeningConceptE_RackFocus { cycle += 1 }
        case "f": PictriOpeningConceptF_ExposurePrint { cycle += 1 }
        case "g": PictriOpeningConceptG_ApertureBreath { cycle += 1 }
        case "h": PictriOpeningConceptH_Afterimage { cycle += 1 }
        // Signature Lab(Block Typography + Fracture Reveal)。fractureが実際に
        // Homeを覗き込む見え方を確認できるよう、ContentView()を背後に重ねた
        // 本番同等の構図(PictriRootWithOpeningと同じZStack順序)で表示する。
        case "sa": ZStack { ContentView(); PictriSignatureConceptA_MonolithAssembly { cycle += 1 }.zIndex(10) }
        case "sb": ZStack { ContentView(); PictriSignatureConceptB_TypeUnderPressure { cycle += 1 }.zIndex(10) }
        case "sc": ZStack { ContentView(); PictriSignatureConceptC_PhotographicNegative { cycle += 1 }.zIndex(10) }
        case "sd": ZStack { ContentView(); PictriSignatureConceptD_DirectorsCut { cycle += 1 }.zIndex(10) }
        case "se": ZStack { ContentView(); PictriSignatureConceptE_LatentImage { cycle += 1 }.zIndex(10) }
        // Peel Reveal Rebuild(Phase 1-5)。Phase 2: typography emergence比較。
        case "p-frag": ZStack { ContentView(); PictriPeelConcept_LatentFragments_SeamReveal { cycle += 1 }.zIndex(10) }
        case "p-bloom": ZStack { ContentView(); PictriPeelConcept_ExposureBloom { cycle += 1 }.zIndex(10) }
        case "p-block": ZStack { ContentView(); PictriPeelConcept_BlockAssembly { cycle += 1 }.zIndex(10) }
        // Phase 3: reveal mechanics比較(typographyはLatent Fragmentsで固定)。
        case "p-seam": ZStack { ContentView(); PictriPeelConcept_SeamRevealCompare { cycle += 1 }.zIndex(10) }
        case "p-split": ZStack { ContentView(); PictriPeelConcept_LatentSplitCompare { cycle += 1 }.zIndex(10) }
        case "p-final": ZStack { ContentView(); PictriPeelConceptFinal { cycle += 1 }.zIndex(10) }
        // Cinematic Peel Finalization: Typography比較3案。
        case "p2-depth": ZStack { ContentView(); PictriPeelConcept_DepthEmergence { cycle += 1 }.zIndex(10) }
        case "p2-latent": ZStack { ContentView(); PictriPeelConcept_LatentImageTypo { cycle += 1 }.zIndex(10) }
        case "p2-soft": ZStack { ContentView(); PictriPeelConcept_SoftMaterialReveal { cycle += 1 }.zIndex(10) }
        case "p3-segcurl": ZStack { ContentView(); PictriPeelConcept_SegmentedCurl { cycle += 1 }.zIndex(10) }
        case "p-cinefinal": ZStack { ContentView(); PictriPeelConceptCinematicFinal { cycle += 1 }.zIndex(10) }
        case "p-refmatch": ZStack { ContentView(); PictriPeelConceptReferenceMatch { cycle += 1 }.zIndex(10) }
        // Pure Peel Refinement: 独立したhighlight/shadow直線を廃止し、
        // band自身のwavy silhouetteから導出する3案比較。
        case "pp-minimal": ZStack { ContentView(); PictriPurePeelConcept_Minimal { cycle += 1 }.zIndex(10) }
        case "pp-editorial": ZStack { ContentView(); PictriPurePeelConcept_Editorial { cycle += 1 }.zIndex(10) }
        case "pp-cinematic": ZStack { ContentView(); PictriPurePeelConcept_Cinematic { cycle += 1 }.zIndex(10) }
        case "final100": ZStack { ContentView(); PictriPeelConceptFinal100 { cycle += 1 }.zIndex(10) }
        case "route-b": ZStack { ContentView(); PictriPeelConceptRouteB_CoreAnimation { cycle += 1 }.zIndex(10) }
        // NO PEEL SIGNATURE FINAL: Peelを廃したfocus/exposure/depth 3案比較。
        case "np-focus":
            PictriNoPeelRoot(homeState: pictriNoPeelHomeState_Focus, totalDuration: pictriNoPeelTotalDuration) { onComplete in
                PictriNoPeelConcept_Focus { onComplete(); cycle += 1 }
            }
        case "np-latent":
            PictriNoPeelRoot(homeState: pictriNoPeelHomeState_Latent, totalDuration: pictriNoPeelTotalDuration) { onComplete in
                PictriNoPeelConcept_Latent { onComplete(); cycle += 1 }
            }
        case "np-depth":
            PictriNoPeelRoot(homeState: pictriNoPeelHomeState_Depth, totalDuration: pictriNoPeelTotalDuration) { onComplete in
                PictriNoPeelConcept_Depth { onComplete(); cycle += 1 }
            }
        // SIGNATURE FOCUS HANDOFF: PicTriが先に手放し、Homeが追いかけて
        // 合焦する3 choreography比較。
        case "fh-rack":
            PictriNoPeelRoot(
                homeState: { elapsed in pictriHandoffHomeState(elapsed: elapsed, style: .rack) },
                totalDuration: pictriNoPeelTotalDuration
            ) { onComplete in
                PictriFocusHandoffConcept_Rack { onComplete(); cycle += 1 }
            }
        case "fh-latent":
            PictriNoPeelRoot(
                homeState: { elapsed in pictriHandoffHomeState(elapsed: elapsed, style: .latent) },
                totalDuration: pictriNoPeelTotalDuration
            ) { onComplete in
                PictriFocusHandoffConcept_Latent { onComplete(); cycle += 1 }
            }
        case "fh-depth":
            PictriNoPeelRoot(
                homeState: { elapsed in pictriHandoffHomeState(elapsed: elapsed, style: .depth) },
                totalDuration: pictriNoPeelTotalDuration
            ) { onComplete in
                PictriFocusHandoffConcept_Depth { onComplete(); cycle += 1 }
            }
        default: PictriOpeningView { cycle += 1 }
        }
    }

    var body: some View {
        openingBody
            .id(cycle)
    }
}
#endif
