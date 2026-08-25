import SwiftUI
import UIKit
import AVFoundation
import CoreLocation

// MARK: - Camera

enum QuestDualCapturePhase {
    case idle
    case countingFront
    case capturingFront
    case countingBack
    case capturingBack
    case preview
}

struct QuestCameraView: View {
    @Binding var selectedTab: AppTab
    @Binding var selectedSpotId: String
    @Binding var pendingExploreSpotId: String?

    @EnvironmentObject var memoryStore: QuestMemoryStore
    @EnvironmentObject var locationManager: QuestLocationManager
    @EnvironmentObject var entitlementStore: QuestEntitlementStore
    @EnvironmentObject var dailyCaptureAllowance: QuestDailyCaptureAllowance

    @AppStorage("developerUnlockMode") private var developerUnlockMode = false

    @StateObject private var cameraService = QuestCameraService()

    @State private var previewImage: UIImage?
    @State private var frontImage: UIImage?
    @State private var backImage: UIImage?

    @State private var hasSaved = false
    @State private var isCapturingSequence = false
    @State private var countdownNumber: Int?
    @State private var capturePhase: QuestDualCapturePhase = .idle
    @State private var captureRunID = UUID()
    @State private var showPaywall = false
    @State private var isSavingMemory = false

    /// Anywhere Capture Phase「Spot Unlock Architecture」で追加。curated Spotの
    /// unlock radius外にいる時だけ、現在地から都道府県を解決するために使う
    /// (radius内ならそのSpot自身がprefectureIdを持っているため解決不要)。
    @State private var resolvedArea: QuestResolvedArea?
    @State private var isResolvingArea = false
    /// 保存が成功した瞬間の捕獲対象を凍結して持つ。色がつく瞬間(coloringMomentView)は
    /// 保存後も動き続けるselectedSpot/nearestUnlockedCuratedSpot/resolvedAreaではなく、
    /// 必ずこのスナップショットだけを参照する(保存後に位置が変わっても、直前に
    /// 保存したMemoryの内容が画面上で入れ替わって見えないようにするため)。
    @State private var savedCaptureTarget: QuestCaptureTarget?
    @State private var wasNewAreaAtSave = false
    @State private var wasNewSpotAtSave = false

    /// FREE = 1日3 Memoryまで。1 Memory = 外カメ+内カメの1セットを実際に保存した回数
    /// (QuestDailyCaptureAllowance.swift参照)。PREMIUMはnil(無制限)。
    private var remainingCapturesToday: Int? {
        dailyCaptureAllowance.remaining(tier: entitlementStore.tier)
    }

    /// レビュー中(previewImageあり)は「その場では」まだ消費していない撮影の続きなので、
    /// クォータの見た目上の枯渇画面は出さない。実際の消費はreviewViewの保存時のみ。
    private var isQuotaExhausted: Bool {
        remainingCapturesToday == 0
    }

    private var selectedSpot: QuestSpot {
        mockQuestSpots.first { $0.id == selectedSpotId } ?? mockQuestSpots[0]
    }

    /// Anywhere Capture Phase「Camera Unlock → Spot Unlock」。selectedSpot
    /// (Mapから遷移した時の文脈)だけでなく、全curated Spotの中から現在地の
    /// unlock radius内にあるものを探す。どのタブからCameraへ入っても、実際に
    /// おすすめSpot圏内にいればそのSpotとして正しく認識されるようにするため。
    /// 複数のradiusが重なる場合は最も近いSpotを優先する。
    private var nearestUnlockedCuratedSpot: QuestSpot? {
        guard locationManager.currentLocation != nil else { return nil }
        return mockQuestSpots
            .filter { locationManager.isNear($0) }
            .min {
                (locationManager.distance(to: $0) ?? .infinity)
                    < (locationManager.distance(to: $1) ?? .infinity)
            }
    }

    /// Product Decision「Spotへ行かないとCamera Unlockされない」を廃止。
    /// 現在地が取得できてさえいれば(=Anywhere Capture)、Spotの近くにいなくても
    /// シャッター自体は使える。Spot/Areaのunlock可否はcurrentCaptureTargetが
    /// 保存時に別途判定する(Camera自体をSpot proximityでgateしない)。
    private var isUnlocked: Bool {
        developerUnlockMode || locationManager.currentLocation != nil
    }

    /// 実機でカメラのハードウェアはあるのに、権限だけが拒否されている状態。
    /// この状態ではシャッターを完全に止め、デモ画像へのフォールバックもさせない。
    private var isCameraPermissionBlocking: Bool {
        cameraService.isCameraAvailable && cameraService.permissionDenied
    }

    /// 位置情報の権限そのものが拒否/制限されている状態(距離が遠いのとは別問題)。
    private var isLocationPermissionBlocking: Bool {
        locationManager.authorizationStatus == .denied
            || locationManager.authorizationStatus == .restricted
    }

    private var canCapture: Bool {
        // dailyCaptureAllowance.canCapture(...)はisQuotaExhaustedと同じ判定だが、
        // shutterの有効/無効という「最終防衛ライン」自体にも明示的に持たせておく
        // (Readyがexhausted時に表示されない構造に将来変更が入っても、誤って
        // shutterだけ押せてしまうことがないように)。
        isUnlocked && !isCameraPermissionBlocking && dailyCaptureAllowance.canCapture(tier: entitlementStore.tier)
    }

    /// 保存時に実際に使うcapture対象。優先順位: developer override(QA再現性のため
    /// 既存selectedSpotを維持) > curated Spot radius内 > 現在地から解決したArea。
    /// どれも成立しなければnil──Product Spec 7章の「安全側」原則により、位置検証
    /// できないMemoryはArea/Spot unlockしない(=保存自体を一旦保留する)。
    private var currentCaptureTarget: QuestCaptureTarget? {
        if developerUnlockMode {
            return .curatedSpot(selectedSpot)
        }
        if let nearestUnlockedCuratedSpot {
            return .curatedSpot(nearestUnlockedCuratedSpot)
        }
        if let resolvedArea {
            return .freeform(
                resolvedArea: resolvedArea,
                latitude: locationManager.currentLocation?.coordinate.latitude,
                longitude: locationManager.currentLocation?.coordinate.longitude
            )
        }
        return nil
    }

    private var currentProofStatus: QuestVerificationStatus {
        if developerUnlockMode { return .developer }
        return currentCaptureTarget != nil ? .verified : .unverified
    }

    private var currentDistanceMeters: Double? {
        guard let nearestUnlockedCuratedSpot else { return nil }
        return locationManager.distance(to: nearestUnlockedCuratedSpot)
    }

    /// プレビュー全体を覆う「決定的な」ブロック状態。この2つだけは全画面で強く見せる。
    /// それ以外(範囲外・シミュレーター・準備完了・保存済み)は下のstatusCard 1枚に集約する。
    private enum BlockingState: Equatable {
        case cameraDenied
        case locationDenied
        case none
    }

    private var blockingState: BlockingState {
        if isCameraPermissionBlocking { return .cameraDenied }
        if isLocationPermissionBlocking { return .locationDenied }
        return .none
    }

    /// place chip等、「今どことして記録されるか」の表示名。curated Spot内なら
    /// そのSpot名、Spot外でも現在地解決済みならそのarea名、解決中は静かな待機文言。
    /// SPOT MODE/UNLOCK CHANCE等のゲームUIにはしない(Product Spec 17章)。
    private var effectivePlaceName: String {
        if developerUnlockMode { return selectedSpot.name }
        if let nearestUnlockedCuratedSpot { return nearestUnlockedCuratedSpot.name }
        if let resolvedArea { return resolvedArea.areaName }
        return isResolvingArea ? "現在地を確認しています…" : "現在地"
    }

    private var effectivePrefectureId: String? {
        if developerUnlockMode { return selectedSpot.prefectureId }
        if let nearestUnlockedCuratedSpot { return nearestUnlockedCuratedSpot.prefectureId }
        return resolvedArea?.prefectureId
    }

    private var selectedPrefectureColor: Color {
        guard let effectivePrefectureId else { return PictriFinalTheme.dormant }
        return PictriFinalTheme.memoryColor(for: effectivePrefectureId)
    }

    /// QuestDualPhotoComposer.compose(spot:)へ渡す表示専用のQuestSpot。compose()は
    /// 焼き込みキャプション(地名テキスト)にspot.englishNameを使うため、curated Spot
    /// 圏外(Anywhere Capture)でも実際に解決した場所名が写真へ正しく焼き込まれるよう、
    /// selectedSpot固定ではなくcurrentCaptureTargetと同じ優先順位で解決する。
    /// 保存はしない、この関数呼び出しの一瞬だけ使う使い捨ての値。
    private var effectiveSpotForComposition: QuestSpot {
        if developerUnlockMode { return selectedSpot }
        if let nearestUnlockedCuratedSpot { return nearestUnlockedCuratedSpot }
        if let resolvedArea {
            return QuestSpot(
                id: "freeform_preview",
                prefectureId: resolvedArea.prefectureId,
                name: resolvedArea.areaName,
                englishName: resolvedArea.areaName,
                areaName: resolvedArea.areaName,
                latitude: locationManager.currentLocation?.coordinate.latitude ?? 0,
                longitude: locationManager.currentLocation?.coordinate.longitude ?? 0,
                unlockRadiusMeters: 0,
                gridIndex: 0
            )
        }
        return selectedSpot
    }

    /// 現在地から都道府県を解決する(curated Spot radius外の時だけ必要)。
    /// 連続する位置更新のたびに再ジオコーディングしない(一度解決したらそのまま
    /// 使う、標準API・通信の節度ある利用)。Readyへ戻る(resetCapture)たびに
    /// リセットされ、新しい撮影サイクルで改めて解決される。
    private func resolveAreaIfNeeded(for location: CLLocation) {
        guard !developerUnlockMode,
              nearestUnlockedCuratedSpot == nil,
              resolvedArea == nil,
              !isResolvingArea else { return }

        isResolvingArea = true
        QuestAreaResolver.resolveArea(for: location) { area in
            DispatchQueue.main.async {
                self.resolvedArea = area
                self.isResolvingArea = false
            }
        }
    }

    var body: some View {
        // alignment: .topを明示。既定(.center)のままだと、reviewView/coloringMomentViewの
        // ように自然な高さがscreenと異なるViewを切り替えた時に、ブロック全体が上下中央へ
        // 再配置され、headerが画面上端からはみ出て見えなくなることがあったため
        // (Readyの`else`枝は結果的に画面いっぱいに近い高さだったため症状が出ていなかった)。
        ZStack(alignment: .top) {
            // Final Design Handoffの「paper shell + dark camera viewport」に合わせる。
            // 実際の映像が乗るのはcameraPanel(cameraLayer)の中だけで、そこはdark/blackのまま。
            // 画面全体をdark navyにしていた以前の見た目は、Home/Mapがpaper基調な中で
            // Cameraだけ別アプリのように断絶して見える原因だったため、シェル側はpaperへ揃える
            // (safe area構造・撮影ロジック・validation・保存導線は無変更)。
            PictriFinalTheme.paper.ignoresSafeArea()

            if hasSaved {
                // Design Spec E「色がつく瞬間」。previewImage/hasSavedはいずれも既存@State、
                // 新しいSource of Truthは追加していない。
                coloringMomentView
            } else if let previewImage {
                // Design Spec D「Capture Confirmation」。ライブのcameraPanel(dark viewport)
                // ではなく、既存のQuestDualPhotoComposer.compose結果(前後2枚が既に1枚の
                // 画像として合成済み・内カメラ側のpaper枠も焼き込み済み)をPictriPhotoPrintで
                // 「1枚の印刷物」として見せる。compose()自体は無変更。
                reviewView(previewImage: previewImage)
            } else if isQuotaExhausted {
                // Product Requirement(今回追加)「FREE=1日3 Memoryまで」を使い切った状態。
                // 「Cameraを完全に使えない謎画面にしない」の通り、Cameraの外側の枠組み
                // (閉じる導線・場所chip)はReadyと共通のcameraHeaderのまま、中身だけ
                // 「今日の3枚を撮った」+Premium導線に差し替える(撮影ロジックには一切触れない)。
                quotaExhaustedView
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    cameraHeader(showQuotaBadge: true)
                    cameraPanel

                    // Anywhere Capture Phaseにより、以前ここにあった「あと120m」という
                    // distanceのカウントダウン表示は前提(=Spot近接でCameraがgateされる)
                    // ごと廃止した。「今どこ扱いになるか」はcameraHeaderのplace chip
                    // (effectivePlaceName)が既に静かに示しているため、同じ情報を
                    // この行で重複表示しない(既存原則「同じ情報を複数箇所で重複表示
                    // しない」に従う)。

                    #if DEBUG
                    // 以前はcameraPanel内(ライブ映像の上)に重ねていたQA用トグル。
                    // Final Designの想定要素ではないため、通常のcontrol群の下、
                    // `-pictriShowCameraDebugControls true`指定時だけ表示する目立たない
                    // 行へ移設した。機能(developerUnlockModeのbinding)自体は無変更。
                    if PictriVisualReview.showCameraDebugControls {
                        HStack(spacing: 8) {
                            Toggle("", isOn: $developerUnlockMode)
                                .labelsHidden()
                                .scaleEffect(0.6)
                            Text("開発用: 位置認証を無視")
                                .font(PictriTypography.mono(9, weight: .regular))
                                .foregroundStyle(PictriFinalTheme.inkFaint)
                        }
                        .accessibilityLabel("開発用: 位置認証を無視して撮影を解放")
                    }
                    #endif

                    cameraBottomArea
                }
                .padding(.horizontal, JQUI.sidePadding)
                .padding(.top, JQUI.screenTopPadding)
                .padding(.bottom, 14)
            }
        }
        .onAppear {
            cameraService.requestAndConfigure()

            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestPermission()
            }

            applyDebugScenarioIfRequested()
            #if DEBUG
            if let location = locationManager.currentLocation {
                resolveAreaIfNeeded(for: location)
            }
            applyDebugAutoSaveIfRequested()
            if PictriVisualReview.showPaywallOnAppear {
                showPaywall = true
            }
            #endif
        }
        .onDisappear {
            cameraService.stopSession()
        }
        .onReceive(locationManager.$currentLocation) { location in
            guard let location else { return }
            resolveAreaIfNeeded(for: location)
            #if DEBUG
            applyDebugAutoSaveIfRequested()
            #endif
        }
        #if DEBUG
        // resolveAreaIfNeededの逆ジオコーディングは非同期(ネットワーク)なため、
        // onReceiveの中で同期的にapplyDebugAutoSaveIfRequested()を呼んだ時点では
        // まだresolvedAreaが確定していないことがある。解決が完了した瞬間にも
        // 改めて自動保存を試すため、resolvedAreaの変化にも反応させる。
        .onChange(of: resolvedArea) {
            applyDebugAutoSaveIfRequested()
        }
        #endif
        .sheet(isPresented: $showPaywall) {
            PictriPaywallSheet(entitlementStore: entitlementStore)
        }
    }

    /// Design Spec「Header: close(left), place chip(paper, ink border, corner-tag radius,
    /// violet pin) centered, ... 44pt spacer right」。以前の大きな左寄せtitle(28pt)から、
    /// 中央寄せの小さなchipへ変更した。閉じる導線(closeCamera)は無変更。
    /// 右側の44pt spacerは、FREEユーザーがReady中だけ「あと2」のような控えめな
    /// quota表示に置き換わる(Core UX Simplification Phase D)。PREMIUM/レビュー中/
    /// クォータ枯渇画面では従来通り空のspacerのまま(安っぽい「∞」表示等は出さない)。
    private func cameraHeader(showQuotaBadge: Bool = false) -> some View {
        HStack(alignment: .center) {
            Button(action: closeCamera) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(PictriFinalTheme.ink)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("カメラを閉じてホームへ戻る")

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Image(systemName: "mappin")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PictriFinalTheme.accent)
                Text(effectivePlaceName)
                    .font(PictriTypography.body(13, weight: .bold))
                    .foregroundStyle(PictriFinalTheme.ink)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(PictriFinalTheme.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(PictriFinalTheme.ink, lineWidth: 1)
            }

            Spacer(minLength: 0)

            Group {
                if showQuotaBadge, let remaining = remainingCapturesToday {
                    Text("あと\(remaining)")
                        .font(PictriTypography.mono(11, weight: .bold))
                        .foregroundStyle(PictriFinalTheme.inkSoft)
                        .frame(width: 44, height: 44)
                        .accessibilityLabel("今日はあと\(remaining)回撮影できます")
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }
            }
        }
    }

    /// Cameraからいつでも確実に戻れるようにする唯一の出口。
    /// previewImage/hasSaved/capturePhase/blockingStateなど、いかなる状態にも依存させない。
    /// 撮影中(isCapturingSequence)のシーケンスIDだけ更新して安全に打ち切ってから戻る。
    private func closeCamera() {
        resetCapture()
        selectedTab = .home
    }

    /// Design Spec「Large preview 3/4, radius 10, 10px side margins」。previewImageが
    /// あるとき(Review以降)はこのpanelではなく`reviewView`側の`PictriPhotoPrint`を使うため、
    /// ここはライブのカメラ映像(Ready/Countdown/dual capture中)専用。
    private var cameraPanel: some View {
        ZStack {
            cameraLayer

            if blockingState == .none {
                primaryBadge
                pipView
            }

            switch blockingState {
            case .cameraDenied:
                PictriPermissionBlock(kind: .cameraDenied)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black.opacity(0.62))
            case .locationDenied:
                PictriPermissionBlock(kind: .locationDenied)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black.opacity(0.58))
            case .none:
                EmptyView()
            }

            if let countdownNumber {
                countdownOverlay(number: countdownNumber)
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(
            RoundedRectangle(
                cornerRadius: JQUI.panelCornerRadius,
                style: .continuous
            )
        )
        // 以前はdark navyのシェル上に浮かせるための白いglow(fill/stroke)だったが、
        // paperシェルの上では暗いviewportそのものが十分に主役として際立つため、
        // 縁取りは印刷物にdark写真が挟まっているような控えめなink系hairlineに変える。
        .overlay {
            RoundedRectangle(
                cornerRadius: JQUI.panelCornerRadius,
                style: .continuous
            )
            .stroke(PictriFinalTheme.line, lineWidth: 1)
        }
        // ink反転(dark premium統一)後もshadowは暗い側を参照する(paperDeep)。
        // paperDeepはmode-awareになったため(light modeでは明るい)、shadowは常に
        // 暗い側を返すPictriDarkTheme.shadowColorを参照する。
        .shadow(color: PictriDarkTheme.shadowColor, radius: 14, x: 0, y: 6)
    }

    private var cameraLayer: some View {
        ZStack {
            if cameraService.isCameraAvailable && !cameraService.permissionDenied {
                QuestCameraPreview(session: cameraService.session)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                demoCameraBackground
            }

            LinearGradient(
                colors: [
                    .black.opacity(0.34),
                    .black.opacity(0.02),
                    .black.opacity(0.60)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 実カメラが無い(主にSimulator)時のプレースホルダー。以前は灰色の矩形が
    /// 縦に並んでおり、スケルトンローディングのような「壊れている画面」に見えるという
    /// 指摘があったため、水平線と淡いwarmトーンだけの写真風の見た目に差し替えた。
    private var demoCameraBackground: some View {
        ZStack {
            // 旧: espresso/brown castのハードコードRGB → Visual Direction
            // Consolidationでcool-neutral graphiteへ統一。accentのwashは
            // 最上部のみ薄く残し、面そのものはmode-awareなsurfaceトークンにする。
            LinearGradient(
                colors: [
                    PictriDarkTheme.accent.opacity(0.16),
                    PictriDarkTheme.surfaceOverlay,
                    PictriDarkTheme.surfaceBase
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            GeometryReader { proxy in
                Rectangle()
                    .fill(.white.opacity(0.12))
                    .frame(width: proxy.size.width, height: 1)
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.58)

                LinearGradient(
                    colors: [.clear, PictriTheme.warm.opacity(0.07)],
                    startPoint: UnitPoint(x: 0.5, y: 0.58),
                    endPoint: .bottom
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Core UX Simplification(Phase C)。以前は「①さきに撮る」/「①撮影ずみ」という
    /// 文言バッジだったが、「撮影順序は視覚的に理解させる。必要であれば1・2程度の小さな
    /// order markだけ使用」の方針により、数字だけの小さな丸バッジへ簡略化した
    /// (説明文はaccessibilityLabelとしてVoiceOverには引き続き伝える)。
    /// frontImage/backImageというロジック側の既存stateを見るだけ、新しいstateは追加しない。
    private var primaryBadge: some View {
        let hasCapturedAny = frontImage != nil || backImage != nil
        return Text("1")
            .font(PictriTypography.mono(13, weight: .bold))
            .foregroundStyle(PictriFinalTheme.onAccent)
            .frame(width: 26, height: 26)
            .background(PictriFinalTheme.accent)
            .clipShape(Circle())
            .opacity(hasCapturedAny ? 0.45 : 1)
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityHidden(isCapturingSequence)
            .accessibilityLabel(hasCapturedAny ? "1枚目 撮影ずみ" : "1枚目 先に撮る側")
    }

    /// PICTRI_COMPONENT_INVENTORY.md「CameraPiP」の実装。94×124・2px paper border・
    /// radius8・固定top-right。実装は単一のAVCaptureSessionで前後カメラを順番に切り替える
    /// 構造(cameraService)のため、撮影前の同時ライブ映像は表示できない
    /// (この制約は最終報告に記載)。その代わりComponent Inventoryが定義する状態
    /// (idle=②じどう、capturing=memory-color ring+②撮影中…)を、既存の
    /// isCapturingSequence/frontImage/backImageからそのまま導出して見せる。
    /// タップでのswitchCamera()は既存ロジックのまま(Design Spec「tap PiP...exchanges
    /// which side is①」)。
    /// Core UX Simplification(Phase C)。「②じどう」「②撮影中…」という文言は廃止し、
    /// 数字バッジ(primaryBadgeと対の視覚言語)+アイコンだけで「ここが2番目・タップで
    /// 入れ替え可能」を伝える。以前bottom部に独立していた「内へ/外へ」切り替えボタンは
    /// このPiP タップと機能が完全に重複していたため削除し(Core UX Simplification #5)、
    /// カメラ切り替えの入口をここ1箇所に統一した。switchCamera()自体は無変更。
    private var pipView: some View {
        let hasCapturedAny = frontImage != nil || backImage != nil
        let isCapturingSecondLeg = isCapturingSequence && hasCapturedAny

        return ZStack {
            // ink反転(dark premium統一)後、ink単体をfillに使うと明るいivoryになって
            // しまうため、PIPのプレースホルダー面は明示的に暗いdormantを使う。
            if isCapturingSecondLeg {
                ZStack {
                    PictriFinalTheme.dormant
                    ProgressView().tint(PictriFinalTheme.ink)
                }
            } else if let frontImage {
                Image(uiImage: frontImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    PictriFinalTheme.dormant
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(PictriFinalTheme.ink.opacity(0.85))
                }
            }
        }
        .frame(width: 94, height: 124)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isCapturingSecondLeg ? selectedPrefectureColor : PictriFinalTheme.line, lineWidth: isCapturingSecondLeg ? 3 : 2)
        }
        .overlay(alignment: .topLeading) {
            if !isCapturingSecondLeg {
                Text("2")
                    .font(PictriTypography.mono(11, weight: .bold))
                    .foregroundStyle(PictriFinalTheme.ink)
                    .frame(width: 22, height: 22)
                    .background(PictriFinalTheme.paper)
                    .clipShape(Circle())
                    .padding(6)
            }
        }
        .onTapGesture {
            guard !isCapturingSequence else { return }
            cameraService.switchCamera()
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .accessibilityLabel(
            isCapturingSecondLeg
                ? "2枚目 撮影中"
                : (cameraService.currentPosition == .front ? "2枚目、外カメラに切り替え" : "2枚目、内カメラに切り替え")
        )
    }

    private func countdownOverlay(number: Int) -> some View {
        ZStack {
            Color.black.opacity(0.22)

            Text("\(number)")
                .font(.system(size: 118, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
                .transition(.scale.combined(with: .opacity))
        }
    }

    private func startDualCapture() {
        guard canCapture, !isCapturingSequence else {
            return
        }

        let runID = UUID()
        captureRunID = runID

        previewImage = nil
        frontImage = nil
        backImage = nil
        hasSaved = false
        isCapturingSequence = true

        let firstPosition = cameraService.currentPosition
        let secondPosition = oppositePosition(of: firstPosition)

        cameraService.switchCamera(to: firstPosition) {
            guard isCurrentCapture(runID) else { return }

            runCountdown(
                phase: countdownPhase(for: firstPosition),
                runID: runID
            ) {
                capturePosition(
                    firstPosition,
                    then: secondPosition,
                    runID: runID
                )
            }
        }
    }

    private func capturePosition(
        _ position: AVCaptureDevice.Position,
        then nextPosition: AVCaptureDevice.Position,
        runID: UUID
    ) {
        guard isCurrentCapture(runID) else { return }

        capturePhase = capturingPhase(for: position)

        captureImageOrDemo(isFront: position == .front) { image in
            guard isCurrentCapture(runID) else { return }

            storeCapturedImage(
                image,
                for: position
            )

            cameraService.switchCamera(to: nextPosition) {
                guard isCurrentCapture(runID) else { return }

                runCountdown(
                    phase: countdownPhase(for: nextPosition),
                    runID: runID
                ) {
                    captureFinalPosition(
                        nextPosition,
                        runID: runID
                    )
                }
            }
        }
    }

    private func captureFinalPosition(
        _ position: AVCaptureDevice.Position,
        runID: UUID
    ) {
        guard isCurrentCapture(runID) else { return }

        capturePhase = capturingPhase(for: position)

        captureImageOrDemo(isFront: position == .front) { image in
            guard isCurrentCapture(runID) else { return }

            storeCapturedImage(
                image,
                for: position
            )

            let finalBackImage = backImage ?? QuestDemoPhotoMaker.makePhoto(
                spot: selectedSpot,
                isFrontCamera: false
            )

            let finalImage = QuestDualPhotoComposer.compose(
                backImage: finalBackImage,
                frontImage: frontImage,
                spot: effectiveSpotForComposition
            )

            previewImage = finalImage
            capturePhase = .preview
            isCapturingSequence = false
            countdownNumber = nil
        }
    }

    private func storeCapturedImage(
        _ image: UIImage,
        for position: AVCaptureDevice.Position
    ) {
        if position == .front {
            frontImage = image
        } else {
            backImage = image
        }
    }

    private func oppositePosition(
        of position: AVCaptureDevice.Position
    ) -> AVCaptureDevice.Position {
        position == .front ? .back : .front
    }

    private func countdownPhase(
        for position: AVCaptureDevice.Position
    ) -> QuestDualCapturePhase {
        position == .front ? .countingFront : .countingBack
    }

    private func capturingPhase(
        for position: AVCaptureDevice.Position
    ) -> QuestDualCapturePhase {
        position == .front ? .capturingFront : .capturingBack
    }

    private func captureImageOrDemo(
        isFront: Bool,
        completion: @escaping (UIImage) -> Void
    ) {
        if cameraService.isCameraAvailable && !cameraService.permissionDenied {
            cameraService.capturePhoto { image in
                if let image {
                    completion(image)
                } else {
                    completion(
                        QuestDemoPhotoMaker.makePhoto(
                            spot: selectedSpot,
                            isFrontCamera: isFront
                        )
                    )
                }
            }
        } else {
            completion(
                QuestDemoPhotoMaker.makePhoto(
                    spot: selectedSpot,
                    isFrontCamera: isFront
                )
            )
        }
    }

    private func runCountdown(
        phase: QuestDualCapturePhase,
        runID: UUID,
        completion: @escaping () -> Void
    ) {
        guard isCurrentCapture(runID) else { return }

        capturePhase = phase
        countdownNumber = 3

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard isCurrentCapture(runID) else { return }
            countdownNumber = 2
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard isCurrentCapture(runID) else { return }
            countdownNumber = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            guard isCurrentCapture(runID) else { return }
            countdownNumber = nil
            completion()
        }
    }

    private func isCurrentCapture(_ runID: UUID) -> Bool {
        isCapturingSequence && captureRunID == runID
    }

    private func resetCapture() {
        captureRunID = UUID()
        previewImage = nil
        frontImage = nil
        backImage = nil
        hasSaved = false
        isCapturingSequence = false
        isSavingMemory = false
        countdownNumber = nil
        capturePhase = .idle
        // Anywhere Capture Phase: 新しい撮影サイクルでは現在地が変わっている可能性が
        // あるため、前回解決したAreaを持ち越さない(次のonReceiveで改めて解決される)。
        resolvedArea = nil
        isResolvingArea = false
        savedCaptureTarget = nil
        wasNewAreaAtSave = false
        wasNewSpotAtSave = false
    }

    /// 「これにする」ボタンの本体。DEBUG専用のAuto-save QAフック
    /// (`-pictriCameraAutoSave`)からも同じ経路を呼べるよう関数として独立させてある
    /// (本番の保存タップと全く同じコードパスを通す、QA用の別ロジックを作らない)。
    private func performSave(previewImage: UIImage) {
        // Pictri Core Invariant 4「同じ保存操作が二重発火してもquotaが2減っては
        // いけない」。保存処理自体は同期的だが、二重タップがこの1回のクロージャ
        // 実行の前に積まれるケースへの防衛として、実行中は即座にガードを立てる。
        guard !isSavingMemory else { return }

        // Product Spec 7章「安全側」原則: 位置検証できないMemoryはArea/Spot
        // unlockしない。ここでは検証できないMemory自体を保存しない
        // (currentCaptureTargetがnil=curated Spot圏内でも現在地解決済みでも
        // ない)。ボタン自体も.disabled(currentCaptureTarget == nil)で
        // 既に無効化されているため、通常この分岐には到達しない防衛的guard。
        guard let target = currentCaptureTarget else { return }
        isSavingMemory = true

        // Coloring Momentの文言分岐(Product Spec 18章)用に、保存が実際に
        // 状態を変える"前"の時点でスナップショットを取る。
        let isNewArea = !memoryStore.visitedPrefectureIds.contains(target.prefectureId)
        let isNewSpot = target.spotId.hasPrefix("freeform_")
            ? false
            : !memoryStore.memoryPhotos.contains(where: { $0.spotId == target.spotId })

        // Pictri Core Invariant 5「保存失敗時はquotaを消費しない」。
        // save()の戻り値(実際にDocumentsへ書き込めたか)を見てからのみ
        // recordCaptureSaved()を呼ぶ(「保存成功→quota消費確定」の順序)。
        let didSave = memoryStore.save(
            image: previewImage,
            target: target,
            verificationStatus: currentProofStatus,
            verifiedDistanceMeters: currentDistanceMeters,
            outerOnlyImage: backImage,
            selfieImage: frontImage
        )

        guard didSave else {
            isSavingMemory = false
            return
        }

        dailyCaptureAllowance.recordCaptureSaved()
        savedCaptureTarget = target
        wasNewAreaAtSave = isNewArea
        wasNewSpotAtSave = isNewSpot
        withAnimation(.easeInOut(duration: 0.22)) {
            hasSaved = true
        }
    }

    #if DEBUG
    /// `-pictriCameraAutoSave true` 指定時、currentCaptureTargetが解決/確定し次第
    /// (curated Spot圏内は即座、Spot外は逆ジオコーディング完了後)、実写真撮影を
    /// 経ずにデモ画像でperformSave()を自動実行する。GUIタップ自動化が本環境では
    /// 不安定なため、全国を実際に移動できないPoC QAで「保存の実効果」
    /// (Area/Spot unlock、Memories/Vlogへの反映)を、本番と全く同じ保存経路
    /// (memoryStore.save)を通して検証するための仕組み。Production buildには
    /// この関数自体が存在しない(#if DEBUG)。
    private func applyDebugAutoSaveIfRequested() {
        guard PictriVisualReview.cameraAutoSave else { return }
        guard !hasSaved, previewImage == nil else { return }
        guard let target = currentCaptureTarget else { return }

        let demoBack = QuestDemoPhotoMaker.makePhoto(spot: selectedSpot, isFrontCamera: false)
        let demoFront = QuestDemoPhotoMaker.makePhoto(spot: selectedSpot, isFrontCamera: true)
        let composite = QuestDualPhotoComposer.compose(backImage: demoBack, frontImage: demoFront, spot: effectiveSpotForComposition)

        frontImage = demoFront
        backImage = demoBack
        previewImage = composite
        _ = target // targetはcurrentCaptureTargetから再取得される(performSave内)。ここでは解決済みか確認するためだけに使う。
        performSave(previewImage: composite)
    }
    #endif

    /// `-pictriCameraScenario ready|review|saved` で撮影前後の主要な見た目を直接スクショ確認できるようにする。
    /// DEBUG限定。実際のカメラセッションや `memoryStore.save()`(UserDefaults/Documents書き込み)には
    /// 一切触れず、既存のデモ画像生成(`QuestDemoPhotoMaker`)を使って画面の状態だけを再現する。
    private func applyDebugScenarioIfRequested() {
        #if DEBUG
        guard let scenario = PictriVisualReview.cameraScenario else { return }

        switch scenario {
        case .ready:
            break

        case .review, .saved:
            let demoBack = QuestDemoPhotoMaker.makePhoto(spot: selectedSpot, isFrontCamera: false)
            let demoFront = QuestDemoPhotoMaker.makePhoto(spot: selectedSpot, isFrontCamera: true)

            backImage = demoBack
            frontImage = demoFront
            previewImage = QuestDualPhotoComposer.compose(
                backImage: demoBack,
                frontImage: demoFront,
                spot: selectedSpot
            )
            capturePhase = .preview
            hasSaved = (scenario == .saved)
        }
        #endif
    }

    /// Design Spec「Control row: flash · 80pt shutter(3px paper ring, violet core) ·
    /// camera swap」。flash controlは実装していない(下記報告)。twoStepIndicator(景色/表情
    /// pill)は「no decorative motifs beyond the place chip and gate hint」という制約に
    /// 抵触するため今回廃止し、進捗はbadge①/PiPの状態表現へ一本化した。
    private var cameraBottomArea: some View {
        captureControls
    }

    /// Core UX Simplification(Phase C)。以前ここにあった「内へ/外へ」カメラ切り替え
    /// ボタンは、pipView タップによる切り替えと機能が完全に重複していたため削除した
    /// (Camera削除候補#5「「内へ」独立ボタン」)。shutterだけが主CTAとして中央に残る。
    /// シャッターの「core」だけが「唯一の意味あるaccent」(violet)を持ち、撮影中は
    /// selectedPrefectureColor(実データ)に変わる(Design Spec「shutter core turns
    /// memory color and is disabled」)。カメラ切り替えロジック(switchCamera)自体は無変更。
    private var captureControls: some View {
        Button {
            startDualCapture()
        } label: {
            Circle()
                .fill(shutterCoreColor)
                .frame(width: 80, height: 80)
                .overlay {
                    Circle().stroke(PictriFinalTheme.paper, lineWidth: 3)
                }
                .overlay {
                    Circle().stroke(PictriFinalTheme.ink.opacity(0.14), lineWidth: 1)
                }
                .shadow(color: canCapture ? PictriFinalTheme.accent.opacity(0.30) : .clear, radius: 12)
                .overlay {
                    if isCapturingSequence {
                        ProgressView()
                            .tint(PictriFinalTheme.onAccent)
                    }
                }
        }
        .disabled(!canCapture || isCapturingSequence)
        .accessibilityLabel("外カメラと内カメラで2枚撮影する")
        .accessibilityHint(canCapture ? "" : "現在は撮影できません")
        .frame(maxWidth: .infinity)
        .frame(height: 96)
    }

    private var shutterCoreColor: Color {
        if isCapturingSequence { return selectedPrefectureColor }
        return canCapture ? PictriFinalTheme.accent : PictriFinalTheme.dormant
    }

    /// Product Requirement(今回追加)「FREE=1日3 Memoryまで」を使い切った時の画面。
    /// 「Cameraを完全に使えない謎画面にしない」の通り、閉じる導線・場所chipはReadyと
    /// 共通のcameraHeaderのまま、ライブのcameraPanelだけを「今日の3枚」+Premium導線に
    /// 差し替える。撮影ロジック(startDualCapture等)には一切触れない
    /// (このView自体がcanCapture=falseの状態でshutterを見せないための専用画面)。
    private var quotaExhaustedView: some View {
        VStack(alignment: .leading, spacing: 14) {
            cameraHeader()

            VStack(spacing: 18) {
                Spacer(minLength: 10)

                Image(systemName: "checkmark.seal")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(PictriFinalTheme.inkFaint)

                VStack(spacing: 6) {
                    Text("今日の3枚を撮りました")
                        .font(PictriTypography.display(18))
                        .foregroundStyle(PictriFinalTheme.ink)

                    Text("続きはまた明日")
                        .font(PictriTypography.body(12, weight: .medium))
                        .foregroundStyle(PictriFinalTheme.inkSoft)
                }
                .multilineTextAlignment(.center)

                Spacer(minLength: 10)

                Button {
                    showPaywall = true
                } label: {
                    Text("もっと残す")
                        .font(PictriTypography.body(15, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .foregroundStyle(PictriFinalTheme.onAccent)
                        .background(PictriFinalTheme.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, JQUI.sidePadding)
            .padding(.top, 40)
        }
        .padding(.horizontal, JQUI.sidePadding)
        .padding(.top, JQUI.screenTopPadding)
    }

    /// Design Spec D「Capture Confirmation」。Top line: place・city + mono timestamp。
    /// pairはPictriPhotoPrintで「1枚の印刷物」として見せる(compose()が既に内カメラ側の
    /// paper枠を焼き込み済みのため、実際の合成比率1080:1920をそのままaspectRatioに渡す
    /// ことで、outer paper padding以外で二重にトリミングしない)。
    /// 「撮りなおす」「これにする」の意味・保存処理(memoryStore.save)は無変更。
    private func reviewView(previewImage: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            cameraHeader()

            // 場所名・日付はheaderのplace chipと、compose()が写真自体に焼き込み済みの
            // キャプションの2箇所に既に出ている。以前はここに3箇所目のテキスト行として
            // 同じ情報(場所名+日付)を重複表示していたため、Core UX Simplificationで削除した
            // (「同じ情報をcard/chip/caption/badgeで重複表示しない」)。
            //
            // サイズはcontentクロージャの内側(Imageに直接)で確定させる。PictriPhotoPrintの
            // 呼び出し結果に外側から.frame(maxWidth:/maxHeight:)を連ねると、内部の
            // .aspectRatio(_, contentMode: .fill)が原因でVStackの理想サイズ計算が壊れ、
            // cameraHeaderなど「前にある」兄弟Viewが幅0になって消える(Xcode 26 SwiftUIで再現)。
            PictriPhotoPrint(aspectRatio: 1080.0 / 1920.0) {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 260, height: 260 * 1920.0 / 1080.0)
                    .clipped()
            }

            Spacer(minLength: 4)

            HStack(spacing: 12) {
                Button {
                    resetCapture()
                } label: {
                    Text("撮りなおす")
                        .font(PictriTypography.body(14, weight: .bold))
                        .foregroundStyle(PictriFinalTheme.inkSoft)
                        .underline()
                }
                .frame(minHeight: 44)

                Button {
                    performSave(previewImage: previewImage)
                } label: {
                    Text("これにする")
                        .font(PictriTypography.body(15, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .foregroundStyle(PictriFinalTheme.onAccent)
                        .background(PictriFinalTheme.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isSavingMemory || currentCaptureTarget == nil)
            }

            // currentCaptureTargetがnilなのは「まだ現在地を解決できていない」時だけ
            // (curated Spot圏内なら即座に、Spot外でも大抵はonReceiveの逆ジオコーディングが
            // この画面に到達するまでに完了している)。SPOT MODE等のゲームUIにはせず、
            // ボタンが押せない理由を1行だけ静かに添える。
            if currentCaptureTarget == nil {
                Text("位置情報を確認しています…")
                    .font(PictriTypography.body(11, weight: .medium))
                    .foregroundStyle(PictriFinalTheme.inkFaint)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.horizontal, JQUI.sidePadding)
        .padding(.top, JQUI.screenTopPadding)
        .padding(.bottom, 14)
    }

    private var coloringPrefectureDisplayName: String {
        guard let prefectureId = savedCaptureTarget?.prefectureId else { return "" }
        return mockQuestPrefectures.first { $0.id == prefectureId }?.name
            ?? questPrefectureShapes.first { $0.id == prefectureId }?.name
            ?? prefectureId
    }

    /// Product Spec 18章「Spot Unlock Moment」。Area初訪問/新Spot unlock/どちらでもない
    /// 通常のAnywhere Captureで文言を分ける(過剰gamificationを避けつつ、実際に起きた
    /// ことと違う文言を出さないため)。両方初の場合は「Area初訪問」の文言を優先し、
    /// 2枚のモーダルを連打しない形で1つの流れへ統合する。
    private var coloringHeadlineText: String {
        guard savedCaptureTarget != nil else { return "" }
        if wasNewAreaAtSave {
            return "\(coloringPrefectureDisplayName)に色がついた"
        }
        if wasNewSpotAtSave {
            return "\(savedCaptureTarget?.areaName ?? "")を残した"
        }
        return "今日のひとつが増えた"
    }

    private var coloringSublineText: String {
        guard let target = savedCaptureTarget else { return "" }
        if wasNewAreaAtSave {
            return "\(memoryStore.visitedPrefectureIds.count)つめの県・\(target.areaName)のこの1枚から"
        }
        if wasNewSpotAtSave {
            return "\(coloringPrefectureDisplayName)のコレクションがまた増えた"
        }
        return "\(target.areaName)のこの1枚から"
    }

    /// Design Spec E「色がつく瞬間」。写真は画面に残したまま、県shapeが実際に
    /// memory colorへ染まる(PictriCollectionPrefecturePathを再利用、Map/Homeと同じ
    /// geometry)。confetti/particle/neon等の演出は使わず、shapeのscale-inだけで表現する
    /// (pictri-bloom: 0.25→1.04→1)。「ちずでみる」「つづけて撮る」以外の第三の
    /// ボタン(以前あった「メモリーで確認する」ショートカット)はInteraction Flowの
    /// 色がつく瞬間が明示的にこの2択のみと定義しているため、今回は持たせていない
    /// (pendingExploreSpotIdの設定は行わなくなった、詳細は最終報告)。
    private var coloringMomentView: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 10)

            if let previewImage {
                PictriPhotoPrint(aspectRatio: 1080.0 / 1920.0) {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                }
                .frame(maxWidth: 220)
            }

            coloringPrefectureShape
                .frame(width: 96, height: 96)

            VStack(spacing: 6) {
                Text(coloringHeadlineText)
                    .font(PictriTypography.display(20))
                    .foregroundStyle(PictriFinalTheme.ink)

                Text(coloringSublineText)
                    .font(PictriTypography.body(12, weight: .medium))
                    .foregroundStyle(PictriFinalTheme.inkSoft)
            }
            .multilineTextAlignment(.center)

            Spacer(minLength: 10)

            VStack(spacing: 10) {
                Button {
                    selectedTab = .map
                } label: {
                    Text("ちずでみる")
                        .font(PictriTypography.body(15, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .foregroundStyle(PictriFinalTheme.onAccent)
                        .background(PictriFinalTheme.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    resetCapture()
                } label: {
                    Text("つづけて撮る")
                        .font(PictriTypography.body(14, weight: .bold))
                        .foregroundStyle(PictriFinalTheme.inkSoft)
                }
                .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, JQUI.sidePadding)
        .padding(.top, JQUI.screenTopPadding)
        .padding(.bottom, 24)
    }

    @State private var coloringShapeAppeared = false

    /// 県shapeは日本全体Map/Homeの「さいきん色づいた場所」と全く同じ
    /// QuestPrefectureGeometry.points(for:) + PictriCollectionPrefecturePathを再利用する
    /// (Camera専用のfake shapeを新しく作らない)。
    private var coloringPrefectureShape: some View {
        GeometryReader { proxy in
            if let prefectureId = savedCaptureTarget?.prefectureId,
               let shape = questPrefectureShapes.first(where: { $0.id == prefectureId }) {
                let points = QuestPrefectureGeometry.points(for: shape)
                let xs = points.map(\.x)
                let ys = points.map(\.y)
                let minX = xs.min() ?? 0
                let minY = ys.min() ?? 0
                let width = max((xs.max() ?? 1) - minX, 1)
                let height = max((ys.max() ?? 1) - minY, 1)
                let pad: CGFloat = 4
                let scale = min((proxy.size.width - pad * 2) / width, (proxy.size.height - pad * 2) / height)
                let offsetX = (proxy.size.width - width * scale) / 2 - minX * scale
                let offsetY = (proxy.size.height - height * scale) / 2 - minY * scale

                PictriCollectionPrefecturePath(points: points, scale: scale, offsetX: offsetX, offsetY: offsetY)
                    .fill(PictriFinalTheme.memoryColor(for: prefectureId))
                    .scaleEffect(coloringShapeAppeared ? 1.0 : 0.25)
                    .opacity(coloringShapeAppeared ? 1.0 : 0.0)
                    .onAppear {
                        withAnimation(.spring(response: 0.52, dampingFraction: 0.68)) {
                            coloringShapeAppeared = true
                        }
                    }
                    .onDisappear {
                        coloringShapeAppeared = false
                    }
            }
        }
    }
}

enum QuestDemoPhotoMaker {
    static func makePhoto(
        spot: QuestSpot,
        isFrontCamera: Bool
    ) -> UIImage {
        let size = CGSize(width: 1080, height: 1920)

        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let cgContext = context.cgContext

            if isFrontCamera {
                drawFrontDemoScene(in: cgContext, size: size)
            } else {
                drawBackDemoScene(in: cgContext, size: size)
            }
        }
    }

    /// 外カメ(旅先の景色)側のplaceholder。斜めのライン/ドット格子は
    /// スケルトンローディングのような「壊れている画面」に見えるという指摘があったため廃止し、
    /// 砂浜〜空へ抜ける落ち着いたグラデーションと淡い水平線1本だけの写真風の見た目にした。
    /// 上部を明るい砂浜色にしていた当初案は、Camera内の小さいパネルでは目立たなかったが、
    /// Explore Detailのほぼ全画面表示では上半分が明るい暖色ブロブのように見えてしまい、
    /// Camera側と印象がズレていたため、全体を暗めで均一なトーンに寄せた。
    private static func drawBackDemoScene(in context: CGContext, size: CGSize) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        let skyColors = [
            UIColor(red: 0.32, green: 0.31, blue: 0.30, alpha: 1).cgColor,
            UIColor(red: 0.16, green: 0.20, blue: 0.25, alpha: 1).cgColor,
            UIColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1).cgColor
        ]

        let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: skyColors as CFArray,
            locations: [0, 0.55, 1]
        )!

        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: size.width / 2, y: 0),
            end: CGPoint(x: size.width / 2, y: size.height),
            options: []
        )

        context.setStrokeColor(UIColor.white.withAlphaComponent(0.14).cgColor)
        context.setLineWidth(2)
        let horizonY = size.height * 0.5
        context.move(to: CGPoint(x: 0, y: horizonY))
        context.addLine(to: CGPoint(x: size.width, y: horizonY))
        context.strokePath()

        context.setFillColor(UIColor.black.withAlphaComponent(0.16).cgColor)
        context.fill(
            CGRect(
                x: 0,
                y: size.height * 0.7,
                width: size.width,
                height: size.height * 0.3
            )
        )
    }

    /// 内カメ(表情)側のplaceholder。AI生成っぽい顔や人物の輪郭は描かず、
    /// 中央の暖色の柔らかいグローだけで「人がそこにいる」気配を表現する。
    /// 以前の「front camera」という透かし文字はデバッグ表示に見えるため削除した。
    private static func drawFrontDemoScene(in context: CGContext, size: CGSize) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        let baseColors = [
            UIColor(red: 0.16, green: 0.14, blue: 0.14, alpha: 1).cgColor,
            UIColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1).cgColor
        ]

        let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: baseColors as CFArray,
            locations: nil
        )!

        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: size.width, y: size.height),
            options: []
        )

        let glowColors = [
            UIColor(red: 0.85, green: 0.55, blue: 0.35, alpha: 0.28).cgColor,
            UIColor(red: 0.85, green: 0.55, blue: 0.35, alpha: 0.0).cgColor
        ]

        let glowGradient = CGGradient(
            colorsSpace: colorSpace,
            colors: glowColors as CFArray,
            locations: [0, 1]
        )!

        let glowCenter = CGPoint(x: size.width / 2, y: size.height * 0.42)

        context.drawRadialGradient(
            glowGradient,
            startCenter: glowCenter,
            startRadius: 0,
            endCenter: glowCenter,
            endRadius: size.width * 0.55,
            options: []
        )
    }
}

enum QuestDualPhotoComposer {
    /// composeが描画するキャンバスサイズと、内カメラ写真を焼き込む位置。
    /// MemoriesViewのExplore Detail(内カメラサムネイル)が同じ値を参照して
    /// 実写真から内カメラ領域だけを切り出すため、この2つの定数だけが「唯一の正解」になる。
    /// ここを変更すればサムネイル側も自動的に追従する(二重管理を避ける)。
    static let canvasSize = CGSize(width: 1080, height: 1920)
    static let frontInsetRect = CGRect(x: 58, y: 78, width: 286, height: 382)

    static func compose(
        backImage: UIImage,
        frontImage: UIImage?,
        spot: QuestSpot
    ) -> UIImage {
        let canvasSize = self.canvasSize

        let renderer = UIGraphicsImageRenderer(size: canvasSize)

        return renderer.image { context in
            let cgContext = context.cgContext

            drawAspectFill(
                image: backImage,
                in: CGRect(origin: .zero, size: canvasSize)
            )

            drawDarkGradient(
                context: cgContext,
                size: canvasSize
            )

            if let frontImage {
                drawFrontInset(
                    image: frontImage,
                    context: cgContext,
                    canvasSize: canvasSize
                )
            }

            drawLocationText(
                context: cgContext,
                canvasSize: canvasSize,
                spot: spot
            )
        }
    }

    private static func drawAspectFill(
        image: UIImage,
        in rect: CGRect
    ) {
        guard image.size.width > 0, image.size.height > 0 else {
            return
        }

        let imageRatio = image.size.width / image.size.height
        let rectRatio = rect.width / rect.height

        var drawSize: CGSize

        if imageRatio > rectRatio {
            drawSize = CGSize(
                width: rect.height * imageRatio,
                height: rect.height
            )
        } else {
            drawSize = CGSize(
                width: rect.width,
                height: rect.width / imageRatio
            )
        }

        let drawOrigin = CGPoint(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2
        )

        image.draw(
            in: CGRect(
                origin: drawOrigin,
                size: drawSize
            )
        )
    }

    private static func drawDarkGradient(
        context: CGContext,
        size: CGSize
    ) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        let colors = [
            UIColor.black.withAlphaComponent(0.00).cgColor,
            UIColor.black.withAlphaComponent(0.58).cgColor
        ] as CFArray

        let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: colors,
            locations: [0.45, 1.0]
        )!

        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: size.width / 2, y: size.height * 0.45),
            end: CGPoint(x: size.width / 2, y: size.height),
            options: []
        )
    }

    private static func drawFrontInset(
        image: UIImage,
        context: CGContext,
        canvasSize: CGSize
    ) {
        let insetRect = frontInsetRect

        context.saveGState()

        let path = UIBezierPath(
            roundedRect: insetRect,
            cornerRadius: 34
        )

        path.addClip()

        drawAspectFill(
            image: image,
            in: insetRect
        )

        context.restoreGState()

        UIColor.white.withAlphaComponent(0.88).setStroke()

        let border = UIBezierPath(
            roundedRect: insetRect,
            cornerRadius: 34
        )
        border.lineWidth = 6
        border.stroke()
    }

    private static func drawLocationText(
        context: CGContext,
        canvasSize: CGSize,
        spot: QuestSpot
    ) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        let dateText = dateFormatter.string(from: Date())
        let placeText = spot.englishName.lowercased()

        let boxRect = CGRect(
            x: 58,
            y: canvasSize.height - 290,
            width: min(560, canvasSize.width - 116),
            height: 158
        )

        let boxPath = UIBezierPath(
            roundedRect: boxRect,
            cornerRadius: 24
        )

        UIColor.white.withAlphaComponent(0.18).setFill()
        boxPath.fill()

        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 44, weight: .semibold),
            .foregroundColor: UIColor.white
        ]

        let placeAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 58, weight: .bold),
            .foregroundColor: UIColor.white
        ]

        dateText.draw(
            in: CGRect(
                x: boxRect.minX + 32,
                y: boxRect.minY + 25,
                width: boxRect.width - 64,
                height: 52
            ),
            withAttributes: dateAttributes
        )

        placeText.draw(
            in: CGRect(
                x: boxRect.minX + 32,
                y: boxRect.minY + 78,
                width: boxRect.width - 64,
                height: 72
            ),
            withAttributes: placeAttributes
        )
    }

    /// composeで焼き込んだ内カメラ領域(frontInsetRect)だけを、実際の画像サイズに合わせて
    /// 比率換算して切り出す。保存された写真は必ずcompose経由(CameraViewの保存ボタンのみが
    /// memoryStore.saveを呼ぶ)なので、この関数だけが「内カメラ画像の取り出し方」を知っていればよく、
    /// 呼び出し側(MemoriesViewのExplore Detail等)は座標を一切ハードコードしない。
    static func cropInnerCamera(from image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let scaleX = CGFloat(cgImage.width) / canvasSize.width
        let scaleY = CGFloat(cgImage.height) / canvasSize.height

        let cropRect = CGRect(
            x: frontInsetRect.origin.x * scaleX,
            y: frontInsetRect.origin.y * scaleY,
            width: frontInsetRect.width * scaleX,
            height: frontInsetRect.height * scaleY
        ).integral

        guard cropRect.width > 0, cropRect.height > 0,
              let cropped = cgImage.cropping(to: cropRect) else {
            return nil
        }

        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }
}
