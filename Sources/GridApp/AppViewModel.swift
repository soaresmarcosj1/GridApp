// GridApp — Copyright (C) 2026 Marcos (soaresmarcosj1)
// Licensed under the GNU General Public License v3.0 (GPL-3.0-or-later).
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
class AppViewModel: ObservableObject {
    @Published var videos: [VideoItem] = []
    @Published var selectedVideoID: UUID?
    @Published var checkedVideoIDs: Set<UUID> = []

    @Published var settings: GridSettings = GridSettings()
    @Published var presets: [SettingsPreset] = []
    @Published var activePresetID: UUID?
    @Published var isShowingSavePresetSheet: Bool = false
    @Published var newPresetName: String = ""

    @Published var selectedInspectorTab: InspectorTab = .adjustments
    @Published var selectedPreferencesSection: AppPreferencesSection = .general
    @Published var preferencesSearchText: String = ""
    @Published var zoomScale: CGFloat = 1.0
    @Published var isDropTargeted: Bool = false

    @Published var isExportingSingle: Bool = false
    @Published var isBatchExporting: Bool = false
    @Published var batchProgress: Double = 0
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    @Published var editingFrame: CapturedFrame? {
        didSet {
            if let frame = editingFrame {
                editingSeconds = frame.timestampSeconds
                editingPreviewImage = frame.image
            } else {
                editingPreviewImage = nil
            }
        }
    }
    @Published var editingSeconds: Double = 0
    @Published var editingPreviewImage: NSImage?
    @Published var isUpdatingSingleFrame: Bool = false

    private let customPresetsStorageKey = "GridApp.CustomPresets.v1"
    private let lastSettingsStorageKey = "GridApp.LastSettings.v1"

    init() {
        loadSavedPresetsAndSettings()
    }

    var selectedVideo: VideoItem? {
        guard let id = selectedVideoID else { return videos.first }
        return videos.first(where: { $0.id == id })
    }

    /// Vídeos marcados com checkbox na fila
    var checkedVideos: [VideoItem] {
        videos.filter { checkedVideoIDs.contains($0.id) }
    }

    /// Vídeos alvo para ações de lote ou seleção (se houver vídeos marcados, usa os marcados; caso contrário, usa o vídeo ativo)
    var targetVideosForAction: [VideoItem] {
        let checked = checkedVideos
        if !checked.isEmpty {
            return checked
        }
        if let selected = selectedVideo {
            return [selected]
        }
        return []
    }

    var allVideosChecked: Bool {
        !videos.isEmpty && checkedVideoIDs.count == videos.count
    }

    // MARK: - Seleção Múltipla na Fila
    func toggleVideoCheck(_ id: UUID) {
        if checkedVideoIDs.contains(id) {
            checkedVideoIDs.remove(id)
        } else {
            checkedVideoIDs.insert(id)
        }
    }

    func isVideoChecked(_ id: UUID) -> Bool {
        checkedVideoIDs.contains(id)
    }

    func selectAllVideos() {
        checkedVideoIDs = Set(videos.map { $0.id })
    }

    func deselectAllVideos() {
        checkedVideoIDs.removeAll()
    }

    func invertVideoSelection() {
        let allIDs = Set(videos.map { $0.id })
        checkedVideoIDs = allIDs.subtracting(checkedVideoIDs)
    }

    func removeCheckedOrCurrentVideo() {
        if !checkedVideoIDs.isEmpty {
            let removedCount = checkedVideoIDs.count
            videos.removeAll { checkedVideoIDs.contains($0.id) }
            checkedVideoIDs.removeAll()
            if let currentID = selectedVideoID, !videos.contains(where: { $0.id == currentID }) {
                selectedVideoID = videos.first?.id
            }
            statusMessage = "\(removedCount) vídeo(s) removido(s) da fila."
        } else if let current = selectedVideo {
            removeVideo(current)
        }
    }

    // MARK: - Modelos de Configuração (Presets)
    func loadSavedPresetsAndSettings() {
        let builtIns = SettingsPreset.builtInPresets
        var customList: [SettingsPreset] = []

        if let data = UserDefaults.standard.data(forKey: customPresetsStorageKey),
           let decoded = try? JSONDecoder().decode([SettingsPreset].self, from: data) {
            customList = decoded
        }

        presets = builtIns + customList

        if let settingsData = UserDefaults.standard.data(forKey: lastSettingsStorageKey),
           let decodedSettings = try? JSONDecoder().decode(GridSettings.self, from: settingsData) {
            settings = decodedSettings
        } else if let first = builtIns.first {
            settings = first.settings
            activePresetID = first.id
        }
        applyAppAppearance()
    }

    func applyAppAppearance() {
        switch settings.appColorScheme {
        case .system:
            NSApp.appearance = nil
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        }
    }

    func persistCurrentSettings() {
        applyAppAppearance()
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: lastSettingsStorageKey)
        }
    }

    private func persistCustomPresets() {
        let customOnly = presets.filter { !$0.isBuiltIn }
        if let data = try? JSONEncoder().encode(customOnly) {
            UserDefaults.standard.set(data, forKey: customPresetsStorageKey)
        }
    }

    func applyPreset(_ preset: SettingsPreset) {
        let oldCount = settings.frameCount
        let oldSpeed = settings.processingSpeed
        settings = preset.settings
        activePresetID = preset.id
        persistCurrentSettings()

        if oldCount != settings.frameCount || oldSpeed != settings.processingSpeed {
            regenerateAllFramesForCountChange()
        } else {
            refreshAllRenderedSheets()
        }
        statusMessage = "Modelo aplicado: \(preset.name)"
    }

    func saveCurrentSettingsAsPreset(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let newPreset = SettingsPreset(name: trimmed, isBuiltIn: false, settings: settings)
        presets.append(newPreset)
        activePresetID = newPreset.id
        persistCustomPresets()
        newPresetName = ""
        isShowingSavePresetSheet = false
        statusMessage = "Modelo \"\(trimmed)\" salvo com sucesso!"
    }

    func updatePresetWithCurrentSettings(_ preset: SettingsPreset) {
        guard !preset.isBuiltIn,
              let idx = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[idx].settings = settings
        activePresetID = preset.id
        persistCustomPresets()
        statusMessage = "Modelo \"\(preset.name)\" atualizado!"
    }

    func deletePreset(_ preset: SettingsPreset) {
        guard !preset.isBuiltIn else { return }
        presets.removeAll { $0.id == preset.id }
        if activePresetID == preset.id {
            activePresetID = nil
        }
        persistCustomPresets()
        statusMessage = "Modelo \"\(preset.name)\" excluído."
    }

    func resetSettingsToDefault() {
        if let defaultPreset = SettingsPreset.builtInPresets.first {
            applyPreset(defaultPreset)
        } else {
            settings = GridSettings()
            regenerateAllFramesForCountChange()
        }
    }

    // MARK: - Arquivos e Fila de Vídeos
    func openFilePicker() {
        let panel = NSOpenPanel()
        panel.title = "Adicionar Arquivos de Vídeo"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .movie, .video, .mpeg4Movie, .quickTimeMovie, .avi, .folder
        ]
        if let mkv = UTType(filenameExtension: "mkv") { panel.allowedContentTypes.append(mkv) }
        if let webm = UTType(filenameExtension: "webm") { panel.allowedContentTypes.append(webm) }
        if let flv = UTType(filenameExtension: "flv") { panel.allowedContentTypes.append(flv) }

        if panel.runModal() == .OK {
            addVideoURLs(panel.urls)
        }
    }

    func chooseCustomExportFolder() {
        let panel = NSOpenPanel()
        panel.title = "Escolher Pasta Padrão de Exportação"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Selecionar Pasta"

        if panel.runModal() == .OK, let folderURL = panel.url {
            settings.customExportFolderURL = folderURL
            settings.saveDestinationMode = .customFolder
            persistCurrentSettings()
        }
    }

    func addVideoURLs(_ urls: [URL]) {
        let validExtensions: Set<String> = [
            "mp4", "mov", "m4v", "mkv", "avi", "webm", "flv", "wmv", "mpg", "mpeg", "ts", "mts", "3gp"
        ]

        var expandedURLs: [URL] = []
        for url in urls {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                if let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                ) {
                    for case let fileURL as URL in enumerator {
                        if validExtensions.contains(fileURL.pathExtension.lowercased()) {
                            expandedURLs.append(fileURL)
                        }
                    }
                }
            } else {
                expandedURLs.append(url)
            }
        }

        var addedAny = false
        for url in expandedURLs {
            let ext = url.pathExtension.lowercased()
            guard validExtensions.contains(ext) else { continue }
            if videos.contains(where: { $0.url == url }) { continue }

            let item = VideoItem(url: url)
            videos.append(item)
            checkedVideoIDs.insert(item.id)
            if selectedVideoID == nil {
                selectedVideoID = item.id
            }
            addedAny = true

            Task {
                await processVideo(item)
            }
        }

        if !addedAny && !urls.isEmpty {
            errorMessage = "Nenhum arquivo de vídeo compatível encontrado ou os vídeos já estão na fila."
        }
    }

    func removeVideo(_ item: VideoItem) {
        videos.removeAll { $0.id == item.id }
        checkedVideoIDs.remove(item.id)
        if selectedVideoID == item.id {
            selectedVideoID = videos.first?.id
        }
    }

    func clearAllVideos() {
        videos.removeAll()
        checkedVideoIDs.removeAll()
        selectedVideoID = nil
    }

    // MARK: - Processamento de Vídeo
    func processVideo(_ item: VideoItem) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        item.status = .loadingMetadata
        do {
            let metadata = try await VideoProcessor.shared.loadMetadata(for: item.url)
            item.metadata = metadata
            await extractFrames(for: item, startTime: startTime)
        } catch {
            item.status = .failed(error.localizedDescription)
        }
    }

    func extractFrames(for item: VideoItem, startTime: CFAbsoluteTime? = nil) async {
        guard let metadata = item.metadata else { return }
        let beginTime = startTime ?? CFAbsoluteTimeGetCurrent()
        item.status = .extractingFrames(progress: 0)

        let count = settings.frameCount
        let speed = settings.processingSpeed
        let timestamps = await VideoProcessor.shared.calculateDefaultTimestamps(
            duration: metadata.durationSeconds,
            count: count
        )

        let baseCellWidth = CGFloat(settings.outputWidth) / CGFloat(max(settings.columns, 1))
        let thumbWidth = max(baseCellWidth * speed.thumbScaleMultiplier, 480)

        do {
            let frames = try await VideoProcessor.shared.extractFrames(
                for: item.url,
                metadata: metadata,
                timestamps: timestamps,
                maxThumbWidth: thumbWidth,
                speed: speed
            ) { [weak item] progress in
                Task { @MainActor in
                    item?.status = .extractingFrames(progress: progress)
                }
            }
            item.frames = frames
            item.processingDurationSeconds = CFAbsoluteTimeGetCurrent() - beginTime
            item.status = .ready
            renderSheet(for: item)
        } catch {
            item.status = .failed(error.localizedDescription)
        }
    }

    func reExtractHighQualityFramesForExport(for item: VideoItem) async throws {
        guard let metadata = item.metadata else { return }
        let currentTimestamps: [Double]
        if item.frames.isEmpty {
            currentTimestamps = await VideoProcessor.shared.calculateDefaultTimestamps(
                duration: metadata.durationSeconds,
                count: settings.frameCount
            )
        } else {
            currentTimestamps = item.frames.map { $0.timestampSeconds }
        }

        let customFlags = item.frames.map { $0.isCustomTimestamp }
        let cellWidth = CGFloat(settings.outputWidth) / CGFloat(max(settings.columns, 1))
        let highResThumbWidth = max(cellWidth * 2.0, CGFloat(metadata.width), 1280)

        item.status = .exportingHighRes(progress: 0)

        let hqFrames = try await VideoProcessor.shared.extractFrames(
            for: item.url,
            metadata: metadata,
            timestamps: currentTimestamps,
            maxThumbWidth: highResThumbWidth,
            speed: .precise
        ) { [weak item] progress in
            Task { @MainActor in
                item?.status = .exportingHighRes(progress: progress)
            }
        }

        item.frames = hqFrames.enumerated().map { idx, frame in
            var updated = frame
            if idx < customFlags.count {
                updated.isCustomTimestamp = customFlags[idx]
            }
            return updated
        }
        item.status = .ready
        renderSheet(for: item)
    }

    func regenerateAllFramesForCountChange() {
        for item in videos {
            Task {
                await extractFrames(for: item)
            }
        }
    }

    func recaptureTargetVideos() {
        let targets = targetVideosForAction
        for item in targets {
            Task {
                await extractFrames(for: item)
            }
        }
    }

    func renderSheet(for item: VideoItem) {
        guard let metadata = item.metadata, !item.frames.isEmpty else { return }
        if let result = SheetRenderer.renderContactSheet(
            metadata: metadata,
            frames: item.frames,
            settings: settings
        ) {
            item.renderedSheet = result.image
            item.frameHitBoxes = result.hitBoxes
        }
    }

    func refreshAllRenderedSheets() {
        persistCurrentSettings()
        for item in videos where item.status == .ready {
            renderSheet(for: item)
        }
    }

    func previewEditingFrame(for item: VideoItem, timestamp: Double) async {
        guard let metadata = item.metadata else { return }
        let clampedTime = min(max(0, timestamp), max(metadata.durationSeconds - 0.05, 0))
        let thumbWidth = max(CGFloat(settings.outputWidth) / CGFloat(max(settings.columns, 1)) * 1.35, 640)

        isUpdatingSingleFrame = true
        defer { isUpdatingSingleFrame = false }

        do {
            let newImage = try await VideoProcessor.shared.extractSingleFrame(
                for: item.url,
                metadata: metadata,
                timestamp: clampedTime,
                maxThumbWidth: thumbWidth
            )
            editingPreviewImage = newImage
        } catch {
            // Mantém a imagem anterior se falhar durante o arraste
        }
    }

    func applyEditingFrame(for item: VideoItem) async {
        guard let frame = editingFrame,
              let metadata = item.metadata,
              let index = item.frames.firstIndex(where: { $0.id == frame.id }) else {
            editingFrame = nil
            return
        }

        let clampedTime = min(max(0, editingSeconds), max(metadata.durationSeconds - 0.05, 0))
        let thumbWidth = max(CGFloat(settings.outputWidth) / CGFloat(max(settings.columns, 1)) * 1.35, 640)

        isUpdatingSingleFrame = true
        do {
            let finalImage: NSImage
            if abs(frame.timestampSeconds - clampedTime) < 0.005, let preview = editingPreviewImage {
                finalImage = preview
            } else {
                finalImage = try await VideoProcessor.shared.extractSingleFrame(
                    for: item.url,
                    metadata: metadata,
                    timestamp: clampedTime,
                    maxThumbWidth: thumbWidth
                )
            }

            var updated = item.frames[index]
            updated.timestampSeconds = clampedTime
            updated.image = finalImage
            updated.isCustomTimestamp = true
            item.frames[index] = updated
            renderSheet(for: item)
            isUpdatingSingleFrame = false
            editingFrame = nil
        } catch {
            isUpdatingSingleFrame = false
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Exportação Unificada (Individual ou Selecionados da Fila)
    func defaultOutputURL(for item: VideoItem, folderOverride: URL? = nil) -> URL {
        let baseName = item.url.deletingPathExtension().lastPathComponent
        let suffix = settings.fileSuffix.isEmpty ? "-sheet" : settings.fileSuffix
        let fileName = "\(baseName)\(suffix).\(settings.exportFormat.fileExtension)"

        if let folder = folderOverride {
            return folder.appendingPathComponent(fileName)
        }

        switch settings.saveDestinationMode {
        case .sameAsVideo:
            return item.url.deletingLastPathComponent().appendingPathComponent(fileName)
        case .customFolder:
            if let customFolder = settings.customExportFolderURL {
                return customFolder.appendingPathComponent(fileName)
            }
            return item.url.deletingLastPathComponent().appendingPathComponent(fileName)
        case .alwaysAsk:
            return item.url.deletingLastPathComponent().appendingPathComponent(fileName)
        }
    }

    func exportCurrentSheet(forceSavePanel: Bool = false) {
        guard let item = selectedVideo else { return }

        var chosenURL: URL? = nil
        if forceSavePanel || settings.saveDestinationMode == .alwaysAsk {
            let savePanel = NSSavePanel()
            savePanel.title = "Exportar Contact Sheet"
            let suggested = defaultOutputURL(for: item)
            savePanel.directoryURL = suggested.deletingLastPathComponent()
            savePanel.nameFieldStringValue = suggested.lastPathComponent
            savePanel.canCreateDirectories = true

            guard savePanel.runModal() == .OK, let url = savePanel.url else { return }
            chosenURL = url
        } else {
            chosenURL = defaultOutputURL(for: item)
        }

        guard let destURL = chosenURL else { return }

        isExportingSingle = true
        Task {
            do {
                if settings.reExtractHighQualityOnExport {
                    try await reExtractHighQualityFramesForExport(for: item)
                } else {
                    renderSheet(for: item)
                }

                guard let image = item.renderedSheet else {
                    throw NSError(domain: "GridApp", code: 10, userInfo: [NSLocalizedDescriptionKey: "Não foi possível renderizar a Contact Sheet."])
                }

                try SheetRenderer.exportImage(
                    image,
                    to: destURL,
                    format: settings.exportFormat,
                    quality: settings.exportQuality
                )

                isExportingSingle = false
                statusMessage = "Salvo em: \(destURL.path)"

                if settings.revealInFinderAfterExport {
                    NSWorkspace.shared.activateFileViewerSelecting([destURL])
                }
            } catch {
                isExportingSingle = false
                item.status = .ready
                errorMessage = "Erro ao salvar em \(destURL.lastPathComponent): \(error.localizedDescription)"
            }
        }
    }

    func exportSelectedOrAllVideos(forceChooseFolder: Bool = false) {
        let targets = checkedVideos.isEmpty ? videos : checkedVideos
        guard !targets.isEmpty else { return }

        // Se houver apenas 1 vídeo para exportar e não for forçado escolher pasta, usa o fluxo direto
        if targets.count == 1, let single = targets.first, single.id == selectedVideo?.id, !forceChooseFolder {
            exportCurrentSheet(forceSavePanel: false)
            return
        }

        var batchFolderOverride: URL? = nil
        if forceChooseFolder || settings.saveDestinationMode == .alwaysAsk {
            let openPanel = NSOpenPanel()
            openPanel.title = "Escolher Pasta para Exportar (\(targets.count) vídeos)"
            openPanel.canChooseFiles = false
            openPanel.canChooseDirectories = true
            openPanel.canCreateDirectories = true
            openPanel.prompt = "Exportar Aqui"

            guard openPanel.runModal() == .OK, let folderURL = openPanel.url else { return }
            batchFolderOverride = folderURL
        }

        isBatchExporting = true
        batchProgress = 0

        Task {
            let total = targets.count
            var exportedCount = 0
            var lastSavedURL: URL?

            for (idx, item) in targets.enumerated() {
                if item.metadata == nil {
                    await processVideo(item)
                }

                do {
                    if settings.reExtractHighQualityOnExport {
                        try await reExtractHighQualityFramesForExport(for: item)
                    } else {
                        renderSheet(for: item)
                    }

                    if let image = item.renderedSheet {
                        let destURL = defaultOutputURL(for: item, folderOverride: batchFolderOverride)
                        try SheetRenderer.exportImage(
                            image,
                            to: destURL,
                            format: settings.exportFormat,
                            quality: settings.exportQuality
                        )
                        exportedCount += 1
                        lastSavedURL = destURL
                    }
                } catch {
                    item.status = .ready
                    errorMessage = "Erro ao exportar \(item.url.lastPathComponent): \(error.localizedDescription)"
                }

                batchProgress = Double(idx + 1) / Double(max(total, 1))
            }

            isBatchExporting = false
            statusMessage = "Exportação concluída! \(exportedCount) de \(total) sheets salvas."
            if settings.revealInFinderAfterExport, let last = lastSavedURL {
                NSWorkspace.shared.activateFileViewerSelecting([last])
            }
        }
    }

    func copyCurrentSheetToClipboard() {
        guard let item = selectedVideo else { return }
        renderSheet(for: item)
        guard let image = item.renderedSheet else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        statusMessage = "Contact sheet copiada para a Área de Transferência!"
    }

    func revealCurrentVideoInFinder() {
        guard let item = selectedVideo else { return }
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    private static var settingsWindow: NSWindow?

    func openAppSettingsWindow() {
        if let existing = Self.settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: AppSettingsWindowView(viewModel: self))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Configurações"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 740, height: 520))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        Self.settingsWindow = window
    }
}
