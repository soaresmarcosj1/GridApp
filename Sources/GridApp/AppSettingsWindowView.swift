// GridApp — Copyright (C) 2026 Marcos (soaresmarcosj1)
// Licensed under the GNU General Public License v3.0 (GPL-3.0-or-later).
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import AppKit

enum AppPreferencesSection: String, CaseIterable, Identifiable {
    case general = "Geral"
    case appearance = "Aparência"
    case shortcutsAndFinder = "Atalhos & Finder"
    case performance = "Leitura & Refinamento"
    case presets = "Modelos Salvos"
    case engines = "Motores de Vídeo"
    case about = "Sobre"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "slider.horizontal.2.square"
        case .shortcutsAndFinder: return "wand.and.stars"
        case .performance: return "bolt.fill"
        case .presets: return "bookmark"
        case .engines: return "cpu"
        case .about: return "info.circle"
        }
    }

    var searchKeywords: String {
        switch self {
        case .general: return "geral pasta destino salvar sufixo finder restaurar padrão"
        case .appearance: return "aparência tema cor cores modo claro escuro sistema compacto normal espaçoso fonte texto tamanho"
        case .shortcutsAndFinder: return "atalhos finder ação rápida quick action serviços automator cli sem abrir app"
        case .performance: return "leitura refinamento velocidade rápida precisa exportar qualidade"
        case .presets: return "modelos salvos presets configurações"
        case .engines: return "motores video avfoundation ffmpeg ffprobe codec"
        case .about: return "sobre versão gridapp"
        }
    }
}

struct AppSettingsWindowView: View {
    @ObservedObject var viewModel: AppViewModel

    private var accentColor: Color {
        viewModel.settings.appThemeColor.color
    }

    private var filteredSections: [AppPreferencesSection] {
        let query = viewModel.preferencesSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return AppPreferencesSection.allCases }
        return AppPreferencesSection.allCases.filter {
            $0.rawValue.lowercased().contains(query) || $0.searchKeywords.contains(query)
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebarMenu
        } detail: {
            detailContent
        }
        .frame(minWidth: 720, idealWidth: 740, minHeight: 500, idealHeight: 520)
        .tint(accentColor)
        .dynamicTypeSize(viewModel.settings.appUIDensity.dynamicTypeSize)
        .preferredColorScheme(viewModel.settings.appColorScheme.preferredColorScheme)
        .onChange(of: viewModel.settings) { _, _ in
            viewModel.refreshAllRenderedSheets()
        }
    }

    // MARK: - Menu Lateral Estilo macOS Settings (Imagem 4)
    private var sidebarMenu: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Campo de Pesquisa Arredondado no Topo da Sidebar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Pesquisar", text: $viewModel.preferencesSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !viewModel.preferencesSearchText.isEmpty {
                    Button {
                        viewModel.preferencesSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.07), in: Capsule())
            .padding(.bottom, 6)

            ForEach(filteredSections) { section in
                let active = (viewModel.selectedPreferencesSection == section)
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.selectedPreferencesSection = section
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: section.icon)
                            .font(.system(size: 15, weight: .medium))
                            .frame(width: 22)
                            .foregroundStyle(active ? accentColor : .secondary)

                        Text(section.rawValue)
                            .font(.system(size: 13, weight: active ? .semibold : .regular))
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(active ? Color.primary.opacity(0.11) : Color.clear)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .frame(minWidth: 205, idealWidth: 215, maxWidth: 230)
        .background(.ultraThinMaterial)
    }

    // MARK: - Painel Direito de Conteúdo da Categoria Selecionada
    private var detailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(viewModel.selectedPreferencesSection.rawValue)
                    .font(.system(size: 20, weight: .bold))
                    .padding(.bottom, 2)

                switch viewModel.selectedPreferencesSection {
                case .general:
                    generalSectionView
                case .appearance:
                    appearanceSectionView
                case .shortcutsAndFinder:
                    shortcutsAndFinderSectionView
                case .performance:
                    performanceSectionView
                case .presets:
                    presetsManagementView
                case .engines:
                    enginesSectionView
                case .about:
                    aboutSectionView
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - 1. Geral
    private var generalSectionView: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsGroup {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pasta padrão de exportação")
                                .font(.system(size: 14, weight: .medium))
                            Text("Onde salvar as Contact Sheets ao clicar em Salvar.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $viewModel.settings.saveDestinationMode) {
                            ForEach(SaveDestinationMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 230)
                    }

                    if viewModel.settings.saveDestinationMode == .customFolder {
                        Divider()
                        HStack(spacing: 10) {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(accentColor)
                            Text(viewModel.settings.customExportFolderURL?.path ?? "Nenhuma pasta selecionada")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button {
                                viewModel.chooseCustomExportFolder()
                            } label: {
                                Text("Escolher Pasta...")
                                    .font(.system(size: 12, weight: .semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(accentColor.opacity(0.15), in: Capsule())
                                    .foregroundStyle(accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sufixo do arquivo exportado")
                                .font(.system(size: 14, weight: .medium))
                            Text("Adicionado automaticamente ao nome do vídeo original.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        TextField("-sheet", text: $viewModel.settings.fileSuffix)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13, design: .monospaced))
                            .frame(width: 130)
                    }

                    Divider()

                    Toggle(isOn: $viewModel.settings.revealInFinderAfterExport) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mostrar arquivo no Finder após exportar")
                                .font(.system(size: 14, weight: .medium))
                            Text("Abre automaticamente a pasta com a Contact Sheet selecionada.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }
            }

            settingsGroup {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Restaurar configurações padrão")
                            .font(.system(size: 14, weight: .medium))
                        Text("Redefine layout, cabeçalho e preferências para os valores de fábrica.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        viewModel.resetSettingsToDefault()
                    } label: {
                        Text("Restaurar Padrão")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.09), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 2. Aparência (Temas, Modo Claro/Escuro, Cores do App e da Sheet)
    private var appearanceSectionView: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsGroup {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aparência do Aplicativo")
                            .font(.system(size: 14, weight: .medium))
                        Text("Escolha entre o modo claro, escuro ou sincronizado com o macOS.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        ForEach(AppColorSchemePreference.allCases) { mode in
                            let active = (viewModel.settings.appColorScheme == mode)
                            Button {
                                viewModel.settings.appColorScheme = mode
                                viewModel.persistCurrentSettings()
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: mode.icon)
                                        .font(.system(size: 20, weight: .semibold))
                                    Text(mode.rawValue)
                                        .font(.system(size: 12, weight: active ? .semibold : .medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(active ? accentColor.opacity(0.16) : Color.primary.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(active ? accentColor : Color.primary.opacity(0.08), lineWidth: active ? 2 : 1)
                                )
                                .foregroundStyle(active ? accentColor : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Densidade de Visualização e Tamanho dos Textos")
                            .font(.system(size: 14, weight: .medium))
                        Text("Ajusta o tamanho das fontes, botões e espaçamentos em todo o aplicativo.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            ForEach(AppUIDensity.allCases) { density in
                                let active = (viewModel.settings.appUIDensity == density)
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        viewModel.settings.appUIDensity = density
                                        viewModel.persistCurrentSettings()
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: density.icon)
                                            .font(.system(size: 18, weight: .semibold))
                                        Text(density.rawValue)
                                            .font(.system(size: 13, weight: active ? .bold : .semibold))
                                        Text(density.subtitle)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(active ? accentColor.opacity(0.16) : Color.primary.opacity(0.05))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(active ? accentColor : Color.primary.opacity(0.08), lineWidth: active ? 2 : 1)
                                    )
                                    .foregroundStyle(active ? accentColor : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Cor de Destaque (Tema do App)")
                            .font(.system(size: 14, weight: .medium))
                        Text("Personaliza a cor dos botões, seletores e destaques na interface.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            ForEach(AppThemeColor.allCases) { theme in
                                let active = (viewModel.settings.appThemeColor == theme)
                                Button {
                                    viewModel.settings.appThemeColor = theme
                                    viewModel.persistCurrentSettings()
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(theme.color)
                                            .frame(width: 28, height: 28)
                                            .shadow(color: theme.color.opacity(0.4), radius: 3, x: 0, y: 2)

                                        if active {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .padding(3)
                                    .overlay(
                                        Circle()
                                            .stroke(active ? theme.color : Color.clear, lineWidth: 2)
                                    )
                                }
                                .buttonStyle(.plain)
                                .help(theme.rawValue)
                            }
                            Spacer()
                        }
                    }
                }
            }

            settingsGroup {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Temas Rápidos para a Contact Sheet")
                        .font(.system(size: 14, weight: .medium))
                    Text("Aplique combinações prontas de cores de fundo e texto para a imagem gerada.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        sheetPaletteButton(
                            title: "Grafite Escuro",
                            bg: CodableRGBA(red: 0.10, green: 0.11, blue: 0.13),
                            fg: CodableRGBA(red: 1.0, green: 1.0, blue: 1.0)
                        )
                        sheetPaletteButton(
                            title: "Preto OLED",
                            bg: CodableRGBA(red: 0.03, green: 0.03, blue: 0.04),
                            fg: CodableRGBA(red: 0.96, green: 0.96, blue: 0.98)
                        )
                        sheetPaletteButton(
                            title: "Azul Noturno",
                            bg: CodableRGBA(red: 0.07, green: 0.10, blue: 0.18),
                            fg: CodableRGBA(red: 0.94, green: 0.97, blue: 1.0)
                        )
                        sheetPaletteButton(
                            title: "Papel Claro",
                            bg: CodableRGBA(red: 0.96, green: 0.96, blue: 0.97),
                            fg: CodableRGBA(red: 0.12, green: 0.12, blue: 0.14)
                        )
                    }
                }
            }
        }
    }

    private func sheetPaletteButton(title: String, bg: CodableRGBA, fg: CodableRGBA) -> some View {
        Button {
            viewModel.settings.backgroundRGBA = bg
            viewModel.settings.textRGBA = fg
            viewModel.refreshAllRenderedSheets()
        } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(bg.swiftUIColor)
                    .frame(height: 36)
                    .overlay(
                        Text("Aa")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(fg.swiftUIColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                    )
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 3. Atalhos & Finder (Executar sem abrir o app)
    private var shortcutsAndFinderSectionView: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsGroup {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "cursorarrow.click.2")
                            .font(.system(size: 22))
                            .foregroundStyle(accentColor)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Ação Rápida no Finder (Clique Direito)")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Clique com o botão direito em qualquer vídeo ou pasta no Finder e escolha 'Ações Rápidas → Criar Contact Sheet (GridApp)'. A imagem será salva direto na pasta sem abrir a janela do aplicativo!")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Divider()

                    HStack {
                        Button {
                            do {
                                let url = try QuickActionAutomation.installFinderQuickAction()
                                viewModel.statusMessage = "Ação Rápida instalada em \(url.lastPathComponent)"
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            } catch {
                                viewModel.errorMessage = error.localizedDescription
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                Text("Reinstalar / Mostrar Ação Rápida do Finder")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(accentColor, in: Capsule())
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                }
            }

            settingsGroup {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "square.stack.3d.up.badge.a.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(accentColor)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Integração com o App Atalhos (Apple Shortcuts)")
                                .font(.system(size: 14, weight: .semibold))
                            Text("O GridApp inclui a ação nativa 'Criar Contact Sheet de Vídeo' para o app Atalhos do macOS (openAppWhenRun = false). Você pode criar automações em segundo plano e escolher qual Modelo usar.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Divider()

                    Toggle(isOn: $viewModel.settings.autoExportOnFinderOpen) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Gerar e salvar automaticamente ao abrir vídeo com o GridApp")
                                .font(.system(size: 14, weight: .medium))
                            Text("Quando ativado, usar 'Abrir Com → GridApp' no Finder gera e salva a Contact Sheet imediatamente na mesma pasta.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .toggleStyle(.switch)
                }
            }

            settingsGroup {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Execução Direta via Terminal / Scripts (Headless)")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Você também pode gerar sheets em segundo plano sem abrir janela via linha de comando:")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Text("\"\(Bundle.main.executablePath ?? "/Applications/GridApp.app/Contents/MacOS/GridApp")\" --headless /caminho/do/video.mp4")
                        .font(.system(size: 11, design: .monospaced))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - 4. Leitura & Refinamento
    private var performanceSectionView: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsGroup {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Velocidade de Leitura na Importação")
                            .font(.system(size: 14, weight: .medium))
                        Text("Define a rapidez com que os vídeos são lidos ao serem adicionados na fila.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        ForEach(ProcessingSpeed.allCases) { speed in
                            let active = (viewModel.settings.processingSpeed == speed)
                            Button {
                                viewModel.settings.processingSpeed = speed
                                viewModel.regenerateAllFramesForCountChange()
                            } label: {
                                Text(speed.shortLabel)
                                    .font(.system(size: 13, weight: active ? .semibold : .medium))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .background(
                                        Capsule()
                                            .fill(active ? accentColor : Color.primary.opacity(0.08))
                                    )
                                    .foregroundStyle(active ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text(viewModel.settings.processingSpeed.descriptionText)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            settingsGroup {
                Toggle(isOn: $viewModel.settings.reExtractHighQualityOnExport) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Refinar em Alta Qualidade ao Exportar")
                            .font(.system(size: 14, weight: .medium))
                        Text("Relê o vídeo original no momento de salvar usando precisão máxima de tempo (0.01s), filtro Lanczos e resolução nativa para nitidez máxima.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.switch)
            }
        }
    }

    // MARK: - 4. Modelos Salvos
    private var presetsManagementView: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsGroup {
                let customPresets = viewModel.presets.filter { !$0.isBuiltIn }
                VStack(alignment: .leading, spacing: 12) {
                    if customPresets.isEmpty {
                        Text("Nenhum modelo personalizado salvo ainda. Você pode salvar qualquer combinação de layout, cabeçalho e cores para aplicar com 1 clique.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(customPresets) { preset in
                            HStack(spacing: 10) {
                                Image(systemName: viewModel.activePresetID == preset.id ? "checkmark.circle.fill" : "bookmark.circle")
                                    .foregroundStyle(viewModel.activePresetID == preset.id ? accentColor : .secondary)
                                    .font(.system(size: 16))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.name)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("\(preset.settings.columns) col • \(preset.settings.frameCount) fotos • \(preset.settings.sheetAspectPreset.rawValue)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button {
                                    viewModel.applyPreset(preset)
                                } label: {
                                    Text("Aplicar")
                                        .font(.system(size: 12, weight: .semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 5)
                                        .background(accentColor.opacity(0.14), in: Capsule())
                                        .foregroundStyle(accentColor)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    viewModel.deletePreset(preset)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12, weight: .semibold))
                                        .padding(7)
                                        .background(Color.red.opacity(0.14), in: Circle())
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(10)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }

                    Button {
                        viewModel.newPresetName = ""
                        viewModel.isShowingSavePresetSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Salvar Configuração Atual como Modelo...")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(accentColor, in: Capsule())
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 5. Motores de Vídeo
    private var enginesSectionView: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsGroup {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Apple AVFoundation + VideoToolbox")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Aceleração nativa de hardware para MP4, MOV, M4V, H.264, HEVC e ProRes.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    HStack(spacing: 12) {
                        if let ffmpeg = VideoProcessor.ffmpegPath {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 20))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("FFmpeg / FFprobe Multithread")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Ativo em \(ffmpeg) para MKV, AVI, WebM, FLV e exportação WebP.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.system(size: 20))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("FFmpeg Não Encontrado")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Instale com 'brew install ffmpeg' para suporte a MKV, AVI e WebM.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 6. Sobre
    private var aboutSectionView: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsGroup {
                HStack(spacing: 16) {
                    if Bundle.main.url(forResource: "Assets", withExtension: "car") != nil {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 72, height: 72)
                    } else if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
                              let appIcon = NSImage(contentsOf: iconURL) {
                        Image(nsImage: appIcon)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 72, height: 72)
                    } else {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 72, height: 72)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("GridApp para macOS")
                            .font(.system(size: 17, weight: .bold))
                        Text("Versão \((Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.1.0") (Pré-release • Apple Silicon Native)")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Text("Gerador rápido e personalizável de Contact Sheets para qualquer formato de vídeo.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            settingsGroup {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Copyright © 2026 Marcos (soaresmarcosj1)")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Distribuído sob a licença GNU General Public License v3.0 (GPLv3). Este é um software livre fornecido sem garantias; modificações redistribuídas devem manter a mesma licença.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
}
