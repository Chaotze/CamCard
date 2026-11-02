import SwiftUI

struct ReviewView: View {
    @StateObject private var viewModel: ReviewViewModel
    let onSaved: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    init(
        viewModel: ReviewViewModel,
        onSaved: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSaved = onSaved
        self.onCancel = onCancel
    }

    var body: some View {
        Form {
            Section("名片图像") {
                HStack(spacing: 12) {
                    imageThumbnail(viewModel.originalImageData, label: "原始图像")
                    if let processed = viewModel.processedImageData {
                        imageThumbnail(processed, label: "处理后图像")
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: "rectangle.slash")
                                .foregroundStyle(.secondary)
                            Text("未生成校正图像")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                Button {
                    viewModel.showRawText = true
                } label: {
                    Label("查看 OCR 原始文本", systemImage: "doc.text.magnifyingglass")
                }
                .accessibilityIdentifier("reviewRawTextButton")
            }

            Section("联系人") {
                fieldRow(.name)
                fieldRow(.company)
                fieldRow(.jobTitle)
                fieldRow(.website)
            }

            phoneSection("手机", field: .mobile)
            phoneSection("办公电话", field: .officePhone)
            phoneSection("传真", field: .fax)
            emailSection
            fieldRow(.address, multiline: true)
            Section("补充信息") {
                fieldRow(.department)
                fieldRow(.postalCode)
                fieldRow(.notes, multiline: true)
            }

            Section("标签") {
                ForEach(viewModel.tags, id: \.self) { tag in
                    HStack {
                        Text(tag)
                        Spacer()
                        Button(role: .destructive) {
                            viewModel.removeTag(tag)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .accessibilityLabel("删除标签 \(tag)")
                    }
                }
                HStack {
                    TextField("添加标签", text: $viewModel.newTag)
                        .accessibilityLabel("新标签")
                        .accessibilityIdentifier("reviewNewTagField")
                    Button("添加") {
                        viewModel.addTag()
                    }
                    .disabled(viewModel.newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .navigationTitle(viewModel.isEditing ? "编辑名片" : "校正名片")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    onCancel()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    Task { await viewModel.save() }
                }
                .disabled(viewModel.isSaving || !viewModel.hasAnyValue)
                .accessibilityIdentifier("reviewSaveButton")
            }
        }
        .alert("提示", isPresented: errorBinding) {
            Button("好", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $viewModel.showRawText) {
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
                        Button("完成") { viewModel.showRawText = false }
                    }
                }
            }
        }
        .onChange(of: viewModel.didSave) { _, saved in
            guard saved else { return }
            onSaved()
            dismiss()
        }
        .interactiveDismissDisabled(viewModel.isSaving)
    }

    private func imageThumbnail(_ data: Data?, label: String) -> some View {
        VStack(spacing: 4) {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(white: 0.92))
                    .frame(height: 90)
                    .overlay(Text("不可用").font(.caption).foregroundStyle(.secondary))
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func fieldRow(_ field: ContactField, multiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(field.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                sourceBadge(for: field)
                Spacer()
                if viewModel.restoreAvailable(for: field) {
                    Button("恢复") {
                        viewModel.restore(field)
                    }
                    .font(.caption)
                    .accessibilityLabel("恢复\(field.displayName)的解析原值")
                    .accessibilityIdentifier("restore-\(field.rawValue)")
                }
            }
            if multiline {
                TextEditor(text: textBinding(for: field))
                    .frame(minHeight: 70)
                    .accessibilityLabel(field.displayName)
                    .accessibilityIdentifier("reviewField-\(field.rawValue)")
            } else {
                TextField("未识别", text: textBinding(for: field))
                    .accessibilityLabel(field.displayName)
                    .accessibilityIdentifier("reviewField-\(field.rawValue)")
            }
        }
        .padding(.vertical, 2)
    }

    private func phoneSection(_ title: String, field: ContactField) -> some View {
        Section {
            ForEach(Array(viewModel.values(for: field).enumerated()), id: \.offset) { index, _ in
                HStack(spacing: 8) {
                    TextField("未识别", text: Binding(
                        get: { viewModel.value(field, at: index) },
                        set: { viewModel.setValue(field, at: index, value: $0) }
                    ))
                    .accessibilityLabel("\(title) \(index + 1)")
                    Menu {
                        ForEach([ContactField.mobile, .officePhone, .fax].filter { $0 != field }, id: \.self) { destination in
                            Button(destination.displayName) {
                                viewModel.movePhone(from: field, at: index, to: destination)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.left.arrow.right")
                    }
                    .accessibilityLabel("更改电话类别")
                    Button(role: .destructive) {
                        viewModel.removeValue(from: field, at: index)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .accessibilityLabel("删除\(title)")
                }
            }
            Button("添加\(title)") {
                viewModel.addValue(to: field)
            }
            .accessibilityIdentifier("add-\(field.rawValue)")
        } header: {
            HStack {
                Text(title)
                sourceBadge(for: field)
            }
        }
    }

    private var emailSection: some View {
        Section {
            ForEach(Array(viewModel.email.enumerated()), id: \.offset) { index, _ in
                HStack(spacing: 8) {
                    TextField("未识别", text: Binding(
                        get: { viewModel.value(.email, at: index) },
                        set: { viewModel.setValue(.email, at: index, value: $0) }
                    ))
                    .accessibilityLabel(index == 0 ? "Email 主地址" : "Email \(index + 1)")
                    if index == 0 {
                        Text("主")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    Button(role: .destructive) {
                        viewModel.removeValue(from: .email, at: index)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .accessibilityLabel("删除 Email")
                }
            }
            Button("添加 Email") {
                viewModel.addValue(to: .email)
            }
            .accessibilityIdentifier("add-email")
        } header: {
            HStack {
                Text("Email")
                sourceBadge(for: .email)
            }
        }
    }

    private func sourceBadge(for field: ContactField) -> some View {
        let source = viewModel.source(for: field)
        let color: Color
        switch source {
        case .parsed: color = .blue
        case .manual: color = .orange
        case .unrecognized: color = .secondary
        }
        return Text(source.rawValue)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .accessibilityIdentifier("source-\(field.rawValue)")
    }

    private func textBinding(for field: ContactField) -> Binding<String> {
        Binding(
            get: { viewModel.values(for: field).first ?? "" },
            set: { viewModel.setString(field, $0) }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue { viewModel.errorMessage = nil }
            }
        )
    }
}
