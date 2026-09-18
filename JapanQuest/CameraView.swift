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
    /// CAMERA ROUND 1「CRITICAL FIX — MAP SELECTED SPOT」。MapのSpot Detailや
    /// 旧QuestSpotDetailViewから「ここで撮る」を明示的にタップした時だけtrueになる
    /// (ContentView側で管理、MapView.swiftの該当2箇所でtrueにする)。Cameraタブへ
    /// 直接入った場合や、前回セッションの使い残しspotIdでは常にfalseのまま。
    /// falseの場合は既存のnearestUnlockedCuratedSpot優先ロジックを一切変更しない。
    @Binding var selectedSpotIsExplicit: Bool

    @EnvironmentObject var memoryStore: QuestMemoryStore
    @EnvironmentObject var locationManager: QuestLocationManager
    @EnvironmentObject var entitlementStore: QuestEntitlementStore
    @EnvironmentObject var dailyCaptureAllowance: QuestDailyCaptureAllowance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

    /// CAMERA ROUND 1「3 CAMERA MODES」。Memory(QuestMemoryPhoto)へは永続化しない
    /// (既存Memory完全互換を優先、Schema変更なし)。CAMERA ROUND 2「MODE MEMORY」:
    /// `@AppStorage`でraw valueだけを保持し、Cameraを閉じて再度開いても・アプリを
    /// 再起動しても前回選んだModeを引き継ぐ(旅行中に毎回「標準」へ戻る煩わしさを
    /// 回避)。QuestMemoryPhoto等の保存Schemaには一切触れていない、UserDefaultsの
    /// キー1つだけの単純な追加。
    @AppStorage("pictriLastCameraStyle") private var cameraStyleRaw: String = PictriCameraStyle.standard.rawValue

    private var cameraStyle: PictriCameraStyle {
        get { PictriCameraStyle(rawValue: cameraStyleRaw) ?? .standard }
        nonmutating set { cameraStyleRaw = newValue.rawValue }
    }
    /// 片面だけの撮り直し中は既存のisCapturingSequenceフローを再利用しつつ、
    /// 「撮り直しているのはどちらの面か」だけを覚えておく(nilなら通常の
    /// 表→裏の連続撮影)。
    @State private var retakeOnlyPosition: AVCaptureDevice.Position?

    #if DEBUG
    /// CAMERA ROUND 3「REAL PHOTO QA HARNESS」。直近撮影の実際のpixel寸法を
    /// DEBUG QA表示のためだけに保持する(保存/圧縮ロジックには一切関与しない)。
    @State private var lastCaptureDebugInfo: String = "—"
    #endif

    /// CAMERA ROUND 3「STEP 20 TWO-SIDE FIELD UX」。Round 2 Reportで
    /// 「表撮影後、即座に裏カメラへ切り替わり止まって確認する間がない」と
    /// 報告された点への対応。「次へ」を押させる確認画面(禁止)は追加せず、
    /// 表撮影完了の直後だけ、ごく短い(420ms)チェックマークの見た目のpulseを
    /// 挟むことで「勝手にカメラが変わった」ではなく「1枚目が撮れて、次に進んだ」と
    /// 分かるようにする。撮影シーケンス自体は完全に自動のまま(タップ不要)。
    @State private var showSideCapturedPulse = false
    private let sideTransitionPauseSeconds: Double = 0.42

    /// CAMERA / POST IMAGING ROUND「PART 7 — TAP TO FOCUS」。tapされたlayer座標
    /// (cameraLayer自身の座標系)を保持し、短いindicatorを表示してから自動で消す。
    @State private var focusIndicatorPoint: CGPoint?
    @State private var focusIndicatorToken = UUID()

    /// v10 3点修正セッション: 内カメラ/外カメラ切り替え時に「ひっくり返る」体感が
    /// 消えていた(実装として一度も存在していなかった)ことへの対応。単一の
    /// AVCaptureSessionが前後カメラを順番に切り替える構造(コメント「PICTRI_
    /// COMPONENT_INVENTORY.md」参照)のため、切り替え前後を同時にライブ表示
    /// することはできない。そのためHome Memory Cardのflip実装(Phase 3で
    /// 二重rotation3DEffectのroot causeを修正済み)と同じ構造 —
    /// 1つのrotation3DEffect + 中間点でだけ切り替えるscaleEffect(x:-1)の
    /// 鏡像補正 — をcameraLayer(ライブ映像そのもの)だけに適用する。badge/
    /// PiP等のUI chromeはcameraLayerの外側にあるため回転の影響を受けない。
    @State private var isCameraFlipped = false
    /// 180°地点(edge-on)でのみ切り替える鏡像補正フラグ。isCameraFlipped自体は
    /// アニメーション対象(0°→180°を連続的に動かす)だが、こちらは
    /// 「今どちらの向きが正しい見た目か」を表す離散値として別に持つ。
    @State private var cameraFlipMirrored = false
    private let cameraFlipDuration: Double = 0.45

    /// `cameraService.currentPosition`の変化(手動PiPタップ・自動デュアル
    /// 撮影シーケンス、どちらの切り替えも同じ経路)に反応して呼ばれる。
    private func triggerCameraFlip() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: cameraFlipDuration)) {
            isCameraFlipped.toggle()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + cameraFlipDuration / 2) {
            cameraFlipMirrored.toggle()
        }
    }

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

    /// CAMERA ROUND 1「CRITICAL FIX」。MapでユーザーがexplicitにSpotを選択しており
    /// (selectedSpotIsExplicit)、かつ現在地がそのSpotのunlockRadiusMeters内にいる時だけ
    /// true。「選択しただけ」では絶対にtrueにならない(isNearの実GPS判定が必須)。
    private var isSelectedSpotExplicitlyInRange: Bool {
        selectedSpotIsExplicit && locationManager.isNear(selectedSpot)
    }

    /// 保存時に実際に使うcapture対象。優先順位:
    /// 1. developer override(QA再現性のため既存selectedSpotを維持)
    /// 2. Mapで明示的に選択されたSpotが実際に範囲内にいる場合はそのSpotを最優先
    ///    (倉敷美観地区/大原美術館のような入れ子radiusで、ユーザーが選んだ方と
    ///    違うSpotが保存される問題の修正)
    /// 3. curated Spot radius内(従来のnearest fallback、Anywhere Captureも含む)
    /// 4. 現在地から解決したArea
    /// どれも成立しなければnil──Product Spec 7章の「安全側」原則により、位置検証
    /// できないMemoryはArea/Spot unlockしない(=保存自体を一旦保留する)。
    private var currentCaptureTarget: QuestCaptureTarget? {
        if developerUnlockMode {
            return .curatedSpot(selectedSpot)
        }
        if isSelectedSpotExplicitlyInRange {
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
        if isSelectedSpotExplicitlyInRange {
            return locationManager.distance(to: selectedSpot)
        }
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
    ///
    /// CAMERA ROUND 4「PART 2 SPOT CONTEXT FIX」。以前は`isSelectedSpotExplicitlyInRange`
    /// (=実GPS範囲内)の時だけSpot名を出し、範囲外になった瞬間にarea名(例:「出雲市」)へ
    /// 後退していたため、「Mapでスポットを選んで来たのに、そのスポットの文脈が
    /// 画面から消える」という体験になっていた。ここは表示専用(=何を撮ろうとしているかの
    /// 文脈)であり、実際の達成判定・保存対象(currentCaptureTarget/
    /// effectiveSpotForComposition、いずれも無変更)とは切り離してよい。
    /// selectedSpotIsExplicit(Mapで明示的に「ここで撮る」した時だけtrue、
    /// 偽装の余地なし)だけを条件にSpot名を表示し、範囲外の場合は
    /// `effectivePlaceDistanceSuffix`で正直に距離を添える。
    private var effectivePlaceName: String {
        if developerUnlockMode { return selectedSpot.name }
        if selectedSpotIsExplicit { return selectedSpot.name }
        if let nearestUnlockedCuratedSpot { return nearestUnlockedCuratedSpot.name }
        if let resolvedArea { return resolvedArea.areaName }
        return isResolvingArea ? "現在地を確認しています…" : "現在地"
    }

    /// Mapで明示選択したSpotがまだ範囲外の時だけ、距離を正直に添える
    /// (「浅草寺まであと320m」のような偽装のない文脈)。範囲内・developer
    /// override中・明示選択が無い場合はnil(chip側は何も付け足さない)。
    private var effectivePlaceDistanceSuffix: String? {
        guard !developerUnlockMode, selectedSpotIsExplicit, !isSelectedSpotExplicitlyInRange else {
            return nil
        }
        guard let distanceText = locationManager.currentLocation != nil
            ? locationManager.distanceText(to: selectedSpot)
            : nil else {
            return nil
        }
        return "あと\(distanceText)"
    }

    private var effectivePrefectureId: String? {
        if developerUnlockMode { return selectedSpot.prefectureId }
        if isSelectedSpotExplicitlyInRange { return selectedSpot.prefectureId }
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
        if isSelectedSpotExplicitlyInRange { return selectedSpot }
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
              !isSelectedSpotExplicitlyInRange,
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
                // CAMERA ROUND 4「PART 1 — camera大きさの違和感」。VStackの
                // spacingを14→8へ縮め、その分をcameraPanel(GeometryReaderで
                // 残りスペースを貪欲に取る)へ還元する。header/mode selector/
                // shutterのpaddingは個別のFreeze対象ではないCamera専用値のため、
                // ここでの調整はHome/Map/Album等の共有JQUI定数には一切影響しない。
                VStack(alignment: .leading, spacing: 8) {
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

                    // CAMERA ROUND 3「STEP 4 REAL PHOTO QA HARNESS」。実機で
                    // Documents保存前の実際の値(mode/lens/flash/直近撮影のpixel寸法)を
                    // 目視確認できる非常に小さいテキストのみ。Production UIには一切
                    // 現れない(#if DEBUG + 同じフラグの二重ガード)。
                    if PictriVisualReview.showCameraDebugControls {
                        cameraDebugQAInfo
                    }
                    #endif

                    cameraBottomArea
                }
                // CAMERA IMAGING ROUND 2「PART 10 — LAYOUT BUDGET AUDIT」。
                // 候補8/10/12/14ptをSimulatorで比較し10ptを採用(8ptは指の誤操作
                // リスクに対して視覚的な余白がほぼ無くなり、Safe Area端の丸みとの
                // 距離が窮屈に見えた。10ptは明確に余白が縮んだと感じられつつ、
                // rounded display端との間に十分な呼吸を残す)。JQUI定数自体には
                // 触れず、この呼び出し箇所だけを変更(Home/Map/Album等、他の
                // JQUI.sidePadding参照箇所には一切影響しない)。
                .padding(.horizontal, 10)
                // CAMERA IMAGING ROUND 2「PART 11 — TOP CHROME COMPACTION」。
                // 監査の結果、この`else`枝(Ready状態のVStack)自体は
                // `.ignoresSafeArea()`されておらず、SwiftUIの既定のSafe Area
                // (Dynamic Island/status bar分)を既に自動的に確保していることが
                // 判明した——旧来の54ptは、その自動確保分の"上に追加で"積んでいた
                // 冗長な余白であり、実機/Simulatorで計測した見た目の天面ギャップ
                // (約138pt相当)の主因だった。Dynamic Island自体の回避はSwiftUIの
                // Safe Area機構が既に保証しているため(このpaddingの値を減らしても
                // Dynamic Islandとの衝突は起こり得ない——安全域の外側に追加している
                // 分だけを削っている)、ここは「ごく僅かな呼吸感」程度の12ptまで
                // 縮める。
                .padding(.top, 12)
                .padding(.bottom, 14)
            }
        }
        .onAppear {
            // CAMERA IMAGING ROUND 2「PART 27 — CAMERA REENTRY」。closeCamera以外の
            // 経路(Dock直接タップ等)でCameraタブを離れた場合、resetCapture()を
            // 経由しないため`cameraService.currentPosition`がfrontのまま残り得る。
            // 再入場のたびに必ずrearへ揃える(Ready Screenは常にrearから始まる、
            // という既存Product Flowの前提をonAppear側でも保証する)。
            if cameraService.currentPosition != .back {
                cameraService.currentPosition = .back
            }
            cameraService.requestAndConfigure()
            cameraService.isDigicamPreviewActive = (cameraStyle == .digicam)

            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestPermission()
            }

            #if DEBUG
            // CAMERA ROUND 2 QA専用。`-pictriCameraStyle`はMode Memory
            // (@AppStorage)より優先して、スクショ確認したいmodeを直接指定できる。
            // `applyDebugScenarioIfRequested()`がこのcameraStyleを使ってcompose()
            // するため、必ずそれより前に適用する(順序を間違えると古いstyleで
            // 合成された画像がスクショに写ってしまう)。
            if let override = PictriVisualReview.cameraStyleOverride {
                cameraStyle = override
            }
            #endif
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
            cameraService.isDigicamPreviewActive = false
            // CRITICAL FIX: Cameraを離れるたびに必ずリセットする(閉じるボタン経由
            // だけでなくDock等からの直接タブ切り替えでも確実に消えるようにするため)。
            // これが無いと、一度Map経由で選んだSpotの「明示選択」フラグが次回以降
            // Cameraタブへ直接入った時にも残り、無関係な場所でSelected Spot Priorityが
            // 誤発動してしまう。
            selectedSpotIsExplicit = false
        }
        // CAMERA / POST IMAGING ROUND「PART 11/26 — MODE SWITCH」。session自体は
        // 再起動せず(既存の単一AVCaptureSessionのまま)、Live Preview処理の
        // ON/OFFだけをここで切り替える。Standardへ戻った瞬間、古いDigicam色の
        // frameが一瞬残って見えないよう`digicamLiveFrame`もここでnilに戻す
        // (次回Digicamへ切り替えた時は新しいframeが届くまでの一瞬だけ、無加工の
        // 実カメラ映像がそのまま見える——黒画面よりも自然、PART 27要件)。
        .onChange(of: cameraStyle) { _, newStyle in
            cameraService.isDigicamPreviewActive = (newStyle == .digicam)
            if newStyle != .digicam {
                cameraService.digicamLiveFrame = nil
            }
        }
        .onChange(of: cameraService.currentPosition) { _, _ in
            triggerCameraFlip()
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

            Spacer(minLength: 8)

            // CAMERA ROUND 4「PART 2」。Spot名は都市名より長くなりがちなため、
            // 固定幅の小さなcapsuleへ無理に収めず、左右のspacer/quota badgeの
            // 分だけ確保した残り幅いっぱいまで使えるようにし、それでも収まらない
            // 場合だけ末尾truncationする。範囲外の明示選択Spotには、偽装のない
            // 距離を2行目の小さなsubtitleとして添える(達成したという意味には
            // ならないよう、chip本体とは明確にトーンを分ける)。
            VStack(spacing: 1) {
                HStack(spacing: 6) {
                    Image(systemName: "mappin")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PictriFinalTheme.accent)
                    Text(effectivePlaceName)
                        .font(PictriTypography.body(13, weight: .bold))
                        .foregroundStyle(PictriFinalTheme.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                if let suffix = effectivePlaceDistanceSuffix {
                    Text(suffix)
                        .font(PictriTypography.mono(9.5, weight: .semibold))
                        .foregroundStyle(PictriFinalTheme.inkFaint)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, effectivePlaceDistanceSuffix == nil ? 9 : 7)
            .background(PictriFinalTheme.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(PictriFinalTheme.ink, lineWidth: 1)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

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

    /// CAMERA ROUND 1「TWO-SIDED CAPTURE EXPERIENCE」。以前の「大きいCamera(cameraLayer)
    /// + 小さいCamera(pipView、94x124のPiP)」という一貫性のない構造を廃止した。
    /// 常に「今撮っている1面」だけを主役として全面表示する(ライブ映像を2つ
    /// 同時に出しているわけではない — 単一のAVCaptureSessionが前後を順番に
    /// 切り替える構造は変えていない)。表/裏の意味は`sideIndicatorBadge`の
    /// side stateだけで伝える(CAMERA LAYOUT CLEANUP ROUNDで背後のpeekカードを
    /// 削除、詳細はcameraPanelのコメント参照)。
    ///
    /// CAMERA LAYOUT CLEANUP ROUND「PART 2/3 — REMOVE ALL PHOTO BORDERS」。
    /// 実機ユーザー確認の結果、`nextSidePeek`(背後にわずかに覗く「次の面」の
    /// カード)が「写真の後ろにある四角形・縁・white/lavender stroke」として
    /// 明確に視認され、不要な装飾として指摘された。表/裏の意味は
    /// `sideIndicatorBadge`のside state("表 1/2"→"裏 2/2")とtransitionだけで
    /// 十分に伝わるため、背後にもう1枚カードがあるように見せる視覚要素
    /// (nextSidePeek関数・呼び出し・関連stateすべて)を完全に削除した。
    /// `hasCapturedBothSides`はこのpeek表示の条件としてのみ使われていたため
    /// 併せて削除(表裏の撮影state自体・保存ロジックには一切影響しない)。
    ///
    /// あわせて、Camera Surface自体を囲っていた`PictriFinalTheme.line`の
    /// 1pt stroke overlayも削除した(「外側の白い枠線」の直接の発生源)。
    /// 最終的にCamera Surfaceは「live preview → 単一clipShape → 軽いshadow」
    /// という最小構成のみで、周囲に別レイヤーの縁取りを持たない。
    ///
    /// Corner radiusは`PictriHomeCardTheme.cornerRadius`(Home投稿Cardと共有)
    /// のまま維持。
    private var cameraPanel: some View {
        // GeometryReader自体はVStack内で「貪欲に残りスペースを取る」子にしないと
        // 高さ0へ潰れてしまうため、明示的にmaxHeight: .infinityを持たせる。
        GeometryReader { proxy in
            let panelSize = panelSize(for: proxy.size)

            ZStack {
                cameraLayer

                if blockingState == .none {
                    sideIndicatorBadge
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

                if showSideCapturedPulse {
                    sideCapturedPulseOverlay
                }
            }
            .frame(width: panelSize.width, height: panelSize.height)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: PictriHomeCardTheme.cornerRadius,
                    style: .continuous
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // ink反転(dark premium統一)後もshadowは暗い側を参照する(paperDeep)。
            // paperDeepはmode-awareになったため(light modeでは明るい)、shadowは常に
            // 暗い側を返すPictriDarkTheme.shadowColorを参照する。写真の周囲に
            // 別レイヤーの縁取りを残さないため、ここには軽いshadowだけを残す
            // (strokeやoutlineは一切無い)。
            .shadow(color: PictriDarkTheme.shadowColor, radius: 14, x: 0, y: 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// CAMERA URGENT CORRECTION ROUND「PART 2 — Home Card実display ratio」。
    /// 以前はcompose()の保存canvasと同じ1080:1920(raw 9:16、比率0.5625)を
    /// そのままCamera UIのviewport比率にも使っていた。実機ユーザー確認の結果、
    /// 縦に長すぎるこの比率がGeometryReaderの「高さで頭打ちになる」計算と
    /// 組み合わさり、実際に表示される写真領域が画面幅よりかなり狭くなり、
    /// 結果として左右に大きな黒余白ができ、「写真の周りに意味のない外枠がある」
    /// ように見える原因になっていた。
    ///
    /// 生Camera出力が9:16だからといってCamera UIのviewportも9:16に固定する
    /// 必要はない、という今回のProduct Decisionに基づき、代わりにHomeの実際の
    /// Hero Card表示比率を使う。
    /// 保存されるraw写真自体(QuestDualPhotoComposer.canvasSize)は
    /// 1080:1920のまま無変更——UI表示だけがこの比率になる
    /// (cameraLayer/PictriCameraPreviewは既存のresizeAspectFillでcrop表示)。
    ///
    /// CAMERA / POST IMAGING ROUND「PART 2 — Camera/Post比率を再同期(ROOT CAUSE修正)」。
    /// 旧リテラル(`0.78 * 0.517 / 0.600`≈0.671)は`PictriHomeCarouselLayoutMetrics.
    /// cardHeight`の理論式(`byWidth = heroHeightLockWidth / cardAspect`)だけを
    /// 前提にしていたが、今回DEBUG計測harness(`print`+`simctl launch --console-pty`、
    /// iPhone 17 Proシミュレータ)で実際の`cardWidth`/`cardHeight`/`heroMaxHeight`を
    /// 実測した結果、この端末クラスでは`byWidth`(466.5pt)ではなく`heroMaxHeight`
    /// (`HomeView.heroCap` = pageArea.height × 0.72、408.3pt)が実際に効いている
    /// constraintだと判明した。つまり旧リテラルは「実際にHomeで表示されている
    /// 比率」とは異なる値だった(旧実測比率 ≈ cardWidth313.56 / cardHeight408.33
    /// ≈ 0.768、旧リテラル0.671とは別物)。
    /// heroHeightBoost(1.06)適用後の実測値(cardWidth 313.56pt / cardHeight
    /// 432.83pt)から、このリテラルを実測比率で置き換える
    /// (Home本体ファイルは不変・値だけをCamera側で再現、という既存方針は維持)。
    ///
    /// CAMERA IMAGING ROUND 2「PART 8 — CENTRALIZE PHOTO ASPECT RATIO」。この
    /// リテラルをPictriCameraStyle.swiftの`PictriPhotoGeometry.displayAspectRatio`
    /// (Home/Camera/Reviewの唯一の共有定数)へ統合し、ここでは参照するだけに
    /// した(値そのものは変更していない——313.56/432.83のまま)。

    private func panelSize(for available: CGSize) -> CGSize {
        let aspect = PictriPhotoGeometry.displayAspectRatio
        let widthConstrained = CGSize(width: available.width, height: available.width / aspect)
        if widthConstrained.height <= available.height {
            return widthConstrained
        }
        return CGSize(width: available.height * aspect, height: available.height)
    }

    /// Live Camera映像本体。常に実カメラ(QuestCameraPreview、AVCaptureVideoPreviewLayer)
    /// を土台として描画し続ける(tap-to-focusのgesture recognizerはこのUIView側にある)。
    /// Digicam Mode選択中は、その上にCore Image処理済みのlive frame
    /// (`cameraService.digicamLiveFrame`、PART 11)を重ねて表示する
    /// (`.allowsHitTesting(false)`でtapは下のQuestCameraPreviewへ素通りする)。
    /// frameがまだ届いていない最初の一瞬だけ、無加工の実カメラ映像がそのまま
    /// 見える(黒画面より自然、PART 27「モード切替で黒画面禁止」とも整合)。
    private var cameraLayer: some View {
        ZStack {
            if cameraService.isCameraAvailable && !cameraService.permissionDenied {
                QuestCameraPreview(session: cameraService.session) { layerPoint, devicePoint in
                    handleFocusTap(layerPoint: layerPoint, devicePoint: devicePoint)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                if cameraStyle == .digicam, let liveFrame = cameraService.digicamLiveFrame {
                    Image(decorative: liveFrame, scale: 1, orientation: .up)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
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

            if let focusIndicatorPoint {
                focusIndicator
                    .position(focusIndicatorPoint)
                    .allowsHitTesting(false)
                    .id(focusIndicatorToken)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 内カメラ/外カメラ切り替え時の「ひっくり返る」動作。単一rotation3DEffect
        // (Home Memory Cardのroot cause修正と同じ構造)+ 中間点でのみ切り替える
        // scaleEffect(x:-1)の鏡像補正。ライブ映像そのものだけを回転させ、
        // badge/PiP等のUI chromeはこのcameraLayerの外側にあるため影響を受けない。
        .scaleEffect(x: cameraFlipMirrored ? -1 : 1, y: 1)
        .rotation3DEffect(
            .degrees(reduceMotion ? 0 : (isCameraFlipped ? 180 : 0)),
            axis: (x: 0, y: 1, z: 0)
        )
    }

    /// CAMERA / POST IMAGING ROUND「PART 7 — TAP TO FOCUS」。撮影中(countdown/
    /// blocking状態)にはtapを効かせない——誤操作でフォーカスが暴れるのを防ぐ。
    private func handleFocusTap(layerPoint: CGPoint, devicePoint: CGPoint) {
        guard blockingState == .none, countdownNumber == nil, !isCapturingSequence else { return }

        cameraService.focus(atDevicePoint: devicePoint)
        PictriCameraHaptics.modeSwitch()

        let token = UUID()
        focusIndicatorToken = token
        withAnimation(.easeOut(duration: 0.18)) {
            focusIndicatorPoint = layerPoint
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            guard focusIndicatorToken == token else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                focusIndicatorPoint = nil
            }
        }
    }

    /// 短時間だけ表示するfocus indicator。iPhone標準Cameraの黄色い正方形のような
    /// 「機能を主張しすぎるUI」ではなく、PicTriの既存トーン(PictriHomeBrandAccent)
    /// に合わせた控えめな正方形の縁取りのみ。塗りつぶし・ISO数値等は表示しない。
    private var focusIndicator: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(PictriHomeBrandAccent.accent.opacity(0.92), lineWidth: 1.5)
            .frame(width: 76, height: 76)
            .opacity(focusIndicatorPoint == nil ? 0 : 1)
            .scaleEffect(focusIndicatorPoint == nil ? 1.15 : 1.0)
            .accessibilityHidden(true)
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

    /// CAMERA ROUND 1「SIDE INDICATOR」。旧primaryBadge(①の丸バッジ)+
    /// pipView(94x124の小さいPiPカメラ)という「大きいCamera+小さいCamera」構造を
    /// 廃止し、「今どちらの面を撮っているか」を1つの控えめなpillだけで示す。
    /// 表=外カメラ(cameraService.currentPosition == .back)、裏=内カメラ(.front)、
    /// という意味付けはHome投稿(PictriHomeMemoryCard)のoutrOnly=表/selfie=裏と
    /// 完全に一致させている。
    /// CAMERA ROUND 2「STEP 4 SIDE UX」+「MICROCOPY」。旧実装は「表 1/2」の
    /// pillとswap iconが別々の黒い丸/カプセルとして浮いており、「1つの写真
    /// オブジェクトに付いたmetadata」ではなく「2つの独立したUI部品」に見えていた。
    /// 縦一列の1つのタグへ統合し、下にごく短いmicrocopy(最大1行)を添えることで、
    /// 説明なしで「今どちらを撮っているか/次は何をするか」が伝わるようにする。
    #if DEBUG
    /// CAMERA ROUND 3「STEP 4 REAL PHOTO QA HARNESS」+「STEP 7 CAMERA DEVICE
    /// AUDIT」。`-pictriShowCameraDebugControls true`の時だけ、実機で以下を
    /// 目視確認できる最小限のテキストを1箇所にまとめる: 現在Mode・使用カメラ位置・
    /// flash状態・検出済みrear lens一覧(機種名からの決め打ちではなくDiscoverySession
    /// の実返却値)・直近撮影のpixel寸法。Production build(#if DEBUG外)には
    /// このView自体が存在しない。
    private var cameraDebugQAInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("QA: mode=\(cameraStyle.rawValue) pos=\(cameraService.currentPosition == .back ? "rear" : "front") flash=\(cameraService.flashMode.rawValue)")
            Text("QA: lastCapture=\(lastCaptureDebugInfo)")
            Text("QA: rearLenses=\(cameraService.discoveredRearLensDescriptions.joined(separator: ", "))")
        }
        .font(PictriTypography.mono(8, weight: .regular))
        .foregroundStyle(PictriFinalTheme.inkFaint)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
    #endif

    private var sideIndicatorBadge: some View {
        let hasCapturedAny = frontImage != nil || backImage != nil
        let isBackSide = cameraService.currentPosition == .back
        let label = isBackSide ? "表" : "裏"
        let index = hasCapturedAny ? "2 / 2" : "1 / 2"

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(PictriHomeBrandAccent.accent)
                        .frame(width: 6, height: 6)
                    Text(label)
                        .font(PictriTypography.body(12, weight: .bold))
                    Text(index)
                        .font(PictriTypography.mono(11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.68))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.46))
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1)
                }

                // 既存Product semantics「pipViewタップでどちらが先かを入れ替える」を、
                // 視覚的なPiPそのものは廃止した上でも1箇所だけ残す(新しいrear/rear・
                // front/front選択機能は追加しない、あくまで撮影順の入れ替えのみ)。
                if !hasCapturedAny {
                    Button {
                        cameraService.switchCamera()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.black.opacity(0.46))
                            .clipShape(Circle())
                            .overlay {
                                Circle().stroke(Color.white.opacity(0.14), lineWidth: 1)
                            }
                    }
                    .disabled(isCapturingSequence)
                    .accessibilityLabel(isBackSide ? "先に裏(内カメラ)から撮る" : "先に表(外カメラ)から撮る")
                }
            }

            if !isCapturingSequence, let microcopy = sideMicrocopy(hasCapturedAny: hasCapturedAny, label: label) {
                Text(microcopy)
                    .font(PictriTypography.body(11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label)を撮影、\(index)")
    }

    /// 「視覚だけで理解できるなら文字追加しない」という方針のため、常時表示せず
    /// シャッターを押す前(idle、まだ1枚も撮っていない)の一瞬だけ最大1行のヒントを
    /// 出す。現行アーキテクチャは表→裏を1回のシャッター操作で自動的に連続撮影する
    /// ため(2枚目だけ別途ユーザー操作を待つ一時停止状態は存在しない)、「次は裏」を
    /// 表示すべき中間状態はそもそも発生しない。
    private func sideMicrocopy(hasCapturedAny: Bool, label: String) -> String? {
        guard capturePhase == .idle, !hasCapturedAny else { return nil }
        return "まずは\(label)を撮る"
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

    /// STEP 20の420msだけ表示する軽量な「撮れた」pulse。opacity/scaleのみで
    /// 3D回転を伴わないため、Reduce Motion時もそのまま安全に使える。
    private var sideCapturedPulseOverlay: some View {
        ZStack {
            Color.black.opacity(0.18)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(PictriHomeBrandAccent.accent)
                .background {
                    Circle().fill(.white).frame(width: 40, height: 40)
                }
        }
        .transition(.opacity)
        .accessibilityHidden(true)
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
        retakeOnlyPosition = nil

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

            // STEP 20: 即座にカメラを切り替えず、420msだけ「1枚目が撮れた」ことを
            // 示す小さなpulseを見せてから次へ進む。reduceMotionでも(単なる
            // opacity切替のみで3D回転を伴わないため)そのまま使う——0にはしない、
            // このpulseは「状態変化の理解」を助ける情報であり装飾的モーションではない。
            withAnimation(.easeOut(duration: 0.16)) {
                showSideCapturedPulse = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + sideTransitionPauseSeconds) {
                guard isCurrentCapture(runID) else { return }
                withAnimation(.easeIn(duration: 0.12)) {
                    showSideCapturedPulse = false
                }

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
                spot: effectiveSpotForComposition,
                style: cameraStyle
            )

            previewImage = finalImage
            capturePhase = .preview
            isCapturingSequence = false
            countdownNumber = nil
        }
    }

    /// CAMERA ROUND 1「RETAKE」。片面だけを撮り直す。previewImageを一時的にnilへ
    /// 戻すことでbody側が自然にライブのcameraPanelへ切り替わり(既存の分岐ロジック
    /// そのまま)、対象の面だけ再撮影して再度compose()する。もう片方の面
    /// (frontImage/backImageのうち触っていない方)はそのまま保持する。
    private func retakeSide(_ position: AVCaptureDevice.Position) {
        guard !isCapturingSequence else { return }

        let runID = UUID()
        captureRunID = runID
        retakeOnlyPosition = position
        previewImage = nil
        isCapturingSequence = true

        cameraService.switchCamera(to: position) {
            guard isCurrentCapture(runID) else { return }

            runCountdown(
                phase: countdownPhase(for: position),
                runID: runID
            ) {
                capturePhase = capturingPhase(for: position)

                captureImageOrDemo(isFront: position == .front) { image in
                    guard isCurrentCapture(runID) else { return }

                    storeCapturedImage(image, for: position)

                    let finalBackImage = backImage ?? QuestDemoPhotoMaker.makePhoto(
                        spot: selectedSpot,
                        isFrontCamera: false
                    )

                    previewImage = QuestDualPhotoComposer.compose(
                        backImage: finalBackImage,
                        frontImage: frontImage,
                        spot: effectiveSpotForComposition,
                        style: cameraStyle
                    )
                    capturePhase = .preview
                    isCapturingSequence = false
                    countdownNumber = nil
                    // retakeOnlyPositionはここではクリアしない。reviewViewが
                    // 「撮り直した面を先に見せる」ためにこの値を読むため、次回の
                    // 通常撮影開始(startDualCapture)またはresetCaptureでのみリセットする。
                }
            }
        }
    }

    private func storeCapturedImage(
        _ image: UIImage,
        for position: AVCaptureDevice.Position
    ) {
        // CAMERA ROUND 1「PHOTO QUALITY AUDIT」+「3 CAMERA MODES」。styleの
        // 画像処理は撮影1回ごとに1回だけ、この保存直前のタイミングで適用する
        // (ライブpreviewには一切適用しない)。標準モードは無加工のまま通す。
        let styledImage = PictriCameraStyleProcessor.apply(cameraStyle, to: image)
        if position == .front {
            frontImage = styledImage
        } else {
            backImage = styledImage
        }
        // CAMERA ROUND 2「HAPTICS」。片面が撮り終わった瞬間だけ軽いfeedbackを足す
        // (撮影中に連打されるcaptureImageOrDemoの完了コールバック1回につき1回のみ)。
        PictriCameraHaptics.sideCompleted()

        #if DEBUG
        if let cgImage = styledImage.cgImage {
            let sideLabel = position == .back ? "表" : "裏"
            lastCaptureDebugInfo = "\(sideLabel) \(cgImage.width)×\(cgImage.height)px"
        }
        #endif
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
        retakeOnlyPosition = nil
        showSideCapturedPulse = false

        // CAMERA IMAGING ROUND 2「PART 2 — DIGICAM SWITCH CAMERA BUGのroot cause修正」。
        // 表(rear)→裏(front)の2面撮影は必ずfrontで終わるが、旧実装はここで
        // `cameraService.currentPosition`を一切リセットしていなかった。そのため
        // 「撮りなおす」「つづけて撮る」「閉じる」(いずれもresetCapture経由)で
        // Readyへ戻った直後のLive Previewはfront cameraのまま残り、ユーザーが
        // 次にStandard⇄Digicamを切り替えた瞬間に「front/rearが変わった」ように
        // 見えていた——実際にはStyle切替が原因ではなく、直前の撮影cycleの
        // 残留stateが原因だった(cameraStyleのonChangeはswitchCamera/
        // configureSessionを一切呼んでいないことをコード監査済み)。
        // Readyへ戻るたびに必ずrearへ戻す(Product Flow上「表」は常にrearから
        // 始まる、という既存の仕様どおり)。既にrearなら無駄なsession
        // reconfigure(黒framephasが一瞬入る)を避けるためguardする。
        if cameraService.currentPosition != .back {
            cameraService.switchCamera(to: .back)
        }
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
        PictriCameraHaptics.saveSuccess()
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
        let composite = QuestDualPhotoComposer.compose(backImage: demoBack, frontImage: demoFront, spot: effectiveSpotForComposition, style: cameraStyle)

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
                spot: selectedSpot,
                style: cameraStyle
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
    /// CAMERA LAYOUT CLEANUP ROUND「PART 9 — FLASH ROW MUST NOT RESIZE CAMERA」。
    /// 以前はflashControlRowを条件付きでVStackへ追加/削除しており、これにより
    /// cameraBottomArea全体の高さがModeによって変わり、その結果
    /// cameraPanel(GeometryReaderが「残りスペース」を計算する側)が
    /// Standard/Digicamで異なるsizeになっていた——これがユーザー指摘
    /// 「標準とデジカメで写真の幅が違う」の直接原因。
    ///
    /// 今回、flash rowの表示スロット自体は常に同じ高さで確保し、
    /// 出す/隠すは中身の有無ではなくopacity/hitTestingだけで切り替える。
    /// これによりcameraBottomAreaの総高さはMode/flash可否に関わらず常に
    /// 一定になり、cameraPanelのGeometryReaderが受け取る「残りスペース」も
    /// 常に同じになる(=Camera Surfaceのgeometryが完全に固定される)。
    private var cameraBottomArea: some View {
        VStack(spacing: 8) {
            flashControlSlot
            cameraStyleSelector
            captureControls
        }
    }

    private var showsFlashRow: Bool {
        cameraStyle.showsFlashControl && cameraService.isFlashAvailable
    }

    /// flash rowの実際のコンテンツ有無に関わらず、常に同じ高さのスロットを
    /// 確保する(`flashControlRow`の実測高さをそのまま流用)。
    private var flashControlSlot: some View {
        flashControlRow
            .opacity(showsFlashRow ? 1 : 0)
            .allowsHitTesting(showsFlashRow)
            .accessibilityHidden(!showsFlashRow)
    }

    /// CAMERA ROUND 1「MODE UI」。previewを邪魔しないcompact selector。
    /// 巨大segmented control・設定画面のようなUI・英語表示・青Buttonは避け、
    /// PicTri lavenderを選択状態にだけ控えめに使う。撮影中は変更させない
    /// (撮影シーケンスの途中でstyleが変わって表裏で見た目が食い違うのを防ぐ)。
    private var cameraStyleSelector: some View {
        let activeStyle = cameraStyle
        return HStack(spacing: 6) {
            ForEach(PictriCameraStyle.allCases) { style in
                let isActive: Bool = activeStyle == style
                let labelColor: Color = isActive ? PictriHomeBrandAccent.onAccent : Color.white.opacity(0.62)
                let fillColor: Color = isActive ? PictriHomeBrandAccent.accent : Color.clear

                Button {
                    guard !isActive else { return }
                    PictriCameraHaptics.modeSwitch()
                    cameraStyle = style
                } label: {
                    Text(style.displayName)
                        .font(PictriTypography.body(12.5, weight: .bold))
                        .foregroundStyle(labelColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background {
                            Capsule().fill(fillColor)
                        }
                }
                .disabled(isCapturingSequence)
                .accessibilityLabel(style.accessibilityLabel)
                .accessibilityAddTraits(isActive ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(PictriFinalTheme.surfaceRaised)
        .clipShape(Capsule())
        .overlay {
            Capsule().stroke(PictriFinalTheme.line, lineWidth: 1)
        }
        // CAMERA LAYOUT CLEANUP ROUND「PART 8 — 2モードでも画面幅いっぱいに
        // 広げない」。以前の`.frame(maxWidth: .infinity)`は3モード時代の名残で、
        // 2モードになった今そのままだとCapsuleが不必要に間延びする。contentの
        // 自然な幅のまま中央寄せする。
        .frame(maxWidth: .infinity, alignment: .center)
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity)
        .opacity(isCapturingSequence ? 0.5 : 1)
        // CAMERA ROUND 2「MODE SELECTOR POLISH」。tapに加えて横swipeでも切替可能に
        // する(spec「横swipeまたはtap」)。閾値を40ptと大きめに取り、誤操作(軽い
        // 指ブレでの意図しないmode変更)を避ける。撮影中は無効。
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    guard !isCapturingSequence else { return }
                    let allCases = PictriCameraStyle.allCases
                    guard let currentIndex = allCases.firstIndex(of: cameraStyle) else { return }
                    if value.translation.width < -40, currentIndex < allCases.count - 1 {
                        PictriCameraHaptics.modeSwitch()
                        cameraStyle = allCases[currentIndex + 1]
                    } else if value.translation.width > 40, currentIndex > 0 {
                        PictriCameraHaptics.modeSwitch()
                        cameraStyle = allCases[currentIndex - 1]
                    }
                }
        )
    }

    /// デジカメModeでのみ、実機がflashに対応する場合だけ表示する。前面カメラや
    /// flash非搭載デバイスでは`cameraService.isFlashAvailable`がfalseになり、
    /// このrow自体が出ない(=嘘のflash stateを見せない)。
    private var flashControlRow: some View {
        HStack(spacing: 6) {
            ForEach([AVCaptureDevice.FlashMode.off, .auto, .on], id: \.rawValue) { mode in
                Button {
                    cameraService.flashMode = mode
                } label: {
                    Image(systemName: flashIconName(for: mode))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(cameraService.flashMode == mode ? PictriHomeBrandAccent.onAccent : PictriFinalTheme.inkSoft)
                        .frame(width: 34, height: 28)
                        .background {
                            Capsule()
                                .fill(cameraService.flashMode == mode ? PictriHomeBrandAccent.accent : Color.clear)
                        }
                }
                .disabled(isCapturingSequence)
                .accessibilityLabel(flashAccessibilityLabel(for: mode))
            }
        }
        .padding(4)
        .background(PictriFinalTheme.surfaceRaised)
        .clipShape(Capsule())
        .overlay {
            Capsule().stroke(PictriFinalTheme.line, lineWidth: 1)
        }
    }

    private func flashIconName(for mode: AVCaptureDevice.FlashMode) -> String {
        switch mode {
        case .off: return "bolt.slash"
        case .auto: return "bolt.badge.a"
        case .on: return "bolt.fill"
        @unknown default: return "bolt.slash"
        }
    }

    private func flashAccessibilityLabel(for mode: AVCaptureDevice.FlashMode) -> String {
        switch mode {
        case .off: return "フラッシュ オフ"
        case .auto: return "フラッシュ 自動"
        case .on: return "フラッシュ オン"
        @unknown default: return "フラッシュ オフ"
        }
    }

    /// Core UX Simplification(Phase C)。以前ここにあった「内へ/外へ」カメラ切り替え
    /// ボタンは、pipView タップによる切り替えと機能が完全に重複していたため削除した
    /// (Camera削除候補#5「「内へ」独立ボタン」)。shutterだけが主CTAとして中央に残る。
    /// シャッターの「core」だけが「唯一の意味あるaccent」(violet)を持ち、撮影中は
    /// selectedPrefectureColor(実データ)に変わる(Design Spec「shutter core turns
    /// memory color and is disabled」)。カメラ切り替えロジック(switchCamera)自体は無変更。
    /// CAMERA ROUND 2「SHUTTER POLISH」。旧実装は単色circle+2本のthin strokeだけの
    /// 素のiOS Camera的な見た目で、accentも旧orange(PictriFinalTheme.accent)の
    /// ままmode selectorのlavenderと衝突していた。今回restrained double-ring
    /// (中立outer ring + soft-white inner core + 選択modeを示す細いlavender
    /// アクセントring)へ差し替え、押した瞬間が分かるtactileなscale feedback+
    /// light hapticを追加する。撮影ロジック(startDualCapture)自体は無変更。
    private var captureControls: some View {
        Button {
            PictriCameraHaptics.shutterTap()
            startDualCapture()
        } label: {
            ZStack {
                Circle()
                    .fill(PictriDarkTheme.surfaceOverlay)
                    .frame(width: 84, height: 84)
                    .overlay {
                        Circle().stroke(PictriHomeBrandAccent.accent.opacity(canCapture ? 0.55 : 0.18), lineWidth: 2)
                    }

                Circle()
                    .fill(shutterCoreColor)
                    .frame(width: 64, height: 64)
                    .overlay {
                        Circle().stroke(Color.white.opacity(0.92), lineWidth: 3)
                    }

                if isCapturingSequence {
                    ProgressView()
                        .tint(PictriFinalTheme.onAccent)
                }
            }
            .shadow(color: canCapture ? PictriHomeBrandAccent.accent.opacity(0.28) : .clear, radius: 14, x: 0, y: 4)
        }
        .buttonStyle(PictriShutterButtonStyle())
        .disabled(!canCapture || isCapturingSequence)
        .accessibilityLabel("外カメラと内カメラで2枚撮影する")
        .accessibilityHint(canCapture ? "" : "現在は撮影できません")
        .frame(maxWidth: .infinity)
        .frame(height: 84)
    }

    private var shutterCoreColor: Color {
        if isCapturingSequence { return selectedPrefectureColor }
        return canCapture ? PictriPrefectureProgressTheme.softWhite : PictriFinalTheme.dormant
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
    /// CAMERA ROUND 1「REVIEW SCREEN」。以前は合成済みcomposite 1枚(小さなPiPが
    /// 焼き込み済み)をPictriPhotoPrintで見せていたが、Home投稿と同じ「表/裏の
    /// two-sided card」という体験に統一する。表示に使うのはoutrOnly/selfieと
    /// 同じ生画像(backImage=表/frontImage=裏)で、compose()済みcomposite自体は
    /// 引き続き裏で計算され保存にも使われる(memoryStore.save呼び出しは無変更)。
    /// tap/swipeでの表裏確認は`PictriCameraTwoSidedReviewCard`(Home Memory Cardと
    /// 同じ回転技法)がそのまま提供する。片面だけの撮り直しもここから行える。
    /// 片面だけ撮り直した直後はその面を先に見せる。`-pictriCameraReviewShowBack true`
    /// (DEBUG限定QA)が指定されている時は、撮り直しが無くても裏から見せる。
    private var reviewInitialSideIsFront: Bool {
        #if DEBUG
        if PictriVisualReview.cameraReviewShowBack { return false }
        #endif
        return retakeOnlyPosition != .front
    }

    private func reviewView(previewImage: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            cameraHeader()

            PictriCameraTwoSidedReviewCard(
                frontLabel: "表",
                backLabel: "裏",
                frontImage: backImage,
                backImage: frontImage,
                onRetakeFront: { retakeSide(.back) },
                onRetakeBack: { retakeSide(.front) },
                initialSideIsFront: reviewInitialSideIsFront
            )
            .frame(maxWidth: 280)
            .frame(maxWidth: .infinity)

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
    ///
    /// CAMERA / POST IMAGING ROUND「PART 6 — STANDARD CAMERA QUALITY」。旧値
    /// 1080×1920(≈2.07MP)は、QuestCameraServiceが`maxPhotoDimensions`で
    /// 実機の最大静止画解像度(例: 12MP超)をそのまま撮っているにも関わらず、
    /// compose()がこのcanvasSizeへ強制的にdrawAspectFillで縮小していたため、
    /// 「撮影後にresizeしている」(監査項目5)の直接の該当箇所だった。
    /// 実機の最大解像度(機種依存、48MP等)をそのままcompose canvasに使うのは
    /// 「決め打ちしない」方針にも反し、UIGraphicsImageRenderer+CGContext text
    /// 描画のメモリ/描画コストが過大になるため、代わりに「旧解像度から意味のある
    /// 画質改善が体感できる」よう1.5倍(縦横比1080:1920は不変)へ引き上げた
    /// (1620×2880、≈4.66MP)。frontInsetRect以下、この関数群が描く全ての
    /// 絶対pixel値(cornerRadius/lineWidth/font size/オフセット)は、旧基準
    /// (1080pt幅)からの比率`scale`で一括計算し、見た目の相対位置・太さ・
    /// フォントサイズ比は変更前と完全に同じになるようにしている。
    static let canvasSize = CGSize(width: 1620, height: 2880)
    /// 上記1.5倍化に伴うscale係数(旧基準1080pt幅からの比率)。
    private static let scale: CGFloat = canvasSize.width / 1080
    static let frontInsetRect = CGRect(
        x: 58 * scale, y: 78 * scale, width: 286 * scale, height: 382 * scale
    )

    /// `style`はCAMERA ROUND 2で追加した引数。既定値`.standard`を持つ追加的な
    /// パラメータのため、既存の全呼び出し箇所(`style`を渡さないコード)は無変更で
    /// そのまま動く。日付/場所の焼き込み方だけがModeに応じてわずかに変わる
    /// (STEP 11「DIGICAM DATE STAMP」)。
    static func compose(
        backImage: UIImage,
        frontImage: UIImage?,
        spot: QuestSpot,
        style: PictriCameraStyle = .standard
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
                spot: spot,
                style: style
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
            cornerRadius: 34 * scale
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
            cornerRadius: 34 * scale
        )
        border.lineWidth = 6 * scale
        border.stroke()
    }

    /// CAMERA ROUND 2「STEP 11 DIGICAM DATE STAMP」。既存の「場所名+日付」box
    /// (1つのstamp system)はそのまま維持し、デジカメModeの時だけ日付の書式・色味
    /// だけをコンパクトデジカメ的な表現(例: '26.09.14、わずかにamber寄りの白)へ
    /// 差し替える。標準/風景では従来通り(yyyy/MM/dd・白)。二重stampにはしていない
    /// ——同じboxの同じ行を置き換えるだけ。
    private static func drawLocationText(
        context: CGContext,
        canvasSize: CGSize,
        spot: QuestSpot,
        style: PictriCameraStyle
    ) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = style == .digicam ? "''yy.MM.dd" : "yyyy/MM/dd"
        let dateText = dateFormatter.string(from: Date())
        let placeText = spot.englishName.lowercased()
        // CAMERA ROUND 3「STEP 15 DATE STAMP AUDIT」。Round 2の値(0.82/0.55、
        // alpha 0.92)は実機写真での検証前の仮値だった。「cheap retro camera
        // filterに見える」リスクを避けるため、彩度を大きく落とし
        // soft warm-white寄りへ弱めた(「気づくと可愛い」程度を狙う)。実機写真での
        // 最終確認は未実施——次回実機QAで濃すぎる/薄すぎる場合は再調整が必要。
        let dateColor: UIColor = style == .digicam
            ? UIColor(red: 0.97, green: 0.93, blue: 0.86, alpha: 0.90)
            : .white

        let boxRect = CGRect(
            x: 58 * scale,
            y: canvasSize.height - 290 * scale,
            width: min(560 * scale, canvasSize.width - 116 * scale),
            height: 158 * scale
        )

        let boxPath = UIBezierPath(
            roundedRect: boxRect,
            cornerRadius: 24 * scale
        )

        UIColor.white.withAlphaComponent(0.18).setFill()
        boxPath.fill()

        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 44 * scale, weight: .semibold),
            .foregroundColor: dateColor
        ]

        let placeAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 58 * scale, weight: .bold),
            .foregroundColor: UIColor.white
        ]

        dateText.draw(
            in: CGRect(
                x: boxRect.minX + 32 * scale,
                y: boxRect.minY + 25 * scale,
                width: boxRect.width - 64 * scale,
                height: 52 * scale
            ),
            withAttributes: dateAttributes
        )

        placeText.draw(
            in: CGRect(
                x: boxRect.minX + 32 * scale,
                y: boxRect.minY + 78 * scale,
                width: boxRect.width - 64 * scale,
                height: 72 * scale
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
