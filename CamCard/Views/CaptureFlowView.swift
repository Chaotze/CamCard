import SwiftUI
import PhotosUI
import UIKit

struct CaptureFlowView: View {
    @StateObject private var viewModel: CaptureFlowViewModel
    let environment: AppEnvironment
    let autoStartPhoto: Bool
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var photoItem: PhotosPickerItem?
    @State private var showManualCrop = false
    @State private var reviewModel: ReviewViewModel?
    @State private var didAutoStart = false

    init(
        environment: AppEnvironment,
        autoStartPhoto: Bool,
        onSaved: @escaping () -> Void
    ) {
        self.environment = environment
        self.autoStartPhoto = autoStartPhoto
        self.onSaved = onSaved
        _viewModel = StateObject(wrappedValue: CaptureFlowViewModel(environment: environment))
    }

    var body: some View {
        Group {
            if let reviewModel {
                ReviewView(
                    viewModel: reviewModel,
                    onSaved: {
                        onSaved()
                        dismiss()
                    },
                    onCancel: {
                        viewModel.cancel()
                        dismiss()
                    }
                )
            } else {
                captureContent
            }
        }
        .navigationTitle(reviewModel == nil ? "扫描名片" : "校正名片")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if reviewModel == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        viewModel.cancel()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            guard !didAutoStart else { return }
            didAutoStart = true
            if autoStartPhoto {
                viewModel.openPhotoPicker()
            } else {
                Task { await viewModel.openCamera() }
            }
        }
        .onChange(of: viewModel.isReadyForReview) { _, isReady in
            guard isReady, reviewModel == nil else { return }
            reviewModel = viewModel.makeReviewViewModel()
        }
        .sheet(isPresented: $viewModel.cameraPickerPresented) {
            CameraPicker(
                onImage: { data in
                    viewModel.cameraPickerPresented = false
                    Task { await viewModel.start(with: data) }
                },
                onCancel: {
                    viewModel.cameraPickerPresented = false
                    viewModel.cancel()
                    dismiss()
                }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showManualCrop) {
            if let data = viewModel.originalImageData,
               let image = UIImage(data: data) {
                ManualCropView(image: image, initialCorners: viewModel.corners) { corners in
                    showManualCrop = false
                    Task { await viewModel.applyManualCrop(corners: corners) }
                }
            }
        }
        .photosPicker(
            isPresented: $viewModel.photoPickerPresented,
            selection: $photoItem,
            matching: .images
        )
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await viewModel.start(with: data)
                } else {
                    viewModel.errorMessage = "图片无法读取，请重新选择"
                }
                photoItem = nil
            }
        }
        .alert("需要相机权限", isPresented: permissionAlertBinding) {
            Button("打开设置") { openSettings() }
            Button("从相册导入") {
                viewModel.cameraPermissionMessage = nil
                viewModel.openPhotoPicker()
            }
            Button("取消", role: .cancel) {
                viewModel.cameraPermissionMessage = nil
                viewModel.cancel()
                dismiss()
            }
        } message: {
            Text(viewModel.cameraPermissionMessage ?? "")
        }
        .alert("提示", isPresented: errorAlertBinding) {
            Button("好", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var captureContent: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let data = viewModel.originalImageData,
                   let image = UIImage(data: data) {
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        if viewModel.corners.count == 4 {
                            DetectionOverlay(corners: viewModel.corners)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .accessibilityIdentifier("capturePreview")
                }

                if viewModel.isBusy {
                    ProgressView(stateDescription)
                        .accessibilityIdentifier("processingIndicator")
                }

                switch viewModel.state {
                case .idle:
                    VStack(spacing: 12) {
                        Text("拍摄或导入一张名片")
                            .font(.headline)
                        Button {
                            Task { await viewModel.openCamera() }
                        } label: {
                            Label("拍摄名片", systemImage: "camera")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        Button {
                            viewModel.openPhotoPicker()
                        } label: {
                            Label("从相册导入", systemImage: "photo")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .accessibilityIdentifier("captureIdleState")
                case .detectionFailed:
                    VStack(spacing: 12) {
                        Label("未能检测到名片区域", systemImage: "exclamationmark.triangle")
                            .font(.headline)
                            .foregroundStyle(.orange)
                        Text(viewModel.detectionMessage ?? "可以重试检测、手动框选，或使用原图继续。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("detectionFailureMessage")
                        Button("重试检测") {
                            Task { await viewModel.retryDetection() }
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("retryDetectionButton")
                        Button("手动框选") {
                            showManualCrop = true
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("manualCropButton")
                        Button("使用原图继续") {
                            Task { await viewModel.continueWithOriginal() }
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("continueOriginalButton")
                        Button("重拍") { viewModel.retake() }
                        Button("取消", role: .cancel) {
                            viewModel.cancel()
                            dismiss()
                        }
                    }
                case .unrecognizable:
                    VStack(spacing: 12) {
                        Label("无法识别名片", systemImage: "text.viewfinder")
                            .font(.headline)
                            .foregroundStyle(.orange)
                        Text("没有识别到名片文字，请重拍或手动填写。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("重拍") { viewModel.retake() }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("retakeButton")
                        Button("手动填写") {
                            Task { await viewModel.proceedToManualEntry() }
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("manualEntryButton")
                        Button("取消", role: .cancel) {
                            viewModel.cancel()
                            dismiss()
                        }
                    }
                    .accessibilityIdentifier("unrecognizableState")
                case .detected, .ocrRunning, .ocrFinished, .parsing:
                    VStack(spacing: 10) {
                        Text("正在识别名片文字…")
                            .foregroundStyle(.secondary)
                        if viewModel.corners.count == 4 {
                            Text("已显示检测到的名片区域")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("detectedRegionLabel")
                        }
                        Button("重拍") { viewModel.retake() }
                            .buttonStyle(.bordered)
                    }
                case .captured, .detecting, .capturing:
                    Text("正在处理图像…")
                        .foregroundStyle(.secondary)
                case .readyForReview:
                    Text("准备校正")
                case .saving, .saved, .savingFailed:
                    Text("正在保存…")
                case .abandoned:
                    Text("已取消")
                }
            }
            .padding()
        }
        .accessibilityIdentifier("captureFlowRoot")
    }

    private var stateDescription: String {
        switch viewModel.state {
        case .detecting: return "正在检测名片区域…"
        case .ocrRunning: return "正在识别文字…"
        case .parsing: return "正在整理字段…"
        case .saving: return "正在保存…"
        default: return "正在处理…"
        }
    }

    private var permissionAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.cameraPermissionMessage != nil },
            set: { newValue in
                if !newValue { viewModel.cameraPermissionMessage = nil }
            }
        )
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue { viewModel.errorMessage = nil }
            }
        )
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
