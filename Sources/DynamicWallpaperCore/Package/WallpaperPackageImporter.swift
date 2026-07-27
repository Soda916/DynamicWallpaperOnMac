import Foundation
import ImageIO
import AVFoundation

/// Handles import, validation, and GIF-to-HEVC video cache conversion for `.wallpaper` packages.
public final class WallpaperPackageImporter {
    public static let shared = WallpaperPackageImporter()

    private let fileManager = FileManager.default

    private init() {}

    /// Validates directory or package path containing metadata.json and media file.
    public func validatePackage(at url: URL) throws -> WallpaperMetadata {
        let metadataURL = url.appendingPathComponent("metadata.json")
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            throw NSError(domain: "WallpaperPackageImporter", code: 404, userInfo: [NSLocalizedDescriptionKey: "metadata.json missing in package"])
        }

        let data = try Data(contentsOf: metadataURL)
        let decoder = JSONDecoder()
        let metadata = try decoder.decode(WallpaperMetadata.self, from: data)

        let mediaURL = url.appendingPathComponent(metadata.mediaFileName)
        guard fileManager.fileExists(atPath: mediaURL.path) else {
            throw NSError(domain: "WallpaperPackageImporter", code: 404, userInfo: [NSLocalizedDescriptionKey: "Media file \(metadata.mediaFileName) missing in package"])
        }

        return metadata
    }

    /// Automatically converts GIF image to hardware-accelerated HEVC MP4 video cache upon first import.
    public func convertGIFToHEVCVideo(gifURL: URL, outputVideoURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let imageSource = CGImageSourceCreateWithURL(gifURL as CFURL, nil) else {
            completion(.failure(NSError(domain: "WallpaperPackageImporter", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to read GIF image source"])))
            return
        }

        let count = CGImageSourceGetCount(imageSource)
        guard count > 0 else {
            completion(.failure(NSError(domain: "WallpaperPackageImporter", code: 400, userInfo: [NSLocalizedDescriptionKey: "GIF contains 0 frames"])))
            return
        }

        guard let firstFrame = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            completion(.failure(NSError(domain: "WallpaperPackageImporter", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to decode first frame of GIF"])))
            return
        }

        let width = firstFrame.width
        let height = firstFrame.height

        try? fileManager.removeItem(at: outputVideoURL)

        do {
            let writer = try AVAssetWriter(outputURL: outputVideoURL, fileType: .mp4)
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.hevc,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height
            ]

            let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: nil)

            if writer.canAdd(writerInput) {
                writer.add(writerInput)
            } else {
                completion(.failure(NSError(domain: "WallpaperPackageImporter", code: 500, userInfo: [NSLocalizedDescriptionKey: "Cannot add AVAssetWriterInput"])))
                return
            }

            writer.startWriting()
            writer.startSession(atSourceTime: .zero)

            var frameTime = CMTime.zero
            let frameDuration = CMTime(value: 1, timescale: 30) // Default 30 FPS for converted GIF

            for i in 0..<count {
                if let cgImage = CGImageSourceCreateImageAtIndex(imageSource, i, nil) {
                    if let pixelBuffer = self.pixelBufferFromCGImage(cgImage: cgImage, width: width, height: height) {
                        while !writerInput.isReadyForMoreMediaData {
                            usleep(1000)
                        }
                        adaptor.append(pixelBuffer, withPresentationTime: frameTime)
                        frameTime = CMTimeAdd(frameTime, frameDuration)
                    }
                }
            }

            writerInput.markAsFinished()
            writer.finishWriting {
                if writer.status == .completed {
                    AppLogger.shared.info("WallpaperPackageImporter: Converted GIF to HEVC MP4 at \(outputVideoURL.path)")
                    completion(.success(outputVideoURL))
                } else {
                    completion(.failure(writer.error ?? NSError(domain: "WallpaperPackageImporter", code: 500, userInfo: [NSLocalizedDescriptionKey: "Asset writer failed"])))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    private func pixelBufferFromCGImage(cgImage: CGImage, width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let options: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            options as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        let pxdata = CVPixelBufferGetBaseAddress(buffer)

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: pxdata,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(buffer, [])
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
}
