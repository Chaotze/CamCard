import Foundation

enum SeedData {
    static func installIfNeeded(environment: AppEnvironment) async {
        guard let fixture = environment.launchOptions.seedFixture, fixture != "empty" else { return }
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        var templates: [BusinessCard] = [
            BusinessCard.fixture(
                name: "张三",
                company: "星河科技有限公司",
                jobTitle: "高级工程师",
                mobile: ["13800138000"],
                officePhone: ["010-88886666"],
                fax: ["010-88887777"],
                email: ["zhangsan@xinghe.com"],
                website: "www.xinghe.com",
                address: "北京市朝阳区建国路88号",
                department: "研发部",
                postalCode: "100022",
                notes: "重点客户",
                tags: ["客户"],
                createdAt: base.addingTimeInterval(-3600)
            ),
            BusinessCard.fixture(
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
                createdAt: base.addingTimeInterval(-1800)
            ),
            BusinessCard.fixture(
                name: "王五",
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
                createdAt: base
            )
        ]
        for index in templates.indices {
            let id = UUID()
            let label = templates[index].displayName
            let imageData = ImageProcessing.sampleJPEG(text: label)
            guard let imageReference = try? await environment.imageStore.write(imageData, id: id, kind: .original) else {
                continue
            }
            templates[index].id = id
            templates[index].originalImage = imageReference
            templates[index].processedImage = nil
            let card = templates[index]
            let audit = CardAudit(
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
            try? await environment.repository.save(card, audit: audit)
        }
    }
}
