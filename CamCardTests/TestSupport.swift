import Foundation
import XCTest
@testable import CamCard

@MainActor
func makeTestEnvironment(
    repository: CardRepository = InMemoryCardRepository(),
    imageStore: ImageStore = InMemoryImageStore(),
    ocr: OCRService = MockOCRService(fixture: "standard"),
    detection: CardDetectionService = MockCardDetectionService(),
    clock: Clock = FixedClock(),
    exportWriter: VCardFileWriter = TemporaryVCardWriter(),
    options: LaunchOptions = LaunchOptions()
) -> AppEnvironment {
    AppEnvironment(
        repository: repository,
        imageStore: imageStore,
        ocr: ocr,
        detection: detection,
        parser: BusinessCardFieldParser(),
        clock: clock,
        cameraPermission: StaticCameraPermissionService(current: .authorized),
        exportWriter: exportWriter,
        launchOptions: options
    )
}

func makeOCRRecord(_ lines: [String], status: OCRStatus = .success) -> OCRRecord {
    let ocrLines = lines.enumerated().map { index, text in
        OCRLine(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!,
            text: text,
            confidence: 0.95,
            x: 0.1,
            y: max(0.02, 0.9 - Double(index) * 0.08),
            width: 0.7,
            height: 0.05,
            sequence: index
        )
    }
    return OCRRecord(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000099")!,
        sequence: 1,
        source: .processed,
        status: status,
        lines: ocrLines,
        createdAt: Date(timeIntervalSince1970: 0)
    )
}

func makeTemporaryDirectory(_ name: String = UUID().uuidString) -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("CamCardTests-\(name)", isDirectory: true)
}
