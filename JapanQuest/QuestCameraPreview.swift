import SwiftUI
import AVFoundation

struct QuestCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    /// CAMERA / POST IMAGING ROUND「PART 7 — TAP TO FOCUS」。layer座標系での
    /// tap位置(そのまま`onFocusTap`へ渡す、`view.bounds`基準)。device point
    /// への変換はQuestCameraPreviewView自身(videoPreviewLayerを直接持っている
    /// 唯一の場所)が行う——呼び出し側は「どこがtapされたか(layer座標)」と
    /// 「そのtapが指すAVCaptureDevice.Point」の両方を受け取るだけでよい。
    var onFocusTap: ((_ layerPoint: CGPoint, _ devicePoint: CGPoint) -> Void)?

    func makeUIView(context: Context) -> QuestCameraPreviewView {
        let view = QuestCameraPreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.onFocusTap = onFocusTap
        return view
    }

    func updateUIView(
        _ uiView: QuestCameraPreviewView,
        context: Context
    ) {
        uiView.videoPreviewLayer.session = session
        uiView.onFocusTap = onFocusTap
        uiView.updateVideoOrientation()
    }
}

final class QuestCameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    var onFocusTap: ((_ layerPoint: CGPoint, _ devicePoint: CGPoint) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTapGesture()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTapGesture()
    }

    private func setupTapGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        let layerPoint = recognizer.location(in: self)
        let devicePoint = videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: layerPoint)
        onFocusTap?(layerPoint, devicePoint)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds
        updateVideoOrientation()
    }

    /// CAMERA IMAGING ROUND 2「PART 5 — ONE ORIENTATION SOURCE OF TRUTH」。
    /// 旧`videoOrientation`(deprecated)から、QuestCameraServiceの
    /// VideoDataOutput/PhotoOutputと同じ`videoRotationAngle`(90° = portrait)
    /// APIへ統一する。PicTriはPortrait-onlyのため、front/rear問わず常に90度
    /// (mirroringだけがpositionで変わる、という同じ単一ポリシー)。
    /// `layoutSubviews`(frameが変わるたび)と`updateUIView`(SwiftUI再描画の
    /// たび)の両方から呼ばれるため、switchCamera直後にconnectionがまだ
    /// 準備できていなくても、次のlayout/再描画で確実に再適用される。
    func updateVideoOrientation() {
        guard let connection = videoPreviewLayer.connection,
              connection.isVideoRotationAngleSupported(90) else {
            return
        }

        connection.videoRotationAngle = 90
    }
}
