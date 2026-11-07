import SwiftUI

struct CardDetailView: View {
    @StateObject private var viewModel: CardDetailViewModel
    @StateObject private var exporter: ExportViewModel
    let environment: AppEnvironment
    let onChanged: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var shareItem: ShareItem?
    @State private var showEdit = false
    @State private var editingModel: ReviewViewModel?
    @State private var showRawText = false
    @State private var showDeleteConfirmation = false

    init(cardID: UUID, environment: AppEnvironment, onChanged: @escaping () -> Void = {}) {
        self.environment = environment
        self.onChanged = onChanged
        _viewModel = StateObject(wrappedValue: CardDetailViewModel(cardID: cardID, environment: environment))
        _exporter = StateObject(wrappedValue: ExportViewModel(environment: environment))
    }

    var body: some View {
        Group {
            if let card = viewModel.card {
                detailContent(card)
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView("无法显示名片", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                ProgressView("正在加载…")
            }
        }
        .navigationTitle(viewModel.card?.displayName ?? "名片详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.card != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("编辑") {
                        editingModel = viewModel.makeReviewViewModel()
                        showEdit = editingModel != nil
                    }
                    .accessibilityIdentifier("detailEditButton")
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .navigationDestination(isPresented: $showEdit) {
            if let editingModel {
                ReviewView(
                    viewModel: editingModel,
                    onSaved: {
                        Task { await viewModel.load() }
                        onChanged()
                    },
                    onCancel: {}
                )
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(url: item.url)
        }
        .sheet(isPresented: $showRawText) {
            NavigationStack {
                ScrollView {
                    Text(viewModel.rawText.isEmpty ? "无 OCR 文本" : viewModel.rawText)
                        .font(.body.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                }
                .navigationTitle("OCR 原始文本")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { showRawText = false }
                    }
                }
            }
        }
        .confirmationDialog(
            "删除这张名片？",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                Task { await viewModel.delete() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后图像与识别记录将一并移除。")
        }
        .onChange(of: viewModel.isDeleted) { _, deleted in
            if deleted {
                onChanged()
                dismiss()
            }
        }
        .onChange(of: exporter.shareURL) { _, url in
            guard let url else { return }
            shareItem = ShareItem(url: url)
            exporter.clearShare()
        }
        .alert("提示", isPresented: alertBinding) {
            Button("好", role: .cancel) {
                viewModel.errorMessage = nil
                exporter.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? exporter.errorMessage ?? "")
        }
        .accessibilityIdentifier("detailRoot")
    }

    private func detailContent(_ card: BusinessCard) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                imageSection(card)

                if viewModel.imageUnavailable {
                    Label("原始图像不可用，文字信息仍可查看", systemImage: "photo.badge.exclamationmark")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("imageUnavailableLabel")
                }

                VStack(alignment: .leading, spacing: 12) {
                    if let name = nonEmpty(card.name) {
                        infoRow("姓名", name)
                    }
                    if let company = nonEmpty(card.company) {
                        infoRow("公司", company)
                    }
                    if let jobTitle = nonEmpty(card.jobTitle) {
                        infoRow("职位", jobTitle)
                    }
                    if let department = nonEmpty(card.department) {
                        infoRow("部门", department)
                    }
                    if !card.mobile.isEmpty {
                        infoRow("手机", card.mobile.joined(separator: "\n"))
                    }
                    if !card.officePhone.isEmpty {
                        infoRow("办公电话", card.officePhone.joined(separator: "\n"))
                    }
                    if !card.fax.isEmpty {
                        infoRow("传真", card.fax.joined(separator: "\n"))
                    }
                    if !card.email.isEmpty {
                        infoRow("Email", card.email.enumerated().map { index, value in
                            index == 0 ? "\(value)（主）" : value
                        }.joined(separator: "\n"))
                    }
                    if let website = nonEmpty(card.website) {
                        infoRow("网站", website)
                    }
                    if let address = nonEmpty(card.address) {
                        infoRow("地址", address)
                    }
                    if let postalCode = nonEmpty(card.postalCode) {
                        infoRow("邮编", postalCode)
                    }
                    if let notes = nonEmpty(card.notes) {
                        infoRow("备注", notes)
                    }
                    if !card.tags.isEmpty {
                        infoRow("标签", card.tags.joined(separator: "、"))
                    }
                }
                .accessibilityIdentifier("detailFields")

                VStack(spacing: 12) {
                    Button {
                        showRawText = true
                    } label: {
                        Label("查看 OCR 原始文本", systemImage: "doc.text.magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("detailRawTextButton")

                    Button {
                        exporter.export([card])
                    } label: {
                        Label("导出 vCard", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("detailExportButton")

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("删除名片", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("detailDeleteButton")
                }
                .padding(.top, 6)
            }
            .padding()
        }
    }

    @ViewBuilder
    private func imageSection(_ card: BusinessCard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.hasProcessedImage {
                Picker("图像", selection: $viewModel.showingOriginal) {
                    Text("原始图像").tag(true)
                    Text("处理后图像").tag(false)
                }
                .pickerStyle(.segmented)
            }
            let data = viewModel.showingOriginal ? viewModel.originalImageData : viewModel.processedImageData
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel(viewModel.showingOriginal ? "原始图像" : "处理后图像")
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.93))
                    .frame(height: 160)
                    .overlay(Text("图像不可用").foregroundStyle(.secondary))
            }
            if card.processedImage == nil {
                Text("该名片未生成校正图像")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .accessibilityIdentifier("detailValue-\(label)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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

#Preview {
    let environment = PreviewData.environment()
    NavigationStack {
        CardDetailView(cardID: PreviewData.cards[0].id, environment: environment)
    }
}
