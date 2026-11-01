import XCTest
@testable import CamCard

final class ModelTests: XCTestCase {
    func testImageReferenceRoundTripAndRelativePath() throws {
        let reference = ImageReference(fileName: "abc-original.jpg", kind: .original)
        let data = try JSONEncoder().encode(reference)
        let decoded = try JSONDecoder().decode(ImageReference.self, from: data)
        XCTAssertEqual(decoded, reference)
        XCTAssertTrue(decoded.isRelative)
        XCTAssertFalse(ImageReference(fileName: "/tmp/abc.jpg", kind: .original).isRelative)
        XCTAssertFalse(ImageReference(fileName: "../abc.jpg", kind: .original).isRelative)
    }

    func testBusinessCardCodableRoundTrip() throws {
        let card = BusinessCard.fixture()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(card)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BusinessCard.self, from: data)
        XCTAssertEqual(decoded, card)
    }

    func testStructuredFieldsAndProvenanceRoundTrip() throws {
        let lineID = UUID()
        let fields = StructuredFields(
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
            provenance: [
                FieldProvenance(field: .name, confidence: 0.9, sourceLineIDs: [lineID], method: .label)
            ]
        )
        let data = try JSONEncoder().encode(fields)
        let decoded = try JSONDecoder().decode(StructuredFields.self, from: data)
        XCTAssertEqual(decoded, fields)
        XCTAssertEqual(decoded.provenance(for: .name)?.sourceLineIDs, [lineID])
        XCTAssertNil(decoded.provenance(for: .fax))
    }

    func testOCRRecordsKeepSequenceAndRawText() throws {
        let first = OCRRecord(
            sequence: 1,
            source: .processed,
            status: .success,
            lines: [OCRLine(text: "第一行", confidence: 0.9, x: 0.1, y: 0.8, width: 0.3, height: 0.05, sequence: 0)]
        )
        let second = OCRRecord(
            sequence: 2,
            source: .original,
            status: .success,
            lines: [OCRLine(text: "第二行", confidence: 0.8, x: 0.1, y: 0.8, width: 0.3, height: 0.05, sequence: 0)]
        )
        let card = BusinessCard.fixture()
        let audit = CardAudit(
            cardID: card.id,
            originalImage: card.originalImage,
            processedImage: card.processedImage,
            ocrRecords: [first, second],
            structuredFields: card.structuredFinalValues,
            corrections: [
                FieldCorrection(field: .name, previousValues: ["张三"], newValues: ["李四"])
            ],
            createdAt: card.createdAt
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(audit)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CardAudit.self, from: data)
        XCTAssertEqual(decoded.ocrRecords.map(\.sequence), [1, 2])
        XCTAssertEqual(decoded.ocrRecords[0].rawText, "第一行")
        XCTAssertEqual(decoded.structuredFields.name, "张三")
        XCTAssertEqual(decoded.corrections.first?.newValues, ["李四"])
    }

    func testCaptureStateLegalAndIllegalTransitions() throws {
        XCTAssertTrue(CaptureState.idle.canTransition(to: .captured))
        XCTAssertTrue(CaptureState.captured.canTransition(to: .detecting))
        XCTAssertTrue(CaptureState.detecting.canTransition(to: .detectionFailed))
        XCTAssertTrue(CaptureState.detectionFailed.canTransition(to: .detected))
        XCTAssertTrue(CaptureState.detected.canTransition(to: .ocrRunning))
        XCTAssertTrue(CaptureState.ocrRunning.canTransition(to: .ocrFinished))
        XCTAssertTrue(CaptureState.ocrFinished.canTransition(to: .parsing))
        XCTAssertTrue(CaptureState.parsing.canTransition(to: .readyForReview))
        XCTAssertTrue(CaptureState.readyForReview.canTransition(to: .saving))
        XCTAssertTrue(CaptureState.saving.canTransition(to: .saved))
        XCTAssertFalse(CaptureState.idle.canTransition(to: .saved))
        XCTAssertFalse(CaptureState.saved.canTransition(to: .readyForReview))
    }

    func testEveryStageCanBeAbandoned() {
        for state in CaptureState.allCases where state != .abandoned {
            XCTAssertTrue(state.canTransition(to: .abandoned), "\(state) should abandon")
        }
    }

    func testDraftTransitionThrowsForInvalidTarget() {
        var draft = CardDraft(originalData: Data([0x01]))
        XCTAssertThrowsError(try draft.transition(to: .saved)) { error in
            XCTAssertEqual(
                error as? CaptureTransitionError,
                .invalid(from: .captured, to: .saved)
            )
        }
    }

    func testFixtureCoversRequiredAndOptionalFields() {
        let fields = BusinessCard.fixture().structuredFinalValues
        for field in ContactField.requiredFields {
            XCTAssertFalse(fields.values(for: field).isEmpty, "\(field) should be populated")
        }
        for field in ContactField.optionalFields {
            XCTAssertFalse(fields.values(for: field).isEmpty, "\(field) should be populated")
        }
        XCTAssertEqual(ContactField.allCases.count, 12)
    }

    func testLaunchOptionsParsing() {
        let options = LaunchOptions.parse([
            "CamCard",
            "-uiTestResetStore",
            "-uiTestSeedFixture", "three",
            "-uiTestOCRFixture=multiphone",
            "-uiTestSkipCamera",
            "-uiTestForceExportFailure"
        ])
        XCTAssertTrue(options.resetStore)
        XCTAssertEqual(options.seedFixture, "three")
        XCTAssertEqual(options.ocrFixture, "multiphone")
        XCTAssertTrue(options.skipCamera)
        XCTAssertTrue(options.forceExportFailure)
        XCTAssertTrue(options.isUITest)
        XCTAssertEqual(LaunchOptions.parse(["CamCard"]), LaunchOptions())
    }

    func testPhoneClassificationFieldsAreMultiValue() {
        XCTAssertTrue(ContactField.mobile.isMultiValue)
        XCTAssertTrue(ContactField.officePhone.isMultiValue)
        XCTAssertTrue(ContactField.fax.isMultiValue)
        XCTAssertTrue(ContactField.email.isMultiValue)
        XCTAssertFalse(ContactField.name.isMultiValue)
    }
}
