import Foundation
import Combine

@MainActor
final class CardDetailViewModel: ObservableObject {
    @Published private(set) var card: BusinessCard?
    @Published private(set) var audit: CardAudit?
    @Published private(set) var imageData: Data?
    @Published private(set) var imageUnavailable = false
    @Published private(set) var isDeleted = false
    @Published var errorMessage: String?

    let cardID: UUID
    let environment: AppEnvironment

    init(cardID: UUID, environment: AppEnvironment) {
        self.cardID = cardID
        self.environment = environment
    }

    var rawText: String {
        audit?.ocrRecords.last?.rawText ?? ""
    }

    func load() async {
        do {
            let snapshot = try await environment.repository.load()
            guard let found = snapshot.cards.first(where: { $0.id == cardID }) else {
                errorMessage = "名片不存在"
                return
            }
            card = found
            audit = snapshot.audits[cardID]
            let reference = found.processedImage ?? found.originalImage
            imageData = try await environment.imageStore.read(reference)
            imageUnavailable = imageData.flatMap { ImageProcessing.uiImage(from: $0) } == nil
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "无法读取名片"
        }
    }

    func delete() async {
        do {
            try await environment.repository.delete(id: cardID)
            isDeleted = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "删除失败，请重试"
        }
    }

    func makeReviewViewModel() -> ReviewViewModel? {
        guard let card else { return nil }
        return ReviewViewModel(
            card: card,
            audit: audit,
            originalImageData: imageData,
            processedImageData: nil,
            environment: environment
        )
    }
}
