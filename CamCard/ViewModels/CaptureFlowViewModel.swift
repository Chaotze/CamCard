import Foundation
import Combine
import CoreGraphics

@MainActor
final class CaptureFlowViewModel: ObservableObject {
    @Published private(set) var state: CaptureState = .idle
    @Published private(set) var originalImageData: Data?
    @Published private(set) var processedImageData: Data?
    @Published private(set) var corners: [CGPoint] = []
    @Published private(set) var ocrRecord: OCRRecord?
    @Published private(set) var structured: StructuredFields?
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?
    @Published var detectionMessage: String?
    @Published var cameraPermissionMessage: String?
    @Published var cameraPickerPresented = false
    @Published var photoPickerPresented = false

    private let environment: AppEnvironment
    private var draft: CardDraft?

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    var isReadyForReview: Bool { state == .readyForReview }
    var isUnrecognizable: Bool { state == .unrecognizable }
    var isDetectionFailed: Bool { state == .detectionFailed }
    var hasProcessedImage: Bool { processedImageData != nil }
    var cameraUnavailable: Bool { environment.cameraPermission.status() == .unavailable }

    func openCamera() async {
        let status = environment.cameraPermission.status()
        switch status {
        case .authorized:
            cameraPickerPresented = true
        case .notDetermined:
            let updated = await environment.cameraPermission.request()
            if updated == .authorized {
                cameraPickerPresented = true
            } else {
                cameraPermissionMessage = "相机权限已被拒绝，请在系统设置中允许访问相机，或从相册导入。"
            }
        case .denied, .restricted, .unavailable:
            cameraPermissionMessage = "无法使用相机。请在系统设置中允许相机访问，或从相册导入。"
        }
    }

    func openPhotoPicker() {
        photoPickerPresented = true
    }

    func start(with imageData: Data) async {
        guard let prepared = ImageProcessing.preparedJPEG(imageData) else {
            errorMessage = "图片无法读取，请重新选择"
            return
        }
        errorMessage = nil
        detectionMessage = nil
        let newDraft = CardDraft(state: .captured, originalData: prepared)
        draft = newDraft
        state = .captured
        originalImageData = prepared
        processedImageData = nil
        corners = []
        ocrRecord = nil
        structured = nil
        await detect()
    }

    func retryDetection() async {
        guard state == .detectionFailed else { return }
        await detect()
    }

    func continueWithOriginal() async {
        guard var current = draft else { return }
        current.processedData = nil
        current.corners = []
        draft = current
        processedImageData = nil
        corners = []
        detectionMessage = "未执行区域校正，继续识别原图"
        await runOCR()
    }

    func applyManualCrop(corners newCorners: [CGPoint]) async {
        guard var current = draft, newCorners.count == 4 else { return }
        isBusy = true
        defer { isBusy = false }
        let outcome = await environment.detection.rectify(
            imageData: current.originalData,
            corners: newCorners
        )
        switch outcome {
        case let .success(detected):
            current.processedData = detected.processedData
            current.corners = detected.corners
            try? current.transition(to: .detected)
            draft = current
            processedImageData = detected.processedData
            corners = detected.corners
            detectionMessage = nil
            state = current.state
            await runOCR()
        case let .failure(failure):
            detectionMessage = failure.message
        }
    }

    func proceedToManualEntry() async {
        guard var current = draft else { return }
        current.structured = .empty
        try? current.transition(to: .parsing)
        draft = current
        state = current.state
        structured = .empty
        try? current.transition(to: .readyForReview)
        draft = current
        state = current.state
    }

    func retake() {
        abandon()
        if cameraUnavailable {
            photoPickerPresented = true
        } else {
            cameraPickerPresented = true
        }
    }

    func cancel() {
        abandon()
    }

    func makeReviewViewModel() -> ReviewViewModel? {
        guard state == .readyForReview, let draft else { return nil }
        return ReviewViewModel(draft: draft, environment: environment)
    }

    private func abandon() {
        if var current = draft {
            try? current.transition(to: .abandoned)
            state = current.state
        }
        draft = nil
        originalImageData = nil
        processedImageData = nil
        corners = []
        ocrRecord = nil
        structured = nil
        detectionMessage = nil
        errorMessage = nil
    }

    private func detect() async {
        guard var current = draft else { return }
        isBusy = true
        defer { isBusy = false }
        try? current.transition(to: .detecting)
        draft = current
        state = current.state
        let outcome = await environment.detection.detect(in: current.originalData)
        switch outcome {
        case let .success(detected):
            current.processedData = detected.processedData
            current.corners = detected.corners
            try? current.transition(to: .detected)
            draft = current
            processedImageData = detected.processedData
            corners = detected.corners
            detectionMessage = nil
            state = current.state
            await runOCR()
        case let .failure(failure):
            current.state = .detectionFailed
            draft = current
            processedImageData = nil
            corners = []
            detectionMessage = failure.message
            state = .detectionFailed
        }
    }

    private func runOCR() async {
        guard var current = draft else { return }
        isBusy = true
        defer { isBusy = false }
        try? current.transition(to: .ocrRunning)
        draft = current
        state = current.state
        let input = current.processedData ?? current.originalData
        let source: OCRSource = current.processedData == nil ? .original : .processed
        let record = await environment.ocr.recognize(imageData: input, source: source)
        current.ocrRecord = record
        ocrRecord = record
        if record.status == .success, !record.lines.isEmpty {
            try? current.transition(to: .ocrFinished)
            draft = current
            state = current.state
            try? current.transition(to: .parsing)
            draft = current
            state = current.state
            let parsed = environment.parser.parse(record)
            current.structured = parsed
            structured = parsed
            try? current.transition(to: .readyForReview)
            draft = current
            state = current.state
        } else {
            current.state = .unrecognizable
            draft = current
            state = .unrecognizable
            errorMessage = "未识别到名片文字，请重拍或手动填写"
        }
    }
}
