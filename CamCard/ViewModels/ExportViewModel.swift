import Foundation
import Combine

@MainActor
final class ExportViewModel: ObservableObject {
    @Published var shareURL: URL?
    @Published var errorMessage: String?

    private let environment: AppEnvironment
    private let exporter = VCardExporter()

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func export(_ cards: [BusinessCard]) {
        guard !cards.isEmpty else {
            errorMessage = ExportError.emptySelection.localizedDescription
            return
        }
        errorMessage = nil
        shareURL = nil
        let content = exporter.export(cards)
        let fileName = exporter.fileName(for: cards, date: environment.clock.now())
        do {
            shareURL = try environment.exportWriter.write(content, fileName: fileName)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "导出失败，请稍后重试"
        }
    }

    func clearShare() {
        shareURL = nil
    }
}
