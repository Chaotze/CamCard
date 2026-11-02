import XCTest
@testable import CamCard

final class VCardExportTests: XCTestCase {
    private let exporter = VCardExporter()

    func testFieldMapping() {
        let card = BusinessCard.fixture()
        let content = exporter.export([card])
        let lines = content.components(separatedBy: "\r\n")
        XCTAssertEqual(lines.first, "BEGIN:VCARD")
        XCTAssertTrue(lines.contains("VERSION:3.0"))
        XCTAssertTrue(lines.contains("FN:张三"))
        XCTAssertTrue(lines.contains("N:;张三;;;"))
        XCTAssertTrue(lines.contains("ORG:星河科技有限公司;研发部"))
        XCTAssertTrue(lines.contains("TITLE:高级工程师"))
        XCTAssertTrue(lines.contains("TEL;TYPE=CELL:13800138000"))
        XCTAssertTrue(lines.contains("TEL;TYPE=WORK:010-88886666"))
        XCTAssertTrue(lines.contains("TEL;TYPE=FAX:010-88887777"))
        XCTAssertTrue(lines.contains("EMAIL;TYPE=INTERNET;TYPE=PREF:zhangsan@xinghe.com"))
        XCTAssertTrue(lines.contains("URL:www.xinghe.com"))
        XCTAssertTrue(lines.contains("ADR:;;北京市朝阳区建国路88号;;;100022;"))
        XCTAssertTrue(lines.contains("CATEGORIES:客户"))
        XCTAssertTrue(lines.contains("NOTE:重点客户"))
        XCTAssertEqual(lines.suffix(2).first, "END:VCARD")
        XCTAssertTrue(content.hasSuffix("\r\n"))
    }

    func testEmptyFieldsAreOmitted() {
        let card = BusinessCard.fixture(
            email: [],
            website: nil,
            address: nil,
            department: nil,
            postalCode: nil,
            notes: nil,
            tags: []
        )
        let content = exporter.export([card])
        XCTAssertFalse(content.contains("URL:"))
        XCTAssertFalse(content.contains("EMAIL"))
        XCTAssertFalse(content.contains("ADR:"))
        XCTAssertFalse(content.contains("CATEGORIES:"))
        XCTAssertFalse(content.contains("NOTE:"))
        XCTAssertFalse(content.contains("未识别"))
    }

    func testSpecialCharactersAreEscaped() {
        var card = BusinessCard.fixture()
        card.company = "A,B; C"
        card.notes = "第一行\n第二行"
        let content = exporter.export([card])
        XCTAssertTrue(content.contains("ORG:A\\,B\\; C;研发部"))
        XCTAssertTrue(content.contains("NOTE:第一行\\n第二行"))
    }

    func testMultipleEmailsFirstHasPreference() {
        var card = BusinessCard.fixture()
        card.email = ["first@example.com", "second@example.com"]
        let content = exporter.export([card])
        let emailLines = content.components(separatedBy: "\r\n").filter { $0.hasPrefix("EMAIL") }
        XCTAssertEqual(emailLines.count, 2)
        XCTAssertTrue(emailLines[0].contains("PREF"))
        XCTAssertTrue(emailLines[1].hasSuffix("second@example.com"))
        XCTAssertFalse(emailLines[1].contains("PREF"))
    }

    func testFileNames() {
        let single = BusinessCard.fixture(name: "张三")
        XCTAssertEqual(exporter.fileName(for: [single]), "张三.vcf")

        var illegal = BusinessCard.fixture(name: "A/B:C*D")
        illegal.name = "A/B:C*D"
        XCTAssertEqual(exporter.fileName(for: [illegal]), "ABCD.vcf")

        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let multiple = exporter.fileName(for: [single, BusinessCard.fixture(name: "李四")], date: date)
        XCTAssertEqual(multiple, "CamCard-Contacts-20231114-221320.vcf")
        XCTAssertFalse(multiple.contains("张三"))
    }

    func testRoundTripFidelity() throws {
        var card = BusinessCard.fixture(
            name: "张三",
            company: "星河科技有限公司",
            jobTitle: "高级工程师",
            mobile: ["13800138000"],
            officePhone: ["010-88886666"],
            fax: ["010-88887777"],
            email: ["first@example.com", "second@example.com"],
            website: "www.example.com",
            address: "北京市朝阳区建国路88号",
            department: "研发部",
            postalCode: "100022",
            notes: "第一行\n第二行",
            tags: ["客户", "重点"]
        )
        card.mobile = ["13800138000", "13900139000"]
        let content = exporter.export([card])
        let parsed = try ParsedVCard(content: content)

        XCTAssertEqual(parsed.value("FN"), "张三")
        XCTAssertEqual(parsed.value("ORG"), "星河科技有限公司;研发部")
        XCTAssertEqual(parsed.value("TITLE"), "高级工程师")
        XCTAssertEqual(parsed.values(whereKeyContains: "TEL;TYPE=CELL"), ["13800138000", "13900139000"])
        XCTAssertEqual(parsed.values(whereKeyContains: "TEL;TYPE=WORK"), ["010-88886666"])
        XCTAssertEqual(parsed.values(whereKeyContains: "TEL;TYPE=FAX"), ["010-88887777"])
        XCTAssertEqual(parsed.values(whereKeyContains: "EMAIL"), ["first@example.com", "second@example.com"])
        XCTAssertEqual(parsed.value("URL"), "www.example.com")
        XCTAssertEqual(parsed.adrStreet, "北京市朝阳区建国路88号")
        XCTAssertEqual(parsed.adrPostalCode, "100022")
        XCTAssertEqual(parsed.value("CATEGORIES"), "客户,重点")
        XCTAssertEqual(parsed.value("NOTE"), "第一行\n第二行")
    }

    @MainActor
    func testWriterProducesVCardFileWithMappedFields() async throws {
        let environment = makeTestEnvironment()
        let viewModel = ExportViewModel(environment: environment)
        let card = BusinessCard.fixture(
            name: "张三",
            mobile: ["13800138000", "13900139000"],
            officePhone: ["010-88886666"],
            fax: ["010-88887777"],
            email: ["first@example.com", "second@example.com"],
            tags: ["客户", "重点"]
        )
        viewModel.export([card])
        let url = try XCTUnwrap(viewModel.shareURL)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(url.pathExtension, "vcf")
        XCTAssertEqual(url.lastPathComponent, "张三.vcf")
        let content = try String(contentsOf: url, encoding: .utf8)
        let parsed = try ParsedVCard(content: content)
        XCTAssertEqual(parsed.value("FN"), "张三")
        XCTAssertEqual(parsed.values(whereKeyContains: "TEL;TYPE=CELL"), ["13800138000", "13900139000"])
        XCTAssertEqual(parsed.values(whereKeyContains: "TEL;TYPE=WORK"), ["010-88886666"])
        XCTAssertEqual(parsed.values(whereKeyContains: "TEL;TYPE=FAX"), ["010-88887777"])
        XCTAssertEqual(parsed.values(whereKeyContains: "EMAIL"), ["first@example.com", "second@example.com"])
        XCTAssertEqual(parsed.value("CATEGORIES"), "客户,重点")
    }

    @MainActor
    func testWriterFailureIsReported() async {
        let environment = makeTestEnvironment(exportWriter: FailingVCardWriter())
        let viewModel = ExportViewModel(environment: environment)
        viewModel.export([BusinessCard.fixture()])
        XCTAssertNil(viewModel.shareURL)
        XCTAssertEqual(viewModel.errorMessage, ExportError.writeFailed.localizedDescription)
    }

    @MainActor
    func testEmptySelectionIsBlocked() async {
        let environment = makeTestEnvironment()
        let viewModel = ExportViewModel(environment: environment)
        viewModel.export([])
        XCTAssertNil(viewModel.shareURL)
        XCTAssertEqual(viewModel.errorMessage, ExportError.emptySelection.localizedDescription)
    }
}

private struct ParsedVCard {
    private var pairs: [(String, String)] = []

    init(content: String) throws {
        for line in content.components(separatedBy: "\r\n") where !line.isEmpty {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<separator])
            let value = String(line[line.index(after: separator)...])
            pairs.append((key, ParsedVCard.unescape(value)))
        }
    }

    var adrStreet: String? {
        guard let value = value("ADR") else { return nil }
        let components = value.components(separatedBy: ";")
        return components.indices.contains(2) ? components[2] : nil
    }

    var adrPostalCode: String? {
        guard let value = value("ADR") else { return nil }
        let components = value.components(separatedBy: ";")
        return components.indices.contains(5) ? components[5] : nil
    }

    func value(_ key: String) -> String? {
        pairs.first { $0.0 == key }?.1
    }

    func values(whereKeyContains fragment: String) -> [String] {
        pairs.filter { $0.0.contains(fragment) }.map(\.1)
    }

    private static func unescape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}
