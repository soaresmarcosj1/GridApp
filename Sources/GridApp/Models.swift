// GridApp — Copyright (C) 2026 Marcos (soaresmarcosj1)
// Licensed under the GNU General Public License v3.0 (GPL-3.0-or-later).
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import AppKit
import SwiftUI

enum AppUIDensity: String, CaseIterable, Identifiable, Codable {
    case compact = "Compacto"
    case normal = "Normal"
    case spacious = "Espaçoso"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .compact: return "Textos menores"
        case .normal: return "Padrão equilibrado"
        case .spacious: return "Textos maiores"
        }
    }

    var icon: String {
        switch self {
        case .compact: return "rectangle.compress.vertical"
        case .normal: return "rectangle.grid.1x2"
        case .spacious: return "rectangle.expand.vertical"
        }
    }

    var fontDelta: CGFloat {
        switch self {
        case .compact: return -3.0
        case .normal: return 0.0
        case .spacious: return 2.0
        }
    }

    var cardPadding: CGFloat {
        switch self {
        case .compact: return 8
        case .normal: return 14
        case .spacious: return 18
        }
    }

    var sectionSpacing: CGFloat {
        switch self {
        case .compact: return 8
        case .normal: return 16
        case .spacious: return 20
        }
    }

    var controlHeight: CGFloat {
        switch self {
        case .compact: return 26
        case .normal: return 34
        case .spacious: return 40
        }
    }

    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .compact: return .xSmall
        case .normal: return .medium
        case .spacious: return .xLarge
        }
    }
}

enum AppColorSchemePreference: String, CaseIterable, Identifiable, Codable {
    case system = "Automático (Sistema)"
    case dark = "Modo Escuro"
    case light = "Modo Claro"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .system: return "Sistema"
        case .dark: return "Escuro"
        case .light: return "Claro"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}

enum AppThemeColor: String, CaseIterable, Identifiable, Codable {
    case blue = "Azul Padrão"
    case indigo = "Índigo"
    case purple = "Roxo"
    case pink = "Rosa"
    case red = "Vermelho"
    case orange = "Laranja"
    case teal = "Turquesa"
    case green = "Esmeralda"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .teal: return .teal
        case .green: return .green
        }
    }
}

enum InspectorTab: String, CaseIterable, Identifiable, Codable {
    case adjustments = "Ajustes & Design"
    case export = "Exportação"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .adjustments: return "slider.horizontal.3"
        case .export: return "square.and.arrow.up.fill"
        }
    }
}

enum SheetAspectPreset: String, CaseIterable, Identifiable, Codable {
    case auto = "Automático"
    case widescreen16x9 = "16:9 (Paisagem)"
    case vertical9x16 = "9:16 (Retrato)"
    case portrait4x5 = "4:5 (Retrato)"
    case landscape5x4 = "5:4 (Paisagem)"
    case square1x1 = "1:1 (Quadrado)"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .auto: return "Auto"
        case .widescreen16x9: return "16:9"
        case .vertical9x16: return "9:16"
        case .portrait4x5: return "4:5"
        case .landscape5x4: return "5:4"
        case .square1x1: return "1:1"
        }
    }

    var subtitle: String {
        switch self {
        case .auto: return "Dinâmico"
        case .widescreen16x9: return "Paisagem"
        case .vertical9x16: return "Retrato"
        case .portrait4x5: return "Retrato"
        case .landscape5x4: return "Paisagem"
        case .square1x1: return "Quadrado"
        }
    }

    var icon: String {
        switch self {
        case .auto: return "rectangle.expand.vertical"
        case .widescreen16x9, .landscape5x4: return "rectangle"
        case .vertical9x16, .portrait4x5: return "rectangle.portrait"
        case .square1x1: return "square"
        }
    }

    /// Proporção (Largura / Altura) da folha inteira, ou nil se for dinâmico conforme as linhas
    var aspectRatio: CGFloat? {
        switch self {
        case .auto: return nil
        case .widescreen16x9: return 16.0 / 9.0
        case .vertical9x16: return 9.0 / 16.0
        case .portrait4x5: return 4.0 / 5.0
        case .landscape5x4: return 5.0 / 4.0
        case .square1x1: return 1.0
        }
    }
}

enum ThumbnailAspectMode: String, CaseIterable, Identifiable, Codable {
    case fillSheet = "Adaptar (Ocupar Folha)"
    case originalVideo = "Original do Vídeo"
    case widescreen16x9 = "16:9"
    case standard4x3 = "4:3"
    case square1x1 = "1:1"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .fillSheet: return "Adaptar"
        case .originalVideo: return "Vídeo"
        case .widescreen16x9: return "16:9"
        case .standard4x3: return "4:3"
        case .square1x1: return "1:1"
        }
    }

    var descriptionText: String {
        switch self {
        case .fillSheet:
            return "Ajusta a largura e altura de cada imagem automaticamente para que o grid preencha 100% da folha sem sobras."
        case .originalVideo:
            return "Mantém a proporção original do arquivo de vídeo em cada captura."
        case .widescreen16x9:
            return "Cada miniatura fica na proporção fixa 16:9 (Widescreen)."
        case .standard4x3:
            return "Cada miniatura fica na proporção fixa 4:3 (Clássico)."
        case .square1x1:
            return "Cada miniatura fica na proporção fixa 1:1 (Quadrada)."
        }
    }

    func fixedCellAspectRatio(videoAspect: CGFloat) -> CGFloat? {
        switch self {
        case .fillSheet: return nil
        case .originalVideo: return videoAspect
        case .widescreen16x9: return 16.0 / 9.0
        case .standard4x3: return 4.0 / 3.0
        case .square1x1: return 1.0
        }
    }
}

enum HeaderTextAlignment: String, CaseIterable, Identifiable, Codable {
    case leading = "Esquerda"
    case center = "Centro"
    case trailing = "Direita"

    var id: String { rawValue }

    var nsTextAlignment: NSTextAlignment {
        switch self {
        case .leading: return .left
        case .center: return .center
        case .trailing: return .right
        }
    }
}

enum SaveDestinationMode: String, CaseIterable, Identifiable, Codable {
    case sameAsVideo = "Mesma pasta do vídeo original"
    case customFolder = "Pasta personalizada"
    case alwaysAsk = "Perguntar onde salvar"

    var id: String { rawValue }
}

enum ExportFormat: String, CaseIterable, Identifiable, Codable {
    case jpeg = "JPEG"
    case png = "PNG"
    case tiff = "TIFF"
    case webp = "WebP"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .tiff: return "tiff"
        case .webp: return "webp"
        }
    }

    var supportsQuality: Bool {
        switch self {
        case .jpeg, .webp: return true
        case .png, .tiff: return false
        }
    }
}

enum ProcessingSpeed: String, CaseIterable, Identifiable, Codable {
    case ultraFast = "Ultra Rápida (Keyframes)"
    case balanced = "Balanceada"
    case precise = "Precisa (Exata)"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .ultraFast: return "Rápida"
        case .balanced: return "Balanceada"
        case .precise: return "Precisa"
        }
    }

    var descriptionText: String {
        switch self {
        case .ultraFast:
            return "Busca instantânea nos keyframes mais próximos e alta paralelização para leitura rápida na importação."
        case .balanced:
            return "Equilíbrio entre velocidade de leitura e precisão do tempo (~0.4s)."
        case .precise:
            return "Decodifica até o milissegundo exato de cada timestamp desde a pré-visualização."
        }
    }

    var timeToleranceSeconds: Double {
        switch self {
        case .ultraFast: return 4.0
        case .balanced: return 0.4
        case .precise: return 0.01
        }
    }

    var thumbScaleMultiplier: CGFloat {
        switch self {
        case .ultraFast: return 1.0
        case .balanced: return 1.15
        case .precise: return 1.5
        }
    }

    var maxConcurrentFFmpegJobs: Int {
        switch self {
        case .ultraFast: return 8
        case .balanced: return 6
        case .precise: return 4
        }
    }
}

enum TimestampPosition: String, CaseIterable, Identifiable, Codable {
    case bottomRight = "Inferior Direito"
    case bottomLeft = "Inferior Esquerdo"
    case topRight = "Superior Direito"
    case topLeft = "Superior Esquerdo"

    var id: String { rawValue }
}

struct CodableRGBA: Equatable, Codable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(color: Color) {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor.black
        self.red = Double(nsColor.redComponent)
        self.green = Double(nsColor.greenComponent)
        self.blue = Double(nsColor.blueComponent)
        self.alpha = Double(nsColor.alphaComponent)
    }

    var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}

struct GridSettings: Equatable, Codable {
    // Aparência, Densidade e Tema do Aplicativo
    var appColorScheme: AppColorSchemePreference = .system
    var appThemeColor: AppThemeColor = .blue
    var appUIDensity: AppUIDensity = .normal
    var autoExportOnFinderOpen: Bool = false

    // Velocidade de Processamento e Refinamento (Configurados na Janela de Configurações do App)
    var processingSpeed: ProcessingSpeed = .ultraFast
    var reExtractHighQualityOnExport: Bool = true

    // Grade e Quantidade
    var frameCount: Int = 16
    var columns: Int = 4

    // Dimensões, Proporção de Layout e Estilo
    var sheetAspectPreset: SheetAspectPreset = .auto
    var thumbnailAspectMode: ThumbnailAspectMode = .fillSheet
    var outputWidth: Int = 1920
    var outerPadding: CGFloat = 24
    var spacing: CGFloat = 12
    var cornerRadius: CGFloat = 8
    var shadowRadius: CGFloat = 4
    var backgroundRGBA: CodableRGBA = CodableRGBA(red: 0.10, green: 0.11, blue: 0.13, alpha: 1.0)
    var textRGBA: CodableRGBA = CodableRGBA(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)

    // Cabeçalho Técnico Rico e Tipografia do Cabeçalho
    var showHeader: Bool = true
    var showFileName: Bool = true
    var showDuration: Bool = true
    var showResolution: Bool = true
    var showFileSize: Bool = true
    var showCodecAndFPS: Bool = true
    var showAudioInfo: Bool = true
    var showBitrateAndColor: Bool = true
    var customTitle: String = ""

    var headerTitleFontSize: CGFloat = 21
    var headerBodyFontSize: CGFloat = 14
    var headerLineSpacing: CGFloat = 6
    var headerBottomSpacing: CGFloat = 18
    var headerTextAlignment: HeaderTextAlignment = .leading
    var showHeaderCardBackground: Bool = true

    // Timestamps nas Miniaturas
    var showTimestamps: Bool = true
    var timestampPosition: TimestampPosition = .bottomRight
    var timestampFontSize: CGFloat = 13

    // Exportação e Destino
    var exportFormat: ExportFormat = .jpeg
    var exportQuality: Double = 0.92 // 0.1 a 1.0
    var saveDestinationMode: SaveDestinationMode = .sameAsVideo
    var customExportFolderPath: String? = nil
    var fileSuffix: String = "-sheet"
    var revealInFinderAfterExport: Bool = false

    // Helpers de conveniência para SwiftUI Color e URL
    var backgroundColor: Color {
        get { backgroundRGBA.swiftUIColor }
        set { backgroundRGBA = CodableRGBA(color: newValue) }
    }

    var textColor: Color {
        get { textRGBA.swiftUIColor }
        set { textRGBA = CodableRGBA(color: newValue) }
    }

    var customExportFolderURL: URL? {
        get {
            guard let path = customExportFolderPath, !path.isEmpty else { return nil }
            return URL(fileURLWithPath: path)
        }
        set {
            customExportFolderPath = newValue?.path
        }
    }
}

struct SettingsPreset: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var isBuiltIn: Bool
    var settings: GridSettings

    init(id: UUID = UUID(), name: String, isBuiltIn: Bool = false, settings: GridSettings) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.settings = settings
    }

    static var builtInPresets: [SettingsPreset] {
        var standard = GridSettings()
        standard.frameCount = 16
        standard.columns = 4
        standard.outputWidth = 1920
        standard.sheetAspectPreset = .auto

        var cinema4K = GridSettings()
        cinema4K.frameCount = 24
        cinema4K.columns = 4
        cinema4K.outputWidth = 3840
        cinema4K.sheetAspectPreset = .widescreen16x9
        cinema4K.cornerRadius = 10
        cinema4K.exportFormat = .png
        cinema4K.backgroundRGBA = CodableRGBA(red: 0.06, green: 0.06, blue: 0.08)

        var socialPortrait = GridSettings()
        socialPortrait.frameCount = 15
        socialPortrait.columns = 3
        socialPortrait.outputWidth = 2160
        socialPortrait.sheetAspectPreset = .portrait4x5
        socialPortrait.spacing = 10
        socialPortrait.outerPadding = 24

        var cleanSquare = GridSettings()
        cleanSquare.frameCount = 9
        cleanSquare.columns = 3
        cleanSquare.outputWidth = 2000
        cleanSquare.sheetAspectPreset = .square1x1
        cleanSquare.showHeader = false
        cleanSquare.showTimestamps = false
        cleanSquare.cornerRadius = 12
        cleanSquare.spacing = 16
        cleanSquare.backgroundRGBA = CodableRGBA(red: 0.96, green: 0.96, blue: 0.97)
        cleanSquare.textRGBA = CodableRGBA(red: 0.12, green: 0.12, blue: 0.14)

        return [
            SettingsPreset(name: "Padrão Full HD (4×4 • Dinâmico)", isBuiltIn: true, settings: standard),
            SettingsPreset(name: "Cinema 4K 16:9 (4×6 • 24 frames)", isBuiltIn: true, settings: cinema4K),
            SettingsPreset(name: "Retrato 4:5 (3×5 • 15 frames)", isBuiltIn: true, settings: socialPortrait),
            SettingsPreset(name: "Quadrado 1:1 Minimalista (3×3)", isBuiltIn: true, settings: cleanSquare)
        ]
    }
}

struct VideoMetadata: Equatable {
    var fileName: String
    var containerFormat: String
    var fileSizeBytes: Int64
    var durationSeconds: Double
    var width: Int
    var height: Int
    var codec: String
    var frameRate: Double
    var totalBitrateBps: Int64
    var videoBitrateBps: Int64
    var colorDepthInfo: String
    var audioCodec: String
    var audioSampleRateHz: Int
    var audioChannels: Int
    var audioBitrateBps: Int64
    var usesFFmpeg: Bool

    var formattedDuration: String {
        TimeFormatter.format(seconds: durationSeconds)
    }

    var formattedFileSize: String {
        let bytesStr = NumberFormatter.localizedString(from: NSNumber(value: fileSizeBytes), number: .decimal)
        let humanStr = ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
        return "\(humanStr) (\(bytesStr) bytes)"
    }

    var formattedShortFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }

    var formattedResolution: String {
        let gcdVal = Self.gcd(width, height)
        if gcdVal > 0 {
            let arW = width / gcdVal
            let arH = height / gcdVal
            if arW <= 32 && arH <= 32 {
                return "\(width) × \(height) (\(arW):\(arH))"
            }
        }
        let ratio = Double(width) / Double(max(height, 1))
        return String(format: "%d × %d (%.2f:1)", width, height, ratio)
    }

    var formattedShortResolution: String {
        "\(width) × \(height)"
    }

    var formattedFPS: String {
        if frameRate > 0 {
            return String(format: "%.2f fps", frameRate).replacingOccurrences(of: ".00 ", with: " ")
        }
        return "N/A"
    }

    var formattedTotalBitrate: String {
        let bps = totalBitrateBps > 0 ? totalBitrateBps : Int64((Double(fileSizeBytes) * 8.0) / max(durationSeconds, 1.0))
        return Self.formatBitrate(bps)
    }

    var formattedVideoBitrate: String {
        if videoBitrateBps > 0 {
            return Self.formatBitrate(videoBitrateBps)
        }
        return formattedTotalBitrate
    }

    var formattedAudioSummary: String {
        guard !audioCodec.isEmpty && audioCodec != "Sem Áudio" else {
            return "Sem faixa de áudio"
        }
        var parts: [String] = [audioCodec]
        if audioChannels > 0 {
            switch audioChannels {
            case 1: parts.append("Mono (1.0)")
            case 2: parts.append("Estéreo (2.0)")
            case 6: parts.append("Surround (5.1)")
            case 8: parts.append("Surround (7.1)")
            default: parts.append("\(audioChannels) canais")
            }
        }
        if audioSampleRateHz > 0 {
            let khz = Double(audioSampleRateHz) / 1000.0
            let khzStr = String(format: "%.1f kHz", khz).replacingOccurrences(of: ".0 ", with: " ")
            parts.append(khzStr)
        }
        if audioBitrateBps > 0 {
            parts.append(Self.formatBitrate(audioBitrateBps))
        }
        return parts.joined(separator: " • ")
    }

    private static func formatBitrate(_ bps: Int64) -> String {
        guard bps > 0 else { return "N/A" }
        let kbps = Double(bps) / 1000.0
        if kbps >= 1000 {
            return String(format: "%.2f Mbps", kbps / 1000.0)
        }
        return String(format: "%.0f kbps", kbps)
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        var x = abs(a)
        var y = abs(b)
        while y != 0 {
            let t = y
            y = x % y
            x = t
        }
        return x
    }
}

struct CapturedFrame: Identifiable {
    let id: UUID
    var index: Int
    var timestampSeconds: Double
    var image: NSImage?
    var isCustomTimestamp: Bool = false

    init(id: UUID = UUID(), index: Int, timestampSeconds: Double, image: NSImage? = nil, isCustomTimestamp: Bool = false) {
        self.id = id
        self.index = index
        self.timestampSeconds = timestampSeconds
        self.image = image
        self.isCustomTimestamp = isCustomTimestamp
    }

    var formattedTimestamp: String {
        TimeFormatter.format(seconds: timestampSeconds)
    }
}

enum VideoProcessingStatus: Equatable {
    case idle
    case loadingMetadata
    case extractingFrames(progress: Double)
    case exportingHighRes(progress: Double)
    case ready
    case failed(String)
}

struct RenderedFrameHitBox: Equatable {
    let frameID: UUID
    let index: Int
    let normalizedRect: CGRect // x, y, width, height normalizados (0.0 a 1.0) com origem no topo-esquerdo
    let normalizedCornerRadius: CGFloat // relativo à largura da folha
}

@MainActor
class VideoItem: ObservableObject, Identifiable {
    let id = UUID()
    let url: URL

    @Published var metadata: VideoMetadata?
    @Published var frames: [CapturedFrame] = []
    @Published var status: VideoProcessingStatus = .idle
    @Published var renderedSheet: NSImage?
    @Published var frameHitBoxes: [RenderedFrameHitBox] = []
    @Published var processingDurationSeconds: Double?

    init(url: URL) {
        self.url = url
    }
}

enum TimeFormatter {
    static func format(seconds: Double, includeMilliseconds: Bool = false) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00:00" }
        let totalSeconds = Int(seconds.rounded(.down))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if includeMilliseconds {
            let ms = Int((seconds - Double(totalSeconds)) * 100)
            return String(format: "%02d:%02d:%02d.%02d", hours, minutes, secs, ms)
        }
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
}
