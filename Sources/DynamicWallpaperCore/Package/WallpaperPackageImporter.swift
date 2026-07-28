import Foundation
import ImageIO
import AVFoundation

/// Handles import, validation, codec inspection, and automatic transcoding for unsupported formats (GIF, AV1, VP9).
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

    /// Inspects video codec to check if native VideoToolbox hardware decoding is supported or if transcoding is required.
    public func inspectVideoCodec(url: URL, completion: @escaping (Bool, String) -> Void) {
        let asset = AVURLAsset(url: url)
        Task {
            do {
                let tracks = try await asset.load(.tracks)
                guard let videoTrack = tracks.first(where: { $0.mediaType == .video }) else {
                    completion(false, "No video track found")
                    return
                }

                let formatDescriptions = try await videoTrack.load(.formatDescriptions)
                guard let firstDesc = formatDescriptions.first else {
                    completion(true, "Unknown format")
                    return
                }

                let subType = CMFormatDescriptionGetMediaSubType(firstDesc)
                let subTypeString = FourCharCodeToString(subType)

                AppLogger.shared.info("WallpaperPackageImporter: Inspected video codec subtype: '\(subTypeString)' for \(url.lastPathComponent)")

                // AV1 (av01) and VP9 (vp09 / vp9) require transcoding to HEVC with -tag:v hvc1
                if subTypeString == "av01" || subTypeString == "vp09" || subTypeString == "vp08" {
                    completion(false, subTypeString)
                } else {
                    completion(true, subTypeString)
                }
            } catch {
                AppLogger.shared.error("WallpaperPackageImporter: Failed to inspect video codec: \(error.localizedDescription)")
                completion(true, "Unknown")
            }
        }
    }

    /// Transcodes unsupported video format (e.g. AV1) to hardware-accelerated HEVC MP4 cache with Apple-required hvc1 tag.
    public func transcodeVideoToHEVC(inputURL: URL, outputVideoURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let ffmpegURL = FFmpegManager.shared.findFFmpegURL() else {
            AppLogger.shared.error("WallpaperPackageImporter: System FFmpeg binary not found")
            let err = NSError(domain: "WallpaperPackageImporter", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "FFmpeg binary not found on system. Please run '\(FFmpegManager.shared.homebrewInstallInstruction)' to enable AV1/VP9 transcoding."
            ])
            completion(.failure(err))
            return
        }

        try? fileManager.removeItem(at: outputVideoURL)

        let process = Process()
        process.executableURL = ffmpegURL
        process.arguments = [
            "-y",
            "-i", inputURL.path,
            "-c:v", "hevc_videotoolbox",
            "-tag:v", "hvc1",
            "-b:v", "2M",
            "-c:a", "aac",
            outputVideoURL.path
        ]

        let pipe = Pipe()
        process.standardError = pipe

        AppLogger.shared.info("WallpaperPackageImporter: Launching FFmpeg HEVC VideoToolbox (-tag:v hvc1) transcoding for \(inputURL.lastPathComponent)...")

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 && fileManager.fileExists(atPath: outputVideoURL.path) {
                AppLogger.shared.info("WallpaperPackageImporter: FFmpeg hvc1 transcoding complete: \(outputVideoURL.path)")
                completion(.success(outputVideoURL))
            } else {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: data, encoding: .utf8) ?? "Unknown error"
                AppLogger.shared.error("WallpaperPackageImporter: FFmpeg failed: \(errorOutput)")
                completion(.failure(NSError(domain: "WallpaperPackageImporter", code: 500, userInfo: [NSLocalizedDescriptionKey: "FFmpeg transcoding failed: \(errorOutput)"])))
            }
        } catch {
            completion(.failure(error))
        }
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
            let frameDuration = CMTime(value: 1, timescale: 30)

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

    private func FourCharCodeToString(_ code: FourCharCode) -> String {
        let bytes: [CChar] = [
            CChar((code >> 24) & 0xff),
            CChar((code >> 16) & 0xff),
            CChar((code >> 8) & 0xff),
            CChar(code & 0xff),
            0
        ]
        return String(cString: bytes)
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
