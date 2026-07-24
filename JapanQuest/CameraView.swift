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

    var label: String {
        switch self {
        case .idle:
            return "準備完了"
        case .countingFront:
            return "内カメ 3秒"
        case .capturingFront:
            return "内カメ保存中"
        case .countingBack:
            return "外カメ 3秒"
        case .capturingBack:
            return "外カメ保存中"
        case .preview:
            return "確認"
        }
    }
}

struct QuestCameraView: View {
    @Binding var selectedTab: AppTab
    @Binding var selectedSpotId: String
    @Binding var pendingExploreSpotId: String?

    @EnvironmentObject var memoryStore: QuestMemoryStore
    @EnvironmentObject var locationManager: QuestLocationManager

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

    /// タブバーを没入時に隠すぶん、Cameraはより背の高いプレビューを主役にできる。
    /// パネルが縮みすぎないための最低保証値のみ。実際の高さはVStackの残り空間に自動追従する。
    private let minPanelHeight: CGFloat = 260

    private var sequenceText: String {
        switch capturePhase {
        case .countingFront:
            return "内カメ撮影"
        case .capturingFront:
            return "内カメ保存中"
        case .countingBack:
            return "外カメ撮影"
        case .capturingBack:
            return "外カメ保存中"
        case .preview:
            return "確認"
        case .idle:
            return ""
        }
    }

    private var selectedSpot: QuestSpot {
        mockQuestSpots.first { $0.id == selectedSpotId } ?? mockQuestSpots[0]
    }

    private var cameraModeText: String {
        cameraService.currentPosition == .front ? "内カメ" : "外カメ"
    }

    private var nextCameraModeText: String {
        cameraService.currentPosition == .front ? "次は外カメ" : "次は内カメ"
    }

    private var isUnlocked: Bool {
        developerUnlockMode || locationManager.isNear(selectedSpot)
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
        isUnlocked && !isCameraPermissionBlocking
    }

    private var currentProofStatus: QuestVerificationStatus {
        if developerUnlockMode {
            return .developer
        }

        if locationManager.isNear(selectedSpot) {
            return .verified
        }

        return .unverified
    }

    private var currentDistanceMeters: Double? {
        locationManager.distance(to: selectedSpot)
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

    private enum StatusMessage {
        case reviewing
        case saved
        case outOfRange(distanceText: String)
        case cameraUnavailable
        case ready
    }

    private var statusMessage: StatusMessage {
        if hasSaved { return .saved }
        if previewImage != nil { return .reviewing }
        if !isUnlocked { return .outOfRange(distanceText: locationManager.distanceText(to: selectedSpot)) }
        if !cameraService.isCameraAvailable { return .cameraUnavailable }
        return .ready
    }

    @ViewBuilder
    private var statusCard: some View {
        switch statusMessage {
        case .reviewing:
            PictriStatusCard(
                systemImage: "photo.on.rectangle.angled",
                title: "この2枚で残す?",
                accent: .indigo
            )
        case .saved:
            PictriStatusCard(
                systemImage: "checkmark.circle.fill",
                title: "メモリーに保存しました",
                accent: .teal
            )
        case .outOfRange(let distanceText):
            PictriStatusCard(
                systemImage: "figure.walk",
                title: "近づくと撮れる",
                detail: "現在地から \(distanceText)",
                accent: .indigo
            )
        case .cameraUnavailable:
            PictriStatusCard(
                systemImage: "sparkles",
                title: "外の景色と、あなたの表情を一緒に残します",
                detail: "シミュレーターでは見本で撮影します",
                accent: .indigo
            )
        case .ready:
            PictriStatusCard(
                systemImage: "camera.aperture",
                title: "外の景色と、あなたの表情を一緒に残します",
                accent: .indigo
            )
        }
    }

    var body: some View {
        ZStack {
            // 純黒だとCamera画面だけ他画面から断絶して見えるため、PicTriアイコンの
            // 紫〜青トーンに近いdeep indigoへ寄せる(safe area構造・撮影ロジックは無変更)。
            PictriLightTheme.photoDepth.ignoresSafeArea()

            // Cameraパネルの高さを固定値にせず、ヘッダー/statusCard/下部コントロールが
            // 実際に使った分を引いた「残り全部」に自動で合わせる。以前は620ptの固定値だったため、
            // 端末やstatusCardの有無によっては合計がscreen heightを超え、
            // シャッターやカメラ切替ボタンが画面下に見切れていた(このバグの直接原因)。
            VStack(alignment: .leading, spacing: 14) {
                cameraHeader

                cameraPanel

                if blockingState == .none {
                    statusCard
                }

                cameraBottomArea
            }
            .padding(.horizontal, JQUI.sidePadding)
            .padding(.top, JQUI.screenTopPadding)
            .padding(.bottom, 14)
        }
        .onAppear {
            cameraService.requestAndConfigure()

            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestPermission()
            }

            applyDebugScenarioIfRequested()
        }
        .onDisappear {
            cameraService.stopSession()
        }
    }

    private var cameraHeader: some View {
        PictriScreenHeader(eyebrow: "CAMERA", title: selectedSpot.name) {
            Button(action: closeCamera) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                    Text("閉じる")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.88))
                .padding(.horizontal, 14)
                .frame(minWidth: 44, minHeight: 44)
                .background(.white.opacity(0.12))
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(.white.opacity(0.16), lineWidth: 1)
                }
            }
            .accessibilityLabel("カメラを閉じてホームへ戻る")
        }
    }

    /// Cameraからいつでも確実に戻れるようにする唯一の出口。
    /// previewImage/hasSaved/capturePhase/blockingStateなど、いかなる状態にも依存させない。
    /// 撮影中(isCapturingSequence)のシーケンスIDだけ更新して安全に打ち切ってから戻る。
    private func closeCamera() {
        resetCapture()
        selectedTab = .home
    }

    private var cameraPanel: some View {
        ZStack {
            cameraLayer

            // 撮影済みプレビュー(previewImage)には、日付+地名が既に画像へ焼き込み済みで、
            // 写真そのものが主役になるべきなので、ライブ中のオーバーレイ類は撮影前だけに限定する。
            if blockingState == .none && previewImage == nil {
                liveLocationOverlay

                if let frontImage {
                    frontMiniPreview(image: frontImage)
                }

                cameraPanelTopControls
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
        .frame(minHeight: minPanelHeight, maxHeight: .infinity)
        .clipShape(
            RoundedRectangle(
                cornerRadius: JQUI.panelCornerRadius,
                style: .continuous
            )
        )
        .background {
            RoundedRectangle(
                cornerRadius: JQUI.panelCornerRadius + 4,
                style: .continuous
            )
            .fill(.white.opacity(0.055))
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: JQUI.panelCornerRadius,
                style: .continuous
            )
            .stroke(.white.opacity(0.10), lineWidth: 1)
        }
    }

    private var cameraLayer: some View {
        ZStack {
            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if cameraService.isCameraAvailable && !cameraService.permissionDenied {
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
            LinearGradient(
                colors: [
                    PictriTheme.accent.opacity(0.26),
                    Color(red: 0.10, green: 0.16, blue: 0.26),
                    Color(red: 0.05, green: 0.08, blue: 0.14)
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

    private var cameraPanelTopControls: some View {
        HStack(alignment: .top) {
            PictriGlassPill(text: cameraModeText)

            Spacer()

            if isCapturingSequence {
                PictriGlassPill(text: sequenceText, tone: .muted)
            } else if !cameraService.isCameraAvailable {
                // 実機カメラが使えない(主にSimulator)場合のみ表示。撮影シーケンス中は
                // sequenceTextと同じ位置を取り合うため、片方だけを出す。
                // アイコン付きの太字ピルだと「トグルUI」のように機械的に見えるため、
                // 通常のstatus pillより控えめな極小キャプションとして表示する。
                Text("サンプル表示")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.46))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.20), in: Capsule())
            }

            #if DEBUG
            // 通常のCamera UIには常に隠す。QA目的で明示的に呼び出したい時だけ
            // `-pictriShowCameraDebugControls true` を渡す。位置認証の解放自体は
            // 引き続き `-pictriDevUnlock true/false` で行えるため、機能は失われない。
            if PictriVisualReview.showCameraDebugControls {
                Toggle("", isOn: $developerUnlockMode)
                    .labelsHidden()
                    .scaleEffect(0.55)
                    .padding(.horizontal, 2)
                    .background(.black.opacity(0.25), in: Capsule())
                    .accessibilityLabel("開発用: 位置認証を無視して撮影を解放")
            }
            #endif
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var liveLocationOverlay: some View {
        PictriGlassPill(text: selectedSpot.englishName.lowercased(), tone: .muted)
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    private func frontMiniPreview(image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 96, height: 132)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.88), lineWidth: 2)
            }
            .overlay(alignment: .bottomLeading) {
                Text("内カメ")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.44))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(8)
            }
            .padding(.top, 76)
            .padding(.leading, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                spot: selectedSpot
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
        countdownNumber = nil
        capturePhase = .idle
    }

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

    private func currentDateText() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: Date())
    }

    private var cameraBottomArea: some View {
        VStack(spacing: 12) {
            if let previewImage {
                previewActions(previewImage: previewImage)
            } else {
                twoStepIndicator
                captureControls
            }
        }
    }

    /// 「外カメ+内カメで2枚残す」という体験を、文章ではなく2つのステップとして見せる。
    private var twoStepIndicator: some View {
        HStack(spacing: 10) {
            stepPill(label: "景色", systemImage: "mountain.2.fill", isDone: backImage != nil)

            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.28))

            stepPill(label: "表情", systemImage: "face.smiling.fill", isDone: frontImage != nil)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func stepPill(label: String, systemImage: String, isDone: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: isDone ? "checkmark.circle.fill" : systemImage)
                .font(.system(size: 11, weight: .bold))

            Text(label)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(isDone ? PictriTheme.teal : .white.opacity(0.42))
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(isDone ? PictriTheme.tealSoft : .white.opacity(0.06))
        .clipShape(Capsule())
        .animation(.easeOut(duration: 0.18), value: isDone)
    }

    private var captureControls: some View {
        ZStack {
            HStack {
                Spacer()

                Button {
                    guard !isCapturingSequence else { return }
                    cameraService.switchCamera()
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: 22, weight: .black))

                        Text(cameraService.currentPosition == .front ? "外へ" : "内へ")
                            .font(.system(size: 10, weight: .black))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 68, height: 68)
                    .background(.white.opacity(0.13))
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(PictriTheme.teal.opacity(0.35), lineWidth: 1.5)
                    }
                }
                .disabled(isCapturingSequence)
                .accessibilityLabel(cameraService.currentPosition == .front ? "外カメラに切り替え" : "内カメラに切り替え")
            }

            // 撮影可能CTAはmint/teal(PicTriの「撮る」文脈色)にする。青いグロー1色に
            // 頼ると、CameraだけAIツールの録画ボタンのように見えてしまうため。
            Button {
                startDualCapture()
            } label: {
                Circle()
                    .stroke(canCapture ? PictriTheme.teal : .white.opacity(0.28), lineWidth: 6)
                    .frame(width: 88, height: 88)
                    .shadow(color: canCapture ? PictriTheme.teal.opacity(0.55) : .clear, radius: 14)
                    .overlay {
                        Circle()
                            .fill(canCapture ? .white : .white.opacity(0.22))
                            .frame(width: 68, height: 68)
                            .overlay {
                                if isCapturingSequence {
                                    ProgressView()
                                        .tint(.black)
                                }
                            }
                    }
            }
            .disabled(!canCapture || isCapturingSequence)
            .accessibilityLabel("外カメラと内カメラで2枚撮影する")
            .accessibilityHint(canCapture ? "" : "現在は撮影できません")
        }
        .frame(height: 96)
    }

    // 「撮り直す」「メモリーに保存/で確認する」は、SpotDetailの「この場所で撮る」と
    // 同じ.pictriSecondary/.pictriPrimaryボタンスタイル経由にする。以前は手書きの
    // cornerRadius 18・font weight blackで、Camera独自の見た目になっていた。
    private func previewActions(previewImage: UIImage) -> some View {
        HStack(spacing: 12) {
            Button {
                resetCapture()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("撮り直す")
                }
            }
            .buttonStyle(.pictriSecondary)

            Button {
                if hasSaved {
                    // 保存後は同じボタンをMemoriesへの導線として使い、
                    // 3つ目のボタンを別枠で追加しない(画面下部がはみ出るため)。
                    // どのスポットを保存したかをMemoriesへ渡し、Collectの一覧経由ではなく
                    // 今撮った記憶をExplore Detailで直接開けるようにする。
                    pendingExploreSpotId = selectedSpot.id
                    selectedTab = .memories
                } else {
                    memoryStore.save(
                        image: previewImage,
                        for: selectedSpot,
                        verificationStatus: currentProofStatus,
                        verifiedDistanceMeters: currentDistanceMeters
                    )

                    withAnimation(.easeInOut(duration: 0.22)) {
                        hasSaved = true
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: hasSaved ? "square.grid.2x2.fill" : "bookmark.fill")
                    Text(hasSaved ? "メモリーで確認する" : "メモリーに保存")
                }
            }
            .buttonStyle(.pictriPrimary)
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
