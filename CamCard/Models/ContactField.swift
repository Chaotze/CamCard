import Foundation

enum ContactField: String, Codable, CaseIterable, Hashable {
    case name
    case company
    case jobTitle
    case mobile
    case officePhone
    case fax
    case email
    case website
    case address
    case department
    case postalCode
    case notes

    var displayName: String {
        switch self {
        case .name: return "姓名"
        case .company: return "公司"
        case .jobTitle: return "职位"
        case .mobile: return "手机"
        case .officePhone: return "办公电话"
        case .fax: return "传真"
        case .email: return "Email"
        case .website: return "网站"
        case .address: return "地址"
        case .department: return "部门"
        case .postalCode: return "邮编"
        case .notes: return "备注"
        }
    }

    var isRequired: Bool {
        Self.requiredFields.contains(self)
    }

    var systemImage: String {
        switch self {
        case .name: return "person.fill"
        case .company: return "building.2.fill"
        case .jobTitle: return "briefcase.fill"
        case .mobile: return "iphone"
        case .officePhone: return "phone.fill"
        case .fax: return "printer.fill"
        case .email: return "envelope.fill"
        case .website: return "globe"
        case .address: return "mappin.and.ellipse"
        case .department: return "person.3.fill"
        case .postalCode: return "mailbox.fill"
        case .notes: return "note.text"
        }
    }

    var isMultiValue: Bool {
        switch self {
        case .mobile, .officePhone, .fax, .email: return true
        default: return false
        }
    }

    static let requiredFields: [ContactField] = [
        .name, .company, .jobTitle, .mobile, .officePhone, .email, .website, .address
    ]

    static let optionalFields: [ContactField] = [
        .department, .fax, .postalCode, .notes
    ]
}
