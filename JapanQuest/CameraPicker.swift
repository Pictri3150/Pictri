import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    let cameraDevice: UIImagePickerController.CameraDevice
    let onImagePicked: (UIImage) -> Void
    let onCancel: () -> Void

    init(
        cameraDevice: UIImagePickerController.CameraDevice = .rear,
        onImagePicked: @escaping (UIImage) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.cameraDevice = cameraDevice
        self.onImagePicked = onImagePicked
        self.onCancel = onCancel
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onImagePicked: onImagePicked,
            onCancel: onCancel
        )
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = false

        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo

            if UIImagePickerController.isCameraDeviceAvailable(cameraDevice) {
                picker.cameraDevice = cameraDevice
            }
        } else {
            picker.sourceType = .photoLibrary
        }

        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIImagePickerController,
        context: Context
    ) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let onCancel: () -> Void

        init(
            onImagePicked: @escaping (UIImage) -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.onImagePicked = onImagePicked
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
