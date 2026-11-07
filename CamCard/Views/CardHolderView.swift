import SwiftUI

struct CardHolderView: View {
    @ObservedObject var viewModel: CardHolderViewModel
    let environment: AppEnvironment

    @StateObject private var exporter: ExportViewModel
    @State private var shareItem: ShareItem?
    @State private var activeRoute: AppRoute?
    @State private var cardPendingDeletion: BusinessCard?

    init(viewModel: CardHolderViewModel, environment: AppEnvironment) {
        self.viewModel = viewModel
        self.environment = environment
        _exporter = StateObject(wrappedValue: ExportViewModel(environment: environment))
    }

    var body: some View {
        Group {
            if viewModel.emptyStateVisible {
                emptyState
            } else {
                cardList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("名片夹")
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingSearchBar(
                text: $viewModel.searchText,
                onScan: { activeRoute = .capture(photo: false) },
                onImport: { activeRoute = .capture(photo: true) }
            )
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 2)
        }
        .navigationDestination(item: $activeRoute) { route in
            AppRouteDestination(route: route, environment: environment) {
                Task { await viewModel.reload() }
            }
        }
        .alert("提示", isPresented: alertBinding) {
            Button("好", role: .cancel) {
                viewModel.errorMessage = nil
                exporter.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? exporter.errorMessage ?? "")
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(url: item.url)
        }
        .cardDeleteConfirmation(card: $cardPendingDeletion) { card in
            Task { await viewModel.delete(card) }
        }
        .onChange(of: exporter.shareURL) { _, url in
            guard let url else { return }
            shareItem = ShareItem(url: url)
            exporter.clearShare()
            viewModel.exitSelection()
        }
        .onAppear {
            Task { await viewModel.reload() }
        }
        .accessibilityIdentifier("cardHolderRoot")
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "person.crop.rectangle.stack")
                .font(.system(size: 54))
                .foregroundStyle(.tint)
            Text("还没有名片")
                .font(.title2.bold())
            Text("拍摄或导入一张名片，开始建立你的名片夹。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            NavigationLink(value: AppRoute.capture(photo: false)) {
                Label("拍摄名片", systemImage: "camera")
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("captureButton")
            NavigationLink(value: AppRoute.capture(photo: true)) {
                Label("从相册导入", systemImage: "photo")
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("importButton")
        }
        .padding(32)
        .accessibilityIdentifier("emptyCardHolder")
    }

    private var cardList: some View {
        List {
            if viewModel.noResultsVisible {
                ContentUnavailableView(
                    "无匹配结果",
                    systemImage: "magnifyingglass",
                    description: Text("没有名片符合当前搜索或标签筛选")
                )
                .accessibilityIdentifier("noResultsState")
                .listRowSeparator(.hidden)
            } else {
                ForEach(viewModel.filteredCards) { card in
                    Group {
                        if viewModel.isSelecting {
                            Button {
                                viewModel.toggleSelection(card.id)
                            } label: {
                                HStack {
                                    Image(systemName: viewModel.selectedIDs.contains(card.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(viewModel.selectedIDs.contains(card.id) ? Color.accentColor : .secondary)
                                    cardRow(card)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("cardRow-\(card.id.uuidString)")
                        } else {
                            NavigationLink(value: AppRoute.detail(card.id)) {
                                cardRow(card)
                            }
                            .accessibilityIdentifier("cardRow-\(card.id.uuidString)")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            cardPendingDeletion = card
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .contentMargins(.bottom, 60, for: .scrollContent)
    }

    private func cardRow(_ card: BusinessCard) -> some View {
        HStack(spacing: 12) {
            StoredThumbnail(card: card) {
                await viewModel.thumbnailData(for: card)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(card.displayName)
                    .font(.headline)
                let organization = [card.company, card.jobTitle]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                if !organization.isEmpty {
                    Text(organization)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let summary = card.summary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !card.tags.isEmpty {
                    Text(card.tags.joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.tint)
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 12) {
                if !viewModel.allTags.isEmpty {
                    Menu {
                        ForEach(viewModel.allTags, id: \.self) { tag in
                            Button {
                                viewModel.toggleTag(tag)
                            } label: {
                                if viewModel.selectedTags.contains(tag) {
                                    Label(tag, systemImage: "checkmark")
                                } else {
                                    Text(tag)
                                }
                            }
                        }
                        if !viewModel.selectedTags.isEmpty {
                            Button("清除标签筛选") {
                                viewModel.selectedTags.removeAll()
                            }
                        }
                    } label: {
                        Label("标签筛选", systemImage: "tag")
                    }
                    .accessibilityIdentifier("tagFilterButton")
                }
                Menu {
                    ForEach(CardSortOrder.allCases) { order in
                        Button {
                            viewModel.sortOrder = order
                        } label: {
                            if viewModel.sortOrder == order {
                                Label(order.displayName, systemImage: "checkmark")
                            } else {
                                Text(order.displayName)
                            }
                        }
                    }
                } label: {
                    Label("排序", systemImage: "arrow.up.arrow.down")
                }
                .accessibilityIdentifier("sortButton")
                if !viewModel.cards.isEmpty {
                    Button(viewModel.isSelecting ? "完成" : "选择") {
                        if viewModel.isSelecting {
                            viewModel.exitSelection()
                        } else {
                            viewModel.isSelecting = true
                        }
                    }
                    .accessibilityIdentifier("selectButton")
                }
                if viewModel.isSelecting {
                    Button("导出") {
                        exporter.export(viewModel.selectedCards)
                    }
                    .disabled(viewModel.selectedIDs.isEmpty)
                    .accessibilityIdentifier("exportButton")
                }
            }
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil || exporter.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.errorMessage = nil
                    exporter.errorMessage = nil
                }
            }
        )
    }
}

#Preview("名片夹") {
    let environment = PreviewData.environment()
    NavigationStack {
        CardHolderView(
            viewModel: CardHolderViewModel(environment: environment),
            environment: environment
        )
    }
}

#Preview("空名片夹") {
    let environment = PreviewData.emptyEnvironment()
    NavigationStack {
        CardHolderView(
            viewModel: CardHolderViewModel(environment: environment),
            environment: environment
        )
    }
}
