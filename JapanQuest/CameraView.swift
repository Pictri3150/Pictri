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
    private let panelHeight: CGFloat = 620

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
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                cameraHeader

                cameraPanel

                if blockingState == .none {
                    statusCard
                }

                cameraBottomArea

                Spacer(minLength: 8)
            }
            .padding(.horizontal, JQUI.sidePadding)
            .padding(.top, 22)
            .padding(.bottom, 14)
        }
        .onAppear {
            cameraService.requestAndConfigure()

            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestPermission()
            }
        }
        .onDisappear {
            cameraService.stopSession()
        }
    }

    private var cameraHeader: some View {
        PictriScreenHeader(eyebrow: "CAMERA", title: selectedSpot.name) {
            Button {
                resetCapture()
                selectedTab = .home
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.10))
                    .clipShape(Circle())
            }
            .accessibilityLabel("カメラを閉じてホームへ戻る")
        }
    }

    private var cameraPanel: some View {
        ZStack {
            cameraLayer

            if blockingState == .none {
                liveLocationOverlay

                if let frontImage, previewImage == nil {
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
        .frame(height: panelHeight)
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
                    .frame(height: panelHeight)
                    .clipped()
            } else if cameraService.isCameraAvailable && !cameraService.permissionDenied {
                QuestCameraPreview(session: cameraService.session)
                    .frame(height: panelHeight)
                    .clipped()
            } else {
                demoCameraBackground
            }

            if !cameraService.isCameraAvailable && previewImage == nil {
                VStack {
                    HStack {
                        Spacer()
                        PictriGlassPill(text: "サンプル表示", systemImage: "sparkles", tone: .muted)
                    }
                    Spacer()
                }
                .padding(18)
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
    }

    private var demoCameraBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.54, green: 0.53, blue: 0.49),
                Color(red: 0.20, green: 0.22, blue: 0.23),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(height: panelHeight)
        .overlay {
            VStack(spacing: 24) {
                Rectangle()
                    .fill(.white.opacity(0.16))
                    .frame(height: 4)
                    .padding(.horizontal, 48)

                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(height: 92)
                    .padding(.horizontal, 34)

                Rectangle()
                    .fill(.white.opacity(0.06))
                    .frame(height: 146)
                    .padding(.horizontal, 18)

                Spacer()
            }
            .padding(.top, 142)
        }
    }

    private var cameraPanelTopControls: some View {
        HStack(alignment: .top) {
            PictriGlassPill(text: cameraModeText)

            Spacer()

            if isCapturingSequence {
                PictriGlassPill(text: sequenceText, tone: .muted)
            }

            #if DEBUG
            Toggle("", isOn: $developerUnlockMode)
                .labelsHidden()
                .scaleEffect(0.55)
                .padding(.horizontal, 2)
                .background(.black.opacity(0.25), in: Capsule())
                .accessibilityLabel("開発用: 位置認証を無視して撮影を解放")
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
                captureControls
            }

            if hasSaved {
                Button {
                    selectedTab = .memories
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.grid.2x2.fill")
                        Text("メモリーで確認する")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: hasSaved)
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
                            .stroke(PictriTheme.accent.opacity(0.35), lineWidth: 1.5)
                    }
                }
                .disabled(isCapturingSequence)
                .accessibilityLabel(cameraService.currentPosition == .front ? "外カメラに切り替え" : "内カメラに切り替え")
            }

            Button {
                startDualCapture()
            } label: {
                Circle()
                    .stroke(canCapture ? PictriTheme.accent : .white.opacity(0.28), lineWidth: 6)
                    .frame(width: 88, height: 88)
                    .shadow(color: canCapture ? PictriTheme.accent.opacity(0.55) : .clear, radius: 14)
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

    private func previewActions(previewImage: UIImage) -> some View {
        HStack(spacing: 12) {
            Button {
                resetCapture()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("撮り直す")
                }
                .font(.system(size: 15, weight: .black))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(.white.opacity(0.12))
                .foregroundStyle(.white)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                )
            }

            Button {
                memoryStore.save(
                    image: previewImage,
                    for: selectedSpot,
                    verificationStatus: currentProofStatus,
                    verifiedDistanceMeters: currentDistanceMeters
                )

                withAnimation(.easeInOut(duration: 0.22)) {
                    hasSaved = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: hasSaved ? "checkmark.circle.fill" : "bookmark.fill")
                    Text(hasSaved ? "保存済み" : "メモリーに保存")
                }
                .font(.system(size: 15, weight: .black))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(hasSaved ? .white.opacity(0.14) : .white)
                .foregroundStyle(hasSaved ? .white.opacity(0.88) : .black)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                )
            }
            .disabled(hasSaved)
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

            let colorSpace = CGColorSpaceCreateDeviceRGB()

            let colors: [CGColor]

            if isFrontCamera {
                colors = [
                    UIColor(red: 0.22, green: 0.21, blue: 0.20, alpha: 1).cgColor,
                    UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1).cgColor
                ]
            } else {
                colors = [
                    UIColor(red: 0.70, green: 0.68, blue: 0.58, alpha: 1).cgColor,
                    UIColor(red: 0.25, green: 0.28, blue: 0.29, alpha: 1).cgColor,
                    UIColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1).cgColor
                ]
            }

            let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: colors as CFArray,
                locations: nil
            )!

            cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )

            drawDemoScene(
                in: cgContext,
                size: size,
                spot: spot,
                isFrontCamera: isFrontCamera
            )
        }
    }

    private static func drawDemoScene(
        in context: CGContext,
        size: CGSize,
        spot: QuestSpot,
        isFrontCamera: Bool
    ) {
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.15).cgColor)
        context.setLineWidth(5)

        for i in 0..<7 {
            let y = CGFloat(280 + i * 130)
            context.move(to: CGPoint(x: 90, y: y))
            context.addLine(to: CGPoint(x: size.width - 90, y: y + CGFloat(i * 8)))
            context.strokePath()
        }

        context.setFillColor(UIColor.white.withAlphaComponent(0.10).cgColor)

        for i in 0..<9 {
            let x = CGFloat(120 + i * 95)
            let rect = CGRect(x: x, y: 520, width: 36, height: 36)
            context.fillEllipse(in: rect)
        }

        context.setFillColor(UIColor.black.withAlphaComponent(0.18).cgColor)
        context.fill(
            CGRect(
                x: 0,
                y: size.height * 0.68,
                width: size.width,
                height: size.height * 0.32
            )
        )

        let title = isFrontCamera ? "front camera" : spot.englishName.lowercased()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 42, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.28)
        ]

        title.draw(
            in: CGRect(
                x: 70,
                y: size.height - 240,
                width: size.width - 140,
                height: 70
            ),
            withAttributes: attributes
        )
    }
}

enum QuestDualPhotoComposer {
    static func compose(
        backImage: UIImage,
        frontImage: UIImage?,
        spot: QuestSpot
    ) -> UIImage {
        let canvasSize = CGSize(width: 1080, height: 1920)

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
        let insetRect = CGRect(
            x: 58,
            y: 78,
            width: 286,
            height: 382
        )

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
}
