import SwiftUI

struct SettingsInspectorView: View {
    @ObservedObject var viewModel: AppViewModel

    private let resolutionPresets = [
        ("HD (1280 px)", 1280),
        ("Full HD (1920 px)", 1920),
        ("QHD / 2K (2560 px)", 2560),
        ("4K UHD (3840 px)", 3840),
        ("5K (5120 px)", 5120)
    ]

    private var density: AppUIDensity {
        viewModel.settings.appUIDensity
    }

    private func fs(_ base: CGFloat) -> CGFloat {
        max(base + density.fontDelta, 9)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Barra de Modelos de Configuração (Presets) + 2 Abas (Ajustes & Design | Exportação)
            VStack(spacing: density == .compact ? 9 : 12) {
                presetsHeaderBar
                tabSelectorHeader
            }
            .padding(.horizontal, density.cardPadding)
            .padding(.vertical, density == .compact ? 10 : 14)
            .background(.ultraThinMaterial)

            Divider()

            // Conteúdo rolável da aba ativa
            ScrollView {
                VStack(alignment: .leading, spacing: density.sectionSpacing) {
                    switch viewModel.selectedInspectorTab {
                    case .adjustments:
                        adjustmentsAndDesignTabContent
                    case .export:
                        exportTabContent
                    }
                }
                .padding(density.cardPadding)
            }

            Divider()

            // Rodapé Principal de Exportação
            quickExportFooter
                .padding(density.cardPadding)
                .background(.ultraThinMaterial)
        }
        .frame(
            minWidth: density == .spacious ? 385 : 355,
            idealWidth: density == .spacious ? 410 : 380,
            maxWidth: density == .spacious ? 445 : 420
        )
        .background(.regularMaterial)
        .dynamicTypeSize(density.dynamicTypeSize)
        .onChange(of: viewModel.settings) { _, _ in
            viewModel.refreshAllRenderedSheets()
        }
        .sheet(isPresented: $viewModel.isShowingSavePresetSheet) {
            SavePresetModalView(viewModel: viewModel)
        }
    }

    // MARK: - Barra de Modelos de Configuração (Presets) — Sem sobreposição ou borda dupla
    private var presetsHeaderBar: some View {
        HStack(spacing: 8) {
            Menu {
                Section("Modelos Padrão") {
                    ForEach(viewModel.presets.filter { $0.isBuiltIn }) { preset in
                        Button {
                            viewModel.applyPreset(preset)
                        } label: {
                            HStack {
                                Text(preset.name)
                                if viewModel.activePresetID == preset.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                let customList = viewModel.presets.filter { !$0.isBuiltIn }
                if !customList.isEmpty {
                    Section("Meus Modelos Salvos") {
                        ForEach(customList) { preset in
                            Button {
                                viewModel.applyPreset(preset)
                            } label: {
                                HStack {
                                    Text(preset.name)
                                    if viewModel.activePresetID == preset.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }

                Divider()

                Button {
                    viewModel.newPresetName = ""
                    viewModel.isShowingSavePresetSheet = true
                } label: {
                    Label("Salvar Configuração Atual como Modelo...", systemImage: "plus.circle")
                }

                if let activeID = viewModel.activePresetID,
                   let activePreset = viewModel.presets.first(where: { $0.id == activeID && !$0.isBuiltIn }) {
                    Button {
                        viewModel.updatePresetWithCurrentSettings(activePreset)
                    } label: {
                        Label("Atualizar Modelo \"\(activePreset.name)\"", systemImage: "arrow.triangle.2.circlepath")
                    }

                    Button(role: .destructive) {
                        viewModel.deletePreset(activePreset)
                    } label: {
                        Label("Excluir Modelo \"\(activePreset.name)\"", systemImage: "trash")
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(viewModel.settings.appThemeColor.color)
                        .font(.system(size: 13, weight: .semibold))
                    Text(currentPresetTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(Color.primary.opacity(0.07), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Button {
                viewModel.newPresetName = ""
                viewModel.isShowingSavePresetSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 36, height: 36)
                    .background(Color.primary.opacity(0.07), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help("Salvar configuração atual como um novo modelo")
        }
    }

    private var currentPresetTitle: String {
        if let id = viewModel.activePresetID,
           let preset = viewModel.presets.first(where: { $0.id == id }) {
            return preset.name
        }
        return "Escolher Modelo..."
    }

    // MARK: - Seletor de 2 Abas (Ajustes & Design | Exportação)
    private var tabSelectorHeader: some View {
        HStack(spacing: 6) {
            ForEach(InspectorTab.allCases) { tab in
                let isSelected = (viewModel.selectedInspectorTab == tab)
                let themeColor = viewModel.settings.appThemeColor.color
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        viewModel.selectedInspectorTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: fs(13), weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: fs(13), weight: isSelected ? .semibold : .medium))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, density == .compact ? 6 : 9)
                    .background(
                        Capsule()
                            .fill(isSelected ? themeColor : Color.clear)
                    )
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - ABA 1 MESCLADA: AJUSTES & DESIGN
    private var adjustmentsAndDesignTabContent: some View {
        VStack(alignment: .leading, spacing: density.sectionSpacing) {
            // Card 1: Grade & Quantidade
            groupCard(title: "Grade & Quantidade", icon: "square.grid.3x3.fill") {
                VStack(alignment: .leading, spacing: density == .compact ? 8 : 14) {
                    HStack {
                        Text("Quantidade de Imagens")
                            .font(.system(size: fs(14), weight: .medium))
                        Spacer()
                        Text("\(viewModel.settings.frameCount) frames")
                            .font(.system(size: fs(14), weight: .bold, design: .rounded))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                        ForEach([4, 9, 12, 16, 20, 24, 30, 36], id: \.self) { preset in
                            let active = (viewModel.settings.frameCount == preset)
                            Button {
                                viewModel.settings.frameCount = preset
                                viewModel.regenerateAllFramesForCountChange()
                            } label: {
                                Text("\(preset)")
                                    .font(.system(size: fs(14), weight: .semibold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: density.controlHeight)
                                    .background(
                                        Capsule()
                                            .fill(active ? Color.accentColor : Color.primary.opacity(0.08))
                                    )
                                    .foregroundStyle(active ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Divider()

                    HStack {
                        Text("Ajuste fino de frames")
                            .font(.system(size: fs(13)))
                        Spacer()
                        Stepper(
                            "\(viewModel.settings.frameCount)",
                            value: Binding(
                                get: { viewModel.settings.frameCount },
                                set: { newVal in
                                    viewModel.settings.frameCount = max(1, min(120, newVal))
                                    viewModel.regenerateAllFramesForCountChange()
                                }
                            ),
                            in: 1...120
                        )
                        .font(.system(size: fs(13), weight: .semibold, design: .monospaced))
                    }

                    HStack {
                        Text("Número de Colunas")
                            .font(.system(size: fs(13)))
                        Spacer()
                        Stepper(
                            "\(viewModel.settings.columns) col",
                            value: $viewModel.settings.columns,
                            in: 1...10
                        )
                        .font(.system(size: fs(13), weight: .semibold, design: .monospaced))
                    }
                }
            }

            // Card 2: Tamanho da Imagem e Layouts Pré-definidos (16:9, 9:16, 4:5, 5:4, 1:1, Auto)
            groupCard(title: "Formato & Tamanho da Imagem", icon: "aspectratio.fill") {
                VStack(alignment: .leading, spacing: density == .compact ? 8 : 14) {
                    Text("Proporção / Layout da Folha:")
                        .font(.system(size: fs(13), weight: .medium))

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                        ForEach(SheetAspectPreset.allCases) { preset in
                            let active = (viewModel.settings.sheetAspectPreset == preset)
                            Button {
                                viewModel.settings.sheetAspectPreset = preset
                            } label: {
                                VStack(spacing: 2) {
                                    HStack(spacing: 4) {
                                        Image(systemName: preset.icon)
                                            .font(.system(size: fs(12), weight: .semibold))
                                        Text(preset.shortTitle)
                                            .font(.system(size: fs(13), weight: .bold, design: .rounded))
                                    }
                                    Text(preset.subtitle)
                                        .font(.system(size: fs(10), weight: .medium))
                                        .opacity(active ? 0.9 : 0.65)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, density == .compact ? 5 : 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(active ? Color.accentColor : Color.primary.opacity(0.08))
                                )
                                .foregroundStyle(active ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Divider()

                    // Opção de Tamanho / Proporção de Cada Imagem no Grid (Adaptar para Ocupar Folha, Original, 16:9, 4:3, 1:1)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tamanho de Cada Imagem no Grid:")
                            .font(.system(size: fs(13), weight: .medium))

                        HStack(spacing: 6) {
                            ForEach(ThumbnailAspectMode.allCases) { mode in
                                let active = (viewModel.settings.thumbnailAspectMode == mode)
                                Button {
                                    viewModel.settings.thumbnailAspectMode = mode
                                } label: {
                                    Text(mode.shortTitle)
                                        .font(.system(size: fs(12), weight: active ? .bold : .medium, design: .rounded))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: density.controlHeight)
                                        .background(
                                            Capsule()
                                                .fill(active ? Color.accentColor : Color.primary.opacity(0.08))
                                        )
                                        .foregroundStyle(active ? Color.white : Color.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text(viewModel.settings.thumbnailAspectMode.descriptionText)
                            .font(.system(size: fs(11)))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Divider()

                    HStack {
                        Text("Resolução Base (Largura)")
                            .font(.system(size: fs(13), weight: .medium))
                        Spacer()
                        if let rendered = viewModel.selectedVideo?.renderedSheet {
                            Text("\(Int(rendered.size.width)) × \(Int(rendered.size.height)) px")
                                .font(.system(size: fs(12), weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.accentColor)
                        } else {
                            Text("\(viewModel.settings.outputWidth) px")
                                .font(.system(size: fs(13), weight: .bold, design: .monospaced))
                        }
                    }

                    Picker("Resolução", selection: $viewModel.settings.outputWidth) {
                        ForEach(resolutionPresets, id: \.1) { label, width in
                            Text(label).tag(width)
                        }
                    }
                    .labelsHidden()
                    .controlSize(density == .compact ? .small : .regular)

                    Slider(
                        value: Binding(
                            get: { Double(viewModel.settings.outputWidth) },
                            set: { viewModel.settings.outputWidth = Int($0.rounded()) }
                        ),
                        in: 800...5120,
                        step: 80
                    )
                }
            }

            // Card 3: Design, Margens e Cores
            groupCard(title: "Design & Estilo Visual", icon: "paintbrush.pointed.fill") {
                VStack(alignment: .leading, spacing: density == .compact ? 8 : 12) {
                    sliderRow(
                        title: "Margem Externa",
                        value: $viewModel.settings.outerPadding,
                        range: 0...80,
                        unit: "px"
                    )

                    sliderRow(
                        title: "Espaçamento entre Fotos",
                        value: $viewModel.settings.spacing,
                        range: 0...48,
                        unit: "px"
                    )

                    sliderRow(
                        title: "Bordas Arredondadas",
                        value: $viewModel.settings.cornerRadius,
                        range: 0...32,
                        unit: "px"
                    )

                    sliderRow(
                        title: "Sombra das Miniaturas",
                        value: $viewModel.settings.shadowRadius,
                        range: 0...20,
                        unit: "px"
                    )

                    Divider()

                    HStack {
                        Text("Cor de Fundo da Sheet")
                            .font(.system(size: fs(13), weight: .medium))
                        Spacer()
                        ColorPicker("", selection: $viewModel.settings.backgroundColor)
                            .labelsHidden()
                    }

                    HStack {
                        Text("Cor do Texto")
                            .font(.system(size: fs(13), weight: .medium))
                        Spacer()
                        ColorPicker("", selection: $viewModel.settings.textColor)
                            .labelsHidden()
                    }
                }
            }

            // Card 4: Cabeçalho Técnico + Tipografia do Cabeçalho
            groupCard(title: "Cabeçalho Técnico & Texto", icon: "doc.text.image") {
                VStack(alignment: .leading, spacing: density == .compact ? 8 : 12) {
                    Toggle("Exibir Cabeçalho na Sheet", isOn: $viewModel.settings.showHeader)
                        .font(.system(size: fs(14), weight: .medium))

                    if viewModel.settings.showHeader {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Título Personalizado (opcional):")
                                .font(.system(size: fs(13)))
                                .foregroundStyle(.secondary)
                            TextField("Ex: Catálogo de Cenas", text: $viewModel.settings.customTitle)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: fs(13)))
                        }

                        Divider()

                        Text("Formatação do Texto do Cabeçalho:")
                            .font(.system(size: fs(13), weight: .semibold))
                            .foregroundStyle(.secondary)

                        stepperRow(
                            title: "Tamanho da Fonte do Título",
                            value: $viewModel.settings.headerTitleFontSize,
                            range: 12...48,
                            unit: "pt"
                        )

                        stepperRow(
                            title: "Tamanho da Fonte dos Dados",
                            value: $viewModel.settings.headerBodyFontSize,
                            range: 9...32,
                            unit: "pt"
                        )

                        stepperRow(
                            title: "Espaçamento entre Linhas",
                            value: $viewModel.settings.headerLineSpacing,
                            range: 0...28,
                            unit: "px"
                        )

                        sliderRow(
                            title: "Espaçamento Cabeçalho ↔ Grid",
                            value: $viewModel.settings.headerBottomSpacing,
                            range: 0...80,
                            unit: "px"
                        )

                        HStack {
                            Text("Alinhamento do Texto")
                                .font(.system(size: fs(13)))
                            Spacer()
                            HStack(spacing: 6) {
                                ForEach(HeaderTextAlignment.allCases) { align in
                                    let active = (viewModel.settings.headerTextAlignment == align)
                                    Button {
                                        viewModel.settings.headerTextAlignment = align
                                    } label: {
                                        Text(align.rawValue)
                                            .font(.system(size: fs(12), weight: active ? .semibold : .medium))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(
                                                Capsule()
                                                    .fill(active ? Color.accentColor : Color.primary.opacity(0.08))
                                            )
                                            .foregroundStyle(active ? Color.white : Color.primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Toggle("Exibir Moldura de Fundo no Cabeçalho", isOn: $viewModel.settings.showHeaderCardBackground)
                            .font(.system(size: fs(13)))

                        Divider()

                        Text("Informações Técnicas Exibidas:")
                            .font(.system(size: fs(13), weight: .semibold))
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: density == .compact ? 5 : 8) {
                            Toggle("Nome do Arquivo e Formato", isOn: $viewModel.settings.showFileName)
                            Toggle("Tamanho Exato (MB + Bytes) e Duração", isOn: Binding(
                                get: { viewModel.settings.showFileSize || viewModel.settings.showDuration },
                                set: { val in
                                    viewModel.settings.showFileSize = val
                                    viewModel.settings.showDuration = val
                                }
                            ))
                            Toggle("Resolução e Proporção do Vídeo", isOn: $viewModel.settings.showResolution)
                            Toggle("Codec de Vídeo e Taxa de Quadros (FPS)", isOn: $viewModel.settings.showCodecAndFPS)
                            Toggle("Bitrate de Vídeo e Profundidade de Cor", isOn: $viewModel.settings.showBitrateAndColor)
                            Toggle("Especificações de Áudio (Codec, Canais, kHz)", isOn: $viewModel.settings.showAudioInfo)
                        }
                        .font(.system(size: fs(13)))
                    }
                }
            }

            // Card 5: Timestamps nas Miniaturas
            groupCard(title: "Timestamps nas Miniaturas", icon: "clock.badge.checkmark") {
                VStack(alignment: .leading, spacing: density == .compact ? 8 : 12) {
                    Toggle("Exibir Tempo em Cada Frame", isOn: $viewModel.settings.showTimestamps)
                        .font(.system(size: fs(14), weight: .medium))

                    if viewModel.settings.showTimestamps {
                        HStack {
                            Text("Posição")
                                .font(.system(size: fs(13)))
                            Spacer()
                            Picker("Posição", selection: $viewModel.settings.timestampPosition) {
                                ForEach(TimestampPosition.allCases) { pos in
                                    Text(pos.rawValue).tag(pos)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 170)
                        }

                        stepperRow(
                            title: "Tamanho da Fonte",
                            value: $viewModel.settings.timestampFontSize,
                            range: 8...32,
                            unit: "pt"
                        )
                    }
                }
            }
        }
    }

    // MARK: - ABA 2: EXPORTAÇÃO
    private var exportTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            groupCard(title: "Formato & Compressão", icon: "photo.badge.checkmark") {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Formato do Arquivo:")
                        .font(.system(size: 13, weight: .medium))

                    HStack(spacing: 8) {
                        ForEach(ExportFormat.allCases) { format in
                            let active = (viewModel.settings.exportFormat == format)
                            Button {
                                viewModel.settings.exportFormat = format
                            } label: {
                                Text(format.rawValue)
                                    .font(.system(size: 13, weight: active ? .semibold : .medium))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 34)
                                    .background(
                                        Capsule()
                                            .fill(active ? Color.accentColor : Color.primary.opacity(0.08))
                                    )
                                    .foregroundStyle(active ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if viewModel.settings.exportFormat.supportsQuality {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Qualidade da Imagem")
                                    .font(.system(size: 13))
                                Spacer()
                                Text("\(Int((viewModel.settings.exportQuality * 100).rounded()))%")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                            }
                            Slider(value: $viewModel.settings.exportQuality, in: 0.1...1.0, step: 0.05)
                        }
                    } else {
                        Text("Compressão sem perdas (Lossless) ativada para \(viewModel.settings.exportFormat.rawValue).")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            groupCard(title: "Destino & Nomenclatura", icon: "folder.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Onde salvar por padrão:")
                            .font(.system(size: 13, weight: .medium))

                        Picker("Destino", selection: $viewModel.settings.saveDestinationMode) {
                            ForEach(SaveDestinationMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .controlSize(.regular)
                    }

                    if viewModel.settings.saveDestinationMode == .customFolder {
                        HStack(spacing: 8) {
                            Image(systemName: "folder")
                                .foregroundStyle(.secondary)
                            Text(viewModel.settings.customExportFolderURL?.path ?? "Nenhuma pasta selecionada")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button {
                                viewModel.chooseCustomExportFolder()
                            } label: {
                                Text("Escolher...")
                                    .font(.system(size: 12, weight: .semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                    }

                    Divider()

                    HStack {
                        Text("Sufixo do arquivo:")
                            .font(.system(size: 13))
                        Spacer()
                        TextField("-sheet", text: $viewModel.settings.fileSuffix)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13, design: .monospaced))
                            .frame(width: 120)
                    }

                    if let selected = viewModel.selectedVideo {
                        let previewURL = viewModel.defaultOutputURL(for: selected)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Exemplo de saída:")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text(previewURL.lastPathComponent)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.accentColor)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(previewURL.deletingLastPathComponent().path)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                    }

                    Toggle("Mostrar arquivo no Finder após salvar", isOn: $viewModel.settings.revealInFinderAfterExport)
                        .font(.system(size: 13))
                }
            }
        }
    }

    // MARK: - Rodapé Principal com Botões Grandes e Arredondados (Sem sobreposição de controles)
    private var quickExportFooter: some View {
        let checkedCount = viewModel.checkedVideos.count
        let totalCount = viewModel.videos.count
        let isBusy = viewModel.isExportingSingle || viewModel.isBatchExporting
        let isDisabled = (viewModel.selectedVideo == nil || isBusy)
        let themeColor = viewModel.settings.appThemeColor.color

        return VStack(spacing: 10) {
            if viewModel.isBatchExporting {
                ProgressView(value: viewModel.batchProgress)
                    .progressViewStyle(.linear)
            }

            HStack(spacing: 10) {
                Button {
                    if checkedCount > 1 {
                        viewModel.exportSelectedOrAllVideos(forceChooseFolder: false)
                    } else {
                        viewModel.exportCurrentSheet(forceSavePanel: false)
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isBusy {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: checkedCount > 1 ? "square.stack.3d.up.fill" : "arrow.down.doc.fill")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        Text(primaryExportButtonTitle(checkedCount: checkedCount, totalCount: totalCount))
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(
                        Capsule()
                            .fill(isDisabled ? Color.gray.opacity(0.35) : themeColor)
                    )
                    .foregroundStyle(Color.white)
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)

                Menu {
                    Button {
                        viewModel.exportCurrentSheet(forceSavePanel: false)
                    } label: {
                        Label("Salvar Vídeo Atual (-sheet)", systemImage: "arrow.down.doc")
                    }

                    Button {
                        viewModel.exportCurrentSheet(forceSavePanel: true)
                    } label: {
                        Label("Salvar Vídeo Atual Como...", systemImage: "folder.badge.gearshape")
                    }

                    if totalCount > 1 {
                        Divider()

                        if checkedCount > 0 {
                            Button {
                                viewModel.exportSelectedOrAllVideos(forceChooseFolder: false)
                            } label: {
                                Label("Exportar \(checkedCount) Selecionado(s) na Pasta Padrão", systemImage: "checkmark.circle")
                            }

                            Button {
                                viewModel.exportSelectedOrAllVideos(forceChooseFolder: true)
                            } label: {
                                Label("Exportar \(checkedCount) Selecionado(s) Escolhendo Pasta...", systemImage: "folder")
                            }
                        }

                        Button {
                            viewModel.selectAllVideos()
                            viewModel.exportSelectedOrAllVideos(forceChooseFolder: false)
                        } label: {
                            Label("Exportar Todos da Fila (\(totalCount))", systemImage: "square.stack.3d.up.fill")
                        }
                    }

                    Divider()

                    Button {
                        viewModel.copyCurrentSheetToClipboard()
                    } label: {
                        Label("Copiar Imagem para Área de Transferência", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 42, height: 42)
                        .background(Color.primary.opacity(0.08), in: Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.09), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)
                .help("Mais opções de exportação")
            }
        }
    }

    private func primaryExportButtonTitle(checkedCount: Int, totalCount: Int) -> String {
        if viewModel.isExportingSingle {
            return "Refinando e Exportando..."
        }
        if viewModel.isBatchExporting {
            return "Exportando (\(Int(viewModel.batchProgress * 100))%)..."
        }
        if checkedCount > 1 {
            return "Exportar Selecionados (\(checkedCount))"
        }
        return "Salvar Contact Sheet"
    }

    private func groupCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let themeColor = viewModel.settings.appThemeColor.color
        return VStack(alignment: .leading, spacing: density == .compact ? 9 : 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(themeColor)
                    .font(.system(size: fs(14), weight: .semibold))
                Text(title)
                    .font(.system(size: fs(14), weight: .semibold))
                    .foregroundStyle(.primary)
            }

            content()
        }
        .padding(density.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.09), lineWidth: 1)
        )
    }

    private func sliderRow(
        title: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        unit: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: fs(13)))
                Spacer()
                Text("\(Int(value.wrappedValue)) \(unit)")
                    .font(.system(size: fs(13), weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: 1)
        }
    }

    private func stepperRow(
        title: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        unit: String
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: fs(13)))
            Spacer()
            Stepper(
                "\(Int(value.wrappedValue)) \(unit)",
                value: Binding(
                    get: { Int(value.wrappedValue.rounded()) },
                    set: { value.wrappedValue = CGFloat($0) }
                ),
                in: Int(range.lowerBound)...Int(range.upperBound)
            )
            .font(.system(size: fs(13), weight: .semibold, design: .monospaced))
        }
    }
}

struct SavePresetModalView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "bookmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Salvar Modelo de Configuração")
                        .font(.system(size: 16, weight: .bold))
                    Text("Guarde a quantidade de frames, proporção, cores, cabeçalho e formato atuais para usar com 1 clique.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            TextField("Nome do modelo (ex: YouTube 16:9, Instagram 4:5, Cliente X)", text: $viewModel.newPresetName)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 14))
                .onSubmit {
                    if !viewModel.newPresetName.trimmingCharacters(in: .whitespaces).isEmpty {
                        viewModel.saveCurrentSettingsAsPreset(name: viewModel.newPresetName)
                    }
                }

            HStack(spacing: 10) {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("Cancelar")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)

                Button {
                    viewModel.saveCurrentSettingsAsPreset(name: viewModel.newPresetName)
                } label: {
                    Text("Salvar Modelo")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 460)
    }
}
