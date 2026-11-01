import XCTest
import UIKit
@testable import CamCard

final class ServiceAndViewModelTests: XCTestCase {
    func testMockOCRIsDeterministic() async {
        let service = MockOCRService(fixture: "standard")
        let first = await service.recognize(imageData: Data([0x01]), source: .processed)
        let second = await service.recognize(imageData: Data([0x02]), source: .processed)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.status, .success)
        XCTAssertFalse(first.lines.isEmpty)
        XCTAssertTrue(first.lines.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
    }

    func testVisionOCRExtractsStructuralLines() async {
        let service = VisionOCRService()
        let image = ImageProcessing.sampleJPEG(
            text: "ZHANG SAN",
            size: CGSize(width: 900, height: 600)
        )
        let record = await service.recognize(imageData: image, source: .processed)
        XCTAssertEqual(record.status, .success)
        XCTAssertFalse(record.lines.isEmpty)
        for line in record.lines {
            XCTAssertFalse(line.text.isEmpty)
            XCTAssertTrue((0...1).contains(line.x))
            XCTAssertTrue((0...1).contains(line.y))
            XCTAssertGreaterThan(line.confidence, 0)
        }
        XCTAssertEqual(record.source, .processed)
    }

    func testMockOCRBlankFixtureIsEmpty() async {
        let service = MockOCRService(fixture: "blank")
        let record = await service.recognize(imageData: Data([0x01]), source: .processed)
        XCTAssertEqual(record.status, .empty)
        XCTAssertTrue(record.lines.isEmpty)
    }

    func testPreparedJPEGCapsLongestEdgeAndDecodes() throws {
        let original = ImageProcessing.sampleJPEG(
            text: "BIG CARD",
            size: CGSize(width: 4200, height: 2100)
        )
        let prepared = try XCTUnwrap(ImageProcessing.preparedJPEG(original))
        let image = try XCTUnwrap(UIImage(data: prepared))
        XCTAssertLessThanOrEqual(max(image.size.width, image.size.height), 3000)
        XCTAssertGreaterThan(image.size.width, image.size.height)
    }

    func testMockDetectionReturnsCornersAndProcessedImage() async {
        let service = MockCardDetectionService()
        let image = ImageProcessing.sampleJPEG(text: "张三")
        let outcome = await service.detect(in: image)
        guard case let .success(detected) = outcome else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(detected.corners.count, 4)
        XCTAssertNotNil(detected.processedData)
        XCTAssertNotNil(UIImage(data: detected.processedData!))
    }

    func testVisionRectificationProducesProcessedImage() async {
        let service = VisionCardDetectionService()
        let image = ImageProcessing.sampleJPEG(text: "张三 星河科技有限公司")
        let outcome = await service.rectify(imageData: image, corners: MockCardDetectionService.defaultCorners)
        guard case let .success(detected) = outcome else {
            return XCTFail("expected rectification success")
        }
        guard let data = detected.processedData, let processed = UIImage(data: data) else {
            return XCTFail("expected decodable output")
        }
        XCTAssertGreaterThan(processed.size.width, 0)
        XCTAssertGreaterThan(processed.size.height, 0)
    }

    @MainActor
    func testCaptureFlowReachesReviewWithMockServices() async {
        let environment = makeTestEnvironment()
        let viewModel = CaptureFlowViewModel(environment: environment)
        await viewModel.start(with: ImageProcessing.sampleJPEG(text: "张三"))
        XCTAssertEqual(viewModel.state, .readyForReview)
        XCTAssertEqual(viewModel.corners.count, 4)
        XCTAssertNotNil(viewModel.processedImageData)
        XCTAssertNotNil(viewModel.ocrRecord)
        XCTAssertFalse(viewModel.structured?.isEmpty ?? true)
    }

    @MainActor
    func testCaptureFlowDetectionFailureCanContinueWithOriginal() async {
        let environment = makeTestEnvironment(detection: MockCardDetectionService(shouldFail: true))
        let viewModel = CaptureFlowViewModel(environment: environment)
        await viewModel.start(with: ImageProcessing.sampleJPEG(text: "张三"))
        XCTAssertEqual(viewModel.state, .detectionFailed)
        XCTAssertNil(viewModel.processedImageData)
        await viewModel.continueWithOriginal()
        XCTAssertEqual(viewModel.state, .readyForReview)
        XCTAssertEqual(viewModel.ocrRecord?.source, .original)
    }

    @MainActor
    func testCameraUnavailableShowsPermissionMessage() async {
        let environment = makeTestEnvironment()
        let viewModel = CaptureFlowViewModel(environment: environment)
        XCTAssertFalse(viewModel.cameraUnavailable)
        let unavailableEnvironment = AppEnvironment(
            repository: InMemoryCardRepository(),
            imageStore: InMemoryImageStore(),
            ocr: MockOCRService(fixture: "standard"),
            detection: MockCardDetectionService(),
            parser: BusinessCardFieldParser(),
            clock: FixedClock(),
            cameraPermission: StaticCameraPermissionService(current: .unavailable),
            exportWriter: TemporaryVCardWriter(),
            launchOptions: LaunchOptions()
        )
        let unavailable = CaptureFlowViewModel(environment: unavailableEnvironment)
        await unavailable.openCamera()
        XCTAssertNotNil(unavailable.cameraPermissionMessage)
        XCTAssertFalse(unavailable.cameraPickerPresented)
    }

    @MainActor
    func testReviewSavesCardWithImagesAndAudit() async throws {
        let environment = makeTestEnvironment()
        let capture = CaptureFlowViewModel(environment: environment)
        await capture.start(with: ImageProcessing.sampleJPEG(text: "张三"))
        let review = try XCTUnwrap(capture.makeReviewViewModel())
        review.newTag = "客户"
        review.addTag()
        review.setString(.notes, "重点客户")
        await review.save()

        XCTAssertTrue(review.didSave)
        let snapshot = try await environment.repository.load()
        XCTAssertEqual(snapshot.cards.count, 1)
        let card = try XCTUnwrap(snapshot.cards.first)
        XCTAssertEqual(card.tags, ["客户"])
        XCTAssertEqual(card.notes, "重点客户")
        XCTAssertNotNil(card.processedImage)
        XCTAssertNotNil(snapshot.audits[card.id])
        let original = try await environment.imageStore.read(card.originalImage)
        XCTAssertNotNil(original)
        if let processed = card.processedImage {
            let processedData = try await environment.imageStore.read(processed)
            XCTAssertNotNil(processedData)
        }
    }

    @MainActor
    func testReviewSaveFailureLeavesNoCardAndCleansImages() async throws {
        let repository = InMemoryCardRepository()
        let imageStore = InMemoryImageStore()
        repository.failNextSave = true
        let environment = makeTestEnvironment(repository: repository, imageStore: imageStore)
        let capture = CaptureFlowViewModel(environment: environment)
        await capture.start(with: ImageProcessing.sampleJPEG(text: "张三"))
        let review = try XCTUnwrap(capture.makeReviewViewModel())
        await review.save()
        XCTAssertFalse(review.didSave)
        XCTAssertFalse(review.errorMessage?.isEmpty ?? true)
        let snapshot = try await repository.load()
        XCTAssertTrue(snapshot.cards.isEmpty)
        XCTAssertTrue(imageStore.storage.isEmpty)
    }

    @MainActor
    func testRetakeAndCancelDiscardDraft() async {
        let environment = makeTestEnvironment()
        let capture = CaptureFlowViewModel(environment: environment)
        await capture.start(with: ImageProcessing.sampleJPEG(text: "张三"))
        XCTAssertEqual(capture.state, .readyForReview)
        capture.retake()
        XCTAssertNil(capture.originalImageData)
        XCTAssertNil(capture.processedImageData)
        XCTAssertEqual(capture.state, .abandoned)
        XCTAssertTrue(capture.cameraPickerPresented)

        await capture.start(with: ImageProcessing.sampleJPEG(text: "李四"))
        XCTAssertEqual(capture.state, .readyForReview)
        capture.cancel()
        XCTAssertEqual(capture.state, .abandoned)
        XCTAssertNil(capture.originalImageData)
    }

    @MainActor
    func testReviewBlocksSavingEmptyCard() async {
        let environment = makeTestEnvironment()
        let draft = CardDraft(
            state: .readyForReview,
            originalData: ImageProcessing.sampleJPEG(text: "空"),
            structured: .empty
        )
        let review = ReviewViewModel(draft: draft, environment: environment)
        XCTAssertFalse(review.hasAnyValue)
        await review.save()
        XCTAssertFalse(review.didSave)
        XCTAssertEqual(review.errorMessage, "请至少填写一项信息后再保存")
    }

    @MainActor
    func testReviewRestoreReturnsToParsedValue() async throws {
        let environment = makeTestEnvironment()
        let parsed = StructuredFields(name: "张三", mobile: ["13800138000"])
        let draft = CardDraft(
            state: .readyForReview,
            originalData: ImageProcessing.sampleJPEG(text: "张三"),
            structured: parsed
        )
        let review = ReviewViewModel(draft: draft, environment: environment)
        XCTAssertEqual(review.source(for: .name), .parsed)
        review.setString(.name, "李四")
        XCTAssertEqual(review.source(for: .name), .manual)
        XCTAssertTrue(review.restoreAvailable(for: .name))
        review.restore(.name)
        XCTAssertEqual(review.name, "张三")
        XCTAssertEqual(review.source(for: .name), .parsed)
    }

    @MainActor
    func testDetailLoadsAndDeletesCard() async throws {
        let environment = makeTestEnvironment()
        let card = BusinessCard.fixture()
        try await environment.repository.save(card, audit: BusinessCard.fixtureAudit(for: card))
        let detail = CardDetailViewModel(cardID: card.id, environment: environment)
        await detail.load()
        XCTAssertEqual(detail.card?.name, "张三")
        XCTAssertTrue(detail.imageUnavailable)
        XCTAssertEqual(detail.rawText.isEmpty, false)
        await detail.delete()
        XCTAssertTrue(detail.isDeleted)
        let snapshot = try await environment.repository.load()
        XCTAssertTrue(snapshot.cards.isEmpty)
    }

    @MainActor
    func testCorruptImageStillShowsCardText() async throws {
        let store = InMemoryImageStore()
        let cardID = UUID()
        let corrupt = try await store.write(Data("not an image".utf8), id: cardID, kind: .original)
        var card = BusinessCard.fixture(id: cardID, name: "张三")
        card.originalImage = corrupt
        card.processedImage = nil
        let repository = InMemoryCardRepository()
        try await repository.save(card, audit: BusinessCard.fixtureAudit(for: card))
        let environment = makeTestEnvironment(repository: repository, imageStore: store)
        let detail = CardDetailViewModel(cardID: cardID, environment: environment)
        await detail.load()
        XCTAssertEqual(detail.card?.name, "张三")
        XCTAssertTrue(detail.imageUnavailable)
    }

    @MainActor
    func testPersistenceSurvivesRelaunchIncludingImagesTagsAndNotes() async throws {
        let directory = makeTemporaryDirectory("relaunch")
        defer { try? FileManager.default.removeItem(at: directory) }
        let imagesDirectory = directory.appendingPathComponent("images", isDirectory: true)

        let firstEnvironment = makeTestEnvironment(
            repository: FileCardRepository(directory: directory, imagesDirectory: imagesDirectory),
            imageStore: FileImageStore(directory: imagesDirectory)
        )
        let capture = CaptureFlowViewModel(environment: firstEnvironment)
        await capture.start(with: ImageProcessing.sampleJPEG(text: "张三"))
        let review = try XCTUnwrap(capture.makeReviewViewModel())
        review.newTag = "客户"
        review.addTag()
        review.setString(.notes, "重启后仍在")
        await review.save()
        XCTAssertTrue(review.didSave)
        let createdAt = try XCTUnwrap(review.savedCard?.createdAt)

        let secondEnvironment = makeTestEnvironment(
            repository: FileCardRepository(directory: directory, imagesDirectory: imagesDirectory),
            imageStore: FileImageStore(directory: imagesDirectory)
        )
        let snapshot = try await secondEnvironment.repository.load()
        XCTAssertEqual(snapshot.cards.count, 1)
        let card = try XCTUnwrap(snapshot.cards.first)
        XCTAssertEqual(card.tags, ["客户"])
        XCTAssertEqual(card.notes, "重启后仍在")
        XCTAssertEqual(card.name, "张三")
        XCTAssertEqual(card.createdAt, createdAt)
        let original = try await secondEnvironment.imageStore.read(card.originalImage)
        XCTAssertNotNil(original)
        let processed = try await secondEnvironment.imageStore.read(try XCTUnwrap(card.processedImage))
        XCTAssertNotNil(processed)
        XCTAssertNotNil(snapshot.audits[card.id])
        XCTAssertFalse(snapshot.audits[card.id]?.structuredFields.isEmpty ?? true)
        XCTAssertFalse(snapshot.audits[card.id]?.ocrRecords.isEmpty ?? true)

        let editReview = ReviewViewModel(
            card: card,
            audit: snapshot.audits[card.id],
            originalImageData: original,
            processedImageData: processed,
            environment: secondEnvironment
        )
        editReview.setString(.name, "李四")
        await editReview.save()
        XCTAssertTrue(editReview.didSave)

        let thirdEnvironment = makeTestEnvironment(
            repository: FileCardRepository(directory: directory, imagesDirectory: imagesDirectory),
            imageStore: FileImageStore(directory: imagesDirectory)
        )
        let finalSnapshot = try await thirdEnvironment.repository.load()
        XCTAssertEqual(finalSnapshot.cards.count, 1)
        XCTAssertEqual(finalSnapshot.cards.first?.name, "李四")
        XCTAssertEqual(finalSnapshot.cards.first?.createdAt, createdAt)
    }

    @MainActor
    func testCardHolderSearchTagFilterAndSort() async throws {
        let cards = [
            BusinessCard.fixture(name: "Cindy", company: "云帆设计", tags: ["供应商"], createdAt: Date(timeIntervalSince1970: 3)),
            BusinessCard.fixture(name: "Alice", company: "星河科技", tags: ["客户"], createdAt: Date(timeIntervalSince1970: 2)),
            BusinessCard.fixture(name: "Bob", company: nil, tags: ["客户", "潜在"], createdAt: Date(timeIntervalSince1970: 1)),
            BusinessCard.fixture(name: nil, company: "无名称公司", tags: [], createdAt: Date(timeIntervalSince1970: 0))
        ]
        let repository = InMemoryCardRepository(snapshot: CardSnapshot(cards: cards))
        let viewModel = CardHolderViewModel(environment: makeTestEnvironment(repository: repository))
        await viewModel.bootstrap()
        XCTAssertEqual(viewModel.filteredCards.count, 4)

        viewModel.searchText = "云"
        XCTAssertEqual(viewModel.filteredCards.map(\.displayName), ["Cindy"])

        viewModel.searchText = ""
        viewModel.toggleTag("客户")
        XCTAssertEqual(Set(viewModel.filteredCards.map(\.displayName)), Set(["Alice", "Bob"]))

        viewModel.toggleTag("供应商")
        XCTAssertEqual(viewModel.filteredCards.count, 3)

        viewModel.selectedTags.removeAll()
        viewModel.sortOrder = .name
        XCTAssertEqual(viewModel.filteredCards.map(\.displayName), ["Alice", "Bob", "Cindy", "未命名"])

        viewModel.sortOrder = .company
        XCTAssertEqual(viewModel.filteredCards.last?.displayName, "Bob")

        viewModel.searchText = "不存在的名片"
        XCTAssertTrue(viewModel.noResultsVisible)
    }
}
