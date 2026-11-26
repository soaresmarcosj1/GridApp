// GridApp — Copyright (C) 2026 Marcos (soaresmarcosj1)
// Licensed under the GNU General Public License v3.0 (GPL-3.0-or-later).
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import AVFoundation
import CoreMedia
import AppKit

enum VideoProcessorError: LocalizedError {
    case invalidVideo
    case durationZero
    case extractionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidVideo:
            return "Não foi possível abrir o arquivo de vídeo. Instale o FFmpeg para suportar formatos adicionais (MKV, AVI, WebM)."
        case .durationZero:
            return "A duração do vídeo é inválida ou zero."
        case .extractionFailed(let msg):
            return "Erro ao extrair frames: \(msg)"
        }
    }
}

actor ProgressCounter {
    private var completed: Int = 0
    private let total: Int

    init(total: Int) {
        self.total = max(total, 1)
    }

    func increment() -> Double {
        completed += 1
        return Double(completed) / Double(total)
    }
}

actor VideoProcessor {
    static let shared = VideoProcessor()

    nonisolated static var ffmpegPath: String? {
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    nonisolated static var ffprobePath: String? {
        let candidates = [
            "/opt/homebrew/bin/ffprobe",
            "/usr/local/bin/ffprobe",
            "/usr/bin/ffprobe"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func loadMetadata(for url: URL) async throws -> VideoMetadata {
        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
        let fileName = url.lastPathComponent
        let ext = url.pathExtension.uppercased()

        let options: [String: Any] = [
            AVURLAssetPreferPreciseDurationAndTimingKey: false
        ]
        let asset = AVURLAsset(url: url, options: options)

        if let videoTracks = try? await asset.loadTracks(withMediaType: .video),
           let videoTrack = videoTracks.first,
           let durationCM = try? await asset.load(.duration) {
            let durationSeconds = CMTimeGetSeconds(durationCM)
            if durationSeconds > 0 && durationSeconds.isFinite {
                async let naturalSizeTask = videoTrack.load(.naturalSize)
                async let transformTask = videoTrack.load(.preferredTransform)
                async let fpsTask = videoTrack.load(.nominalFrameRate)
                async let descTask = videoTrack.load(.formatDescriptions)
                async let videoBitrateTask = videoTrack.load(.estimatedDataRate)
                async let audioTracksTask = asset.loadTracks(withMediaType: .audio)

                let naturalSize = (try? await naturalSizeTask) ?? .zero
                let transform = (try? await transformTask) ?? .identity
                let transformedSize = naturalSize.applying(transform)
                let width = Int(abs(transformedSize.width).rounded())
                let height = Int(abs(transformedSize.height).rounded())
                let fps = Double((try? await fpsTask) ?? 0)
                let videoBitrate = Int64((try? await videoBitrateTask) ?? 0)

                var codecName = "Desconhecido"
                var colorDepthInfo = "YUV 4:2:0 • 8-bit"
                if let descriptions = try? await descTask,
                   let firstDesc = descriptions.first {
                    let subType = CMFormatDescriptionGetMediaSubType(firstDesc)
                    codecName = fourCCToString(subType)
                    if subType == kCMVideoCodecType_HEVCWithAlpha || codecName.contains("10") {
                        colorDepthInfo = "YUV 4:2:0 • 10-bit"
                    }
                    if let extDict = CMFormatDescriptionGetExtensions(firstDesc) as? [String: Any] {
                        if let depth = extDict["BitsPerComponent"] as? Int {
                            colorDepthInfo = "YUV • \(depth)-bit"
                        } else if let primaries = extDict[kCMFormatDescriptionExtension_ColorPrimaries as String] as? String {
                            colorDepthInfo = "Color: \(primaries)"
                        }
                    }
                }

                // Extrair informações de áudio da primeira faixa de áudio
                var audioCodec = "Sem Áudio"
                var audioSampleRateHz = 0
                var audioChannels = 0
                var audioBitrateBps: Int64 = 0

                if let audioTracks = try? await audioTracksTask,
                   let firstAudio = audioTracks.first {
                    if let aBitrate = try? await firstAudio.load(.estimatedDataRate) {
                        audioBitrateBps = Int64(aBitrate)
                    }
                    if let aDescs = try? await firstAudio.load(.formatDescriptions),
                       let aDesc = aDescs.first {
                        let aSub = CMFormatDescriptionGetMediaSubType(aDesc)
                        audioCodec = audioFourCCToString(aSub)
                        if let basic = CMAudioFormatDescriptionGetStreamBasicDescription(aDesc)?.pointee {
                            audioSampleRateHz = Int(basic.mSampleRate.rounded())
                            audioChannels = Int(basic.mChannelsPerFrame)
                        }
                    }
                }

                let totalBitrate = Int64((Double(fileSize) * 8.0) / max(durationSeconds, 1.0))

                return VideoMetadata(
                    fileName: fileName,
                    containerFormat: ext.isEmpty ? "MOV/MP4" : ext,
                    fileSizeBytes: fileSize,
                    durationSeconds: durationSeconds,
                    width: max(width, 1),
                    height: max(height, 1),
                    codec: codecName,
                    frameRate: fps,
                    totalBitrateBps: totalBitrate,
                    videoBitrateBps: videoBitrate > 0 ? videoBitrate : totalBitrate,
                    colorDepthInfo: colorDepthInfo,
                    audioCodec: audioCodec,
                    audioSampleRateHz: audioSampleRateHz,
                    audioChannels: audioChannels,
                    audioBitrateBps: audioBitrateBps,
                    usesFFmpeg: false
                )
            }
        }

        if let ffprobe = Self.ffprobePath {
            return try await loadMetadataViaFFprobe(url: url, ffprobePath: ffprobe, fileName: fileName, fileSize: fileSize)
        }

        throw VideoProcessorError.invalidVideo
    }

    private func loadMetadataViaFFprobe(url: URL, ffprobePath: String, fileName: String, fileSize: Int64) async throws -> VideoMetadata {
        return try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ffprobePath)
            process.arguments = [
                "-v", "error",
                "-analyzeduration", "2000000",
                "-probesize", "2000000",
                "-show_entries", "stream=codec_type,width,height,codec_name,profile,pix_fmt,r_frame_rate,bit_rate,sample_rate,channels,duration:format=format_name,duration,bit_rate",
                "-of", "json",
                url.path
            ]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard process.terminationStatus == 0,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw VideoProcessorError.invalidVideo
            }

            let streams = (json["streams"] as? [[String: Any]]) ?? []
            let videoStream = streams.first { ($0["codec_type"] as? String) == "video" } ?? streams.first
            let audioStream = streams.first { ($0["codec_type"] as? String) == "audio" }
            let format = json["format"] as? [String: Any]

            let width = (videoStream?["width"] as? Int) ?? 1920
            let height = (videoStream?["height"] as? Int) ?? 1080
            let codecRaw = ((videoStream?["codec_name"] as? String) ?? "video").uppercased()
            let profile = (videoStream?["profile"] as? String) ?? ""
            let codec = profile.isEmpty ? codecRaw : "\(codecRaw) (\(profile))"
            let pixFmt = ((videoStream?["pix_fmt"] as? String) ?? "yuv420p").uppercased()

            var duration = 0.0
            if let streamDurStr = videoStream?["duration"] as? String, let d = Double(streamDurStr) {
                duration = d
            } else if let formatDurStr = format?["duration"] as? String, let d = Double(formatDurStr) {
                duration = d
            }

            var fps = 0.0
            if let rateStr = videoStream?["r_frame_rate"] as? String {
                let parts = rateStr.split(separator: "/")
                if parts.count == 2, let num = Double(parts[0]), let den = Double(parts[1]), den > 0 {
                    fps = num / den
                } else if let direct = Double(rateStr) {
                    fps = direct
                }
            }

            let videoBitrate = Int64((videoStream?["bit_rate"] as? String) ?? "") ?? 0
            let totalBitrate = Int64((format?["bit_rate"] as? String) ?? "") ?? Int64((Double(fileSize) * 8.0) / max(duration, 1.0))

            var audioCodec = "Sem Áudio"
            var audioSampleRateHz = 0
            var audioChannels = 0
            var audioBitrateBps: Int64 = 0

            if let aStream = audioStream {
                audioCodec = ((aStream["codec_name"] as? String) ?? "Áudio").uppercased()
                audioSampleRateHz = Int((aStream["sample_rate"] as? String) ?? "") ?? 0
                audioChannels = (aStream["channels"] as? Int) ?? 0
                audioBitrateBps = Int64((aStream["bit_rate"] as? String) ?? "") ?? 0
            }

            guard duration > 0 else {
                throw VideoProcessorError.durationZero
            }

            let ext = url.pathExtension.uppercased()
            return VideoMetadata(
                fileName: fileName,
                containerFormat: ext.isEmpty ? "MKV/Vídeo" : ext,
                fileSizeBytes: fileSize,
                durationSeconds: duration,
                width: width,
                height: height,
                codec: codec,
                frameRate: fps,
                totalBitrateBps: totalBitrate,
                videoBitrateBps: videoBitrate > 0 ? videoBitrate : totalBitrate,
                colorDepthInfo: pixFmt,
                audioCodec: audioCodec,
                audioSampleRateHz: audioSampleRateHz,
                audioChannels: audioChannels,
                audioBitrateBps: audioBitrateBps,
                usesFFmpeg: true
            )
        }.value
    }

    func calculateDefaultTimestamps(duration: Double, count: Int) -> [Double] {
        guard count > 0, duration > 0 else { return [] }
        let step = duration / Double(count + 1)
        return (1...count).map { Double($0) * step }
    }

    func extractFrames(
        for url: URL,
        metadata: VideoMetadata,
        timestamps: [Double],
        maxThumbWidth: CGFloat = 960,
        speed: ProcessingSpeed = .ultraFast,
        onProgress: @Sendable @escaping (Double) -> Void
    ) async throws -> [CapturedFrame] {
        if !metadata.usesFFmpeg {
            do {
                return try await extractFramesViaAVFoundation(
                    url: url,
                    timestamps: timestamps,
                    maxThumbWidth: maxThumbWidth,
                    speed: speed,
                    onProgress: onProgress
                )
            } catch {
                if let ffmpeg = Self.ffmpegPath {
                    return try await extractFramesViaFFmpegParallel(
                        url: url,
                        ffmpegPath: ffmpeg,
                        timestamps: timestamps,
                        maxThumbWidth: Int(maxThumbWidth),
                        speed: speed,
                        onProgress: onProgress
                    )
                }
                throw error
            }
        } else if let ffmpeg = Self.ffmpegPath {
            return try await extractFramesViaFFmpegParallel(
                url: url,
                ffmpegPath: ffmpeg,
                timestamps: timestamps,
                maxThumbWidth: Int(maxThumbWidth),
                speed: speed,
                onProgress: onProgress
            )
        } else {
            throw VideoProcessorError.invalidVideo
        }
    }

    func extractSingleFrame(
        for url: URL,
        metadata: VideoMetadata,
        timestamp: Double,
        maxThumbWidth: CGFloat = 960
    ) async throws -> NSImage {
        if !metadata.usesFFmpeg {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: maxThumbWidth, height: maxThumbWidth)
            generator.requestedTimeToleranceBefore = CMTime(seconds: 0.05, preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)

            let cmTime = CMTime(seconds: timestamp, preferredTimescale: 600)
            if let (cgImage, _) = try? await generator.image(at: cmTime) {
                return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            }
        }

        if let ffmpeg = Self.ffmpegPath {
            if let img = try? Self.runSingleFFmpegFrame(
                url: url,
                ffmpegPath: ffmpeg,
                timestamp: timestamp,
                maxThumbWidth: Int(maxThumbWidth),
                speed: .precise
            ) {
                return img
            }
        }

        throw VideoProcessorError.extractionFailed("Não foi possível capturar o frame em \(TimeFormatter.format(seconds: timestamp)).")
    }

    private func extractFramesViaAVFoundation(
        url: URL,
        timestamps: [Double],
        maxThumbWidth: CGFloat,
        speed: ProcessingSpeed,
        onProgress: @Sendable @escaping (Double) -> Void
    ) async throws -> [CapturedFrame] {
        guard !timestamps.isEmpty else { return [] }

        let preferPreciseTiming = (speed == .precise)
        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: preferPreciseTiming
        ])
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxThumbWidth, height: maxThumbWidth)

        let tolerance = CMTime(seconds: speed.timeToleranceSeconds, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance

        let cmTimes = timestamps.map { CMTime(seconds: $0, preferredTimescale: 600) }
        let counter = ProgressCounter(total: timestamps.count)

        var framesByRequestedTime: [(requested: Double, frame: CapturedFrame)] = []
        framesByRequestedTime.reserveCapacity(timestamps.count)

        for await result in generator.images(for: cmTimes) {
            let reqSec = CMTimeGetSeconds(result.requestedTime)
            switch result {
            case .success(requestedTime: _, image: let cgImage, actualTime: let actualTime):
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                let actualSec = CMTimeGetSeconds(actualTime)
                let displaySec = (speed == .ultraFast) ? reqSec : (actualSec.isFinite ? actualSec : reqSec)
                let frame = CapturedFrame(
                    index: 0,
                    timestampSeconds: displaySec,
                    image: nsImage
                )
                framesByRequestedTime.append((requested: reqSec, frame: frame))
            case .failure(requestedTime: _, error: _):
                break
            }
            let currentProgress = await counter.increment()
            onProgress(currentProgress)
        }

        guard !framesByRequestedTime.isEmpty else {
            throw VideoProcessorError.extractionFailed("Nenhum frame pôde ser extraído pelo AVFoundation.")
        }

        framesByRequestedTime.sort { $0.requested < $1.requested }
        return framesByRequestedTime.enumerated().map { idx, item in
            var f = item.frame
            f.index = idx
            return f
        }
    }

    private func extractFramesViaFFmpegParallel(
        url: URL,
        ffmpegPath: String,
        timestamps: [Double],
        maxThumbWidth: Int,
        speed: ProcessingSpeed,
        onProgress: @Sendable @escaping (Double) -> Void
    ) async throws -> [CapturedFrame] {
        guard !timestamps.isEmpty else { return [] }

        let maxConcurrent = speed.maxConcurrentFFmpegJobs
        let counter = ProgressCounter(total: timestamps.count)

        return try await withThrowingTaskGroup(of: (Int, CapturedFrame).self) { group in
            var nextIndex = 0
            let total = timestamps.count

            while nextIndex < min(maxConcurrent, total) {
                let currentIndex = nextIndex
                let ts = timestamps[currentIndex]
                nextIndex += 1

                group.addTask {
                    let img = try Self.runSingleFFmpegFrame(
                        url: url,
                        ffmpegPath: ffmpegPath,
                        timestamp: ts,
                        maxThumbWidth: maxThumbWidth,
                        speed: speed
                    )
                    let progress = await counter.increment()
                    onProgress(progress)
                    return (
                        currentIndex,
                        CapturedFrame(index: currentIndex, timestampSeconds: ts, image: img)
                    )
                }
            }

            var collected: [(Int, CapturedFrame)] = []
            collected.reserveCapacity(total)

            for try await item in group {
                collected.append(item)

                if nextIndex < total {
                    let currentIndex = nextIndex
                    let ts = timestamps[currentIndex]
                    nextIndex += 1

                    group.addTask {
                        let img = try Self.runSingleFFmpegFrame(
                            url: url,
                            ffmpegPath: ffmpegPath,
                            timestamp: ts,
                            maxThumbWidth: maxThumbWidth,
                            speed: speed
                        )
                        let progress = await counter.increment()
                        onProgress(progress)
                        return (
                            currentIndex,
                            CapturedFrame(index: currentIndex, timestampSeconds: ts, image: img)
                        )
                    }
                }
            }

            collected.sort { $0.0 < $1.0 }
            return collected.map { $0.1 }
        }
    }

    nonisolated private static func runSingleFFmpegFrame(
        url: URL,
        ffmpegPath: String,
        timestamp: Double,
        maxThumbWidth: Int,
        speed: ProcessingSpeed
    ) throws -> NSImage {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        let timeStr = String(format: "%.3f", max(0, timestamp))

        var args: [String] = [
            "-hide_banner",
            "-loglevel", "error",
            "-hwaccel", "auto"
        ]

        switch speed {
        case .ultraFast:
            args += [
                "-skip_frame", "nokey",
                "-ss", timeStr,
                "-i", url.path,
                "-frames:v", "1",
                "-vf", "scale='min(\(maxThumbWidth),iw)':-1:flags=fast_bilinear",
                "-f", "image2pipe",
                "-vcodec", "mjpeg",
                "-q:v", "3",
                "-"
            ]
        case .balanced:
            args += [
                "-ss", timeStr,
                "-i", url.path,
                "-frames:v", "1",
                "-vf", "scale='min(\(maxThumbWidth),iw)':-1:flags=bilinear",
                "-f", "image2pipe",
                "-vcodec", "mjpeg",
                "-q:v", "2",
                "-"
            ]
        case .precise:
            args += [
                "-ss", timeStr,
                "-i", url.path,
                "-frames:v", "1",
                "-vf", "scale='min(\(maxThumbWidth),iw)':-1:flags=lanczos",
                "-f", "image2pipe",
                "-vcodec", "png",
                "-"
            ]
        }

        process.arguments = args

        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = Pipe()

        try process.run()
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if let image = NSImage(data: data) {
            return image
        }

        if speed == .ultraFast {
            return try runSingleFFmpegFrame(
                url: url,
                ffmpegPath: ffmpegPath,
                timestamp: timestamp,
                maxThumbWidth: maxThumbWidth,
                speed: .balanced
            )
        }

        throw VideoProcessorError.extractionFailed("FFmpeg não retornou imagem válida.")
    }

    private func fourCCToString(_ code: FourCharCode) -> String {
        let bytes: [CChar] = [
            CChar((code >> 24) & 0xff),
            CChar((code >> 16) & 0xff),
            CChar((code >> 8) & 0xff),
            CChar(code & 0xff),
            0
        ]
        let raw = String(cString: bytes).trimmingCharacters(in: .whitespaces)
        switch raw.lowercased() {
        case "avc1": return "H.264 / AVC1"
        case "hvc1", "hev1": return "HEVC / H.265"
        case "vp09": return "VP9"
        case "av01": return "AV1"
        case "apch", "apcn", "apcs", "apco", "ap4h": return "Apple ProRes"
        default: return raw.isEmpty ? "Vídeo" : raw.uppercased()
        }
    }

    private func audioFourCCToString(_ code: FourCharCode) -> String {
        switch code {
        case kAudioFormatMPEG4AAC, kAudioFormatMPEG4AAC_HE, kAudioFormatMPEG4AAC_HE_V2:
            return "AAC"
        case kAudioFormatLinearPCM:
            return "PCM"
        case kAudioFormatAC3:
            return "Dolby AC-3"
        case kAudioFormatEnhancedAC3:
            return "Dolby Digital Plus (E-AC-3)"
        case kAudioFormatFLAC:
            return "FLAC"
        case kAudioFormatOpus:
            return "Opus"
        case kAudioFormatAppleLossless:
            return "ALAC"
        case kAudioFormatMPEGLayer3:
            return "MP3"
        default:
            let bytes: [CChar] = [
                CChar((code >> 24) & 0xff),
                CChar((code >> 16) & 0xff),
                CChar((code >> 8) & 0xff),
                CChar(code & 0xff),
                0
            ]
            let raw = String(cString: bytes).trimmingCharacters(in: .whitespaces)
            return raw.isEmpty ? "Áudio" : raw.uppercased()
        }
    }
}
