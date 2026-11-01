import Foundation

actor FileImageStore: ImageStore {
    private let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    func write(_ data: Data, id: UUID, kind: ImageKind) async throws -> ImageReference {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let reference = ImageReference(
                fileName: InMemoryImageStore.fileName(id: id, kind: kind),
                kind: kind
            )
            try data.write(to: url(for: reference), options: .atomic)
            return reference
        } catch {
            throw ImageStoreError.writeFailed
        }
    }

    func read(_ reference: ImageReference) async throws -> Data? {
        guard reference.isRelative else { throw ImageStoreError.invalidReference }
        let fileURL = url(for: reference)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            return try Data(contentsOf: fileURL)
        } catch {
            throw ImageStoreError.readFailed
        }
    }

    func delete(_ reference: ImageReference) async throws {
        guard reference.isRelative else { throw ImageStoreError.invalidReference }
        let fileURL = url(for: reference)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    func reset() async throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.removeItem(at: directory)
    }

    private func url(for reference: ImageReference) -> URL {
        directory.appendingPathComponent(reference.fileName)
    }
}
