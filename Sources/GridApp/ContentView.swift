import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel

    private var themeColor: Color {
        viewModel.settings.appThemeColor.color
    }

    private var density: AppUIDensity {
        viewModel.settings.appUIDensity
    }

    private func fs(_ base: CGFloat) -> CGFloat {
        max(base + density.fontDelta, 9)
    }

    var body: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            HStack(spacing: 0) {
                centerWorkspaceView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                SettingsInspectorView(viewModel: viewModel)
            }
        }
        .navigationTitle("GridApp")
        .tint(themeColor)
        .dynamicTypeSize(density.dynamicTypeSize)
        .preferredColorScheme(viewModel.settings.appColorScheme.preferredColorScheme)
        .sheet(item: $viewModel.editingFrame) { frame in
            if let video = viewModel.selectedVideo {
                FrameEditorSheet(viewModel: viewModel, videoItem: video, frame: frame)
            }
        }
        .alert(
            "Aviso",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onDrop(of: [.fileURL], isTargeted: $viewModel.isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    // MARK: - Sidebar Esquerda (Fila de Vídeos — Sem ícones duplicados ou sobrepostos)
    private var sidebarView: some View {
        let themeColor = viewModel.settings.appThemeColor.color
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                if !viewModel.videos.isEmpty {
                    Button {
                        if viewModel.allVideosChecked {
                            viewModel.deselectAllVideos()
                        } else {
                            viewModel.selectAllVideos()
                        }
                    } label: {
                        Image(
                            systemName: viewModel.allVideosChecked
                                ? "checkmark.square.fill"
                                : (viewModel.checkedVideoIDs.isEmpty ? "square" : "minus.square.fill")
                        )
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(viewModel.checkedVideoIDs.isEmpty ? .secondary : themeColor)
                    }
                    .buttonStyle(.plain)
                    .help(viewModel.allVideosChecked ? "Desmarcar todos" : "Selecionar todos os vídeos")
                }

                Text("Fila (\(viewModel.videos.count))")
                    .font(.system(size: 14, weight: .semibold))

                if !viewModel.checkedVideoIDs.isEmpty {
                    Text("• \(viewModel.checkedVideoIDs.count) sel.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(themeColor)
                }

                Spacer()

                if !viewModel.videos.isEmpty {
                    Menu {
                        Button("Selecionar Todos") {
                            viewModel.selectAllVideos()
                        }
                        Button("Desmarcar Todos") {
                            viewModel.deselectAllVideos()
                        }
                        Button("Inverter Seleção") {
                            viewModel.invertVideoSelection()
                        }
                        Divider()
                        if !viewModel.checkedVideoIDs.isEmpty {
                            Button("Remover Selecionados (\(viewModel.checkedVideoIDs.count))", role: .destructive) {
                                viewModel.removeCheckedOrCurrentVideo()
                            }
                        }
                        Button("Limpar Toda a Fila", role: .destructive) {
                            viewModel.clearAllVideos()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.primary.opacity(0.07), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            if viewModel.videos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("Nenhum vídeo na fila")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Arraste vídeos ou use ⌘O")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List(selection: $viewModel.selectedVideoID) {
                    ForEach(viewModel.videos) { item in
                        VideoRowView(
                            item: item,
                            isChecked: viewModel.isVideoChecked(item.id),
                            density: density,
                            onToggleCheck: {
                                viewModel.toggleVideoCheck(item.id)
                            },
                            onRemove: {
                                viewModel.removeVideo(item)
                            }
                        )
                        .tag(item.id)
                        .contextMenu {
                            Button {
                                viewModel.toggleVideoCheck(item.id)
                            } label: {
                                Label(
                                    viewModel.isVideoChecked(item.id) ? "Desmarcar da Seleção" : "Marcar para Lote",
                                    systemImage: viewModel.isVideoChecked(item.id) ? "circle" : "checkmark.circle"
                                )
                            }

                            Button {
                                Task {
                                    await viewModel.extractFrames(for: item)
                                }
                            } label: {
                                Label("Recapturar Frames", systemImage: "arrow.clockwise")
                            }

                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([item.url])
                            } label: {
                                Label("Mostrar no Finder", systemImage: "folder")
                            }

                            Divider()

                            Button(role: .destructive) {
                                viewModel.removeVideo(item)
                            } label: {
                                Label("Remover da Fila", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }

            if !viewModel.checkedVideoIDs.isEmpty && viewModel.videos.count > 1 {
                Divider()
                HStack(spacing: 8) {
                    Button {
                        viewModel.removeCheckedOrCurrentVideo()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "trash")
                            Text("Apagar (\(viewModel.checkedVideoIDs.count))")
                        }
                        .font(.system(size: fs(12), weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: density.controlHeight)
                        .background(Color.red.opacity(0.14), in: Capsule())
                        .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewModel.recaptureTargetVideos()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.clockwise")
                            Text("Recapturar")
                        }
                        .font(.system(size: fs(12), weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: density.controlHeight)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }

            Divider()

            // Rodapé Fixo do Menu da Fila com Botão Destacado de Adicionar Vídeos + Botão de Configurações
            HStack(spacing: 8) {
                Button {
                    viewModel.openFilePicker()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "plus.rectangle.on.folder.fill")
                            .font(.system(size: fs(13), weight: .semibold))
                        Text("Adicionar Vídeos")
                            .font(.system(size: fs(13), weight: .semibold))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: max(density.controlHeight + 4, 34))
                    .background(themeColor, in: Capsule())
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .help("Adicionar arquivos ou pastas de vídeo (⌘O)")

                Button {
                    viewModel.openAppSettingsWindow()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: fs(14), weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: max(density.controlHeight + 4, 34), height: max(density.controlHeight + 4, 34))
                        .background(Color.primary.opacity(0.09), in: Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.09), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("Abrir Configurações do GridApp (⌘,)")
            }
            .padding(12)
            .background(.ultraThinMaterial)
        }
        .frame(minWidth: 235, idealWidth: 260, maxWidth: 300)
    }

    // MARK: - Área Central de Preview e Edição Direta
    private var centerWorkspaceView: some View {
        ZStack {
            Color(nsColor: .underPageBackgroundColor)
                .ignoresSafeArea()

            if let selected = viewModel.selectedVideo {
                SelectedVideoWorkspace(
                    videoItem: selected,
                    viewModel: viewModel,
                    zoomScale: $viewModel.zoomScale
                )
            } else {
                emptyDropZoneView
            }

            if viewModel.isDropTargeted {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(18)
            }

            if let status = viewModel.statusMessage {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.green)
                        Text(status)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button {
                            viewModel.statusMessage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(radius: 8)
                    .padding(.bottom, 18)
                    .padding(.horizontal, 24)
                }
            }
        }
    }

    private var emptyDropZoneView: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 42))
                    .foregroundStyle(Color.accentColor)
            }

            Text("Arraste e solte seus vídeos ou pastas aqui")
                .font(.system(size: 20, weight: .semibold))

            Text("Suporta MP4, MOV, M4V, MKV, AVI, WebM e processamento em lote.\nPasse o mouse sobre qualquer frame da Contact Sheet e clique para ajustá-lo.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
        }
        .padding(36)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var found = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                found = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        Task { @MainActor in
                            viewModel.addVideoURLs([url])
                        }
                    } else if let url = item as? URL {
                        Task { @MainActor in
                            viewModel.addVideoURLs([url])
                        }
                    }
                }
            }
        }
        return found
    }
}

struct VideoRowView: View {
    @ObservedObject var item: VideoItem
    let isChecked: Bool
    let density: AppUIDensity
    let onToggleCheck: () -> Void
    let onRemove: () -> Void

    private var fontDelta: CGFloat {
        density.fontDelta
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggleCheck) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isChecked ? Color.accentColor : .secondary)
                    .font(.system(size: 15 + fontDelta, weight: .medium))
            }
            .buttonStyle(.plain)
            .help(isChecked ? "Desmarcar vídeo" : "Selecionar vídeo para ações em lote")

            VStack(alignment: .leading, spacing: 3) {
                Text(item.url.lastPathComponent)
                    .font(.system(size: 13 + fontDelta, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 5) {
                    statusBadge
                    if let meta = item.metadata {
                        Text("\(meta.formattedShortResolution) • \(meta.formattedDuration)")
                            .font(.system(size: 11 + fontDelta))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(statusSubtitle)
                            .font(.system(size: 11 + fontDelta))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 4)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14 + fontDelta))
                    .foregroundStyle(.secondary.opacity(0.75))
            }
            .buttonStyle(.plain)
            .help("Remover vídeo da fila")
        }
        .padding(.vertical, density == .compact ? 3 : (density == .spacious ? 7 : 5))
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch item.status {
        case .idle, .loadingMetadata:
            ProgressView()
                .controlSize(.mini)
        case .extractingFrames(let progress), .exportingHighRes(let progress):
            ProgressView(value: progress)
                .progressViewStyle(.circular)
                .controlSize(.mini)
        case .ready:
            Circle()
                .fill(Color.green)
                .frame(width: 7, height: 7)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 10))
        }
    }

    private var statusSubtitle: String {
        switch item.status {
        case .idle: return "Aguardando..."
        case .loadingMetadata: return "Lendo metadados..."
        case .extractingFrames(let p): return "Capturando (\(Int(p * 100))%)..."
        case .exportingHighRes(let p): return "Alta Qualidade (\(Int(p * 100))%)..."
        case .ready: return "Pronto"
        case .failed(let msg): return msg
        }
    }
}

struct SelectedVideoWorkspace: View {
    @ObservedObject var videoItem: VideoItem
    @ObservedObject var viewModel: AppViewModel
    @Binding var zoomScale: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            if let meta = videoItem.metadata {
                HStack(spacing: 12) {
                    Label("Clique em qualquer frame para ajustar", systemImage: "cursorarrow.click")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    Divider().frame(height: 16)

                    Text("\(meta.formattedShortResolution) • \(meta.formattedDuration) • \(meta.codec)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let elapsed = videoItem.processingDurationSeconds {
                        Label(String(format: "%.2fs", elapsed), systemImage: "bolt.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.12), in: Capsule())
                    }

                    Spacer()

                    // Controles de Zoom Arredondados + Suporte ao Trackpad
                    HStack(spacing: 6) {
                        Button {
                            zoomScale = max(0.4, zoomScale - 0.25)
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 12, weight: .bold))
                                .frame(width: 28, height: 28)
                                .background(Color.primary.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Diminuir Zoom (⌘-)")

                        Button {
                            zoomScale = 1.0
                        } label: {
                            Text("\(Int((zoomScale * 100).rounded()))%")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 10)
                                .frame(height: 28)
                                .background(Color.primary.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Clique para restaurar 100% ou use pinça no Trackpad")

                        Button {
                            zoomScale = min(4.0, zoomScale + 0.25)
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                                .frame(width: 28, height: 28)
                                .background(Color.primary.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Aumentar Zoom (⌘+)")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)

                Divider()
            }

            switch videoItem.status {
            case .idle, .loadingMetadata:
                VStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Analisando arquivo de vídeo...")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .extractingFrames(let progress):
                VStack(spacing: 14) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(width: 280)
                    Text("Extraindo capturas de tela (\(Int(progress * 100))%)...")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .exportingHighRes(let progress):
                VStack(spacing: 14) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(width: 300)
                    Text("Relendo vídeo em qualidade máxima para exportação (\(Int(progress * 100))%)...")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("Capturando quadros exatos em resolução nativa")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .failed(let errMsg):
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(.orange)
                    Text("Falha ao processar vídeo")
                        .font(.system(size: 16, weight: .bold))
                    Text(errMsg)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 440)
                    Button {
                        Task {
                            await viewModel.processVideo(videoItem)
                        }
                    } label: {
                        Text("Tentar Novamente")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(Color.accentColor, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .ready:
                renderedSheetPreview
            }
        }
    }

    private var renderedSheetPreview: some View {
        ZStack {
            if let sheetImage = videoItem.renderedSheet {
                ZoomableSheetScrollView(
                    image: sheetImage,
                    hitBoxes: videoItem.frameHitBoxes,
                    zoomScale: $zoomScale
                ) { clickedFrameID in
                    if let frame = videoItem.frames.first(where: { $0.id == clickedFrameID }) {
                        viewModel.editingFrame = frame
                    }
                }
                .contextMenu {
                    Button {
                        viewModel.exportCurrentSheet(forceSavePanel: false)
                    } label: {
                        Label("Salvar Contact Sheet (-sheet)", systemImage: "arrow.down.doc.fill")
                    }
                    Button {
                        viewModel.exportCurrentSheet(forceSavePanel: true)
                    } label: {
                        Label("Salvar Como...", systemImage: "folder.badge.gearshape")
                    }
                    Divider()
                    Button {
                        viewModel.copyCurrentSheetToClipboard()
                    } label: {
                        Label("Copiar Imagem", systemImage: "doc.on.doc")
                    }
                }
            }
        }
    }
}
