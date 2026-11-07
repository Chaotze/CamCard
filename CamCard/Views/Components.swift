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

    @Environment(\.dismiss) private var dismiss
    @State private var corners: [CGPoint]

    init(image: UIImage, initialCorners: [CGPoint], onConfirm: @escaping ([CGPoint]) -> Void) {
        self.image = image
        self.initialCorners = initialCorners
        self.onConfirm = onConfirm
        let defaults = [
            CGPoint(x: 0.08, y: 0.18),
            CGPoint(x: 0.92, y: 0.18),
            CGPoint(x: 0.08, y: 0.82),
            CGPoint(x: 0.92, y: 0.82)
        ]
        _corners = State(initialValue: initialCorners.count == 4 ? initialCorners : defaults)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let rect = fittedRect(in: geometry.size)
                ZStack {
                    Color.black
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                    Path { path in
                        let points = corners.map {
                            CGPoint(
                                x: rect.minX + $0.x * rect.width,
                                y: rect.minY + $0.y * rect.height
                            )
                        }
                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                        path.closeSubpath()
                    }
                    .stroke(Color.green, lineWidth: 3)
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(Color.green)
                            .frame(width: 26, height: 26)
                            .position(
                                x: rect.minX + corners[index].x * rect.width,
                                y: rect.minY + corners[index].y * rect.height
                            )
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let x = min(1, max(0, (value.location.x - rect.minX) / rect.width))
                                        let y = min(1, max(0, (value.location.y - rect.minY) / rect.height))
                                        corners[index] = CGPoint(x: x, y: y)
                                    }
                            )
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("手动框选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("应用") {
                        onConfirm(corners)
                        dismiss()
                    }
                }
            }
        }
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
    ManualCropView(
        image: UIImage(data: ImageProcessing.sampleJPEG(text: "名片原图"))!,
        initialCorners: MockCardDetectionService.defaultCorners,
        onConfirm: { _ in }
    )
}
