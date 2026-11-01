import AVFoundation
import UIKit

enum CameraPermissionStatus: Equatable {
    case authorized
    case denied
    case restricted
    case notDetermined
    case unavailable

    var isDenied: Bool {
        self == .denied || self == .restricted
    }
}

protocol CameraPermissionProviding {
    func status() -> CameraPermissionStatus
    func request() async -> CameraPermissionStatus
}

final class CameraPermissionService: CameraPermissionProviding {
    func status() -> CameraPermissionStatus {
        guard UIImagePickerCameraAvailable() else { return .unavailable }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .unavailable
        }
    }

    func request() async -> CameraPermissionStatus {
        guard UIImagePickerCameraAvailable() else { return .unavailable }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        return granted ? .authorized : .denied
    }

    private func UIImagePickerCameraAvailable() -> Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
}

final class StaticCameraPermissionService: CameraPermissionProviding {
    var current: CameraPermissionStatus

    init(current: CameraPermissionStatus) {
        self.current = current
    }

    func status() -> CameraPermissionStatus { current }

    func request() async -> CameraPermissionStatus { current }
}
