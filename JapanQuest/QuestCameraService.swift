import Foundation
import SwiftUI
import UIKit
import AVFoundation
import Combine

final class QuestCameraService: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()

    @Published var isRunning = false
    @Published var isCameraAvailable = false
    @Published var permissionDenied = false
    @Published var currentPosition: AVCaptureDevice.Position = .back
    @Published var errorMessage: String?
    /// CAMERA ROUND 1「PHOTO QUALITY AUDIT」。デジカメModeでのみUIへ露出する
    /// flash設定。前面カメラ等flashが物理的に存在しない場合は`isFlashAvailable`が
    /// falseになるため、Viewはそちらを見て「使えない嘘のflash state」を出さない。
    @Published var flashMode: AVCaptureDevice.FlashMode = .off

    /// CAMERA / POST IMAGING ROUND「PART 11 — LIVE DIGICAM PREVIEW」。Digicam
    /// Mode選択中だけ、処理済みのlive frameがここに流れる(標準Mode中はnilの
    /// まま——処理コストをかけない)。CameraViewはこれがnilの間は通常の
    /// AVCaptureVideoPreviewLayer(QuestCameraPreview)を表示し続ける。
    @Published var digicamLiveFrame: CGImage?

    private let photoOutput = AVCapturePhotoOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let videoDataOutputQueue = DispatchQueue(label: "quest.camera.videoData.queue")
    /// Metal-backed(software renderer不使用)。Live Preview(低解像度frame)と
    /// 最終撮影後の後処理では別々のCIContextを持たず、この1つを共有する
    /// (GPUリソースの二重確保を避ける)。CIContextはApple公式に複数threadからの
    /// 並行renderingが安全と文書化されているため、`captureOutput`(専用の
    /// videoDataOutputQueue上で呼ばれる、MainActor外)から触れるよう
    /// `nonisolated(unsafe)`にする(このプロジェクトは`SWIFT_DEFAULT_ACTOR_
    /// ISOLATION = MainActor`のため、明示しない限り全型がMainActor-isolated
    /// になる)。
    nonisolated private let liveContext = CIContext(options: [.useSoftwareRenderer: false])
    /// Digicam Live Preview処理を今アクティブにすべきか。CameraView側から
    /// `cameraStyle == .digicam`の間だけtrueにする(MainActor上でBoolを
    /// set)。falseの間はcaptureOutput(_:didOutput:from:)の冒頭で即returnし、
    /// 処理コストをかけない。単純なBoolのtoggleで、1frame分の古い値を読んでも
    /// 実害が無い(最悪でも1frameだけ余分/不足に処理するだけ)ため
    /// `nonisolated(unsafe)`で許容する。
    nonisolated(unsafe) var isDigicamPreviewActive = false
    /// 「毎frame full processing禁止」(PART 12)のための簡易フレームスキップ。
    /// AVCaptureVideoDataOutputは通常30fps前後で届くため、2枚に1枚だけ処理して
    /// 実質15fps程度のprocessing負荷に抑える(表示自体はCALayer.contentsが
    /// 更新されるまで直前のframeを保持するため、体感は滑らかなまま)。
    /// videoDataOutputQueueという単一のserial queueからしか触れないため
    /// (AVCaptureVideoDataOutputは1つのdelegate queueでしかcallbackしない)、
    /// `nonisolated(unsafe)`でも競合状態にならない。
    nonisolated(unsafe) private var digicamFrameSkipCounter = 0
    private let sessionQueue = DispatchQueue(label: "quest.camera.session.queue")
    private var currentInput: AVCaptureDeviceInput?
    private var photoCompletion: ((UIImage?) -> Void)?

    /// 現在の入力デバイスが実際にflashを備えているか(前面カメラ等では常にfalse)。
    var isFlashAvailable: Bool {
        currentInput?.device.hasFlash ?? false
    }

    /// CAMERA ROUND 3「STEP 7 CAMERA DEVICE AUDIT」。機種名から存在するlensを
    /// 決め打ちせず、`AVCaptureDevice.DiscoverySession`が実機で実際に返す
    /// 個別の物理lens deviceTypeだけを見る。各lensの表示倍率は、wide lensとの
    /// `videoFieldOfView`比から計算する(ハードコードした「iPhone 17 Proは5x」等の
    /// 決め打ちは行わない)。Simulatorは常に単一の仮想カメラしか報告しないため、
    /// このリストは実質的に1件になり、Lens Selector UIは自動的に出ない
    /// (fake lensを出さない設計)。DEBUG QA表示専用、Production UIには出さない。
    var discoveredRearLensDescriptions: [String] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera, .builtInWideAngleCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: .back
        )
        guard let wideDevice = discovery.devices.first(where: { $0.deviceType == .builtInWideAngleCamera }) else {
            return discovery.devices.map { $0.localizedName }
        }
        let wideFOV = wideDevice.activeFormat.videoFieldOfView

        return discovery.devices.map { device in
            guard wideFOV > 0 else { return device.localizedName }
            let ratio = wideFOV / device.activeFormat.videoFieldOfView
            let rounded = (ratio * 2).rounded() / 2
            return "\(device.localizedName)(約\(rounded)x)"
        }
    }

    func requestAndConfigure() {
        let available = cameraDevice(for: .back) != nil || cameraDevice(for: .front) != nil

        DispatchQueue.main.async {
            self.isCameraAvailable = available
        }

        guard available else {
            DispatchQueue.main.async {
                self.errorMessage = "この環境ではカメラが使えません。"
            }
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession(
                position: currentPosition,
                startAfterConfigure: true,
                completion: nil
            )

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.permissionDenied = !granted
                }

                if granted {
                    self.configureSession(
                        position: self.currentPosition,
                        startAfterConfigure: true,
                        completion: nil
                    )
                }
            }

        case .denied, .restricted:
            DispatchQueue.main.async {
                self.permissionDenied = true
                self.errorMessage = "カメラの使用が許可されていません。"
            }

        @unknown default:
            break
        }
    }

    func switchCamera(
        to position: AVCaptureDevice.Position,
        completion: (() -> Void)? = nil
    ) {
        configureSession(
            position: position,
            startAfterConfigure: true,
            completion: completion
        )
    }

    func switchCamera() {
        let nextPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back

        configureSession(
            position: nextPosition,
            startAfterConfigure: true,
            completion: nil
        )
    }

    func capturePhoto(
        completion: @escaping (UIImage?) -> Void
    ) {
        guard isCameraAvailable, !permissionDenied else {
            completion(nil)
            return
        }

        photoCompletion = completion

        let settings = AVCapturePhotoSettings()
        // PHOTO QUALITY AUDIT: 以前は常時.offへ固定していたため、実機がflashを
        // 備えていても絶対に発光しなかった。デジカメModeでのみUIへ露出する
        // flashMode(AUTO/ON/OFF)をそのまま反映する。flash非対応デバイス/前面
        // カメラではisFlashAvailableがfalseになりUI自体を出さないため、ここでは
        // 常にflashModeをそのまま使ってよい(嘘のON状態が来ることはない)。
        settings.flashMode = isFlashAvailable ? flashMode : .off
        // PHOTO QUALITY AUDIT: qualityPrioritizationは非推奨APIではなく、
        // photoQualityPrioritizationがiOS 13+の正式な後継API。speed最適化
        // ではなく画質を優先させる(以前は未設定=システムのデフォルト任せだった)。
        if photoOutput.maxPhotoQualityPrioritization != .speed {
            settings.photoQualityPrioritization = photoOutput.maxPhotoQualityPrioritization
        }

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    /// CAMERA / POST IMAGING ROUND「PART 7 — TAP TO FOCUS / EXPOSURE」。manual
    /// ISO/shutterは持たず、標準的なiPhone Cameraアプリと同じ「tapした点へ
    /// focus+exposureを合わせる」の1点だけを実装する。前面カメラ等
    /// `isFocusPointOfInterestSupported`/`isExposurePointOfInterestSupported`が
    /// falseなデバイスでは何もしない(嘘の反応を返さない)。
    func focus(atDevicePoint devicePoint: CGPoint) {
        guard let device = currentInput?.device else { return }

        do {
            try device.lockForConfiguration()

            if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = devicePoint
                device.focusMode = .autoFocus
            }

            if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .autoExpose
            }

            device.unlockForConfiguration()
        } catch {
            // ロック取得に失敗しても撮影自体は継続できるため、エラー表示はしない
            // (既存のerrorMessageは「撮影不能」級の問題専用に使っている)。
        }
    }

    func stopSession() {
        sessionQueue.async {
            guard self.session.isRunning else {
                return
            }

            self.session.stopRunning()

            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }

    private func configureSession(
        position: AVCaptureDevice.Position,
        startAfterConfigure: Bool,
        completion: (() -> Void)?
    ) {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            if let currentInput = self.currentInput {
                self.session.removeInput(currentInput)
                self.currentInput = nil
            }

            guard let device = self.cameraDevice(for: position) else {
                self.session.commitConfiguration()

                DispatchQueue.main.async {
                    self.errorMessage = "カメラデバイスが見つかりません。"
                    completion?()
                }

                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)

                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.currentInput = input
                }

                let alreadyHasOutput = self.session.outputs.contains {
                    $0 === self.photoOutput
                }

                if !alreadyHasOutput, self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                }

                // CAMERA / POST IMAGING ROUND「PART 11 — LIVE DIGICAM PREVIEW」。
                // 同一sessionへAVCaptureVideoDataOutputを追加する(別sessionは
                // 持たない——2本のsessionを同時稼働させるコスト/複雑さを避ける)。
                // Standard Mode中もoutputはsessionに繋がったままだが、
                // `isDigicamPreviewActive`がfalseの間はdelegate側で即returnするため
                // 実質的な処理コストは発生しない。
                let alreadyHasVideoDataOutput = self.session.outputs.contains {
                    $0 === self.videoDataOutput
                }
                if !alreadyHasVideoDataOutput, self.session.canAddOutput(self.videoDataOutput) {
                    self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
                    self.videoDataOutput.setSampleBufferDelegate(self, queue: self.videoDataOutputQueue)
                    self.session.addOutput(self.videoDataOutput)
                }
                // CAMERA IMAGING ROUND 2「PART 4/5 — ONE ORIENTATION SOURCE OF
                // TRUTH」。旧実装は`videoDataOutput`のconnectionにだけorientationを
                // 明示していて、`photoOutput`のconnectionには一度も設定していな
                // かった(監査で発見)。AVCapturePhotoOutputは明示しない場合、
                // connection作成時点のデバイス回転状態に依存した既定値を使うため、
                // front cameraへの切替タイミング次第で「保存された写真だけ横向き」
                // になり得る——これがユーザー報告の「Front Cameraで横向きになる」
                // 症状の実体である可能性が高い。Preview(QuestCameraPreview.swift)・
                // VideoDataOutput・PhotoOutputの3つの出力すべてに、同じ1つの
                // ポリシー関数で同じportrait角度(90°)を適用する
                // (front/rearでrotation angle自体を変える必要は無い——front/rearの
                // 違いはmirroringだけで表現する、という単一のorientationポリシー)。
                Self.applyPortraitRotationAngle(to: self.videoDataOutput.connection(with: .video))
                Self.applyPortraitRotationAngle(to: self.photoOutput.connection(with: .video))

                // PHOTO QUALITY AUDIT: photoOutput.maxPhotoQualityPrioritizationを
                // 明示的に.qualityへ引き上げる(未設定時のデフォルトは.balanced)。
                // capturePhoto側のsettings.photoQualityPrioritizationと対にする必要がある
                // (出力側の上限を超える値をsettingsへ指定するとcapturePhotoが例外を出すため、
                // 先に出力側の上限を上げてから、settings側はその上限をそのまま使う)。
                self.photoOutput.maxPhotoQualityPrioritization = .quality

                // PHOTO QUALITY AUDIT: iOS 16+のmaxPhotoDimensions APIで、
                // アクティブフォーマットが対応する最大解像度を明示的に使う
                // (未設定のままだとsessionPreset由来の解像度に留まることがある)。
                // 新しいdeprecated APIは追加しない(既存のsessionPreset = .photoは維持)。
                if #available(iOS 16.0, *),
                   let maxDimensions = device.activeFormat.supportedMaxPhotoDimensions.max(by: {
                       Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height)
                   }) {
                    self.photoOutput.maxPhotoDimensions = maxDimensions
                }

                self.session.commitConfiguration()

                if startAfterConfigure, !self.session.isRunning {
                    self.session.startRunning()
                }

                DispatchQueue.main.async {
                    self.currentPosition = position
                    self.isRunning = self.session.isRunning
                    self.errorMessage = nil
                    completion?()
                }
            } catch {
                self.session.commitConfiguration()

                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    completion?()
                }
            }
        }
    }

    // MARK: - Digicam Live Preview (PART 11)

    /// 低解像度frame(長辺640px程度)へdownscaleしてからCore Image処理する。
    /// 撮影されるfull-resolution写真には一切影響しない(このframeは表示専用、
    /// `digicamLiveFrame`としてCameraViewが読むだけ)。
    nonisolated private static let livePreviewMaxDimension: CGFloat = 640

    nonisolated private func downscaledCIImage(from ciImage: CIImage) -> CIImage {
        let extent = ciImage.extent
        let longSide = max(extent.width, extent.height)
        guard longSide > Self.livePreviewMaxDimension, longSide.isFinite, longSide > 0 else {
            return ciImage
        }
        let factor = Self.livePreviewMaxDimension / longSide
        return ciImage.transformed(by: CGAffineTransform(scaleX: factor, y: factor))
    }

    /// CAMERA IMAGING ROUND 2「PART 5 — 単一のorientationポリシー」。PicTriは
    /// Portrait-only(他画面含め回転をサポートしない前提、ContentView/各画面が
    /// 縦固定のレイアウトのみを組んでいることを確認済み)なので、
    /// front/rear問わず常にrotation angle 90(portrait)を使う。front/rearの
    /// 見た目の違いはmirroring(`isVideoMirrored`)だけで表現し、角度自体は
    /// 決め打ちの90/270切替のような場当たり的なmagic numberにしない
    /// (どちらのpositionでも90固定、という一貫したルール)。
    /// VideoDataOutput/PhotoOutput双方のconnectionへ同じ関数で適用することで、
    /// 出力ごとに別々のorientationポリシーを持たないようにする(Preview側は
    /// QuestCameraPreview.swiftのupdateVideoOrientationが同じ90度ルールを
    /// 適用する——3出力共通のポリシー)。
    private static func applyPortraitRotationAngle(to connection: AVCaptureConnection?) {
        guard let connection, connection.isVideoRotationAngleSupported(90) else { return }
        connection.videoRotationAngle = 90
    }

    private func cameraDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: position
        )
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let completion = photoCompletion
        photoCompletion = nil

        if let error {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                completion?(nil)
            }
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            DispatchQueue.main.async {
                self.errorMessage = "写真データを読み込めませんでした。"
                completion?(nil)
            }
            return
        }

        DispatchQueue.main.async {
            completion?(image)
        }
    }
}

// MARK: - Digicam Live Preview frame delegate (PART 11/12)

extension QuestCameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard isDigicamPreviewActive else { return }

        // PART 12「NO HEAVY FULL-RES LIVE PROCESSING」。2枚に1枚だけ処理し、
        // 残り帯域を撮影/session自体の安定性へ譲る。
        digicamFrameSkipCounter += 1
        guard digicamFrameSkipCounter % 2 == 0 else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let sourceImage = CIImage(cvImageBuffer: pixelBuffer)
        let downscaled = downscaledCIImage(from: sourceImage)

        guard let processed = PictriCameraStyleProcessor.applyProfile(.liveFast, to: downscaled) else {
            return
        }

        guard let cgImage = liveContext.createCGImage(processed, from: processed.extent) else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.digicamLiveFrame = cgImage
        }
    }
}
