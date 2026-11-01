import Foundation

enum CaptureState: String, Codable, CaseIterable, Equatable {
    case idle
    case capturing
    case captured
    case detecting
    case detected
    case detectionFailed
    case ocrRunning
    case ocrFinished
    case unrecognizable
    case parsing
    case readyForReview
    case saving
    case saved
    case savingFailed
    case abandoned

    func canTransition(to next: CaptureState) -> Bool {
        if next == .abandoned { return self != .abandoned }
        switch (self, next) {
        case (.idle, .capturing), (.idle, .captured):
            return true
        case (.capturing, .captured):
            return true
        case (.captured, .detecting):
            return true
        case (.detecting, .detected), (.detecting, .detectionFailed):
            return true
        case (.detected, .ocrRunning):
            return true
        case (.detectionFailed, .detecting), (.detectionFailed, .detected), (.detectionFailed, .ocrRunning):
            return true
        case (.ocrRunning, .ocrFinished), (.ocrRunning, .unrecognizable):
            return true
        case (.ocrFinished, .parsing), (.ocrFinished, .unrecognizable):
            return true
        case (.unrecognizable, .ocrRunning), (.unrecognizable, .parsing):
            return true
        case (.parsing, .readyForReview):
            return true
        case (.readyForReview, .saving):
            return true
        case (.saving, .saved), (.saving, .savingFailed):
            return true
        case (.savingFailed, .saving):
            return true
        default:
            return false
        }
    }
}

enum CaptureTransitionError: Error, LocalizedError, Equatable {
    case invalid(from: CaptureState, to: CaptureState)

    var errorDescription: String? {
        switch self {
        case let .invalid(from, to):
            return "无法从 \(from.rawValue) 进入 \(to.rawValue)"
        }
    }
}

struct DetectedCard: Equatable {
    var corners: [CGPoint]
    var processedData: Data?
}

struct CardDraft {
    var id: UUID
    var state: CaptureState
    var originalData: Data
    var processedData: Data?
    var corners: [CGPoint]
    var ocrRecord: OCRRecord?
    var structured: StructuredFields?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        state: CaptureState = .captured,
        originalData: Data,
        processedData: Data? = nil,
        corners: [CGPoint] = [],
        ocrRecord: OCRRecord? = nil,
        structured: StructuredFields? = nil,
        createdAt: Date = Date(timeIntervalSince1970: 0)
    ) {
        self.id = id
        self.state = state
        self.originalData = originalData
        self.processedData = processedData
        self.corners = corners
        self.ocrRecord = ocrRecord
        self.structured = structured
        self.createdAt = createdAt
    }

    mutating func transition(to next: CaptureState) throws {
        guard state.canTransition(to: next) else {
            throw CaptureTransitionError.invalid(from: state, to: next)
        }
        state = next
    }
}
