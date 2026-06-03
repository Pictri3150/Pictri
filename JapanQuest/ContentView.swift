import SwiftUI
import UIKit
import AVFoundation
import CoreLocation
import Combine

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @State private var activeCameraSpotId: String = "enoshima_coast"
    @StateObject private var memoryStore = QuestMemoryStore()
    @StateObject private var friendStore = QuestFriendStore()
    @StateObject private var locationManager = QuestLocationManager()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            activeScreen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.ignoresSafeArea())
                .animation(.easeInOut(duration: 0.18), value: selectedTab)

            JQFloatingTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
        }
        .background(Color.black.ignoresSafeArea())
        .environmentObject(memoryStore)
        .environmentObject(friendStore)
        .environmentObject(locationManager)
    }
    
    @ViewBuilder
    private var activeScreen: some View {
        switch selectedTab {
        case .home:
            HomeView(selectedTab: $selectedTab)

        case .map:
            QuestMapView(
                selectedTab: $selectedTab,
                activeCameraSpotId: $activeCameraSpotId
            )

        case .camera:
            QuestCameraView(
                selectedTab: $selectedTab,
                selectedSpotId: $activeCameraSpotId
            )

        case .memories:
            MemoriesView()
        }
    }
}

struct JQFloatingTabBar: View {
    @Binding var selectedTab: AppTab

    private let tabs: [AppTab] = [
        .home,
        .map,
        .camera,
        .memories
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selectedTab = tab
                    }
                } label: {
                    JQFloatingTabItem(
                        tab: tab,
                        isSelected: selectedTab == tab
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(7)
        .background {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.black.opacity(0.78))
                .background {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 22, x: 0, y: 12)
    }
}

struct JQFloatingTabItem: View {
    let tab: AppTab
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: tab.iconName)
                .font(.system(size: 22, weight: .bold))
                .symbolRenderingMode(.hierarchical)

            Text(tab.title)
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(isSelected ? .black : .white.opacity(0.78))
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(.white)
                    .shadow(color: .white.opacity(0.18), radius: 10, x: 0, y: 0)
            } else {
                Color.clear
            }
        }
        .contentShape(Rectangle())
    }
}

enum AppTab: Hashable, CaseIterable {
    case home
    case map
    case camera
    case memories

    var title: String {
        switch self {
        case .home:
            return "ホーム"
        case .map:
            return "マップ"
        case .camera:
            return "カメラ"
        case .memories:
            return "メモリー"
        }
    }

    var iconName: String {
        switch self {
        case .home:
            return "house.fill"
        case .map:
            return "map.fill"
        case .camera:
            return "camera.fill"
        case .memories:
            return "square.grid.2x2.fill"
        }
    }
}

enum JQUI {
    static let sidePadding: CGFloat = 18
    static let screenTopPadding: CGFloat = 70
    static let panelHeight: CGFloat = 540
    static let panelCornerRadius: CGFloat = 34
    static let bottomBarReserve: CGFloat = 116
}

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

    @AppStorage("developerUnlockMode") private var developerUnlockMode = true

    @StateObject private var cameraService = QuestCameraService()

    @State private var previewImage: UIImage?
    @State private var frontImage: UIImage?
    @State private var backImage: UIImage?

    @State private var hasSaved = false
    @State private var isCapturingSequence = false
    @State private var countdownNumber: Int?
    @State private var capturePhase: QuestDualCapturePhase = .idle
    @State private var captureRunID = UUID()

    private let panelHeight: CGFloat = 540
    
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

    private var unlockStatusText: String {
        if developerUnlockMode {
            return "開発モード"
        }

        if locationManager.isNear(selectedSpot) {
            return "撮影できます"
        }

        return "近づくと解放"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                cameraHeader

                cameraPanel

                cameraBottomArea

                Spacer(minLength: JQUI.bottomBarReserve)
            }
            .padding(.horizontal, JQUI.sidePadding)
            .padding(.top, JQUI.screenTopPadding)
        }
        .onAppear {
            cameraService.requestAndConfigure()
        }
        .onDisappear {
            cameraService.stopSession()
        }
    }

    private var cameraHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Camera")
                    .font(.system(size: 44, weight: .black))
                    .foregroundStyle(.white)

                Text("\(selectedSpot.name)で撮影")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.46))
                    .lineLimit(1)
            }

            Spacer()

            Button {
                resetCapture()
                selectedTab = .home
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.black)
                    .frame(width: 56, height: 56)
                    .background(.white)
                    .clipShape(Circle())
            }
            .padding(.top, 4)
        }
    }

    private var cameraPanel: some View {
        ZStack {
            cameraLayer

            liveLocationOverlay

            if let frontImage, previewImage == nil {
                frontMiniPreview(image: frontImage)
            }

            if !isUnlocked {
                lockedOverlay
            }

            if let countdownNumber {
                countdownOverlay(number: countdownNumber)
            }

            cameraPanelTopControls
        }
        .frame(height: JQUI.panelHeight)
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
                    .frame(height: JQUI.panelHeight)
                    .clipped()
            } else if cameraService.isCameraAvailable && !cameraService.permissionDenied {
                QuestCameraPreview(session: cameraService.session)
                    .frame(height: JQUI.panelHeight)
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

    private var cameraBootView: some View {
        ZStack {
            Color.black

            VStack(spacing: 12) {
                ProgressView()
                    .tint(.white)

                Text("カメラを起動中")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.82))

                if let message = cameraService.errorMessage {
                    Text(message)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.50))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
        }
        .frame(height: panelHeight)
    }

    private var cameraPanelTopControls: some View {
        VStack(spacing: 10) {
            HStack {
                Text(cameraModeText)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.white)
                    .clipShape(Capsule())

                Spacer()

                if isCapturingSequence {
                    Text(sequenceText)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(.black.opacity(0.32))
                        .clipShape(Capsule())
                }
            }

            HStack {
                Text("\(unlockStatusText) ・ \(locationManager.distanceText(to: selectedSpot))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer()

                #if DEBUG
                Toggle("", isOn: $developerUnlockMode)
                    .labelsHidden()
                    .scaleEffect(0.68)
                #endif
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(.black.opacity(0.25))
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var liveLocationOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(currentDateText())
                .font(.system(size: 24, weight: .semibold, design: .monospaced))

            Text(selectedSpot.englishName.lowercased())
                .font(.system(size: 31, weight: .black, design: .monospaced))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(.white.opacity(0.17))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .padding(22)
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

    private var lockedOverlay: some View {
        Color.black.opacity(0.58)
            .overlay {
                VStack(spacing: 13) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 42, weight: .bold))

                    Text("ここではまだ撮れません")
                        .font(.system(size: 21, weight: .bold))

                    Text("\(selectedSpot.name)の近くで解放されます")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.58))
                }
                .foregroundStyle(.white)
            }
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
        guard isUnlocked, !isCapturingSequence else {
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

            Text("選択中のカメラから撮影し、続けて反対側を撮ります")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.42))
                .frame(maxWidth: .infinity, alignment: .center)
        }
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
                }
                .disabled(isCapturingSequence)
            }

            Button {
                startDualCapture()
            } label: {
                Circle()
                    .stroke(isUnlocked ? .white : .white.opacity(0.28), lineWidth: 6)
                    .frame(width: 88, height: 88)
                    .overlay {
                        Circle()
                            .fill(isUnlocked ? .white : .white.opacity(0.22))
                            .frame(width: 68, height: 68)
                            .overlay {
                                if isCapturingSequence {
                                    ProgressView()
                                        .tint(.black)
                                }
                            }
                    }
            }
            .disabled(!isUnlocked || isCapturingSequence)
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

                hasSaved = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: hasSaved ? "checkmark.circle.fill" : "paperplane.fill")
                    Text(hasSaved ? "保存済み" : "保存してシェア")
                }
                .font(.system(size: 15, weight: .black))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(hasSaved ? .green : .white)
                .foregroundStyle(hasSaved ? .white : .black)
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


// MARK: - Shared

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.02, blue: 0.025),
                Color(red: 0.07, green: 0.07, blue: 0.075)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}


#Preview {
    ContentView()
}
