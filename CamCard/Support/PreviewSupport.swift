import Foundation

@MainActor
enum PreviewData {
    static let cards: [BusinessCard] = [
        .fixture(createdAt: Date(timeIntervalSince1970: 1_700_000_000)),
        .fixture(
            name: "李四",
            company: "云帆设计有限公司",
            jobTitle: "设计总监",
            mobile: ["13900139000"],
            officePhone: ["021-66668888"],
            fax: [],
            email: ["lisi@yunfan.com"],
            website: "www.yunfan.com",
            address: "上海市浦东新区世纪大道100号",
            department: "设计部",
            postalCode: "200120",
            notes: nil,
            tags: ["供应商"],
            originalFileName: "preview-original-2.jpg",
            processedFileName: "preview-processed-2.jpg",
            createdAt: Date(timeIntervalSince1970: 1_700_003_600)
        ),
        .fixture(
            name: nil,
            company: nil,
            jobTitle: nil,
            mobile: [],
            officePhone: [],
            fax: [],
            email: ["wangwu@example.com"],
            website: nil,
            address: nil,
            department: nil,
            postalCode: nil,
            notes: nil,
            tags: ["客户", "潜在"],
            originalFileName: "preview-original-3.jpg",
            processedFileName: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_007_200)
        )
    ]

    static func environment(cards: [BusinessCard] = PreviewData.cards) -> AppEnvironment {
        let snapshot = CardSnapshot(
            cards: cards,
            audits: Dictionary(uniqueKeysWithValues: cards.map { ($0.id, BusinessCard.fixtureAudit(for: $0)) })
        )
        return AppEnvironment(
            repository: InMemoryCardRepository(snapshot: snapshot),
            imageStore: PreviewImageStore(),
            ocr: MockOCRService(fixture: "standard"),
            detection: MockCardDetectionService(),
            parser: BusinessCardFieldParser(),
            cameraPermission: StaticCameraPermissionService(current: .authorized),
            launchOptions: LaunchOptions()
        )
    }

    static func emptyEnvironment() -> AppEnvironment {
        environment(cards: [])
    }

    static func reviewViewModel() -> ReviewViewModel {
        let environment = environment()
        let card = cards[0]
        let imageData = ImageProcessing.sampleJPEG(text: card.displayName)
        return ReviewViewModel(
            card: card,
            audit: BusinessCard.fixtureAudit(for: card),
            originalImageData: imageData,
            processedImageData: nil,
            environment: environment
        )
    }
}

final class PreviewImageStore: ImageStore {
    private var cache: [String: Data] = [:]

    func write(_ data: Data, id: UUID, kind: ImageKind) async throws -> ImageReference {
        let reference = ImageReference(fileName: InMemoryImageStore.fileName(id: id, kind: kind), kind: kind)
        cache[reference.fileName] = data
        return reference
    }

    func read(_ reference: ImageReference) async throws -> Data? {
        if let cached = cache[reference.fileName] {
            return cached
        }
        let label = reference.kind == .processed ? "校正后名片" : "名片原图"
        let data = ImageProcessing.sampleJPEG(text: label)
        cache[reference.fileName] = data
        return data
    }

    func delete(_ reference: ImageReference) async throws {
        cache[reference.fileName] = nil
    }

    func reset() async throws {
        cache.removeAll()
    }
}