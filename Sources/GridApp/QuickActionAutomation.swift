import Foundation
import AppKit
import UserNotifications

enum QuickActionAutomation {
    static let lastSettingsStorageKey = "GridApp.LastSettings.v1"
    static let customPresetsStorageKey = "GridApp.CustomPresets.v1"

    static func loadCurrentSettings(presetNameOverride: String? = nil) -> GridSettings {
        let builtIns = SettingsPreset.builtInPresets
        var customList: [SettingsPreset] = []
        if let data = UserDefaults.standard.data(forKey: customPresetsStorageKey),
           let decoded = try? JSONDecoder().decode([SettingsPreset].self, from: data) {
            customList = decoded
        }
        let allPresets = builtIns + customList

        if let name = presetNameOverride,
           let matched = allPresets.first(where: { $0.name.localizedCaseInsensitiveContains(name) }) {
            return matched.settings
        }

        if let data = UserDefaults.standard.data(forKey: lastSettingsStorageKey),
           let decoded = try? JSONDecoder().decode(GridSettings.self, from: data) {
            return decoded
        }
        return GridSettings()
    }

    /// Processa uma lista de URLs de vídeo ou pastas diretamente e salva as Contact Sheets sem precisar interagir com a janela do app
    @MainActor
    static func generateSheetsHeadless(
        for inputURLs: [URL],
        presetNameOverride: String? = nil
    ) async -> [URL] {
        let validExtensions: Set<String> = [
            "mp4", "mov", "m4v", "mkv", "avi", "webm", "flv", "wmv", "mpg", "mpeg", "ts", "mts", "3gp"
        ]

        var videoURLs: [URL] = []
        for url in inputURLs {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                if let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                ) {
                    for case let fileURL as URL in enumerator {
                        if validExtensions.contains(fileURL.pathExtension.lowercased()) {
                            videoURLs.append(fileURL)
                        }
                    }
                }
            } else if validExtensions.contains(url.pathExtension.lowercased()) {
                videoURLs.append(url)
            }
        }

        guard !videoURLs.isEmpty else { return [] }
        let settings = loadCurrentSettings(presetNameOverride: presetNameOverride)
        var savedURLs: [URL] = []

        for url in videoURLs {
            do {
                let metadata = try await VideoProcessor.shared.loadMetadata(for: url)
                let timestamps = await VideoProcessor.shared.calculateDefaultTimestamps(
                    duration: metadata.durationSeconds,
                    count: settings.frameCount
                )
                let cellWidth = CGFloat(settings.outputWidth) / CGFloat(max(settings.columns, 1))
                let highResWidth = settings.reExtractHighQualityOnExport
                    ? max(cellWidth * 2.0, CGFloat(metadata.width), 1280)
                    : max(cellWidth * settings.processingSpeed.thumbScaleMultiplier, 640)
                let speed: ProcessingSpeed = settings.reExtractHighQualityOnExport ? .precise : settings.processingSpeed

                let frames = try await VideoProcessor.shared.extractFrames(
                    for: url,
                    metadata: metadata,
                    timestamps: timestamps,
                    maxThumbWidth: highResWidth,
                    speed: speed
                ) { _ in }

                if let result = SheetRenderer.renderContactSheet(
                    metadata: metadata,
                    frames: frames,
                    settings: settings
                ) {
                    let baseName = url.deletingPathExtension().lastPathComponent
                    let suffix = settings.fileSuffix.isEmpty ? "-sheet" : settings.fileSuffix
                    let fileName = "\(baseName)\(suffix).\(settings.exportFormat.fileExtension)"

                    let destFolder: URL
                    if settings.saveDestinationMode == .customFolder, let customURL = settings.customExportFolderURL {
                        destFolder = customURL
                    } else {
                        destFolder = url.deletingLastPathComponent()
                    }
                    let destURL = destFolder.appendingPathComponent(fileName)

                    try SheetRenderer.exportImage(
                        result.image,
                        to: destURL,
                        format: settings.exportFormat,
                        quality: settings.exportQuality
                    )
                    savedURLs.append(destURL)
                }
            } catch {
                fputs("Erro ao processar \(url.lastPathComponent): \(error.localizedDescription)\n", stderr)
            }
        }

        if settings.revealInFinderAfterExport, let last = savedURLs.last {
            NSWorkspace.shared.activateFileViewerSelecting([last])
        }

        return savedURLs
    }

    /// Instala a Ação Rápida (Quick Action / Workflow) em ~/Library/Services para aparecer no clique direito do Finder e no Atalhos
    static func installFinderQuickAction() throws -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let servicesDir = home.appendingPathComponent("Library/Services", isDirectory: true)
        try FileManager.default.createDirectory(at: servicesDir, withIntermediateDirectories: true)

        let workflowURL = servicesDir.appendingPathComponent("Criar Contact Sheet (GridApp).workflow", isDirectory: true)
        let contentsDir = workflowURL.appendingPathComponent("Contents", isDirectory: true)
        try? FileManager.default.removeItem(at: workflowURL)
        try FileManager.default.createDirectory(at: contentsDir, withIntermediateDirectories: true)

        // Descobre o caminho do executável do GridApp
        let currentExecPath = Bundle.main.executablePath ?? "/Users/marcos/Downloads/GridApp/GridApp.app/Contents/MacOS/GridApp"

        let infoPlist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>NSServices</key>
            <array>
                <dict>
                    <key>NSBackgroundColorName</key>
                    <string>background</string>
                    <key>NSIconName</key>
                    <string>NSActionTemplate</string>
                    <key>NSMenuItem</key>
                    <dict>
                        <key>default</key>
                        <string>Criar Contact Sheet (GridApp)</string>
                    </dict>
                    <key>NSMessage</key>
                    <string>runWorkflowAsService</string>
                    <key>NSRequiredContext</key>
                    <dict>
                        <key>NSApplicationIdentifier</key>
                        <string>com.apple.finder</string>
                    </dict>
                    <key>NSSendFileTypes</key>
                    <array>
                        <string>public.movie</string>
                        <string>public.video</string>
                        <string>public.folder</string>
                    </array>
                </dict>
            </array>
        </dict>
        </plist>
        """
        try infoPlist.write(to: contentsDir.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)

        let documentWflow = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>AMApplicationBuild</key>
            <string>523</string>
            <key>AMApplicationVersion</key>
            <string>2.10</string>
            <key>AMDocumentVersion</key>
            <string>2</string>
            <key>actions</key>
            <array>
                <dict>
                    <key>action</key>
                    <dict>
                        <key>AMAccepts</key>
                        <dict>
                            <key>Container</key>
                            <string>List</string>
                            <key>Optional</key>
                            <true/>
                            <key>Types</key>
                            <array>
                                <string>com.apple.cocoa.path</string>
                            </array>
                        </dict>
                        <key>AMActionVersion</key>
                        <string>2.0.3</string>
                        <key>AMApplication</key>
                        <array>
                            <string>Automator</string>
                        </array>
                        <key>AMParameterProperties</key>
                        <dict>
                            <key>COMMAND_STRING</key>
                            <dict/>
                            <key>CheckedForUserDefaultShell</key>
                            <dict/>
                            <key>inputMethod</key>
                            <dict/>
                            <key>shell</key>
                            <dict/>
                            <key>source</key>
                            <dict/>
                        </dict>
                        <key>AMProvides</key>
                        <dict>
                            <key>Container</key>
                            <string>List</string>
                            <key>Types</key>
                            <array>
                                <string>com.apple.cocoa.path</string>
                            </array>
                        </dict>
                        <key>ActionBundlePath</key>
                        <string>/System/Library/Automator/Run Shell Script.action</string>
                        <key>ActionName</key>
                        <string>Executar Script Shell</string>
                        <key>ActionParameters</key>
                        <dict>
                            <key>COMMAND_STRING</key>
                            <string>"\(currentExecPath)" --headless "$@"</string>
                            <key>CheckedForUserDefaultShell</key>
                            <true/>
                            <key>inputMethod</key>
                            <integer>1</integer>
                            <key>shell</key>
                            <string>/bin/zsh</string>
                            <key>source</key>
                            <string></string>
                        </dict>
                        <key>BundleIdentifier</key>
                        <string>com.apple.RunShellScript</string>
                        <key>CFBundleVersion</key>
                        <string>2.0.3</string>
                        <key>CanShowSelectedItemsWhenRun</key>
                        <false/>
                        <key>CanShowWhenRun</key>
                        <true/>
                        <key>Category</key>
                        <array>
                            <string>AMCategoryUtilities</string>
                        </array>
                        <key>Class Name</key>
                        <string>RunShellScriptAction</string>
                        <key>InputUUID</key>
                        <string>8A9014C1-1288-404A-8D2B-9A4B4E8A1101</string>
                        <key>Keywords</key>
                        <array>
                            <string>Shell</string>
                            <string>Script</string>
                        </array>
                        <key>OutputUUID</key>
                        <string>9B8025D2-2399-515B-9E3C-AB5C5F9B2202</string>
                        <key>UUID</key>
                        <string>7C7036E3-34AA-626C-AF4D-BC6D60AC3303</string>
                        <key>UnlocalizedApplications</key>
                        <array>
                            <string>Automator</string>
                        </array>
                    </dict>
                </dict>
            </array>
            <key>connectors</key>
            <dict/>
            <key>workflowMetaData</key>
            <dict>
                <key>workflowTypeIdentifier</key>
                <string>com.apple.Automator.servicesMenu</string>
                <key>serviceInputTypeIdentifier</key>
                <string>com.apple.Automator.fileSystemObject.movie</string>
                <key>serviceOutputTypeIdentifier</key>
                <string>com.apple.Automator.nothing</string>
                <key>serviceProcessesInput</key>
                <integer>0</integer>
                <key>systemImageName</key>
                <string>NSActionTemplate</string>
                <key>useAutomaticInputType</key>
                <integer>0</integer>
            </dict>
        </dict>
        </plist>
        """
        try documentWflow.write(to: contentsDir.appendingPathComponent("document.wflow"), atomically: true, encoding: .utf8)

        // Atualiza o registro de serviços do macOS
        let pbs = Process()
        pbs.executableURL = URL(fileURLWithPath: "/System/Library/CoreServices/pbs")
        pbs.arguments = ["-update"]
        try? pbs.run()

        return workflowURL
    }
}

/// Provedor de Serviço Nativo do macOS (Menu Serviços / Finder Quick Actions)
final class MacServiceProvider: NSObject {
    @objc func createContactSheetService(
        _ pboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        guard let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty else {
            return
        }

        Task { @MainActor in
            let saved = await QuickActionAutomation.generateSheetsHeadless(for: urls)
            if let last = saved.last {
                NSSound(named: "Glass")?.play()
                NSWorkspace.shared.activateFileViewerSelecting([last])
            }
        }
    }
}
