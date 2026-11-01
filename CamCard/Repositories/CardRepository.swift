import Foundation

protocol CardRepository {
    func load() async throws -> CardSnapshot
    func save(_ card: BusinessCard, audit: CardAudit) async throws
    func update(_ card: BusinessCard, audit: CardAudit?) async throws
    func delete(id: UUID) async throws
    func reset() async throws
}

enum RepositoryError: Error, LocalizedError, Equatable {
    case loadFailed
    case saveFailed
    case cardNotFound
    case storageIncompatible(found: Int, supported: Int)
    case storageCorrupted

    var errorDescription: String? {
        switch self {
        case .loadFailed: return "无法读取名片数据"
        case .saveFailed: return "保存失败，请重试"
        case .cardNotFound: return "名片不存在"
        case let .storageIncompatible(found, supported):
            return "存储版本不兼容（数据版本 \(found)，应用支持 \(supported)）"
        case .storageCorrupted: return "名片数据已损坏"
        }
    }
}

final class InMemoryCardRepository: CardRepository {
    private(set) var snapshot: CardSnapshot
    var failNextSave = false
    var failNextUpdate = false
    var failNextLoad = false
    var failNextDelete = false

    init(snapshot: CardSnapshot = .empty) {
        self.snapshot = snapshot
    }

    func load() async throws -> CardSnapshot {
        if failNextLoad {
            failNextLoad = false
            throw RepositoryError.loadFailed
        }
        return snapshot
    }

    func save(_ card: BusinessCard, audit: CardAudit) async throws {
        if failNextSave {
            failNextSave = false
            throw RepositoryError.saveFailed
        }
        upsert(card, audit: audit)
    }

    func update(_ card: BusinessCard, audit: CardAudit?) async throws {
        if failNextUpdate {
            failNextUpdate = false
            throw RepositoryError.saveFailed
        }
        guard snapshot.cards.contains(where: { $0.id == card.id }) else {
            throw RepositoryError.cardNotFound
        }
        upsert(card, audit: audit)
    }

    func delete(id: UUID) async throws {
        if failNextDelete {
            failNextDelete = false
            throw RepositoryError.saveFailed
        }
        snapshot.cards.removeAll { $0.id == id }
        snapshot.audits[id] = nil
    }

    func reset() async throws {
        snapshot = .empty
    }

    private func upsert(_ card: BusinessCard, audit: CardAudit?) {
        if let index = snapshot.cards.firstIndex(where: { $0.id == card.id }) {
            snapshot.cards[index] = card
        } else {
            snapshot.cards.append(card)
        }
        if let audit {
            snapshot.audits[card.id] = audit
        }
    }
}
