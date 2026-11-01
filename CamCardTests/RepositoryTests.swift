import XCTest
@testable import CamCard

final class RepositoryTests: XCTestCase {
    func testInMemoryRepositorySaveLoadUpdateDeleteReset() async throws {
        let repository = InMemoryCardRepository()
        let card = BusinessCard.fixture()
        try await repository.save(card, audit: BusinessCard.fixtureAudit(for: card))
        var snapshot = try await repository.load()
        XCTAssertEqual(snapshot.cards.count, 1)
        XCTAssertEqual(snapshot.audits[card.id]?.cardID, card.id)

        var updated = card
        updated.company = "新公司"
        try await repository.update(updated, audit: nil)
        snapshot = try await repository.load()
        XCTAssertEqual(snapshot.cards.first?.company, "新公司")
        XCTAssertNotNil(snapshot.audits[card.id])

        try await repository.delete(id: card.id)
        snapshot = try await repository.load()
        XCTAssertTrue(snapshot.cards.isEmpty)

        try await repository.save(card, audit: BusinessCard.fixtureAudit(for: card))
        try await repository.reset()
        snapshot = try await repository.load()
        XCTAssertTrue(snapshot.cards.isEmpty)
    }

    func testInMemorySaveFailureLeavesSnapshotUnchanged() async throws {
        let repository = InMemoryCardRepository()
        repository.failNextSave = true
        let card = BusinessCard.fixture()
        do {
            try await repository.save(card, audit: BusinessCard.fixtureAudit(for: card))
            XCTFail("expected failure")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .saveFailed)
        }
        let snapshot = try await repository.load()
        XCTAssertTrue(snapshot.cards.isEmpty)
    }

    func testInMemoryUpdateFailureLeavesSnapshotUnchanged() async throws {
        let repository = InMemoryCardRepository()
        let card = BusinessCard.fixture()
        try await repository.save(card, audit: BusinessCard.fixtureAudit(for: card))
        repository.failNextUpdate = true
        var updated = card
        updated.name = "李四"
        do {
            try await repository.update(updated, audit: nil)
            XCTFail("expected failure")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .saveFailed)
        }
        let snapshot = try await repository.load()
        XCTAssertEqual(snapshot.cards.first?.name, "张三")
    }

    func testFileRepositoryRoundTripAndUpdate() async throws {
        let directory = makeTemporaryDirectory("file-repo")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileCardRepository(directory: directory)
        var card = BusinessCard.fixture(originalFileName: "card-original.jpg")
        try await repository.save(card, audit: BusinessCard.fixtureAudit(for: card))
        var snapshot = try await repository.load()
        XCTAssertEqual(snapshot.cards.count, 1)
        XCTAssertEqual(snapshot.cards.first?.name, "张三")

        card.name = "李四"
        try await repository.update(card, audit: nil)
        snapshot = try await repository.load()
        XCTAssertEqual(snapshot.cards.first?.name, "李四")
        XCTAssertNotNil(snapshot.audits[card.id])
    }

    func testFileRepositoryDeleteCleansOwnedImages() async throws {
        let directory = makeTemporaryDirectory("delete-cleanup")
        defer { try? FileManager.default.removeItem(at: directory) }
        let imagesDirectory = directory.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        let original = imagesDirectory.appendingPathComponent("owned-original.jpg")
        let processed = imagesDirectory.appendingPathComponent("owned-processed.jpg")
        try Data([0x01]).write(to: original)
        try Data([0x02]).write(to: processed)

        let repository = FileCardRepository(directory: directory, imagesDirectory: imagesDirectory)
        let card = BusinessCard.fixture(
            originalFileName: "owned-original.jpg",
            processedFileName: "owned-processed.jpg"
        )
        try await repository.save(card, audit: BusinessCard.fixtureAudit(for: card))
        try await repository.delete(id: card.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: original.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: processed.path))
    }

    func testSharedImageIsKeptWhenOneCardIsDeleted() async throws {
        let directory = makeTemporaryDirectory("shared-image")
        defer { try? FileManager.default.removeItem(at: directory) }
        let imagesDirectory = directory.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        let shared = imagesDirectory.appendingPathComponent("shared-original.jpg")
        try Data([0x01]).write(to: shared)

        let repository = FileCardRepository(directory: directory, imagesDirectory: imagesDirectory)
        let first = BusinessCard.fixture(originalFileName: "shared-original.jpg", processedFileName: nil)
        var second = BusinessCard.fixture(originalFileName: "shared-original.jpg", processedFileName: nil)
        second.id = UUID()
        try await repository.save(first, audit: BusinessCard.fixtureAudit(for: first))
        try await repository.save(second, audit: BusinessCard.fixtureAudit(for: second))
        try await repository.delete(id: first.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: shared.path))
    }

    func testHigherSchemaVersionIsRejectedOnReadAndWrite() async throws {
        let directory = makeTemporaryDirectory("higher-schema")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storeURL = directory.appendingPathComponent("store.json")
        try Data(#"{"schemaVersion":99,"cards":[],"audits":[]}"#.utf8).write(to: storeURL)
        let repository = FileCardRepository(directory: directory)
        do {
            _ = try await repository.load()
            XCTFail("expected incompatibility")
        } catch {
            XCTAssertEqual(
                error as? RepositoryError,
                .storageIncompatible(found: 99, supported: 1)
            )
        }
        do {
            let card = BusinessCard.fixture()
            try await repository.save(card, audit: BusinessCard.fixtureAudit(for: card))
            XCTFail("expected incompatibility")
        } catch {
            XCTAssertEqual(
                error as? RepositoryError,
                .storageIncompatible(found: 99, supported: 1)
            )
        }
        let bytes = try Data(contentsOf: storeURL)
        XCTAssertEqual(String(data: bytes, encoding: .utf8), #"{"schemaVersion":99,"cards":[],"audits":[]}"#)
    }

    func testOlderSchemaVersionLoads() async throws {
        let directory = makeTemporaryDirectory("older-schema")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"schemaVersion":0,"cards":[],"audits":[]}"#.utf8)
            .write(to: directory.appendingPathComponent("store.json"))
        let repository = FileCardRepository(directory: directory)
        let snapshot = try await repository.load()
        XCTAssertTrue(snapshot.cards.isEmpty)
    }

    func testCorruptStoreThrows() async throws {
        let directory = makeTemporaryDirectory("corrupt")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: directory.appendingPathComponent("store.json"))
        let repository = FileCardRepository(directory: directory)
        do {
            _ = try await repository.load()
            XCTFail("expected corruption")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .storageCorrupted)
        }
    }

    func testOrphanImagesAreCleanedOnLoad() async throws {
        let directory = makeTemporaryDirectory("orphans")
        defer { try? FileManager.default.removeItem(at: directory) }
        let imagesDirectory = directory.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        let orphan = imagesDirectory.appendingPathComponent("orphan.jpg")
        try Data([0x00]).write(to: orphan)
        try Data(#"{"schemaVersion":1,"cards":[],"audits":[]}"#.utf8)
            .write(to: directory.appendingPathComponent("store.json"))
        let repository = FileCardRepository(directory: directory, imagesDirectory: imagesDirectory)
        _ = try await repository.load()
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path))
    }

    func testInMemoryImageStoreWriteReadDeleteReset() async throws {
        let store = InMemoryImageStore()
        let id = UUID()
        let reference = try await store.write(Data([0x01, 0x02]), id: id, kind: .original)
        let firstRead = try await store.read(reference)
        XCTAssertEqual(firstRead, Data([0x01, 0x02]))
        try await store.delete(reference)
        let deletedRead = try await store.read(reference)
        XCTAssertNil(deletedRead)
        try await store.delete(reference)
        let second = try await store.write(Data([0x03]), id: id, kind: .processed)
        let secondRead = try await store.read(second)
        XCTAssertNotNil(secondRead)
        try await store.reset()
        let resetRead = try await store.read(second)
        XCTAssertNil(resetRead)
    }

    func testFileImageStoreRoundTripAndMissingReference() async throws {
        let directory = makeTemporaryDirectory("image-store")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileImageStore(directory: directory)
        let reference = try await store.write(Data([0x01]), id: UUID(), kind: .original)
        let written = try await store.read(reference)
        XCTAssertEqual(written, Data([0x01]))
        XCTAssertTrue(reference.isRelative)
        try await store.delete(reference)
        let deleted = try await store.read(reference)
        XCTAssertNil(deleted)
        do {
            _ = try await store.read(ImageReference(fileName: "../escape.jpg", kind: .original))
            XCTFail("expected invalid reference")
        } catch {
            XCTAssertEqual(error as? ImageStoreError, .invalidReference)
        }
    }
}
