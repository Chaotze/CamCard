import SwiftUI
import PhotosUI

struct CardHolderView: View {
    @ObservedObject var viewModel: CardHolderViewModel
    let environment: AppEnvironment

    @StateObject private var exporter: ExportViewModel
    @State private var shareItem: ShareItem?
    @State private var cardPendingDeletion: BusinessCard?
    @State private var cameraPresented = false
    @State private var photoPickerPresented = false
    @State private var photoItem: PhotosPickerItem?
    @State private var pendingCaptureData: Data?
    @State private var capturedImage: CapturedImage?
    @State private var detailRoute: CardDetailRoute?
    @State private var showBulkDeleteConfirmation = false
    @State private var cameraPermissionMessage: String?

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
        .toolbar {
            if !viewModel.emptyStateVisible {
                toolbarContent
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !viewModel.emptyStateVisible {
                FloatingSearchBar(
                    text: $viewModel.searchText,
                    onScan: startCamera,
                    onImport: { photoPickerPresented = true }
                )
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 0)
            }
        }
        .navigationDestination(item: $capturedImage) { item in
            CaptureFlowView(
                environment: environment,
                initialImageData: item.data,
                onSaved: { Task { await viewModel.reload() } }
            )
        }
        .navigationDestination(item: $detailRoute) { route in
            CardDetailView(
                cardID: route.id,
                environment: environment,
                autoEdit: route.autoEdit,
                onChanged: { Task { await viewModel.reload() } }
            )
        }
        .sheet(isPresented: $cameraPresented, onDismiss: {
            if let data = pendingCaptureData {
                pendingCaptureData = nil
                capturedImage = CapturedImage(data: data)
            }
        }) {
            CameraPicker(
                onImage: { data in
                    pendingCaptureData = data
                    cameraPresented = false
                },
                onCancel: {
                    pendingCaptureData = nil
                    cameraPresented = false
                }
            )
            .ignoresSafeArea()
            .interactiveDismissDisabled()
        }
        .photosPicker(
            isPresented: $photoPickerPresented,
            selection: $photoItem,
            matching: .images
        )
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    capturedImage = CapturedImage(data: data)
                } else {
                    viewModel.errorMessage = "图片无法读取，请重新选择"
                }
                photoItem = nil
            }
        }
        .alert("需要相机权限", isPresented: permissionAlertBinding) {
            Button("请求相机权限") {
                Task { await requestCameraAccess() }
            }
            Button("从相册导入") {
                cameraPermissionMessage = nil
                photoPickerPresented = true
            }
            Button("取消", role: .cancel) {
                cameraPermissionMessage = nil
            }
        } message: {
            Text(cameraPermissionMessage ?? "")
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
        .alert("删除所选名片？", isPresented: $showBulkDeleteConfirmation) {
            Button("删除", role: .destructive) {
                Task {
                    await viewModel.delete(viewModel.selectedCards)
                    viewModel.exitSelection()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("所选 \(viewModel.selectedIDs.count) 张名片、图像与识别记录将被永久删除，且无法恢复。")
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
            Button(action: startCamera) {
                Label("拍摄名片", systemImage: "camera")
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("captureButton")
            Button {
                photoPickerPresented = true
            } label: {
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
                            Button {
                                detailRoute = CardDetailRoute(id: card.id)
                            } label: {
                                cardRow(card)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("cardRow-\(card.id.uuidString)")
                        }
                    }
                    .contextMenu {
                        Button {
                            detailRoute = CardDetailRoute(id: card.id)
                        } label: {
                            Label("查看", systemImage: "eye")
                        }
                        Button {
                            detailRoute = CardDetailRoute(id: card.id, autoEdit: true)
                        } label: {
                            Label("编辑", systemImage: "square.and.pencil")
                        }
                        Button(role: .destructive) {
                            cardPendingDeletion = card
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            cardPendingDeletion = card
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        .tint(.red)
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
                    Button(role: .destructive) {
                        showBulkDeleteConfirmation = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                    .disabled(viewModel.selectedIDs.isEmpty)
                    .accessibilityIdentifier("bulkDeleteButton")
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

    private var permissionAlertBinding: Binding<Bool> {
        Binding(
            get: { cameraPermissionMessage != nil },
            set: { newValue in
                if !newValue { cameraPermissionMessage = nil }
            }
        )
    }

    private func startCamera() {
        switch environment.cameraPermission.status() {
        case .authorized:
            cameraPresented = true
        case .notDetermined:
            Task {
                if await environment.cameraPermission.request() == .authorized {
                    cameraPresented = true
                } else {
                    cameraPermissionMessage = "相机权限已被拒绝，请在系统设置中允许访问相机，或从相册导入。"
                }
            }
        case .denied, .restricted, .unavailable:
            cameraPermissionMessage = "无法使用相机。请在系统设置中允许相机访问，或从相册导入。"
        }
    }

    private func requestCameraAccess() async {
        cameraPermissionMessage = nil
        if await environment.cameraPermission.request() == .authorized {
            cameraPresented = true
        } else {
            viewModel.errorMessage = "相机权限未开启，请在系统设置中允许相机访问，或从相册导入。"
        }
    }
}

struct CapturedImage: Identifiable, Hashable {
    let id = UUID()
    let data: Data
}

struct CardDetailRoute: Identifiable, Hashable {
    let id: UUID
    var autoEdit = false
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
