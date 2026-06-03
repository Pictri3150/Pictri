import SwiftUI
import AVFoundation

struct QuestCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> QuestCameraPreviewView {
        let view = QuestCameraPreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(
        _ uiView: QuestCameraPreviewView,
        context: Context
    ) {
        uiView.videoPreviewLayer.session = session
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

    override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds
        updateVideoOrientation()
    }

    func updateVideoOrientation() {
        guard let connection = videoPreviewLayer.connection,
              connection.isVideoOrientationSupported else {
            return
        }

        connection.videoOrientation = .portrait
    }
}
