import UIKit
import CoreImage
import Vision

enum ImageProcessing {
    static let context = CIContext(options: nil)

    static func preparedJPEG(_ data: Data, maxDimension: CGFloat = 3000) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }
        let scale = min(1, maxDimension / max(sourceSize.width, sourceSize.height))
        let targetSize = CGSize(
            width: max(1, (sourceSize.width * scale).rounded()),
            height: max(1, (sourceSize.height * scale).rounded())
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let rendered = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return rendered.jpegData(compressionQuality: 0.9)
    }

    static func cgImage(from data: Data) -> CGImage? {
        UIImage(data: data)?.cgImage
    }

    static func uiImage(from data: Data) -> UIImage? {
        UIImage(data: data)
    }

    static func ciImage(from data: Data) -> CIImage? {
        guard let image = CIImage(data: data) else { return nil }
        return image.oriented(.up)
    }

    static func jpegData(from ciImage: CIImage, quality: CGFloat = 0.9) -> Data? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent, format: .RGBA8, colorSpace: colorSpace) else {
            return nil
        }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: quality)
    }

    static func sampleJPEG(text: String = "名片", size: CGSize = CGSize(width: 600, height: 380)) -> Data {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(white: 0.9, alpha: 1).setStroke()
            context.cgContext.setLineWidth(4)
            context.cgContext.stroke(CGRect(x: 16, y: 16, width: size.width - 32, height: size.height - 32))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 42, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            let bounds = (text as NSString).boundingRect(
                with: CGSize(width: size.width - 80, height: size.height - 80),
                options: [.usesLineFragmentOrigin],
                attributes: attributes,
                context: nil
            )
            (text as NSString).draw(
                with: CGRect(
                    x: 40,
                    y: (size.height - bounds.height) / 2,
                    width: size.width - 80,
                    height: bounds.height
                ),
                options: [.usesLineFragmentOrigin],
                attributes: attributes,
                context: nil
            )
        }
        return image.jpegData(compressionQuality: 0.9) ?? Data()
    }
}
