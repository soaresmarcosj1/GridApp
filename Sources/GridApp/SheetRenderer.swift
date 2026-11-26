import Foundation
import AppKit
import SwiftUI
import ImageIO
import UniformTypeIdentifiers

struct SheetRenderOutput {
    let image: NSImage
    let hitBoxes: [RenderedFrameHitBox]
}

enum SheetRenderer {
    @MainActor
    static func renderContactSheet(
        metadata: VideoMetadata,
        frames: [CapturedFrame],
        settings: GridSettings
    ) -> SheetRenderOutput? {
        guard !frames.isEmpty else { return nil }

        let totalWidth = CGFloat(max(settings.outputWidth, 640))
        let cols = max(settings.columns, 1)
        let rows = max(Int(ceil(Double(frames.count) / Double(cols))), 1)
        let outerPad = settings.outerPadding
        let spacing = settings.spacing
        let scaleFactor = totalWidth / 1920.0

        let aspect = CGFloat(metadata.width) / CGFloat(max(metadata.height, 1))
        let safeVideoAspect = (aspect.isFinite && aspect > 0.1) ? aspect : (16.0 / 9.0)

        // Preparar linhas e altura real do cabeçalho técnico com base no tamanho de fonte e espaçamento de linhas configurados
        let headerLines = buildHeaderLines(metadata: metadata, settings: settings)
        let titleFontSize = max(settings.headerTitleFontSize, 12) * scaleFactor
        let bodyFontSize = max(settings.headerBodyFontSize, 9) * scaleFactor
        let lineSpacing = max(settings.headerLineSpacing, 0) * scaleFactor

        let titleFont = NSFont.systemFont(ofSize: titleFontSize, weight: .bold)
        let bodyFont = NSFont.monospacedDigitSystemFont(ofSize: bodyFontSize, weight: .medium)

        var calculatedHeaderBoxHeight: CGFloat = 0
        if settings.showHeader && !headerLines.isEmpty {
            let verticalInnerPad = 24.0 * scaleFactor
            var linesTotalH: CGFloat = 0
            for (idx, line) in headerLines.enumerated() {
                let f = (idx == 0) ? titleFont : bodyFont
                let h = NSAttributedString(string: line, attributes: [.font: f]).size().height
                linesTotalH += h
                if idx == 0 && headerLines.count > 1 {
                    linesTotalH += max(lineSpacing * 1.6, 10.0 * scaleFactor)
                } else if idx < headerLines.count - 1 {
                    linesTotalH += lineSpacing
                }
            }
            calculatedHeaderBoxHeight = ceil(linesTotalH + verticalInnerPad)
        }

        let headerBottomGap: CGFloat = (settings.showHeader && !headerLines.isEmpty)
            ? (max(settings.headerBottomSpacing, 0) * scaleFactor)
            : 0
        let headerSectionHeight = calculatedHeaderBoxHeight + headerBottomGap

        // Calcular dimensões da folha e da grade conforme o layout pré-definido (Auto, 16:9, 9:16, 4:5, 5:4, 1:1)
        // e a proporção escolhida para cada miniatura (Adaptar para Ocupar Folha, Original do Vídeo, 16:9, 4:3, 1:1)
        let maxAvailGridW = max(totalWidth - (outerPad * 2), 100)
        var cellWidth: CGFloat
        var cellHeight: CGFloat
        let totalHeight: CGFloat
        let gridOriginX: CGFloat
        let gridTopY: CGFloat

        if let targetSheetRatio = settings.sheetAspectPreset.aspectRatio {
            // Proporção fixa escolhida para a folha (ex: 4:5, 16:9, 1:1, 9:16, 5:4)
            let fixedHeight = ceil(totalWidth / targetSheetRatio)
            let maxAvailGridH = max(fixedHeight - (outerPad * 2) - headerSectionHeight, 120)

            if let fixedThumbAspect = settings.thumbnailAspectMode.fixedCellAspectRatio(videoAspect: safeVideoAspect) {
                // Miniaturas com proporção pré-definida (Vídeo, 16:9, 4:3, 1:1) centralizadas na folha
                let candidateCellWByWidth = (maxAvailGridW - spacing * CGFloat(cols - 1)) / CGFloat(cols)
                let candidateCellHByWidth = candidateCellWByWidth / fixedThumbAspect
                let totalGridHIfWidthBound = candidateCellHByWidth * CGFloat(rows) + spacing * CGFloat(rows - 1)

                if totalGridHIfWidthBound <= maxAvailGridH {
                    cellWidth = max(candidateCellWByWidth, 24)
                    cellHeight = max(candidateCellHByWidth, 24)
                } else {
                    cellHeight = max((maxAvailGridH - spacing * CGFloat(rows - 1)) / CGFloat(rows), 24)
                    cellWidth = max(cellHeight * fixedThumbAspect, 24)
                }

                totalHeight = max(fixedHeight, ceil((outerPad * 2) + headerSectionHeight + (cellHeight * CGFloat(rows)) + (spacing * CGFloat(rows - 1))))
                let actualGridW = (cellWidth * CGFloat(cols)) + (spacing * CGFloat(cols - 1))
                let actualGridH = (cellHeight * CGFloat(rows)) + (spacing * CGFloat(rows - 1))
                let remainingH = totalHeight - (outerPad * 2) - headerSectionHeight

                gridOriginX = outerPad + max((maxAvailGridW - actualGridW) / 2.0, 0)
                gridTopY = totalHeight - outerPad - headerSectionHeight - max((remainingH - actualGridH) / 2.0, 0)
            } else {
                // Modo "Adaptar (Ocupar Folha)": adapta a largura e a altura de cada imagem para que o grid ocupe 100% da área útil da folha
                totalHeight = fixedHeight
                cellWidth = max((maxAvailGridW - spacing * CGFloat(cols - 1)) / CGFloat(cols), 24)
                cellHeight = max((maxAvailGridH - spacing * CGFloat(rows - 1)) / CGFloat(rows), 24)
                gridOriginX = outerPad
                gridTopY = totalHeight - outerPad - headerSectionHeight
            }
        } else {
            // Modo de Folha Automático (Dinâmico conforme a quantidade de linhas)
            let thumbAspect = settings.thumbnailAspectMode.fixedCellAspectRatio(videoAspect: safeVideoAspect) ?? safeVideoAspect
            cellWidth = max((maxAvailGridW - (spacing * CGFloat(cols - 1))) / CGFloat(cols), 32)
            cellHeight = cellWidth / thumbAspect
            let gridHeight = (CGFloat(rows) * cellHeight) + (CGFloat(max(rows - 1, 0)) * spacing)
            totalHeight = ceil((outerPad * 2) + headerSectionHeight + gridHeight)
            gridOriginX = outerPad
            gridTopY = totalHeight - outerPad - headerSectionHeight
        }

        let widthInt = Int(totalWidth)
        let heightInt = Int(totalHeight)

        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: widthInt,
            pixelsHigh: heightInt,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = context
        let cg = context.cgContext
        cg.interpolationQuality = .high

        let bgNSColor = settings.backgroundRGBA.nsColor
        bgNSColor.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: totalWidth, height: totalHeight)).fill()

        let textNSColor = settings.textRGBA.nsColor

        // Desenhar Cabeçalho Técnico Multi-Linhas com Tipografia Configurável
        if settings.showHeader && !headerLines.isEmpty {
            let headerBoxY = totalHeight - outerPad - calculatedHeaderBoxHeight
            let headerBoxRect = NSRect(
                x: outerPad,
                y: headerBoxY,
                width: totalWidth - (outerPad * 2),
                height: calculatedHeaderBoxHeight
            )

            if settings.showHeaderCardBackground {
                textNSColor.withAlphaComponent(0.05).setFill()
                let boxRadius = max(settings.cornerRadius * scaleFactor, 8.0 * scaleFactor)
                let boxPath = NSBezierPath(roundedRect: headerBoxRect, xRadius: boxRadius, yRadius: boxRadius)
                boxPath.fill()

                textNSColor.withAlphaComponent(0.12).setStroke()
                boxPath.lineWidth = max(1.0 * scaleFactor, 0.5)
                boxPath.stroke()
            }

            let innerPadX = settings.showHeaderCardBackground ? (18.0 * scaleFactor) : (4.0 * scaleFactor)
            var currentTopY = headerBoxRect.maxY - (12.0 * scaleFactor)

            for (idx, line) in headerLines.enumerated() {
                let isTitle = (idx == 0)
                let font = isTitle ? titleFont : bodyFont
                let color = isTitle ? textNSColor : textNSColor.withAlphaComponent(0.84)

                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineBreakMode = .byTruncatingTail
                paragraphStyle.alignment = settings.headerTextAlignment.nsTextAlignment

                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: paragraphStyle
                ]
                let attrStr = NSAttributedString(string: line, attributes: attrs)
                let size = attrStr.size()
                currentTopY -= size.height

                let drawRect = NSRect(
                    x: headerBoxRect.minX + innerPadX,
                    y: currentTopY,
                    width: headerBoxRect.width - (innerPadX * 2),
                    height: size.height + (2.0 * scaleFactor)
                )
                attrStr.draw(in: drawRect)

                if isTitle && headerLines.count > 1 {
                    let dividerGap = max(lineSpacing * 0.8, 5.0 * scaleFactor)
                    currentTopY -= dividerGap
                    textNSColor.withAlphaComponent(0.10).setStroke()
                    let sep = NSBezierPath()
                    sep.move(to: NSPoint(x: headerBoxRect.minX + innerPadX, y: currentTopY))
                    sep.line(to: NSPoint(x: headerBoxRect.maxX - innerPadX, y: currentTopY))
                    sep.lineWidth = max(1.0 * scaleFactor, 0.5)
                    sep.stroke()
                    currentTopY -= dividerGap
                } else {
                    currentTopY -= lineSpacing
                }
            }
        }

        // Desenhar Grade de Frames e registrar hitBoxes normalizados (origem no topo-esquerdo)
        var hitBoxes: [RenderedFrameHitBox] = []
        hitBoxes.reserveCapacity(frames.count)

        for (index, frame) in frames.enumerated() {
            let row = index / cols
            let col = index % cols

            let cellX = gridOriginX + CGFloat(col) * (cellWidth + spacing)
            let cellY = gridTopY - CGFloat(row + 1) * cellHeight - CGFloat(row) * spacing
            let cellRect = NSRect(x: cellX, y: cellY, width: cellWidth, height: cellHeight)
            let radius = settings.cornerRadius * scaleFactor

            let topDownY = totalHeight - cellRect.maxY
            let normRect = CGRect(
                x: cellX / totalWidth,
                y: topDownY / totalHeight,
                width: cellWidth / totalWidth,
                height: cellHeight / totalHeight
            )
            hitBoxes.append(
                RenderedFrameHitBox(
                    frameID: frame.id,
                    index: index,
                    normalizedRect: normRect,
                    normalizedCornerRadius: radius / totalWidth
                )
            )

            if settings.shadowRadius > 0 {
                cg.saveGState()
                let shadow = NSShadow()
                shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
                shadow.shadowOffset = NSSize(width: 0, height: -2 * scaleFactor)
                shadow.shadowBlurRadius = settings.shadowRadius * scaleFactor
                shadow.set()

                NSColor.black.setFill()
                NSBezierPath(roundedRect: cellRect, xRadius: radius, yRadius: radius).fill()
                cg.restoreGState()
            }

            cg.saveGState()
            let clipPath = NSBezierPath(roundedRect: cellRect, xRadius: radius, yRadius: radius)
            clipPath.addClip()

            if let nsImage = frame.image {
                drawAspectFill(image: nsImage, in: cellRect)
            } else {
                NSColor.darkGray.setFill()
                cellRect.fill()
            }

            if settings.showTimestamps {
                drawTimestampBadge(
                    text: frame.formattedTimestamp,
                    in: cellRect,
                    position: settings.timestampPosition,
                    fontSize: settings.timestampFontSize * scaleFactor,
                    scaleFactor: scaleFactor
                )
            }

            cg.restoreGState()

            NSColor.white.withAlphaComponent(0.12).setStroke()
            let borderPath = NSBezierPath(roundedRect: cellRect, xRadius: radius, yRadius: radius)
            borderPath.lineWidth = max(1.0 * scaleFactor, 0.5)
            borderPath.stroke()
        }

        NSGraphicsContext.restoreGraphicsState()

        let finalImage = NSImage(size: NSSize(width: widthInt, height: heightInt))
        finalImage.addRepresentation(bitmapRep)
        return SheetRenderOutput(image: finalImage, hitBoxes: hitBoxes)
    }

    private static func buildHeaderLines(metadata: VideoMetadata, settings: GridSettings) -> [String] {
        var lines: [String] = []
        let trimmedCustom = settings.customTitle.trimmingCharacters(in: .whitespaces)

        if !trimmedCustom.isEmpty {
            lines.append(trimmedCustom)
        } else if settings.showFileName {
            lines.append(metadata.fileName)
        } else {
            lines.append("Resumo Técnico do Vídeo")
        }

        var fileLineParts: [String] = []
        if !trimmedCustom.isEmpty && settings.showFileName {
            fileLineParts.append("Arquivo: \(metadata.fileName)")
        }
        fileLineParts.append("Formato: \(metadata.containerFormat)")
        if settings.showFileSize {
            fileLineParts.append("Tamanho: \(metadata.formattedFileSize)")
        }
        if settings.showDuration {
            fileLineParts.append("Duração: \(metadata.formattedDuration)")
        }
        if !fileLineParts.isEmpty {
            lines.append(fileLineParts.joined(separator: "   •   "))
        }

        var videoLineParts: [String] = []
        if settings.showResolution {
            videoLineParts.append("Vídeo: \(metadata.formattedResolution)")
        }
        if settings.showCodecAndFPS {
            videoLineParts.append("Codec: \(metadata.codec)")
            videoLineParts.append("Taxa de Quadros: \(metadata.formattedFPS)")
        }
        if settings.showBitrateAndColor {
            videoLineParts.append("Bitrate: \(metadata.formattedVideoBitrate)")
            videoLineParts.append("Cor: \(metadata.colorDepthInfo)")
        }
        if !videoLineParts.isEmpty {
            lines.append(videoLineParts.joined(separator: "   •   "))
        }

        var bottomLineParts: [String] = []
        if settings.showAudioInfo {
            bottomLineParts.append("Áudio: \(metadata.formattedAudioSummary)")
        }
        let rows = Int(ceil(Double(settings.frameCount) / Double(max(settings.columns, 1))))
        let intervalSec = metadata.durationSeconds / Double(max(settings.frameCount + 1, 1))
        let layoutLabel = settings.sheetAspectPreset == .auto ? "Dinâmico" : settings.sheetAspectPreset.shortTitle
        bottomLineParts.append("Grade: \(settings.columns)×\(rows) (\(settings.frameCount) capturas • Layout \(layoutLabel) • Intervalo ~\(TimeFormatter.format(seconds: intervalSec)))")

        if !bottomLineParts.isEmpty {
            lines.append(bottomLineParts.joined(separator: "   •   "))
        }

        return lines
    }

    private static func drawAspectFill(image: NSImage, in rect: NSRect) {
        let imgSize = image.size
        guard imgSize.width > 0 && imgSize.height > 0 else { return }

        let widthRatio = rect.width / imgSize.width
        let heightRatio = rect.height / imgSize.height
        let scale = max(widthRatio, heightRatio)

        let scaledWidth = imgSize.width * scale
        let scaledHeight = imgSize.height * scale
        let drawX = rect.origin.x + (rect.width - scaledWidth) / 2.0
        let drawY = rect.origin.y + (rect.height - scaledHeight) / 2.0
        let drawRect = NSRect(x: drawX, y: drawY, width: scaledWidth, height: scaledHeight)

        image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    private static func drawTimestampBadge(
        text: String,
        in cellRect: NSRect,
        position: TimestampPosition,
        fontSize: CGFloat,
        scaleFactor: CGFloat
    ) {
        let font = NSFont.monospacedDigitSystemFont(ofSize: max(fontSize, 9), weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let textSize = attrStr.size()

        let padH = 7.0 * scaleFactor
        let padV = 3.5 * scaleFactor
        let margin = 8.0 * scaleFactor

        let badgeWidth = textSize.width + (padH * 2)
        let badgeHeight = textSize.height + (padV * 2)

        let badgeX: CGFloat
        let badgeY: CGFloat

        switch position {
        case .bottomRight:
            badgeX = cellRect.maxX - badgeWidth - margin
            badgeY = cellRect.minY + margin
        case .bottomLeft:
            badgeX = cellRect.minX + margin
            badgeY = cellRect.minY + margin
        case .topRight:
            badgeX = cellRect.maxX - badgeWidth - margin
            badgeY = cellRect.maxY - badgeHeight - margin
        case .topLeft:
            badgeX = cellRect.minX + margin
            badgeY = cellRect.maxY - badgeHeight - margin
        }

        let badgeRect = NSRect(x: badgeX, y: badgeY, width: badgeWidth, height: badgeHeight)
        NSColor.black.withAlphaComponent(0.68).setFill()
        NSBezierPath(roundedRect: badgeRect, xRadius: 4.5 * scaleFactor, yRadius: 4.5 * scaleFactor).fill()

        attrStr.draw(at: NSPoint(x: badgeX + padH, y: badgeY + padV))
    }

    static func exportImage(
        _ image: NSImage,
        to destinationURL: URL,
        format: ExportFormat,
        quality: Double
    ) throws {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "SheetRenderer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Falha ao converter imagem para exportação."])
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)

        switch format {
        case .jpeg:
            guard let data = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
                throw NSError(domain: "SheetRenderer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Falha ao gerar arquivo JPEG."])
            }
            try data.write(to: destinationURL)

        case .png:
            guard let data = bitmapRep.representation(using: .png, properties: [:]) else {
                throw NSError(domain: "SheetRenderer", code: 3, userInfo: [NSLocalizedDescriptionKey: "Falha ao gerar arquivo PNG."])
            }
            try data.write(to: destinationURL)

        case .tiff:
            guard let data = bitmapRep.representation(using: .tiff, properties: [:]) else {
                throw NSError(domain: "SheetRenderer", code: 4, userInfo: [NSLocalizedDescriptionKey: "Falha ao gerar arquivo TIFF."])
            }
            try data.write(to: destinationURL)

        case .webp:
            if let data = encodeWebPViaImageIO(cgImage: cgImage, quality: quality) {
                try data.write(to: destinationURL)
            } else if let ffmpeg = VideoProcessor.ffmpegPath,
                      let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                try encodeWebPViaFFmpeg(pngData: pngData, destinationURL: destinationURL, quality: quality, ffmpegPath: ffmpeg)
            } else {
                throw NSError(domain: "SheetRenderer", code: 5, userInfo: [NSLocalizedDescriptionKey: "Para exportar em WebP, certifique-se de que o FFmpeg está instalado."])
            }
        }
    }

    private static func encodeWebPViaImageIO(cgImage: CGImage, quality: Double) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.webP.identifier as CFString, 1, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(dest, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    private static func encodeWebPViaFFmpeg(pngData: Data, destinationURL: URL, quality: Double, ffmpegPath: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        let qValue = Int((quality * 100).rounded())
        process.arguments = [
            "-y",
            "-f", "image2pipe",
            "-vcodec", "png",
            "-i", "-",
            "-c:v", "libwebp",
            "-quality", "\(qValue)",
            destinationURL.path
        ]

        let inPipe = Pipe()
        process.standardInput = inPipe
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        try process.run()
        inPipe.fileHandleForWriting.write(pngData)
        try? inPipe.fileHandleForWriting.close()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw NSError(domain: "SheetRenderer", code: 6, userInfo: [NSLocalizedDescriptionKey: "Erro ao converter para WebP via FFmpeg."])
        }
    }
}
