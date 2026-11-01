import Foundation
import Combine

@MainActor
final class CardDetailViewModel: ObservableObject {
    @Published private(set) var card: BusinessCard?
    @Published private(set) var audit: CardAudit?
    @Published private(set) var originalImageData: Data?
    @Published private(set) var processedImageData: Data?
    @Published private(set) var imageUnavailable = false
    @Published private(set) var isDeleted = false
    @Published var errorMessage: String?
    @Published var showingOriginal = true

    let cardID: UUID
    let environment: AppEnvironment

    init(cardID: UUID, environment: AppEnvironment) {
        self.cardID = cardID
        self.environment = environment
    }

    var rawText: String {
        audit?.ocrRecords.last?.rawText ?? ""
    }

    var hasProcessedImage: Bool {
        card?.processedImage != nil && processedImageData != nil
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
            originalImageData = try await environment.imageStore.read(found.originalImage)
            if let processed = found.processedImage {
                processedImageData = try await environment.imageStore.read(processed)
            } else {
                processedImageData = nil
            }
            if let data = originalImageData {
                imageUnavailable = ImageProcessing.uiImage(from: data) == nil
            } else {
                imageUnavailable = true
            }
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
            originalImageData: originalImageData,
            processedImageData: processedImageData,
            environment: environment
        )
    }
}
