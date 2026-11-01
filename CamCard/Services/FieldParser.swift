import Foundation

protocol FieldParser {
    func parse(_ record: OCRRecord) -> StructuredFields
}

final class BusinessCardFieldParser: FieldParser {
    private let emailPattern = "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
    private let urlPattern = "(?i)(?<![@\\w.])((?:https?://|www\\.)[^\\s，,；;]+|(?:[a-z0-9-]+\\.)+(?:com|cn|net|org|io|co|biz|me)(?:/[^\\s，,；;]*)?)"
    private let phonePattern = "\\+?[0-9(（][0-9\\s\\-()（）]{5,}[0-9]"

    private let companySuffixes = [
        "有限公司", "有限责任公司", "股份有限公司", "公司", "集团", "科技", "控股",
        "Inc", "Ltd", "LLC", "Corp", "GmbH", "Company", "Technologies", "Technology",
        "Solutions", "Holdings", "Bank", "University"
    ]

    private let jobKeywords = [
        "经理", "总监", "总裁", "董事长", "总经理", "工程师", "架构师", "设计师", "顾问",
        "主管", "专员", "主任", "CEO", "CTO", "CFO", "COO", "President", "Manager",
        "Director", "Engineer", "Architect", "Designer", "Consultant", "Specialist",
        "Lead", "Founder", "Owner", "Sales"
    ]

    private let addressKeywords = [
        "省", "市", "区", "县", "镇", "乡", "村", "路", "街", "道", "号", "楼", "室",
        "层", "栋", "弄", "巷", "Road", "Rd.", "Street", "St.", "Avenue", "Ave.",
        "Suite", "Floor", "Building", "District", "Beijing", "Shanghai", "Shenzhen",
        "Guangzhou", "Hangzhou"
    ]

    private let contactKeywords = [
        "手机", "电话", "座机", "传真", "邮箱", "邮件", "网址", "网站",
        "mobile", "office", "tel", "fax", "email", "web", "url"
    ]

    func parse(_ record: OCRRecord) -> StructuredFields {
        var result = StructuredFields()
        guard record.status == .success, !record.lines.isEmpty else {
            result.emptyInput = true
            return result
        }
        let lines = record.lines.sorted { $0.sequence < $1.sequence }
        var used = Set<UUID>()

        let emails = extractEmails(from: lines, used: &used)
        result.email = emails
        if !emails.isEmpty {
            addProvenance(.email, lineIDs: usedLineIDs(for: lines, containingAny: emails), method: .regex, confidence: 0.9, to: &result)
        }

        let websites = extractWebsites(from: lines, used: &used)
        result.website = websites.first
        if let website = result.website {
            addProvenance(.website, lineIDs: usedLineIDs(for: lines, containing: website), method: .regex, confidence: 0.85, to: &result)
        }

        extractPhones(from: lines, used: &used, into: &result)
        extractDepartment(from: lines, used: &used, into: &result)
        extractPostalCode(from: lines, used: &used, into: &result)
        extractNotes(from: lines, used: &used, into: &result)
        extractJobTitle(from: lines, used: &used, into: &result)
        extractCompany(from: lines, emails: emails, used: &used, into: &result)
        extractName(from: lines, used: &used, into: &result)
        extractAddress(from: lines, used: &used, into: &result)

        if result.company == nil && result.jobTitle == nil {
            let leftovers = lines.filter { line in
                !used.contains(line.id)
                    && !line.text.isEmpty
                    && !looksContact(line.text)
                    && !looksAddress(line.text)
                    && !isPersonName(line.text)
            }
            if !leftovers.isEmpty {
                result.ambiguousFields = [.company, .jobTitle]
            }
        }
        return result
    }

    private func extractEmails(from lines: [OCRLine], used: inout Set<UUID>) -> [String] {
        var emails: [String] = []
        for line in lines {
            for match in matches(emailPattern, in: line.text) {
                if !emails.contains(match) {
                    emails.append(match)
                }
            }
            if !matches(emailPattern, in: line.text).isEmpty {
                used.insert(line.id)
            }
        }
        return emails
    }

    private func extractWebsites(from lines: [OCRLine], used: inout Set<UUID>) -> [String] {
        var websites: [String] = []
        for line in lines where !line.text.contains("@") {
            let found = matches(urlPattern, in: line.text)
                .map { trimPunctuation($0) }
                .filter { !$0.isEmpty }
            for website in found where !websites.contains(website) {
                websites.append(website)
            }
            if !found.isEmpty {
                used.insert(line.id)
            }
        }
        return websites
    }

    private func extractPhones(from lines: [OCRLine], used: inout Set<UUID>, into result: inout StructuredFields) {
        for line in lines {
            let lower = line.text.lowercased()
            if lower.contains("邮编") || lower.contains("zip") || lower.contains("postal") {
                continue
            }
            if line.text.contains("@") {
                continue
            }
            let numbers = matches(phonePattern, in: line.text)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { digitCount($0) >= 7 && digitCount($0) <= 15 }
            guard !numbers.isEmpty else { continue }

            let field: ContactField
            let method: ExtractionMethod
            if lower.contains("fax") || line.text.contains("传真") {
                field = .fax
                method = .label
            } else if lower.contains("office") || lower.contains("tel")
                || line.text.contains("电话") || line.text.contains("座机")
                || line.text.contains("工作") || line.text.contains("公司") {
                field = .officePhone
                method = .label
            } else if lower.contains("mobile") || lower.contains("cell")
                || line.text.contains("手机") || line.text.contains("移动") {
                field = .mobile
                method = .label
            } else {
                field = .mobile
                method = .defaultMobile
            }

            for number in numbers {
                switch field {
                case .mobile:
                    if !result.mobile.contains(number) { result.mobile.append(number) }
                case .officePhone:
                    if !result.officePhone.contains(number) { result.officePhone.append(number) }
                case .fax:
                    if !result.fax.contains(number) { result.fax.append(number) }
                default:
                    break
                }
            }
            used.insert(line.id)
            addProvenance(field, lineIDs: [line.id], method: method, confidence: method == .defaultMobile ? 0.6 : 0.85, to: &result)
        }
    }

    private func extractDepartment(from lines: [OCRLine], used: inout Set<UUID>, into result: inout StructuredFields) {
        for line in lines where !used.contains(line.id) {
            if let value = labeledValue(line.text, labels: ["部门", "department", "dept", "division"]) {
                result.department = value
                used.insert(line.id)
                addProvenance(.department, lineIDs: [line.id], method: .label, confidence: 0.95, to: &result)
                return
            }
        }
    }

    private func extractPostalCode(from lines: [OCRLine], used: inout Set<UUID>, into result: inout StructuredFields) {
        for line in lines where !used.contains(line.id) {
            if let value = labeledValue(line.text, labels: ["邮编", "邮政编码", "zip", "postal code", "postalcode"]) {
                let digits = value.filter(\.isNumber)
                if digits.count == 6 {
                    result.postalCode = digits
                } else {
                    result.postalCode = value
                }
                used.insert(line.id)
                addProvenance(.postalCode, lineIDs: [line.id], method: .label, confidence: 0.95, to: &result)
                return
            }
            let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count == 6, trimmed.allSatisfy(\.isNumber), !used.contains(line.id) {
                result.postalCode = trimmed
                used.insert(line.id)
                addProvenance(.postalCode, lineIDs: [line.id], method: .regex, confidence: 0.8, to: &result)
                return
            }
        }
    }

    private func extractNotes(from lines: [OCRLine], used: inout Set<UUID>, into result: inout StructuredFields) {
        for line in lines where !used.contains(line.id) {
            if let value = labeledValue(line.text, labels: ["备注", "note", "notes", "remark", "remarks"]) {
                result.notes = value
                used.insert(line.id)
                addProvenance(.notes, lineIDs: [line.id], method: .label, confidence: 0.95, to: &result)
                return
            }
        }
    }

    private func extractJobTitle(from lines: [OCRLine], used: inout Set<UUID>, into result: inout StructuredFields) {
        for line in lines where !used.contains(line.id) {
            if let value = labeledValue(line.text, labels: ["职位", "title", "job title"]) {
                result.jobTitle = value
                used.insert(line.id)
                addProvenance(.jobTitle, lineIDs: [line.id], method: .label, confidence: 0.9, to: &result)
                return
            }
        }
        for line in lines where !used.contains(line.id) {
            let lower = line.text.lowercased()
            if jobKeywords.contains(where: { lower.contains($0.lowercased()) }),
               !looksCompany(line.text) {
                result.jobTitle = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
                used.insert(line.id)
                addProvenance(.jobTitle, lineIDs: [line.id], method: .regex, confidence: 0.8, to: &result)
                return
            }
        }
    }

    private func extractCompany(
        from lines: [OCRLine],
        emails: [String],
        used: inout Set<UUID>,
        into result: inout StructuredFields
    ) {
        for line in lines where !used.contains(line.id) {
            if let value = labeledValue(line.text, labels: ["公司", "company", "organization", "org"]) {
                result.company = value
                used.insert(line.id)
                addProvenance(.company, lineIDs: [line.id], method: .label, confidence: 0.95, to: &result)
                return
            }
        }
        for line in lines where !used.contains(line.id) {
            if looksCompany(line.text) && !looksAddress(line.text) {
                result.company = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
                used.insert(line.id)
                addProvenance(.company, lineIDs: [line.id], method: .regex, confidence: 0.8, to: &result)
                return
            }
        }
        guard let domain = emails.first?.split(separator: "@").last else { return }
        let host = String(domain).lowercased()
        let root = host.split(separator: ".").first.map(String.init) ?? host
        for line in lines where !used.contains(line.id) {
            let normalized = line.text.lowercased().filter { $0.isLetter || $0.isNumber }
            if normalized == root || normalized == host {
                result.company = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
                used.insert(line.id)
                addProvenance(.company, lineIDs: [line.id], method: .domainMatch, confidence: 0.85, to: &result)
                return
            }
        }
    }

    private func extractName(from lines: [OCRLine], used: inout Set<UUID>, into result: inout StructuredFields) {
        for line in lines where !used.contains(line.id) {
            if let value = labeledValue(line.text, labels: ["姓名", "name"]) {
                result.name = value
                used.insert(line.id)
                addProvenance(.name, lineIDs: [line.id], method: .label, confidence: 0.95, to: &result)
                return
            }
        }
        for line in lines where !used.contains(line.id) {
            if isPersonName(line.text) {
                result.name = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
                used.insert(line.id)
                addProvenance(.name, lineIDs: [line.id], method: .layout, confidence: 0.75, to: &result)
                return
            }
        }
    }

    private func extractAddress(from lines: [OCRLine], used: inout Set<UUID>, into result: inout StructuredFields) {
        for (index, line) in lines.enumerated() where !used.contains(line.id) {
            if let value = labeledValue(line.text, labels: ["地址", "address"]) {
                var parts = [value]
                var addressLineIDs = [line.id]
                used.insert(line.id)
                var offset = index + 1
                while offset < lines.count {
                    let next = lines[offset]
                    if used.contains(next.id) || looksContact(next.text) || labeledValue(next.text, labels: ["公司", "company", "职位", "title", "姓名", "name"]) != nil {
                        break
                    }
                    if looksAddress(next.text) {
                        parts.append(next.text.trimmingCharacters(in: .whitespacesAndNewlines))
                        addressLineIDs.append(next.id)
                        used.insert(next.id)
                        offset += 1
                    } else {
                        break
                    }
                }
                result.address = parts.joined(separator: "\n")
                addProvenance(.address, lineIDs: addressLineIDs, method: .label, confidence: 0.9, to: &result)
                return
            }
        }
        var addressLines: [OCRLine] = []
        for line in lines where !used.contains(line.id) {
            if looksAddress(line.text) && !looksCompany(line.text) {
                addressLines.append(line)
            } else if !addressLines.isEmpty {
                break
            }
        }
        if !addressLines.isEmpty {
            result.address = addressLines.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.joined(separator: "\n")
            for line in addressLines { used.insert(line.id) }
            addProvenance(.address, lineIDs: addressLines.map(\.id), method: .layout, confidence: 0.75, to: &result)
        }
    }

    private func addProvenance(
        _ field: ContactField,
        lineIDs: [UUID],
        method: ExtractionMethod,
        confidence: Double,
        to result: inout StructuredFields
    ) {
        guard !lineIDs.isEmpty else { return }
        if let index = result.provenance.firstIndex(where: { $0.field == field }) {
            var existing = result.provenance[index]
            for id in lineIDs where !existing.sourceLineIDs.contains(id) {
                existing.sourceLineIDs.append(id)
            }
            existing.confidence = max(existing.confidence, confidence)
            result.provenance[index] = existing
        } else {
            result.provenance.append(
                FieldProvenance(
                    field: field,
                    confidence: confidence,
                    sourceLineIDs: lineIDs,
                    method: method
                )
            )
        }
    }

    private func labeledValue(_ text: String, labels: [String]) -> String? {
        let escaped = labels.map { NSRegularExpression.escapedPattern(for: $0) }
        let pattern = "^(?:\(escaped.joined(separator: "|")))\\s*[:：]?\\s*(.+)$"
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = expression.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let value = String(text[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func matches(_ pattern: String, in text: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.matches(in: text, options: [], range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: text) else { return nil }
            return String(text[matchRange])
        }
    }

    private func usedLineIDs(for lines: [OCRLine], containing value: String) -> [UUID] {
        lines.filter { $0.text.contains(value) }.map(\.id)
    }

    private func usedLineIDs(for lines: [OCRLine], containingAny values: [String]) -> [UUID] {
        lines.filter { line in values.contains(where: { line.text.contains($0) }) }.map(\.id)
    }

    private func trimPunctuation(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: " \t\n,，.;；。:："))
    }

    private func digitCount(_ value: String) -> Int {
        value.filter(\.isNumber).count
    }

    private func looksCompany(_ text: String) -> Bool {
        let lower = text.lowercased()
        return companySuffixes.contains { lower.contains($0.lowercased()) }
    }

    private func looksAddress(_ text: String) -> Bool {
        addressKeywords.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private func looksContact(_ text: String) -> Bool {
        let lower = text.lowercased()
        if text.contains("@") { return true }
        if contactKeywords.contains(where: { lower.contains($0) }) { return true }
        return matches(phonePattern, in: text).contains { digitCount($0) >= 7 }
    }

    private func isPersonName(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 40 else { return false }
        if trimmed.contains("@") || trimmed.contains("http") { return false }
        if matches(phonePattern, in: trimmed).contains(where: { digitCount($0) >= 7 }) { return false }
        if looksCompany(trimmed) || looksAddress(trimmed) || looksContact(trimmed) { return false }
        if jobKeywords.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) { return false }
        if (2...4).contains(trimmed.count), trimmed.allSatisfy(isChineseNameCharacter) {
            return true
        }
        let tokens = trimmed.split(separator: " ").map(String.init)
        guard (2...4).contains(tokens.count) else { return false }
        return tokens.allSatisfy { token in
            if (1...2).contains(token.count), token.allSatisfy(isChineseNameCharacter) {
                return true
            }
            guard let first = token.first, first.isUppercase || first.isLetter else { return false }
            return token.allSatisfy { $0.isLetter || $0 == "." || $0 == "-" }
        }
    }

    private func isChineseNameCharacter(_ character: Character) -> Bool {
        if character == "·" { return true }
        guard let scalar = character.unicodeScalars.first, character.unicodeScalars.count == 1 else {
            return false
        }
        return (0x4E00...0x9FA5).contains(scalar.value)
    }
}
