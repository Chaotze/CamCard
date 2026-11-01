import Foundation
import Combine

enum CardSortOrder: String, CaseIterable, Identifiable {
    case newest
    case name
    case company

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .newest: return "创建时间"
        case .name: return "姓名"
        case .company: return "公司"
        }
    }
}

@MainActor
final class CardHolderViewModel: ObservableObject {
    @Published private(set) var cards: [BusinessCard] = []
    @Published var searchText = ""
    @Published var selectedTags: Set<String> = []
    @Published var sortOrder: CardSortOrder = .newest
    @Published var isSelecting = false
    @Published var selectedIDs: Set<UUID> = []
    @Published var errorMessage: String?
    @Published var isLoading = false

    let environment: AppEnvironment
    private var didBootstrap = false

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func bootstrap() async {
        guard !didBootstrap else {
            await reload()
            return
        }
        didBootstrap = true
        if environment.launchOptions.isUITest {
            try? await environment.repository.reset()
            try? await environment.imageStore.reset()
            await SeedData.installIfNeeded(environment: environment)
        }
        await reload()
    }

    func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let snapshot = try await environment.repository.load()
            cards = snapshot.cards
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "无法读取名片"
        }
    }

    var queryIsActive: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedTags.isEmpty
    }

    var filteredCards: [BusinessCard] {
        var result = cards
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter { $0.searchableText.lowercased().contains(query) }
        }
        if !selectedTags.isEmpty {
            let tags = Set(selectedTags.map { $0.lowercased() })
            result = result.filter { card in
                !card.tags.isEmpty && !tags.isDisjoint(with: Set(card.tags.map { $0.lowercased() }))
            }
        }
        return sorted(result)
    }

    var allTags: [String] {
        var seen = Set<String>()
        var tags: [String] = []
        for card in cards {
            for tag in card.tags {
                let key = tag.lowercased()
                if seen.insert(key).inserted {
                    tags.append(tag)
                }
            }
        }
        return tags.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var emptyStateVisible: Bool {
        cards.isEmpty
    }

    var noResultsVisible: Bool {
        !cards.isEmpty && filteredCards.isEmpty && queryIsActive
    }

    var selectedCards: [BusinessCard] {
        cards.filter { selectedIDs.contains($0.id) }
    }

    func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }

    func clearFilters() {
        searchText = ""
        selectedTags.removeAll()
    }

    func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    func exitSelection() {
        isSelecting = false
        selectedIDs.removeAll()
    }

    func thumbnailData(for card: BusinessCard) async -> Data? {
        try? await environment.imageStore.read(card.processedImage ?? card.originalImage)
    }

    private func sorted(_ input: [BusinessCard]) -> [BusinessCard] {
        let indexed = Array(input.enumerated())
        let sorted: [(offset: Int, element: BusinessCard)]
        switch sortOrder {
        case .newest:
            sorted = indexed.sorted { lhs, rhs in
                if lhs.element.createdAt == rhs.element.createdAt {
                    return lhs.offset < rhs.offset
                }
                return lhs.element.createdAt > rhs.element.createdAt
            }
        case .name:
            sorted = indexed.sorted { lhs, rhs in
                let left = lhs.element.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let right = rhs.element.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if left.isEmpty != right.isEmpty { return !left.isEmpty }
                let comparison = left.localizedStandardCompare(right)
                return comparison == .orderedSame ? lhs.offset < rhs.offset : comparison == .orderedAscending
            }
        case .company:
            sorted = indexed.sorted { lhs, rhs in
                let left = lhs.element.company?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let right = rhs.element.company?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if left.isEmpty != right.isEmpty { return !left.isEmpty }
                let comparison = left.localizedStandardCompare(right)
                return comparison == .orderedSame ? lhs.offset < rhs.offset : comparison == .orderedAscending
            }
        }
        return sorted.map(\.element)
    }
}
