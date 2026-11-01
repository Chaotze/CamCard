import XCTest
@testable import CamCard

final class FieldParserTests: XCTestCase {
    private let parser = BusinessCardFieldParser()

    func testStandardCardMapsAllFields() {
        let record = makeOCRRecord([
            "姓名：张三",
            "星河科技有限公司",
            "高级工程师",
            "手机：138 0013 8000",
            "Office：010-8888 6666",
            "Fax：010-8888 7777",
            "邮箱：zhangsan@xinghe.com",
            "网址：www.xinghe.com",
            "地址：北京市朝阳区建国路88号",
            "北京市海淀区中关村大街1号",
            "邮编：100022",
            "部门：研发部",
            "备注：重点客户"
        ])
        let fields = parser.parse(record)
        XCTAssertEqual(fields.name, "张三")
        XCTAssertEqual(fields.company, "星河科技有限公司")
        XCTAssertEqual(fields.jobTitle, "高级工程师")
        XCTAssertEqual(fields.mobile, ["138 0013 8000"])
        XCTAssertEqual(fields.officePhone, ["010-8888 6666"])
        XCTAssertEqual(fields.fax, ["010-8888 7777"])
        XCTAssertEqual(fields.email, ["zhangsan@xinghe.com"])
        XCTAssertEqual(fields.website, "www.xinghe.com")
        XCTAssertEqual(fields.address, "北京市朝阳区建国路88号\n北京市海淀区中关村大街1号")
        XCTAssertEqual(fields.postalCode, "100022")
        XCTAssertEqual(fields.department, "研发部")
        XCTAssertEqual(fields.notes, "重点客户")
        for field in ContactField.allCases {
            XCTAssertNotNil(fields.provenance(for: field), "\(field) should have provenance")
            XCTAssertFalse(fields.provenance(for: field)?.sourceLineIDs.isEmpty ?? true)
        }
    }

    func testMissingWebsiteReturnsNilAndIsNotDerivedFromEmail() {
        let record = makeOCRRecord([
            "张三",
            "手机：13800138000",
            "邮箱：zhangsan@example.com"
        ])
        let fields = parser.parse(record)
        XCTAssertNil(fields.website)
        XCTAssertEqual(fields.email, ["zhangsan@example.com"])
    }

    func testMissingFieldsStayNil() {
        let record = makeOCRRecord(["王五", "手机：13600136000"])
        let fields = parser.parse(record)
        XCTAssertNil(fields.company)
        XCTAssertNil(fields.jobTitle)
        XCTAssertNil(fields.department)
        XCTAssertNil(fields.website)
        XCTAssertNil(fields.address)
        XCTAssertNil(fields.postalCode)
        XCTAssertTrue(fields.email.isEmpty)
    }

    func testPhoneClassificationKeepsAllNumbers() {
        let record = makeOCRRecord([
            "李四",
            "手机：139 0013 9000",
            "Mobile: 137 0013 7000",
            "Office：021-6666 8888",
            "电话：021-6666 9999",
            "Fax：021-6666 7777"
        ])
        let fields = parser.parse(record)
        XCTAssertEqual(Set(fields.mobile), Set(["139 0013 9000", "137 0013 7000"]))
        XCTAssertEqual(Set(fields.officePhone), Set(["021-6666 8888", "021-6666 9999"]))
        XCTAssertEqual(fields.fax, ["021-6666 7777"])
    }

    func testUnlabeledNumberDefaultsToMobileWithInferredProvenance() {
        let record = makeOCRRecord(["赵六", "13800138000"])
        let fields = parser.parse(record)
        XCTAssertEqual(fields.mobile, ["13800138000"])
        XCTAssertEqual(fields.provenance(for: .mobile)?.method, .defaultMobile)
    }

    func testCompanyAmbiguityUsesEmailDomainAndLeavesJobTitleEmpty() {
        let record = makeOCRRecord([
            "Apple",
            "iPhone",
            "张三",
            "手机：13800138000",
            "Email：zhangsan@apple.com"
        ])
        let fields = parser.parse(record)
        XCTAssertEqual(fields.company, "Apple")
        XCTAssertNil(fields.jobTitle)
        XCTAssertNil(fields.website)
        XCTAssertEqual(fields.name, "张三")
    }

    func testMultipleEmailsPreserveOrderAndCaseAndDeduplicate() {
        let record = makeOCRRecord([
            "张三",
            "Email：ZHANGSAN@Example.COM",
            "邮箱：zhangsan@example.com",
            "邮箱：ZHANGSAN@Example.COM"
        ])
        let fields = parser.parse(record)
        XCTAssertEqual(fields.email, ["ZHANGSAN@Example.COM", "zhangsan@example.com"])
    }

    func testWebsiteLiteralIsPreserved() {
        let record = makeOCRRecord(["张三", "网址：www.example.com"])
        let fields = parser.parse(record)
        XCTAssertEqual(fields.website, "www.example.com")
    }

    func testPostalCodeNotInferredFromAddress() {
        let record = makeOCRRecord([
            "张三",
            "地址：北京市朝阳区建国路100000号"
        ])
        let fields = parser.parse(record)
        XCTAssertNil(fields.postalCode)
        XCTAssertEqual(fields.address, "北京市朝阳区建国路100000号")
    }

    func testMultilineAddressPreserved() {
        let record = makeOCRRecord([
            "张三",
            "地址：上海市浦东新区世纪大道100号",
            "陆家嘴环路2号",
            "3层"
        ])
        let fields = parser.parse(record)
        XCTAssertEqual(fields.address, "上海市浦东新区世纪大道100号\n陆家嘴环路2号\n3层")
    }

    func testMixedChineseEnglishCard() {
        let record = makeOCRRecord([
            "Zhang Wei",
            "Nova Robotics Inc.",
            "Senior Engineer",
            "Mobile: +86 138 0013 8000",
            "Email: zhang.wei@novarobotics.com",
            "Web: www.novarobotics.com",
            "Address: 88 Jianguo Road, Chaoyang District, Beijing"
        ])
        let fields = parser.parse(record)
        XCTAssertEqual(fields.name, "Zhang Wei")
        XCTAssertEqual(fields.company, "Nova Robotics Inc.")
        XCTAssertEqual(fields.jobTitle, "Senior Engineer")
        XCTAssertEqual(fields.mobile, ["+86 138 0013 8000"])
        XCTAssertEqual(fields.email, ["zhang.wei@novarobotics.com"])
        XCTAssertEqual(fields.website, "www.novarobotics.com")
        XCTAssertEqual(fields.address, "88 Jianguo Road, Chaoyang District, Beijing")
    }

    func testEmptyInputProducesEmptyStructure() {
        let fields = parser.parse(makeOCRRecord([], status: .empty))
        XCTAssertTrue(fields.emptyInput)
        XCTAssertTrue(fields.isEmpty)
        XCTAssertTrue(fields.provenance.isEmpty)
        XCTAssertEqual(fields.allFieldNames.count, 12)
    }

    func testDeterministicParsing() {
        let record = makeOCRRecord(["张三", "星河科技有限公司", "手机：13800138000", "邮箱：zhangsan@xinghe.com"])
        XCTAssertEqual(parser.parse(record), parser.parse(record))
    }

    func testEmptyFieldHasNoProvenance() {
        let record = makeOCRRecord(["张三", "手机：13800138000"])
        let fields = parser.parse(record)
        XCTAssertNil(fields.provenance(for: .website))
        XCTAssertNil(fields.provenance(for: .email))
        XCTAssertNil(fields.provenance(for: .postalCode))
    }

    func testDepartmentIsNotInferredFromJobTitle() {
        let record = makeOCRRecord(["张三", "销售经理"])
        let fields = parser.parse(record)
        XCTAssertNil(fields.department)
        XCTAssertEqual(fields.jobTitle, "销售经理")
    }
}
