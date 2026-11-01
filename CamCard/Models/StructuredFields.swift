import Foundation

enum ExtractionMethod: String, Codable, Hashable {
    case label
    case regex
    case layout
    case domainMatch
    case inference
    case defaultMobile
    case manual
}

struct FieldProvenance: Codable, Equatable, Hashable {
    var field: ContactField
    var confidence: Double
    var sourceLineIDs: [UUID]
    var method: ExtractionMethod
}

struct StructuredFields: Codable, Equatable {
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
    var provenance: [FieldProvenance]
    var ambiguousFields: [ContactField]
    var emptyInput: Bool

    init(
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
        provenance: [FieldProvenance] = [],
        ambiguousFields: [ContactField] = [],
        emptyInput: Bool = false
    ) {
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
        self.provenance = provenance
        self.ambiguousFields = ambiguousFields
        self.emptyInput = emptyInput
    }

    static let empty = StructuredFields()

    var allFieldNames: [ContactField] { ContactField.allCases }

    func values(for field: ContactField) -> [String] {
        switch field {
        case .name: return name.map { [$0] } ?? []
        case .company: return company.map { [$0] } ?? []
        case .jobTitle: return jobTitle.map { [$0] } ?? []
        case .mobile: return mobile
        case .officePhone: return officePhone
        case .fax: return fax
        case .email: return email
        case .website: return website.map { [$0] } ?? []
        case .address: return address.map { [$0] } ?? []
        case .department: return department.map { [$0] } ?? []
        case .postalCode: return postalCode.map { [$0] } ?? []
        case .notes: return notes.map { [$0] } ?? []
        }
    }

    func provenance(for field: ContactField) -> FieldProvenance? {
        provenance.first { $0.field == field }
    }

    var isEmpty: Bool {
        ContactField.allCases.allSatisfy { values(for: $0).allSatisfy(\.isEmpty) }
    }
}
