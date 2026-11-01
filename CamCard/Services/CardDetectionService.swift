import Foundation
import CoreImage
import Vision
import UIKit

enum DetectionFailure: String, Equatable, Error {
    case invalidImage
    case noCard
    case processingFailed

    var message: String {
        switch self {
        case .invalidImage: return "图片无法读取"
        case .noCard: return "未检测到名片区域"
        case .processingFailed: return "图像校正失败"
        }
    }
}

enum DetectionOutcome: Equatable {
    case success(DetectedCard)
    case failure(DetectionFailure)
}

protocol CardDetectionService {
    func detect(in imageData: Data) async -> DetectionOutcome
    func rectify(imageData: Data, corners: [CGPoint]) async -> DetectionOutcome
}

final class VisionCardDetectionService: CardDetectionService {
    func detect(in imageData: Data) async -> DetectionOutcome {
        let prepared = ImageProcessing.preparedJPEG(imageData) ?? imageData
        guard let cgImage = ImageProcessing.cgImage(from: prepared) else {
            return .failure(.invalidImage)
        }
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 8
        request.minimumConfidence = 0.5
        request.minimumSize = 0.2
        request.quadratureTolerance = 30
        request.minimumAspectRatio = 0.5
        request.maximumAspectRatio = 3.0
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return .failure(.processingFailed)
        }
        guard let observation = chooseCandidate(request.results ?? []) else {
            return .failure(.noCard)
        }
        let corners = normalizedCorners(for: observation)
        return await rectify(imageData: prepared, corners: corners)
    }

    func rectify(imageData: Data, corners: [CGPoint]) async -> DetectionOutcome {
        guard corners.count == 4 else { return .failure(.invalidImage) }
        let prepared = ImageProcessing.preparedJPEG(imageData) ?? imageData
        guard let ciImage = ImageProcessing.ciImage(from: prepared) else {
            return .failure(.invalidImage)
        }
        let extent = ciImage.extent
        guard extent.width > 0, extent.height > 0 else {
            return .failure(.invalidImage)
        }
        func point(_ normalized: CGPoint) -> CGPoint {
            CGPoint(
                x: extent.origin.x + normalized.x * extent.width,
                y: extent.origin.y + (1 - normalized.y) * extent.height
            )
        }
        let filter = CIFilter(name: "CIPerspectiveCorrection")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(CIVector(cgPoint: point(corners[0])), forKey: "inputTopLeft")
        filter?.setValue(CIVector(cgPoint: point(corners[1])), forKey: "inputTopRight")
        filter?.setValue(CIVector(cgPoint: point(corners[2])), forKey: "inputBottomLeft")
        filter?.setValue(CIVector(cgPoint: point(corners[3])), forKey: "inputBottomRight")
        guard var output = filter?.outputImage else {
            return .failure(.processingFailed)
        }
        let outputExtent = output.extent
        guard outputExtent.width > 0, outputExtent.height > 0 else {
            return .failure(.processingFailed)
        }
        output = output.transformed(by: CGAffineTransform(
            translationX: -outputExtent.origin.x,
            y: -outputExtent.origin.y
        ))
        if output.extent.width < output.extent.height {
            output = output.oriented(.right)
        }
        guard let processed = ImageProcessing.jpegData(from: output) else {
            return .failure(.processingFailed)
        }
        return .success(DetectedCard(corners: corners, processedData: processed))
    }

    private func chooseCandidate(_ observations: [VNRectangleObservation]) -> VNRectangleObservation? {
        guard !observations.isEmpty else { return nil }
        let sorted = observations.sorted { lhs, rhs in
            let leftArea = lhs.boundingBox.width * lhs.boundingBox.height
            let rightArea = rhs.boundingBox.width * rhs.boundingBox.height
            if abs(leftArea - rightArea) > 0.1 * max(leftArea, rightArea) {
                return leftArea > rightArea
            }
            return aspectDistance(lhs) < aspectDistance(rhs)
        }
        return sorted.first
    }

    private func aspectDistance(_ observation: VNRectangleObservation) -> Double {
        let box = observation.boundingBox
        guard box.height > 0 else { return .infinity }
        let ratio = Double(box.width / box.height)
        return abs(ratio - 1.58)
    }

    private func normalizedCorners(for observation: VNRectangleObservation) -> [CGPoint] {
        func convert(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x, y: 1 - point.y)
        }
        return [
            convert(observation.topLeft),
            convert(observation.topRight),
            convert(observation.bottomLeft),
            convert(observation.bottomRight)
        ]
    }
}

final class MockCardDetectionService: CardDetectionService {
    var outcome: DetectionOutcome?
    var shouldFail = false

    init(shouldFail: Bool = false) {
        self.shouldFail = shouldFail
    }

    func detect(in imageData: Data) async -> DetectionOutcome {
        if let outcome { return outcome }
        if shouldFail { return .failure(.noCard) }
        let prepared = ImageProcessing.preparedJPEG(imageData) ?? imageData
        return .success(DetectedCard(corners: Self.defaultCorners, processedData: prepared))
    }

    func rectify(imageData: Data, corners: [CGPoint]) async -> DetectionOutcome {
        if shouldFail { return .failure(.processingFailed) }
        let prepared = ImageProcessing.preparedJPEG(imageData) ?? imageData
        return .success(DetectedCard(corners: corners, processedData: prepared))
    }

    static let defaultCorners = [
        CGPoint(x: 0.08, y: 0.18),
        CGPoint(x: 0.92, y: 0.18),
        CGPoint(x: 0.08, y: 0.82),
        CGPoint(x: 0.92, y: 0.82)
    ]
}
