// GridApp — Copyright (C) 2026 Marcos (soaresmarcosj1)
// Licensed under the GNU General Public License v3.0 (GPL-3.0-or-later).
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import AppKit

struct AppMenuCommands: Commands {
    @ObservedObject var viewModel: AppViewModel

    var body: some Commands {
        // Menu GridApp -> Sobre o GridApp
        CommandGroup(replacing: .appInfo) {
            Button("Sobre o GridApp") {
                NSApplication.shared.orderFrontStandardAboutPanel(
                    options: [
                        NSApplication.AboutPanelOptionKey.applicationName: "GridApp",
                        NSApplication.AboutPanelOptionKey.applicationVersion: (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.1.0",
                        NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "Copyright © 2026 Marcos (soaresmarcosj1) • Licenciado sob GNU GPLv3"
                    ]
                )
            }
        }

        // Menu GridApp -> Configurações... (⌘,) seguindo o padrão Apple HIG
        CommandGroup(replacing: .appSettings) {
            Button("Configurações do GridApp...") {
                viewModel.openAppSettingsWindow()
            }
            .keyboardShortcut(",", modifiers: [.command])
        }

        // Menu Arquivo
        CommandGroup(replacing: .newItem) {
            Button("Adicionar Vídeos...") {
                viewModel.openFilePicker()
            }
            .keyboardShortcut("o", modifiers: [.command])

            Divider()

            Button("Salvar Contact Sheet Atual") {
                viewModel.exportCurrentSheet(forceSavePanel: false)
            }
            .keyboardShortcut("s", modifiers: [.command])
            .disabled(viewModel.selectedVideo == nil || viewModel.isExportingSingle)

            Button("Salvar Como...") {
                viewModel.exportCurrentSheet(forceSavePanel: true)
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(viewModel.selectedVideo == nil || viewModel.isExportingSingle)

            if viewModel.videos.count > 1 {
                Button(
                    viewModel.checkedVideos.isEmpty
                        ? "Exportar Todos da Fila (\(viewModel.videos.count))..."
                        : "Exportar Vídeos Selecionados (\(viewModel.checkedVideos.count))..."
                ) {
                    viewModel.exportSelectedOrAllVideos(forceChooseFolder: false)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(viewModel.isBatchExporting || viewModel.isExportingSingle)
            }

            Divider()

            Button("Mostrar Vídeo Original no Finder") {
                viewModel.revealCurrentVideoInFinder()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(viewModel.selectedVideo == nil)
        }

        // Menu Editar
        CommandGroup(after: .pasteboard) {
            Button("Copiar Contact Sheet") {
                viewModel.copyCurrentSheetToClipboard()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(viewModel.selectedVideo?.renderedSheet == nil)

            Divider()

            Button("Selecionar Todos os Vídeos da Fila") {
                viewModel.selectAllVideos()
            }
            .keyboardShortcut("a", modifiers: [.command, .option])
            .disabled(viewModel.videos.isEmpty)

            Button("Desmarcar Todos os Vídeos") {
                viewModel.deselectAllVideos()
            }
            .disabled(viewModel.checkedVideoIDs.isEmpty)

            Button("Inverter Seleção da Fila") {
                viewModel.invertVideoSelection()
            }
            .disabled(viewModel.videos.isEmpty)

            Divider()

            Button(
                viewModel.checkedVideoIDs.isEmpty
                    ? "Remover Vídeo Atual da Fila"
                    : "Remover Vídeos Selecionados (\(viewModel.checkedVideoIDs.count))"
            ) {
                viewModel.removeCheckedOrCurrentVideo()
            }
            .keyboardShortcut(.delete, modifiers: [.command])
            .disabled(viewModel.videos.isEmpty)

            Button("Limpar Toda a Fila") {
                viewModel.clearAllVideos()
            }
            .disabled(viewModel.videos.isEmpty)
        }

        // Menu Visualizar (Abas + Zoom)
        CommandGroup(after: .toolbar) {
            Button("Aba: Ajustes & Design") {
                viewModel.selectedInspectorTab = .adjustments
            }
            .keyboardShortcut("1", modifiers: [.command])

            Button("Aba: Exportação") {
                viewModel.selectedInspectorTab = .export
            }
            .keyboardShortcut("2", modifiers: [.command])

            Divider()

            Button("Aumentar Zoom") {
                viewModel.zoomScale = min(4.0, viewModel.zoomScale + 0.25)
            }
            .keyboardShortcut("+", modifiers: [.command])
            .disabled(viewModel.selectedVideo == nil)

            Button("Diminuir Zoom") {
                viewModel.zoomScale = max(0.4, viewModel.zoomScale - 0.25)
            }
            .keyboardShortcut("-", modifiers: [.command])
            .disabled(viewModel.selectedVideo == nil)

            Button("Tamanho Real (100%)") {
                viewModel.zoomScale = 1.0
            }
            .keyboardShortcut("0", modifiers: [.command])
            .disabled(viewModel.selectedVideo == nil)

            Divider()

            Menu("Densidade de Visualização") {
                ForEach(AppUIDensity.allCases) { density in
                    Button {
                        viewModel.settings.appUIDensity = density
                        viewModel.persistCurrentSettings()
                    } label: {
                        if viewModel.settings.appUIDensity == density {
                            Text("✓ \(density.rawValue) (\(density.subtitle))")
                        } else {
                            Text("\(density.rawValue) (\(density.subtitle))")
                        }
                    }
                }
            }
        }

        // Menu Customizado "Captura"
        CommandMenu("Captura") {
            Button("Recapturar Frames do Vídeo Atual") {
                if let selected = viewModel.selectedVideo {
                    Task {
                        await viewModel.extractFrames(for: selected)
                    }
                }
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(viewModel.selectedVideo == nil)

            Button("Recapturar Todos os Vídeos da Fila") {
                viewModel.regenerateAllFramesForCountChange()
            }
            .disabled(viewModel.videos.isEmpty)

            Divider()

            Menu("Proporção de Layout da Sheet") {
                ForEach(SheetAspectPreset.allCases) { preset in
                    Button {
                        viewModel.settings.sheetAspectPreset = preset
                        viewModel.refreshAllRenderedSheets()
                    } label: {
                        if viewModel.settings.sheetAspectPreset == preset {
                            Text("✓ \(preset.rawValue)")
                        } else {
                            Text(preset.rawValue)
                        }
                    }
                }
            }

            Menu("Proporção de Cada Imagem no Grid") {
                ForEach(ThumbnailAspectMode.allCases) { mode in
                    Button {
                        viewModel.settings.thumbnailAspectMode = mode
                        viewModel.refreshAllRenderedSheets()
                    } label: {
                        if viewModel.settings.thumbnailAspectMode == mode {
                            Text("✓ \(mode.rawValue)")
                        } else {
                            Text(mode.rawValue)
                        }
                    }
                }
            }

            Menu("Quantidade de Imagens") {
                ForEach([4, 9, 12, 16, 20, 24, 30, 36, 48], id: \.self) { count in
                    Button {
                        viewModel.settings.frameCount = count
                        viewModel.regenerateAllFramesForCountChange()
                    } label: {
                        if viewModel.settings.frameCount == count {
                            Text("✓ \(count) imagens")
                        } else {
                            Text("\(count) imagens")
                        }
                    }
                }
            }

            Menu("Colunas da Grade") {
                ForEach(1...8, id: \.self) { cols in
                    Button {
                        viewModel.settings.columns = cols
                        viewModel.refreshAllRenderedSheets()
                    } label: {
                        if viewModel.settings.columns == cols {
                            Text("✓ \(cols) colunas")
                        } else {
                            Text("\(cols) colunas")
                        }
                    }
                }
            }

            Divider()

            Toggle("Exibir Cabeçalho Técnico", isOn: $viewModel.settings.showHeader)
            Toggle("Exibir Timestamps nas Miniaturas", isOn: $viewModel.settings.showTimestamps)

            Divider()

            Button("Aparência e Temas do App...") {
                viewModel.selectedPreferencesSection = .appearance
                viewModel.openAppSettingsWindow()
            }

            Button("Configurações de Leitura e Refinamento...") {
                viewModel.selectedPreferencesSection = .performance
                viewModel.openAppSettingsWindow()
            }
        }

        // Menu Customizado "Modelos"
        CommandMenu("Modelos") {
            Button("Salvar Configuração Atual como Modelo...") {
                viewModel.newPresetName = ""
                viewModel.isShowingSavePresetSheet = true
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])

            Divider()

            ForEach(viewModel.presets) { preset in
                Button {
                    viewModel.applyPreset(preset)
                } label: {
                    if viewModel.activePresetID == preset.id {
                        Text("✓ \(preset.name)")
                    } else {
                        Text(preset.name)
                    }
                }
            }

            Divider()

            Button("Gerenciar Modelos Salvos...") {
                viewModel.selectedPreferencesSection = .presets
                viewModel.openAppSettingsWindow()
            }

            Button("Restaurar Configurações Padrão") {
                viewModel.resetSettingsToDefault()
            }
        }
    }
}
