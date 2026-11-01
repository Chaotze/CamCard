import Foundation
import Vision

protocol OCRService {
    func recognize(imageData: Data, source: OCRSource) async -> OCRRecord
}

final class VisionOCRService: OCRService {
    func recognize(imageData: Data, source: OCRSource) async -> OCRRecord {
        let prepared = ImageProcessing.preparedJPEG(imageData) ?? imageData
        guard let cgImage = ImageProcessing.cgImage(from: prepared) else {
            return OCRRecord(
                sequence: 1,
                source: source,
                status: .failed,
                failureReason: "图片无法读取"
            )
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return OCRRecord(
                sequence: 1,
                source: source,
                status: .failed,
                failureReason: "文字识别失败"
            )
        }
        let observations = (request.results ?? []).sorted { lhs, rhs in
            if abs(lhs.boundingBox.maxY - rhs.boundingBox.maxY) > 0.02 {
                return lhs.boundingBox.maxY > rhs.boundingBox.maxY
            }
            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }
        var lines: [OCRLine] = []
        for (index, observation) in observations.enumerated() {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let box = observation.boundingBox
            lines.append(
                OCRLine(
                    text: candidate.string,
                    confidence: Double(candidate.confidence),
                    x: Double(box.minX),
                    y: Double(1 - box.maxY),
                    width: Double(box.width),
                    height: Double(box.height),
                    sequence: index
                )
            )
        }
        return OCRRecord(
            sequence: 1,
            source: source,
            status: lines.isEmpty ? .empty : .success,
            lines: lines
        )
    }
}

final class MockOCRService: OCRService {
    private let record: OCRRecord

    init(lines: [String], source: OCRSource = .processed, status: OCRStatus? = nil) {
        let ocrLines = lines.enumerated().map { index, text in
            OCRLine(
                id: Self.stableID(index),
                text: text,
                confidence: 0.95,
                x: 0.1,
                y: max(0.02, 0.9 - Double(index) * 0.08),
                width: 0.7,
                height: 0.05,
                sequence: index
            )
        }
        self.record = OCRRecord(
            id: Self.stableID(99),
            sequence: 1,
            source: source,
            status: status ?? (lines.isEmpty ? .empty : .success),
            lines: ocrLines,
            failureReason: lines.isEmpty ? "未识别到文字" : nil,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    convenience init(fixture: String?) {
        self.init(lines: Self.fixtureLines(fixture))
    }

    func recognize(imageData: Data, source: OCRSource) async -> OCRRecord {
        var result = record
        result.source = source
        return result
    }

    static func fixtureLines(_ name: String?) -> [String] {
        switch name {
        case "blank":
            return []
        case "multiphone":
            return [
                "李四",
                "云帆设计有限公司",
                "设计总监",
                "手机：139 0013 9000",
                "Mobile: 137 0013 7000",
                "Office：021-6666 8888",
                "电话：021-6666 9999",
                "Fax：021-6666 7777",
                "Email：lisi@yunfan.com",
                "邮箱：lisi.work@yunfan.com",
                "网址：www.yunfan.com",
                "地址：上海市浦东新区世纪大道100号",
                "部门：设计部",
                "邮编：200120"
            ]
        case "ambiguous":
            return [
                "Apple",
                "iPhone",
                "张三",
                "手机：13800138000",
                "Email：zhangsan@apple.com"
            ]
        case "missing":
            return [
                "王五",
                "手机：13600136000"
            ]
        case "mixed":
            return [
                "张伟 Zhang Wei",
                "Nova Robotics Inc.",
                "Senior Engineer",
                "Mobile: +86 138 0013 8000",
                "Email: zhang.wei@novarobotics.com",
                "Web: www.novarobotics.com",
                "Address: 88 Jianguo Road, Chaoyang District, Beijing"
            ]
        default:
            return [
                "张三",
                "星河科技有限公司",
                "高级工程师",
                "手机：138 0013 8000",
                "Office：010-8888 6666",
                "Fax：010-8888 7777",
                "邮箱：zhangsan@xinghe.com",
                "网址：www.xinghe.com",
                "地址：北京市朝阳区建国路88号",
                "邮编：100022"
            ]
        }
    }

    private static func stableID(_ index: Int) -> UUID {
        let suffix = String(format: "%012d", index)
        return UUID(uuidString: "00000000-0000-0000-0000-\(suffix)") ?? UUID()
    }
}
