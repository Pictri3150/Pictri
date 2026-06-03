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

    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "quest.camera.session.queue")
    private var currentInput: AVCaptureDeviceInput?
    private var photoCompletion: ((UIImage?) -> Void)?

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
        settings.flashMode = .off

        photoOutput.capturePhoto(with: settings, delegate: self)
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
