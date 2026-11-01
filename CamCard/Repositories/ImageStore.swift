import Foundation

protocol ImageStore {
    func write(_ data: Data, id: UUID, kind: ImageKind) async throws -> ImageReference
    func read(_ reference: ImageReference) async throws -> Data?
    func delete(_ reference: ImageReference) async throws
    func reset() async throws
}

enum ImageStoreError: Error, LocalizedError, Equatable {
    case invalidReference
    case writeFailed
    case readFailed

    var errorDescription: String? {
        switch self {
        case .invalidReference: return "图像引用无效"
        case .writeFailed: return "图像保存失败"
        case .readFailed: return "图像读取失败"
        }
    }
}

final class InMemoryImageStore: ImageStore {
    private(set) var storage: [String: Data] = [:]
    var failNextWrite = false
    var failNextDelete = false

    func write(_ data: Data, id: UUID, kind: ImageKind) async throws -> ImageReference {
        if failNextWrite {
            failNextWrite = false
            throw ImageStoreError.writeFailed
        }
        let reference = ImageReference(fileName: Self.fileName(id: id, kind: kind), kind: kind)
        storage[reference.fileName] = data
        return reference
    }

    func read(_ reference: ImageReference) async throws -> Data? {
        storage[reference.fileName]
    }

    func delete(_ reference: ImageReference) async throws {
        if failNextDelete {
            failNextDelete = false
            throw ImageStoreError.writeFailed
        }
        storage[reference.fileName] = nil
    }

    func reset() async throws {
        storage.removeAll()
    }

    static func fileName(id: UUID, kind: ImageKind) -> String {
        "\(id.uuidString)-\(kind.rawValue).jpg"
    }
}
