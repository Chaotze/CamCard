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
    @State private var cardPendingDeletion: BusinessCard?

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
                        Button("完成") { showRawText = false }
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
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heroHeader(card)
                imageSection

                if viewModel.imageUnavailable {
                    Label("名片图像不可用，文字信息仍可查看", systemImage: "photo.badge.exclamationmark")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("imageUnavailableLabel")
                }

                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("联系信息")
                    if let department = nonEmpty(card.department) {
                        fieldRow("部门", department, icon: "person.3.fill")
                    }
                    if !card.mobile.isEmpty {
                        fieldRow("手机", card.mobile.joined(separator: "\n"), icon: "iphone")
                    }
                    if !card.officePhone.isEmpty {
                        fieldRow("办公电话", card.officePhone.joined(separator: "\n"), icon: "phone.fill")
                    }
                    if !card.fax.isEmpty {
                        fieldRow("传真", card.fax.joined(separator: "\n"), icon: "printer.fill")
                    }
                    if !card.email.isEmpty {
                        fieldRow(
                            "Email",
                            card.email.enumerated().map { index, value in
                                index == 0 ? "\(value)（主）" : value
                            }.joined(separator: "\n"),
                            icon: "envelope.fill"
                        )
                    }
                    if let website = nonEmpty(card.website) {
                        fieldRow("网站", website, icon: "globe")
                    }
                    if let address = nonEmpty(card.address) {
                        fieldRow("地址", address, icon: "mappin.and.ellipse")
                    }
                    if let postalCode = nonEmpty(card.postalCode) {
                        fieldRow("邮编", postalCode, icon: "mailbox.fill")
                    }
                    if let notes = nonEmpty(card.notes) {
                        fieldRow("备注", notes, icon: "note.text")
                    }
                }
                .accessibilityIdentifier("detailFields")

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button {
                            exporter.export([card])
                        } label: {
                            Label("导出名片", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityIdentifier("detailExportButton")

                        Button {
                            showRawText = true
                        } label: {
                            Label("OCR 文本", systemImage: "doc.text.magnifyingglass")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityIdentifier("detailRawTextButton")
                    }

                    Button(role: .destructive) {
                        cardPendingDeletion = card
                    } label: {
                        Label("删除名片", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("detailDeleteButton")
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func heroHeader(_ card: BusinessCard) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(monogram(for: card.displayName))
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.accentColor)
                .frame(width: 84, height: 84)
                .background(Color.accentColor.opacity(0.12), in: Circle())
                .overlay(Circle().stroke(Color.accentColor.opacity(0.18), lineWidth: 1))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(card.displayName)
                    .font(.largeTitle.bold())
                    .lineLimit(2)
                let subtitle = [card.company, card.jobTitle]
                    .compactMap { nonEmpty($0) }
                    .joined(separator: " · ")
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                if !card.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(card.tags.prefix(4)), id: \.self) { tag in
                            Text(tag)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    private var imageSection: some View {
        Group {
            if let data = viewModel.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.14), radius: 16, y: 8)
                    .accessibilityLabel("名片图像")
            } else {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .frame(height: 180)
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

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(1.2)
    }

    private func fieldRow(_ label: String, _ value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(
                    Color.accentColor.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body.weight(.medium))
                    .textSelection(.enabled)
                    .accessibilityIdentifier("detailValue-\(label)")
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        )
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
