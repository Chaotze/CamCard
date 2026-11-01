import Foundation

actor FileCardRepository: CardRepository {
    private struct StoreFile: Codable {
        var schemaVersion: Int
        var cards: [BusinessCard]
        var audits: [CardAudit]
    }

    static let currentSchemaVersion = 1

    private let directory: URL
    private let imagesDirectory: URL?
    private let storeURL: URL

    init(directory: URL, imagesDirectory: URL? = nil) {
        self.directory = directory
        self.imagesDirectory = imagesDirectory
        self.storeURL = directory.appendingPathComponent("store.json")
    }

    func load() async throws -> CardSnapshot {
        let store = try readStoreIfPresent()
        guard let store else { return .empty }
        guard store.schemaVersion <= Self.currentSchemaVersion else {
            throw RepositoryError.storageIncompatible(
                found: store.schemaVersion,
                supported: Self.currentSchemaVersion
            )
        }
        let references = referencedFileNames(cards: store.cards)
        cleanupOrphanImages(keeping: references)
        return CardSnapshot(
            cards: store.cards,
            audits: Dictionary(uniqueKeysWithValues: store.audits.map { ($0.cardID, $0) })
        )
    }

    func save(_ card: BusinessCard, audit: CardAudit) async throws {
        var store = try readStoreIfPresent() ?? StoreFile(
            schemaVersion: Self.currentSchemaVersion,
            cards: [],
            audits: []
        )
        guard store.schemaVersion <= Self.currentSchemaVersion else {
            throw RepositoryError.storageIncompatible(
                found: store.schemaVersion,
                supported: Self.currentSchemaVersion
            )
        }
        store.schemaVersion = Self.currentSchemaVersion
        if let index = store.cards.firstIndex(where: { $0.id == card.id }) {
            store.cards[index] = card
        } else {
            store.cards.append(card)
        }
        if let index = store.audits.firstIndex(where: { $0.cardID == card.id }) {
            store.audits[index] = audit
        } else {
            store.audits.append(audit)
        }
        try writeStore(store)
    }

    func update(_ card: BusinessCard, audit: CardAudit?) async throws {
        guard var store = try readStoreIfPresent() else {
            throw RepositoryError.cardNotFound
        }
        guard store.schemaVersion <= Self.currentSchemaVersion else {
            throw RepositoryError.storageIncompatible(
                found: store.schemaVersion,
                supported: Self.currentSchemaVersion
            )
        }
        guard let index = store.cards.firstIndex(where: { $0.id == card.id }) else {
            throw RepositoryError.cardNotFound
        }
        store.cards[index] = card
        if let audit {
            if let auditIndex = store.audits.firstIndex(where: { $0.cardID == card.id }) {
                store.audits[auditIndex] = audit
            } else {
                store.audits.append(audit)
            }
        }
        try writeStore(store)
    }

    func delete(id: UUID) async throws {
        guard var store = try readStoreIfPresent() else { return }
        store.cards.removeAll { $0.id == id }
        store.audits.removeAll { $0.cardID == id }
        try writeStore(store)
        cleanupOrphanImages(keeping: referencedFileNames(cards: store.cards))
    }

    func reset() async throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: storeURL.path) {
            try fileManager.removeItem(at: storeURL)
        }
        if let imagesDirectory, fileManager.fileExists(atPath: imagesDirectory.path) {
            try? fileManager.removeItem(at: imagesDirectory)
        }
    }

    private func readStoreIfPresent() throws -> StoreFile? {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: storeURL)
            return try Self.decoder.decode(StoreFile.self, from: data)
        } catch {
            throw RepositoryError.storageCorrupted
        }
    }

    private func writeStore(_ store: StoreFile) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data: Data
        do {
            data = try Self.encoder.encode(store)
        } catch {
            throw RepositoryError.saveFailed
        }
        let temporaryURL = directory.appendingPathComponent("store.json.tmp")
        do {
            try data.write(to: temporaryURL, options: .atomic)
            if fileManager.fileExists(atPath: storeURL.path) {
                _ = try fileManager.replaceItemAt(storeURL, withItemAt: temporaryURL)
            } else {
                try fileManager.moveItem(at: temporaryURL, to: storeURL)
            }
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw RepositoryError.saveFailed
        }
    }

    private func referencedFileNames(cards: [BusinessCard]) -> Set<String> {
        var names = Set<String>()
        for card in cards {
            names.insert(card.originalImage.fileName)
            if let processed = card.processedImage {
                names.insert(processed.fileName)
            }
        }
        return names
    }

    private func cleanupOrphanImages(keeping references: Set<String>) {
        guard let imagesDirectory else { return }
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: imagesDirectory,
            includingPropertiesForKeys: nil
        ) else { return }
        for file in files where !references.contains(file.lastPathComponent) {
            try? fileManager.removeItem(at: file)
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
