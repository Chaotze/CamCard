import Foundation
import Combine

enum FieldSource: String {
    case parsed = "解析"
    case manual = "人工"
    case unrecognized = "未识别"
}

@MainActor
final class ReviewViewModel: ObservableObject {
    @Published var name = ""
    @Published var company = ""
    @Published var jobTitle = ""
    @Published var mobile: [String] = []
    @Published var officePhone: [String] = []
    @Published var fax: [String] = []
    @Published var email: [String] = []
    @Published var website = ""
    @Published var address = ""
    @Published var department = ""
    @Published var postalCode = ""
    @Published var notes = ""
    @Published var tags: [String] = []
    @Published var newTag = ""
    @Published var errorMessage: String?
    @Published var isSaving = false
    @Published var didSave = false
    @Published var savedCard: BusinessCard?
    @Published var originalImageData: Data?
    @Published var processedImageData: Data?
    @Published var rawText = ""
    @Published var showRawText = false

    private let environment: AppEnvironment
    private var parsed: StructuredFields
    private var parsedValues: [ContactField: [String]] = [:]
    private var manualFields: Set<ContactField> = []
    private var existingCard: BusinessCard?
    private var existingAudit: CardAudit?
    private var draftID: UUID?
    private var draftOriginalData: Data?
    private var draftProcessedData: Data?
    private var existingRecords: [OCRRecord] = []

    init(draft: CardDraft, environment: AppEnvironment) {
        self.environment = environment
        self.parsed = draft.structured ?? .empty
        self.draftID = draft.id
        self.draftOriginalData = draft.originalData
        self.draftProcessedData = draft.processedData
        self.originalImageData = draft.originalData
        self.processedImageData = draft.processedData
        self.rawText = draft.ocrRecord?.rawText ?? ""
        self.existingRecords = draft.ocrRecord.map { [$0] } ?? []
        self.parsedValues = Self.valueMap(for: parsed)
        applyParsedValues()
    }

    init(
        card: BusinessCard,
        audit: CardAudit?,
        originalImageData: Data?,
        processedImageData: Data?,
        environment: AppEnvironment
    ) {
        self.environment = environment
        self.parsed = audit?.structuredFields ?? card.structuredFinalValues
        self.existingCard = card
        self.existingAudit = audit
        self.originalImageData = originalImageData
        self.processedImageData = processedImageData
        self.existingRecords = audit?.ocrRecords ?? []
        self.rawText = audit?.ocrRecords.last?.rawText ?? ""
        self.parsedValues = Self.valueMap(for: parsed)
        self.name = card.name ?? ""
        self.company = card.company ?? ""
        self.jobTitle = card.jobTitle ?? ""
        self.mobile = card.mobile
        self.officePhone = card.officePhone
        self.fax = card.fax
        self.email = card.email
        self.website = card.website ?? ""
        self.address = card.address ?? ""
        self.department = card.department ?? ""
        self.postalCode = card.postalCode ?? ""
        self.notes = card.notes ?? ""
        self.tags = card.tags
        for field in ContactField.allCases where normalized(values(for: field)) != normalized(parsedValues[field] ?? []) {
            manualFields.insert(field)
        }
    }

    var isEditing: Bool { existingCard != nil }

    var displayImageData: Data? {
        processedImageData ?? originalImageData
    }

    var hasAnyValue: Bool {
        ContactField.allCases.contains { !normalized(values(for: $0)).isEmpty }
            || !normalized(tags).isEmpty
    }

    var structuredSnapshot: StructuredFields { parsed }

    func source(for field: ContactField) -> FieldSource {
        if normalized(values(for: field)).isEmpty { return .unrecognized }
        if manualFields.contains(field) { return .manual }
        if !normalized(parsedValues[field] ?? []).isEmpty { return .parsed }
        return .manual
    }

    func restoreAvailable(for field: ContactField) -> Bool {
        manualFields.contains(field)
    }

    func restore(_ field: ContactField) {
        let values = parsedValues[field] ?? []
        setValues(values, for: field, markManual: false)
        manualFields.remove(field)
    }

    func setString(_ field: ContactField, _ value: String) {
        switch field {
        case .name: name = value
        case .company: company = value
        case .jobTitle: jobTitle = value
        case .website: website = value
        case .address: address = value
        case .department: department = value
        case .postalCode: postalCode = value
        case .notes: notes = value
        default: break
        }
        updateManualState(for: field)
    }

    func value(_ field: ContactField, at index: Int) -> String {
        let list = array(for: field)
        return list.indices.contains(index) ? list[index] : ""
    }

    func setValue(_ field: ContactField, at index: Int, value: String) {
        var list = array(for: field)
        guard list.indices.contains(index) else { return }
        list[index] = value
        setArray(list, for: field)
        updateManualState(for: field)
    }

    func addValue(to field: ContactField) {
        var list = array(for: field)
        list.append("")
        setArray(list, for: field)
    }

    func removeValue(from field: ContactField, at index: Int) {
        var list = array(for: field)
        guard list.indices.contains(index) else { return }
        list.remove(at: index)
        setArray(list, for: field)
        updateManualState(for: field)
    }

    func movePhone(from source: ContactField, at index: Int, to destination: ContactField) {
        var sourceList = array(for: source)
        guard sourceList.indices.contains(index) else { return }
        let value = sourceList.remove(at: index)
        setArray(sourceList, for: source)
        var destinationList = array(for: destination)
        destinationList.append(value)
        setArray(destinationList, for: destination)
        updateManualState(for: source)
        updateManualState(for: destination)
    }

    func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        guard !tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) else {
            newTag = ""
            return
        }
        tags.append(tag)
        newTag = ""
    }

    func removeTag(_ tag: String) {
        tags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
    }

    func save() async {
        guard hasAnyValue else {
            errorMessage = "请至少填写一项信息后再保存"
            return
        }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let now = environment.clock.now()
        do {
            if let existing = existingCard {
                var card = existing
                applyFields(to: &card)
                card.tags = normalized(tags)
                card.updatedAt = now
                let audit = CardAudit(
                    cardID: card.id,
                    originalImage: existing.originalImage,
                    processedImage: existing.processedImage,
                    ocrRecords: existingAudit?.ocrRecords ?? existingRecords,
                    structuredFields: parsed,
                    corrections: (existingAudit?.corrections ?? []) + makeCorrections(previous: existing.structuredFinalValues, timestamp: now),
                    createdAt: existingAudit?.createdAt ?? existing.createdAt
                )
                try await environment.repository.update(card, audit: audit)
                savedCard = card
            } else {
                guard let draftID, let imageData = draftProcessedData ?? draftOriginalData else {
                    throw RepositoryError.saveFailed
                }
                let reference = try await environment.imageStore.write(
                    imageData,
                    id: draftID,
                    kind: .original
                )
                var card = BusinessCard(
                    id: draftID,
                    originalImage: reference,
                    processedImage: nil,
                    createdAt: now,
                    updatedAt: now
                )
                applyFields(to: &card)
                card.tags = normalized(tags)
                let audit = CardAudit(
                    cardID: card.id,
                    originalImage: reference,
                    processedImage: nil,
                    ocrRecords: existingRecords,
                    structuredFields: parsed,
                    corrections: makeCorrections(previous: parsed, timestamp: now),
                    createdAt: now
                )
                try await environment.repository.save(card, audit: audit)
                savedCard = card
            }
            didSave = true
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func values(for field: ContactField) -> [String] {
        switch field {
        case .name: return [name]
        case .company: return [company]
        case .jobTitle: return [jobTitle]
        case .mobile: return mobile
        case .officePhone: return officePhone
        case .fax: return fax
        case .email: return email
        case .website: return [website]
        case .address: return [address]
        case .department: return [department]
        case .postalCode: return [postalCode]
        case .notes: return [notes]
        }
    }

    private func applyParsedValues() {
        name = parsed.name ?? ""
        company = parsed.company ?? ""
        jobTitle = parsed.jobTitle ?? ""
        mobile = parsed.mobile
        officePhone = parsed.officePhone
        fax = parsed.fax
        email = parsed.email
        website = parsed.website ?? ""
        address = parsed.address ?? ""
        department = parsed.department ?? ""
        postalCode = parsed.postalCode ?? ""
        notes = parsed.notes ?? ""
    }

    private func setValues(_ values: [String], for field: ContactField, markManual: Bool) {
        switch field {
        case .name: name = values.first ?? ""
        case .company: company = values.first ?? ""
        case .jobTitle: jobTitle = values.first ?? ""
        case .website: website = values.first ?? ""
        case .address: address = values.first ?? ""
        case .department: department = values.first ?? ""
        case .postalCode: postalCode = values.first ?? ""
        case .notes: notes = values.first ?? ""
        case .mobile, .officePhone, .fax, .email:
            setArray(values, for: field)
        }
        if markManual {
            updateManualState(for: field)
        }
    }

    private func array(for field: ContactField) -> [String] {
        switch field {
        case .mobile: return mobile
        case .officePhone: return officePhone
        case .fax: return fax
        case .email: return email
        default: return []
        }
    }

    private func setArray(_ values: [String], for field: ContactField) {
        switch field {
        case .mobile: mobile = values
        case .officePhone: officePhone = values
        case .fax: fax = values
        case .email: email = values
        default: break
        }
    }

    private func updateManualState(for field: ContactField) {
        if normalized(values(for: field)) == normalized(parsedValues[field] ?? []) {
            manualFields.remove(field)
        } else {
            manualFields.insert(field)
        }
    }

    private func applyFields(to card: inout BusinessCard) {
        card.name = trimmedOrNil(name)
        card.company = trimmedOrNil(company)
        card.jobTitle = trimmedOrNil(jobTitle)
        card.mobile = normalized(mobile)
        card.officePhone = normalized(officePhone)
        card.fax = normalized(fax)
        card.email = normalized(email, deduplicate: true)
        card.website = trimmedOrNil(website)
        card.address = trimmedOrNil(address)
        card.department = trimmedOrNil(department)
        card.postalCode = trimmedOrNil(postalCode)
        card.notes = trimmedOrNil(notes)
    }

    private func makeCorrections(previous: StructuredFields, timestamp: Date) -> [FieldCorrection] {
        ContactField.allCases.compactMap { field in
            let old = normalized(previous.values(for: field))
            let new = normalized(values(for: field))
            guard old != new else { return nil }
            return FieldCorrection(
                field: field,
                previousValues: old,
                newValues: new,
                timestamp: timestamp
            )
        }
    }

    private func normalized(_ values: [String], deduplicate: Bool = false) -> [String] {
        var result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if deduplicate, result.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                continue
            }
            result.append(trimmed)
        }
        return result
    }

    private func trimmedOrNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func valueMap(for fields: StructuredFields) -> [ContactField: [String]] {
        var map: [ContactField: [String]] = [:]
        for field in ContactField.allCases {
            map[field] = fields.values(for: field)
        }
        return map
    }

    private static func message(for error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return "保存失败，请重试"
    }
}
