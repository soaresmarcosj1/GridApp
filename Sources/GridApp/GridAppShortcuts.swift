import Foundation
import AppIntents
import AppKit

@available(macOS 14.0, *)
struct CreateContactSheetIntent: AppIntent {
    static var title: LocalizedStringResource = "Criar Contact Sheet de Vídeo"
    static var description = IntentDescription("Gera automaticamente uma Contact Sheet (grade de capturas) para um ou mais arquivos de vídeo usando suas configurações do GridApp, sem precisar abrir a interface.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Arquivos de Vídeo")
    var videos: [IntentFile]

    @Parameter(title: "Nome do Modelo (Opcional)", description: "Ex: Padrão Full HD, Cinema 4K, Retrato 4:5 ou o nome de um modelo salvo por você.")
    var presetName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[IntentFile]> {
        let urls = videos.compactMap { $0.fileURL }
        let savedURLs = await QuickActionAutomation.generateSheetsHeadless(
            for: urls,
            presetNameOverride: presetName
        )
        let outputFiles = savedURLs.map { IntentFile(fileURL: $0) }
        return .result(value: outputFiles)
    }
}

@available(macOS 14.0, *)
struct GridAppShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateContactSheetIntent(),
            phrases: [
                "Criar Contact Sheet no \(.applicationName)",
                "Gerar grade de vídeo com \(.applicationName)"
            ],
            shortTitle: "Criar Contact Sheet",
            systemImageName: "square.grid.3x3.fill"
        )
    }
}
