import SwiftUI

struct CardDetailView: View {
    @StateObject private var viewModel: CardDetailViewModel
    @StateObject private var exporter: ExportViewModel
    let environment: AppEnvironment
    let onChanged: () -> Void
    let autoEdit: Bool

    @Environment(\.dismiss) private var dismiss

    @State private var shareItem: ShareItem?
    @State private var showEdit = false
    @State private var didAutoEdit = false
    @State private var editingModel: ReviewViewModel?
    @State private var showRawText = false
    @State private var cardPendingDeletion: BusinessCard?

    init(
        cardID: UUID,
        environment: AppEnvironment,
        autoEdit: Bool = false,
        onChanged: @escaping () -> Void = {}
    ) {
        self.environment = environment
        self.onChanged = onChanged
        self.autoEdit = autoEdit
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
                    Button {
                        editingModel = viewModel.makeReviewViewModel()
                        showEdit = editingModel != nil
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel("编辑")
                    .accessibilityIdentifier("detailEditButton")
                }
            }
        }
        .task {
            await viewModel.load()
            if autoEdit, !didAutoEdit, viewModel.card != nil {
                didAutoEdit = true
                editingModel = viewModel.makeReviewViewModel()
                showEdit = editingModel != nil
            }
        }
        .navigationDestination(isPresented: $showEdit) {
            if let editingModel {
                ReviewView(
                    viewModel: editingModel,
                    onSaved: {
                        Task { await viewModel.load() }
                        onChanged()
                    }
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
                        Button {
                            showRawText = false
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .accessibilityLabel("完成")
                    }
                }
            }
        }
        .cardDeleteConfirmation(card: $cardPendingDeletion) { _ in
            Task { await viewModel.delete() }
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
        Form {
            Section {
                heroHeader(card)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                imageSection
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            }

            if viewModel.imageUnavailable {
                Section {
                    Label("名片图像不可用，文字信息仍可查看", systemImage: "photo.badge.exclamationmark")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("imageUnavailableLabel")
                }
            }

            Section("联系信息") {
                if let department = nonEmpty(card.department) {
                    fieldRow(.department, department)
                }
                if !card.mobile.isEmpty {
                    fieldRow(.mobile, card.mobile.joined(separator: "\n"))
                }
                if !card.officePhone.isEmpty {
                    fieldRow(.officePhone, card.officePhone.joined(separator: "\n"))
                }
                if !card.fax.isEmpty {
                    fieldRow(.fax, card.fax.joined(separator: "\n"))
                }
                if !card.email.isEmpty {
                    fieldRow(
                        .email,
                        card.email.enumerated().map { index, value in
                            index == 0 ? "\(value)（主）" : value
                        }.joined(separator: "\n")
                    )
                }
                if let website = nonEmpty(card.website) {
                    fieldRow(.website, website)
                }
                if let address = nonEmpty(card.address) {
                    fieldRow(.address, address)
                }
                if let postalCode = nonEmpty(card.postalCode) {
                    fieldRow(.postalCode, postalCode)
                }
                if let notes = nonEmpty(card.notes) {
                    fieldRow(.notes, notes)
                }
            }
            .accessibilityIdentifier("detailFields")

            Section {
                Button {
                    exporter.export([card])
                } label: {
                    Label("导出名片", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("detailExportButton")

                Button {
                    showRawText = true
                } label: {
                    Label("查看 OCR 原始文本", systemImage: "doc.text.magnifyingglass")
                }
                .accessibilityIdentifier("detailRawTextButton")
            }

            Section {
                Button(role: .destructive) {
                    cardPendingDeletion = card
                } label: {
                    Label("删除名片", systemImage: "trash")
                }
                .accessibilityIdentifier("detailDeleteButton")
            }
        }
    }

    private func heroHeader(_ card: BusinessCard) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(monogram(for: card.displayName))
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.accentColor)
                .frame(width: 68, height: 68)
                .background(Color.accentColor.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(card.displayName)
                    .font(.title.bold())
                    .lineLimit(2)
                let subtitle = [card.company, card.jobTitle]
                    .compactMap { nonEmpty($0) }
                    .joined(separator: " · ")
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !card.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(card.tags.prefix(4)), id: \.self) { tag in
                            Text(tag)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var imageSection: some View {
        Group {
            if let data = viewModel.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityLabel("名片图像")
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemFill))
                    .frame(height: 160)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.title2)
                            Text("图像不可用")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
            }
        }
    }

    private func fieldRow(_ field: ContactField, _ value: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: field.systemImage)
                .font(.body)
                .fontWeight(.light)
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(field.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("detailValue-\(field.displayName)")
            }
        }
        .padding(.vertical, 2)
    }

    private func monogram(for name: String) -> String {
        let tokens = name.split(separator: " ")
        if tokens.count > 1 {
            return tokens.prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
        }
        return String(name.prefix(1)).uppercased()
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
