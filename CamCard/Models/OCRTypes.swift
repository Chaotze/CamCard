import Foundation
import CoreGraphics

enum OCRSource: String, Codable, Hashable {
    case original
    case processed

    var displayName: String {
        switch self {
        case .original: return "原始图像"
        case .processed: return "处理后图像"
        }
    }
}

enum OCRStatus: String, Codable, Hashable {
    case success
    case empty
    case failed
}

struct OCRLine: Codable, Equatable, Identifiable, Hashable {
    var id: UUID
    var text: String
    var confidence: Double
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var sequence: Int

    init(
        id: UUID = UUID(),
        text: String,
        confidence: Double,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        sequence: Int
    ) {
        self.id = id
        self.text = text
        self.confidence = confidence
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.sequence = sequence
    }

    var normalizedRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

struct OCRRecord: Codable, Equatable, Identifiable, Hashable {
    var id: UUID
    var sequence: Int
    var source: OCRSource
    var status: OCRStatus
    var lines: [OCRLine]
    var failureReason: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        sequence: Int = 1,
        source: OCRSource,
        status: OCRStatus,
        lines: [OCRLine] = [],
        failureReason: String? = nil,
        createdAt: Date = Date(timeIntervalSince1970: 0)
    ) {
        self.id = id
        self.sequence = sequence
        self.source = source
        self.status = status
        self.lines = lines
        self.failureReason = failureReason
        self.createdAt = createdAt
    }

    var rawText: String {
        lines.sorted { $0.sequence < $1.sequence }.map(\.text).joined(separator: "\n")
    }
}
