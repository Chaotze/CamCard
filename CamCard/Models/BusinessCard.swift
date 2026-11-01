import Foundation

enum ImageKind: String, Codable, Hashable {
    case original
    case processed
}

struct ImageReference: Codable, Hashable {
    var fileName: String
    var kind: ImageKind

    var isRelative: Bool {
        !fileName.hasPrefix("/") && !fileName.contains("..") && !fileName.contains("/")
    }
}

struct BusinessCard: Codable, Identifiable, Equatable {
    var id: UUID
    var originalImage: ImageReference
    var processedImage: ImageReference?
    var name: String?
    var company: String?
    var jobTitle: String?
    var mobile: [String]
    var officePhone: [String]
    var fax: [String]
    var email: [String]
    var website: String?
    var address: String?
    var department: String?
    var postalCode: String?
    var notes: String?
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        originalImage: ImageReference,
        processedImage: ImageReference? = nil,
        name: String? = nil,
        company: String? = nil,
        jobTitle: String? = nil,
        mobile: [String] = [],
        officePhone: [String] = [],
        fax: [String] = [],
        email: [String] = [],
        website: String? = nil,
        address: String? = nil,
        department: String? = nil,
        postalCode: String? = nil,
        notes: String? = nil,
        tags: [String] = [],
        createdAt: Date = Date(timeIntervalSince1970: 0),
        updatedAt: Date = Date(timeIntervalSince1970: 0)
    ) {
        self.id = id
        self.originalImage = originalImage
        self.processedImage = processedImage
        self.name = name
        self.company = company
        self.jobTitle = jobTitle
        self.mobile = mobile
        self.officePhone = officePhone
        self.fax = fax
        self.email = email
        self.website = website
        self.address = address
        self.department = department
        self.postalCode = postalCode
        self.notes = notes
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var displayName: String {
        guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "未命名"
        }
        return name
    }

    var summary: String? {
        if let first = mobile.first, !first.isEmpty { return first }
        if let first = officePhone.first, !first.isEmpty { return first }
        if let first = email.first, !first.isEmpty { return first }
        return nil
    }

    var searchableText: String {
        var parts: [String] = [name, company, jobTitle, website, address, department, postalCode, notes]
            .compactMap { $0 }
        parts.append(contentsOf: mobile)
        parts.append(contentsOf: officePhone)
        parts.append(contentsOf: fax)
        parts.append(contentsOf: email)
        parts.append(contentsOf: tags)
        return parts.joined(separator: "\n")
    }

    var structuredFinalValues: StructuredFields {
        StructuredFields(
            name: name,
            company: company,
            jobTitle: jobTitle,
            mobile: mobile,
            officePhone: officePhone,
            fax: fax,
            email: email,
            website: website,
            address: address,
            department: department,
            postalCode: postalCode,
            notes: notes
        )
    }

    static func fixture(
        id: UUID = UUID(),
        name: String? = "张三",
        company: String? = "星河科技有限公司",
        jobTitle: String? = "高级工程师",
        mobile: [String] = ["13800138000"],
        officePhone: [String] = ["010-88886666"],
        fax: [String] = ["010-88887777"],
        email: [String] = ["zhangsan@xinghe.com"],
        website: String? = "www.xinghe.com",
        address: String? = "北京市朝阳区建国路88号",
        department: String? = "研发部",
        postalCode: String? = "100022",
        notes: String? = "重点客户",
        tags: [String] = ["客户"],
        originalFileName: String = "fixture-original.jpg",
        processedFileName: String? = "fixture-processed.jpg",
        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> BusinessCard {
        BusinessCard(
            id: id,
            originalImage: ImageReference(fileName: originalFileName, kind: .original),
            processedImage: processedFileName.map { ImageReference(fileName: $0, kind: .processed) },
            name: name,
            company: company,
            jobTitle: jobTitle,
            mobile: mobile,
            officePhone: officePhone,
            fax: fax,
            email: email,
            website: website,
            address: address,
            department: department,
            postalCode: postalCode,
            notes: notes,
            tags: tags,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    static func fixtureAudit(for card: BusinessCard) -> CardAudit {
        CardAudit(
            cardID: card.id,
            originalImage: card.originalImage,
            processedImage: card.processedImage,
            ocrRecords: [
                OCRRecord(
                    sequence: 1,
                    source: .processed,
                    status: .success,
                    lines: [
                        OCRLine(text: card.name ?? "", confidence: 0.98, x: 0.1, y: 0.8, width: 0.3, height: 0.06, sequence: 0),
                        OCRLine(text: card.company ?? "", confidence: 0.95, x: 0.1, y: 0.7, width: 0.5, height: 0.06, sequence: 1)
                    ]
                )
            ],
            structuredFields: card.structuredFinalValues,
            corrections: [],
            createdAt: card.createdAt
        )
    }
}

struct FieldCorrection: Codable, Equatable, Identifiable {
    var id: UUID
    var field: ContactField
    var previousValues: [String]
    var newValues: [String]
    var isRestore: Bool
    var timestamp: Date

    init(
        id: UUID = UUID(),
        field: ContactField,
        previousValues: [String],
        newValues: [String],
        isRestore: Bool = false,
        timestamp: Date = Date(timeIntervalSince1970: 0)
    ) {
        self.id = id
        self.field = field
        self.previousValues = previousValues
        self.newValues = newValues
        self.isRestore = isRestore
        self.timestamp = timestamp
    }
}

struct CardAudit: Codable, Equatable {
    var cardID: UUID
    var originalImage: ImageReference
    var processedImage: ImageReference?
    var ocrRecords: [OCRRecord]
    var structuredFields: StructuredFields
    var corrections: [FieldCorrection]
    var createdAt: Date
}

struct CardSnapshot {
    var cards: [BusinessCard]
    var audits: [UUID: CardAudit]

    init(cards: [BusinessCard] = [], audits: [UUID: CardAudit] = [:]) {
        self.cards = cards
        self.audits = audits
    }

    static let empty = CardSnapshot()
}
