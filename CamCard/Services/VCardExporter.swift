import Foundation

enum ExportError: Error, LocalizedError, Equatable {
    case emptySelection
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .emptySelection: return "请选择至少一张名片"
        case .writeFailed: return "导出失败，请稍后重试"
        }
    }
}

struct VCardExporter {
    func export(_ cards: [BusinessCard]) -> String {
        cards.map(record(for:)).joined()
    }

    func record(for card: BusinessCard) -> String {
        var lines: [String] = ["BEGIN:VCARD", "VERSION:3.0"]
        let name = card.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !name.isEmpty {
            lines.append("FN:\(escape(name))")
            lines.append("N:;\(escape(name));;;")
        }

        let company = card.company?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let department = card.department?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !company.isEmpty || !department.isEmpty {
            if !company.isEmpty && !department.isEmpty {
                lines.append("ORG:\(escape(company));\(escape(department))")
            } else if !company.isEmpty {
                lines.append("ORG:\(escape(company))")
            } else {
                lines.append("ORG:;\(escape(department))")
            }
        }

        if let jobTitle = nonEmpty(card.jobTitle) {
            lines.append("TITLE:\(escape(jobTitle))")
        }

        card.mobile.filter { !$0.isEmpty }.forEach { lines.append("TEL;TYPE=CELL:\(escape($0))") }
        card.officePhone.filter { !$0.isEmpty }.forEach { lines.append("TEL;TYPE=WORK:\(escape($0))") }
        card.fax.filter { !$0.isEmpty }.forEach { lines.append("TEL;TYPE=FAX:\(escape($0))") }

        let emails = card.email.filter { !$0.isEmpty }
        for (index, email) in emails.enumerated() {
            if index == 0 {
                lines.append("EMAIL;TYPE=INTERNET;TYPE=PREF:\(escape(email))")
            } else {
                lines.append("EMAIL;TYPE=INTERNET:\(escape(email))")
            }
        }

        if let website = nonEmpty(card.website) {
            lines.append("URL:\(escape(website))")
        }

        let address = card.address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let postalCode = card.postalCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !address.isEmpty || !postalCode.isEmpty {
            lines.append("ADR:;;\(escape(address));;;\(escape(postalCode));")
        }

        if !card.tags.isEmpty {
            lines.append("CATEGORIES:\(card.tags.map(escape).joined(separator: ","))")
        }

        if let notes = nonEmpty(card.notes) {
            lines.append("NOTE:\(escape(notes))")
        }

        lines.append("END:VCARD")
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    func fileName(for cards: [BusinessCard], date: Date = Date()) -> String {
        guard !cards.isEmpty else { return "名片.vcf" }
        if cards.count == 1 {
            let name = cards[0].name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let sanitized = sanitizeFileName(name)
            return (sanitized.isEmpty ? "名片" : sanitized) + ".vcf"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "CamCard-Contacts-\(formatter.string(from: date)).vcf"
    }

    func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\n")
    }

    private func sanitizeFileName(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?*\"<>|").union(.controlCharacters)
        return value
            .components(separatedBy: invalid)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

protocol VCardFileWriter {
    func write(_ content: String, fileName: String) throws -> URL
}

struct TemporaryVCardWriter: VCardFileWriter {
    func write(_ content: String, fileName: String) throws -> URL {
        guard let data = content.data(using: .utf8) else {
            throw ExportError.writeFailed
        }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CamCardExport", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(fileName)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            throw ExportError.writeFailed
        }
    }
}

struct FailingVCardWriter: VCardFileWriter {
    func write(_ content: String, fileName: String) throws -> URL {
        throw ExportError.writeFailed
    }
}
