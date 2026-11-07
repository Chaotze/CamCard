import SwiftUI
import PhotosUI

struct DetectionOverlay: View {
    let corners: [CGPoint]
    var color: Color = .green

    var body: some View {
        GeometryReader { geometry in
            if corners.count == 4 {
                Path { path in
                    let points = corners.map {
                        CGPoint(x: $0.x * geometry.size.width, y: $0.y * geometry.size.height)
                    }
                    path.move(to: points[0])
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                    path.closeSubpath()
                }
                .stroke(color, lineWidth: 3)
            }
        }
    }
}

struct StoredThumbnail: View {
    let card: BusinessCard
    let loader: () async -> Data?

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(white: 0.92)
                    Image(systemName: "person.crop.rectangle")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 56, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel("名片的处理后图像缩略图")
        .task(id: card.id) {
            if let data = await loader() {
                image = UIImage(data: data)
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (Data) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (Data) -> Void
        let onCancel: () -> Void

        init(onImage: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
            self.onImage = onImage
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.95) {
                onImage(data)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onCancel()
        }
    }
}

struct ManualCropView: View {
    let image: UIImage
    let initialCorners: [CGPoint]
    let onConfirm: ([CGPoint]) -> Void

    @State private var corners: [CGPoint]

    // Vision 返回的顺序是 左上、右上、左下、右下；绘制时按顺时针取点。
    private let displayOrder = [0, 1, 3, 2]

    init(image: UIImage, initialCorners: [CGPoint], onConfirm: @escaping ([CGPoint]) -> Void) {
        self.image = image
        self.initialCorners = initialCorners
        self.onConfirm = onConfirm
        let defaults = [
            CGPoint(x: 0.08, y: 0.16),
            CGPoint(x: 0.92, y: 0.16),
            CGPoint(x: 0.08, y: 0.84),
            CGPoint(x: 0.92, y: 0.84)
        ]
        _corners = State(initialValue: initialCorners.count == 4 ? initialCorners : defaults)
    }

    var body: some View {
        GeometryReader { geometry in
            let rect = fittedRect(in: geometry.size)
            ZStack {
                Color.black
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                dimMask(size: geometry.size, rect: rect)
                quadPath(in: rect)
                    .stroke(
                        Color.white.opacity(0.95),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 3)
                ForEach(displayOrder, id: \.self) { index in
                    handle(for: index, in: rect)
                }
            }
            .coordinateSpace(.named("cropSpace"))
            .overlay(alignment: .bottom) {
                confirmBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("框选名片")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var confirmBar: some View {
        VStack(spacing: 10) {
            Text("拖动四角，让边框贴合名片")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
            Button {
                onConfirm(corners)
            } label: {
                Label("下一步", systemImage: "arrow.right")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor, in: Capsule())
                    .shadow(color: Color.black.opacity(0.18), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("cropConfirmButton")
        }
    }

    private func dimMask(size: CGSize, rect: CGRect) -> some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: size))
            path.addPath(quadPath(in: rect))
        }
        .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
    }

    private func quadPath(in rect: CGRect) -> Path {
        let points = displayOrder.map { screenPoint(for: corners[$0], in: rect) }
        return Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
        }
    }

    private func handle(for index: Int, in rect: CGRect) -> some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 24, height: 24)
            Circle()
                .stroke(Color.accentColor, lineWidth: 2.5)
                .frame(width: 24, height: 24)
        }
        .shadow(color: Color.black.opacity(0.28), radius: 4, y: 2)
        .position(screenPoint(for: corners[index], in: rect))
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("cropSpace"))
                .onChanged { value in
                    let x = min(1, max(0, (value.location.x - rect.minX) / rect.width))
                    let y = min(1, max(0, (value.location.y - rect.minY) / rect.height))
                    corners[index] = CGPoint(x: x, y: y)
                }
        )
        .accessibilityLabel("名片角点 \(index + 1)")
    }

    private func screenPoint(for point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + point.x * rect.width,
            y: rect.minY + point.y * rect.height
        )
    }

    private func fittedRect(in size: CGSize) -> CGRect {
        guard image.size.width > 0, image.size.height > 0 else {
            return CGRect(origin: .zero, size: size)
        }
        let scale = min(size.width / image.size.width, size.height / image.size.height)
        let width = image.size.width * scale
        let height = image.size.height * scale
        return CGRect(
            x: (size.width - width) / 2,
            y: (size.height - height) / 2,
            width: width,
            height: height
        )
    }
}

struct CardDeleteConfirmationModifier: ViewModifier {
    @Binding var card: BusinessCard?
    let onDelete: (BusinessCard) -> Void

    func body(content: Content) -> some View {
        content.alert(
            "删除名片",
            isPresented: Binding(
                get: { card != nil },
                set: { if !$0 { card = nil } }
            ),
            presenting: card
        ) { target in
            Button("删除", role: .destructive) {
                card = nil
                onDelete(target)
            }
            Button("取消", role: .cancel) {
                card = nil
            }
        } message: { target in
            Text("「\(target.displayName)」的名片、图像与识别记录将被永久删除，且无法恢复。")
        }
    }
}

extension View {
    func cardDeleteConfirmation(
        card: Binding<BusinessCard?>,
        onDelete: @escaping (BusinessCard) -> Void
    ) -> some View {
        modifier(CardDeleteConfirmationModifier(card: card, onDelete: onDelete))
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

#Preview("检测框") {
    ZStack {
        Image(uiImage: UIImage(data: ImageProcessing.sampleJPEG(text: "名片"))!)
            .resizable()
            .scaledToFit()
        DetectionOverlay(corners: MockCardDetectionService.defaultCorners)
    }
    .padding()
}

#Preview("名片缩略图") {
    StoredThumbnail(card: PreviewData.cards[0]) {
        ImageProcessing.sampleJPEG(text: "名片")
    }
    .padding()
}

#Preview("手动框选") {
    NavigationStack {
        ManualCropView(
            image: UIImage(data: ImageProcessing.sampleJPEG(text: "名片原图"))!,
            initialCorners: MockCardDetectionService.defaultCorners,
            onConfirm: { _ in }
        )
    }
}
