#!/usr/bin/env swift
//
// frame_screenshots.swift
// Places simulator screenshots into the transparent screen cutout of a device mockup.
//
// Usage (from repository root):
//   swift docs/assets/scripts/frame_screenshots.swift
//   swift docs/assets/scripts/frame_screenshots.swift \
//     --mockup docs/assets/mockups/iphone-17-pro-silver-portrait.png \
//     --screenshots docs/assets/screenshots \
//     --out docs/assets/framed
//
// The screen rect is auto-detected as the largest transparent region that
// contains the mockup centre. Override it with --screen x,y,w,h if needed.
//

import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct Options {
    var mockup = "docs/assets/mockups/iphone-17-pro-silver-portrait.png"
    var screenshots = "docs/assets/screenshots"
    var output = "docs/assets/framed"
    var explicitScreen: CGRect?
}

func parseOptions() -> Options {
    var options = Options()
    var args = Array(CommandLine.arguments.dropFirst())
    while let flag = args.first {
        args.removeFirst()
        func value() -> String { args.isEmpty ? "" : args.removeFirst() }
        switch flag {
        case "--mockup": options.mockup = value()
        case "--screenshots": options.screenshots = value()
        case "--out": options.output = value()
        case "--screen":
            let parts = value().split(separator: ",").compactMap { Double($0) }
            if parts.count == 4 {
                options.explicitScreen = CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
            }
        default:
            FileHandle.standardError.write(Data("Unknown option: \(flag)\n".utf8))
            exit(2)
        }
    }
    return options
}

func loadRGBA(_ path: String) -> (width: Int, height: Int, bytes: [UInt8])? {
    guard let image = NSImage(contentsOfFile: path),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return nil
    }
    let width = cgImage.width
    let height = cgImage.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    guard let context = CGContext(
        data: &bytes,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    return (width, height, bytes)
}

/// Flood-fills the transparent screen cutout from the image centre and returns its bounds.
func detectScreenRect(width: Int, height: Int, bytes: [UInt8]) -> CGRect? {
    let startX = width / 2
    let startY = height / 2
    func isTransparent(_ x: Int, _ y: Int) -> Bool {
        bytes[(y * width + x) * 4 + 3] < 8
    }
    guard isTransparent(startX, startY) else { return nil }

    var visited = [Bool](repeating: false, count: width * height)
    var stack = [startY * width + startX]
    var minX = startX, maxX = startX, minY = startY, maxY = startY

    while let index = stack.popLast() {
        if visited[index] { continue }
        visited[index] = true
        let x = index % width
        let y = index / width
        guard isTransparent(x, y) else { continue }
        minX = min(minX, x); maxX = max(maxX, x)
        minY = min(minY, y); maxY = max(maxY, y)
        if x > 0 { stack.append(index - 1) }
        if x < width - 1 { stack.append(index + 1) }
        if y > 0 { stack.append(index - width) }
        if y < height - 1 { stack.append(index + width) }
    }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

func render(mockupPath: String, screenshotPath: String, outputPath: String, explicitScreen: CGRect?) throws {
    guard let mockup = NSImage(contentsOfFile: mockupPath),
          let screenshot = NSImage(contentsOfFile: screenshotPath),
          let mockupCG = mockup.cgImage(forProposedRect: nil, context: nil, hints: nil),
          let screenshotCG = screenshot.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw NSError(domain: "FrameScreenshots", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot read input images"])
    }

    let width = mockupCG.width
    let height = mockupCG.height
    let screen: CGRect
    if let explicitScreen {
        screen = explicitScreen
    } else {
        guard let loaded = loadRGBA(mockupPath),
              let detected = detectScreenRect(width: loaded.width, height: loaded.height, bytes: loaded.bytes) else {
            throw NSError(domain: "FrameScreenshots", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot detect the transparent screen cutout"])
        }
        screen = detected
    }

    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "FrameScreenshots", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot create bitmap context"])
    }

    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    // The detected rect uses top-left origin; Core Graphics draws from bottom-left.
    let drawRect = CGRect(
        x: screen.minX,
        y: CGFloat(height) - screen.maxY,
        width: screen.width,
        height: screen.height
    )
    context.draw(screenshotCG, in: drawRect)
    context.draw(mockupCG, in: CGRect(x: 0, y: 0, width: width, height: height))

    guard let output = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(
            URL(fileURLWithPath: outputPath) as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
          ) else {
        throw NSError(domain: "FrameScreenshots", code: 4, userInfo: [NSLocalizedDescriptionKey: "Cannot write output image"])
    }
    CGImageDestinationAddImage(destination, output, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "FrameScreenshots", code: 5, userInfo: [NSLocalizedDescriptionKey: "Cannot finalize output image"])
    }
}

let options = parseOptions()
let fileManager = FileManager.default
try fileManager.createDirectory(atPath: options.output, withIntermediateDirectories: true)

let screenshots = try fileManager.contentsOfDirectory(atPath: options.screenshots)
    .filter { $0.lowercased().hasSuffix(".png") }
    .sorted()

guard !screenshots.isEmpty else {
    FileHandle.standardError.write(Data("No PNG screenshots found in \(options.screenshots)\n".utf8))
    exit(1)
}

for name in screenshots {
    let input = "\(options.screenshots)/\(name)"
    let output = "\(options.output)/\(name)"
    do {
        try render(
            mockupPath: options.mockup,
            screenshotPath: input,
            outputPath: output,
            explicitScreen: options.explicitScreen
        )
        print("Framed \(name)")
    } catch {
        FileHandle.standardError.write(Data("Failed \(name): \(error.localizedDescription)\n".utf8))
        exit(1)
    }
}