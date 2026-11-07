import SwiftUI
import PhotosUI
import UIKit

struct CaptureFlowView: View {
    @StateObject private var viewModel: CaptureFlowViewModel
    let initialImageData: Data
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reviewModel: ReviewViewModel?
    @State private var didStart = false
    @State private var photoItem: PhotosPickerItem?

    init(
        environment: AppEnvironment,
        initialImageData: Data,
        onSaved: @escaping () -> Void
    ) {
        self.initialImageData = initialImageData
        self.onSaved = onSaved
        _viewModel = StateObject(wrappedValue: CaptureFlowViewModel(environment: environment))
    }

    var body: some View {
        Group {
            if let reviewModel {
                ReviewView(viewModel: reviewModel) {
                    onSaved()
                }
            } else if viewModel.state == .unrecognizable {
                unrecognizableContent
                    .navigationTitle("无法识别名片")
            } else if viewModel.isAwaitingCrop, let image = cropImage {
                ManualCropView(image: image, initialCorners: viewModel.corners) { corners in
                    Task { await viewModel.applyManualCrop(corners: corners) }
                }
            } else {
                processingContent
                    .navigationTitle("扫描名片")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !didStart else { return }
            didStart = true
            await viewModel.start(with: initialImageData)
        }        .onChange(of: viewModel.isReadyForReview) { _, isReady in
            guard isReady, reviewModel == nil else { return }
            reviewModel = viewModel.makeReviewViewModel()
        }
        .alert("提示", isPresented: errorAlertBinding) {
            Button("好", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
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
            .interactiveDismissDisabled()
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
        .onChange(of: viewModel.photoPickerPresented) { _, presented in
            guard !presented, photoItem == nil, viewModel.originalImageData == nil else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                if photoItem == nil, viewModel.originalImageData == nil, !viewModel.isAwaitingCrop {
                    viewModel.cancel()
                    dismiss()
                }
            }
        }
    }

    private var cropImage: UIImage? {
        viewModel.originalImageData.flatMap { UIImage(data: $0) }
    }

    private var processingContent: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            if let image = cropImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .opacity(0.16)
                    .blur(radius: 2)
                    .allowsHitTesting(false)
            }
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text(stateDescription)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("captureFlowRoot")
    }

    private var unrecognizableContent: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let image = cropImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                }

                Label("无法识别名片", systemImage: "text.viewfinder")
                    .font(.title3.bold())
                    .foregroundStyle(.orange)

                Text("没有识别到名片文字，请重新拍摄或手动填写。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    viewModel.retake()
                } label: {
                    Label("重新拍摄", systemImage: "camera.rotate")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("retakeButton")

                Button {
                    Task { await viewModel.proceedToManualEntry() }
                } label: {
                    Label("手动填写", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("manualEntryButton")
            }
            .padding(24)
        }
    }

    private var stateDescription: String {
        switch viewModel.state {
        case .detecting: return "正在检测名片区域…"
        case .ocrRunning: return "正在识别文字…"
        case .parsing: return "正在整理字段…"
        case .saving: return "正在保存…"
        default: return viewModel.isBusy ? "正在处理…" : "正在准备…"
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue { viewModel.errorMessage = nil }
            }
        )
    }
}

#Preview {
    let environment = PreviewData.environment()
    NavigationStack {
        CaptureFlowView(
            environment: environment,
            initialImageData: ImageProcessing.sampleJPEG(text: "名片"),
            onSaved: {}
        )
    }
}