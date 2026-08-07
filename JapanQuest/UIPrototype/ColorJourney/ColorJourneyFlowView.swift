import SwiftUI

// MARK: - Color Journey Flow
//
// "地図から場所を選ぶ→現地で写真を残す→場所と地図が色づく"を1本の操作として
// つなげる、インタラクティブ版プロトタイプ。既存の静的4画面
// (ColorJourneyHomeView/MapView/SpotDetailView)は一切壊さず、それぞれへ
// 追加したオプショナルパラメータ(デフォルト値あり)経由で駆動するだけに留める。
//
// 状態の単一の源はColorJourneyPrototypeStore。このView自身はStoreの状態を
// 読んで「今何を表示すべきか」を描画するだけで、遷移ロジックは一切持たない
// (状態管理と描画の分離)。
//
// Map⇄SpotDetailの遷移だけは、両者が同じView階層内でif/elseによって
// 入れ替わる構造にした上でNamespaceを共有し、matchedGeometryEffectで
// 神奈川の形が連続して見えるようにする。NavigationStackの標準pushは使わない
// (pushだと山/川のような単純な画面遷移に見え、「同じ要素が拡大しながら移動する」
// という連続性を表現できないため)。撮影シミュレーションだけはfullScreenCoverで
// 独立したモーダル文脈として重ねる(カメラ的な没入UIとして自然な提示方法であり、
// matchedGeometryEffectの対象にもしていないため独立させても違和感がない)。

struct ColorJourneyFlowView: View {
    @State private var store: ColorJourneyPrototypeStore
    @Namespace private var kanagawaNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// debugInitialStepが指定された場合、通常のインタラクティブ操作(タップ)ではなく
    /// そのstepへ直接シークして起動する。DEBUG限定のQA用(実装後の確認章を参照)。
    /// 通常起動(nil)では従来通り.mapUnvisitedから始まり、自動遷移も通常通り動く。
    init(debugInitialStep: ColorJourneyPrototypeStore.Step? = nil) {
        _store = State(initialValue: ColorJourneyPrototypeStore(debugInitialStep: debugInitialStep))
    }

    private var spot: CJSpotDetail {
        ColorJourneyPreviewData.spotDetail(id: "senshu_university_ikuta", isVisited: store.isKanagawaVisited)
    }

    private var transitionAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.22) : .spring(response: 0.45, dampingFraction: 0.82)
    }

    var body: some View {
        ZStack {
            switch store.topDestination {
            case .map:
                mapDestination
            case .home:
                homeDestination
            }

            if store.isShowingSpotDetail {
                spotDetailOverlay
                    .transition(reduceMotion ? .opacity : .identity)
            }
        }
        .fullScreenCover(isPresented: captureSimulationBinding) {
            ColorJourneyCaptureSimulationView(
                spotName: spot.name,
                phase: store.step,
                reduceMotion: reduceMotion,
                onShutter: { store.shutter() },
                onClose: { store.closeCaptureSimulation() }
            )
        }
        // stepが変わるたびに評価し直す。前のidの待機はSwiftUIが自動キャンセルするため、
        // 手動でTaskを保持・キャンセルする必要はない。
        .task(id: store.step) {
            await advanceIfNeeded()
        }
    }

    // MARK: - Destinations

    private var mapDestination: some View {
        VStack(spacing: 0) {
            ColorJourneyMapView(
                prefectureStates: ColorJourneyPreviewData.prefectureColorStates(kanagawaVisited: store.isKanagawaVisited),
                nextTarget: ColorJourneyPreviewData.nextColorTarget,
                externalIsKanagawaSelected: store.step == .mapSelected,
                onTapKanagawa: {
                    withAnimation(transitionAnimation) {
                        store.tapKanagawa()
                    }
                },
                kanagawaGeometryNamespace: reduceMotion ? nil : kanagawaNamespace
            )

            if store.isKanagawaVisited {
                peekLink(title: "ホームで見る", systemImage: "chevron.right") {
                    withAnimation(transitionAnimation) {
                        store.showHome()
                    }
                }
            }
        }
    }

    private var homeDestination: some View {
        VStack(spacing: 0) {
            if store.topDestination == .home {
                peekLink(title: "地図に戻る", systemImage: "chevron.left") {
                    withAnimation(transitionAnimation) {
                        store.showMap()
                    }
                }
            }

            ColorJourneyHomeView(
                extraFragment: store.isKanagawaVisited ? justColoredFragment : nil,
                ribbonOverride: store.isKanagawaVisited
                    ? (stateText: "専修大学の写真が加わった", accentColor: CJTokens.Color.mutedGreen)
                    : nil
            )
        }
    }

    private var justColoredFragment: CJTravelFragment {
        CJTravelFragment(
            id: "fragment_senshu_flow",
            username: "you",
            placeName: spot.name,
            areaName: "\(spot.areaName)・神奈川",
            stateText: "たった今、記憶をひとつ残した",
            accentColor: CJTokens.Color.mutedGreen,
            likeCount: 0
        )
    }

    private func peekLink(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if systemImage == "chevron.left" {
                    Image(systemName: systemImage)
                }
                Text(title)
                if systemImage == "chevron.right" {
                    Image(systemName: systemImage)
                }
            }
            .font(CJTokens.Typography.stateLine)
            .foregroundStyle(CJTokens.Color.mutedGreen)
            .padding(.horizontal, CJTokens.Spacing.md)
            .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity, alignment: systemImage == "chevron.left" ? .leading : .trailing)
        .background(CJTokens.Color.backgroundWarm)
    }

    // MARK: - Spot Detail Overlay

    private var spotDetailOverlay: some View {
        ColorJourneySpotDetailView(
            spot: spot,
            justColored: store.justColored,
            kanagawaGeometryNamespace: reduceMotion ? nil : kanagawaNamespace,
            onCaptureTapped: {
                withAnimation(transitionAnimation) {
                    store.beginCapture()
                }
            },
            onViewMemory: {
                withAnimation(transitionAnimation) {
                    store.returnToMap()
                }
            },
            onBackToMap: {
                withAnimation(transitionAnimation) {
                    store.returnToMap()
                }
            }
        )
    }

    private var captureSimulationBinding: Binding<Bool> {
        Binding(
            get: { store.isCaptureSimulationPresented },
            set: { isPresented in
                guard !isPresented else { return }
                store.closeCaptureSimulation()
            }
        )
    }

    // MARK: - Auto-advance (短い間を置くだけの遷移。すべてTask.sleepでキャンセル可能)

    private func advanceIfNeeded() async {
        guard !store.isDebugFrozen else { return }
        switch store.step {
        case .mapSelected:
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            withAnimation(transitionAnimation) {
                store.confirmKanagawaSelection()
            }

        case .capturing:
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            store.finishCapturing()

        case .captureCompleted:
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            withAnimation(transitionAnimation) {
                store.revealSpotVisited()
            }

        case .spotVisited:
            guard store.justColored else { return }
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            store.clearJustColored()

        case .mapUnvisited, .spotUnvisited, .captureReady, .mapVisited, .homeUpdated:
            break
        }
    }
}

#Preview("Color Journey Flow") {
    ColorJourneyFlowView()
}
