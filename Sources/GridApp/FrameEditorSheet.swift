// GridApp — Copyright (C) 2026 Marcos (soaresmarcosj1)
// Licensed under the GNU General Public License v3.0 (GPL-3.0-or-later).
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import AppKit

struct FrameEditorSheet: View {
    @ObservedObject var viewModel: AppViewModel
    let videoItem: VideoItem
    let initialFrame: CapturedFrame

    @Environment(\.dismiss) private var dismiss

    init(viewModel: AppViewModel, videoItem: VideoItem, frame: CapturedFrame) {
        self.viewModel = viewModel
        self.videoItem = videoItem
        self.initialFrame = frame
    }

    private var duration: Double {
        videoItem.metadata?.durationSeconds ?? 100
    }

    var body: some View {
        VStack(spacing: 18) {
            // Cabeçalho limpo sem botões duplicados
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Ajustar Captura #\(initialFrame.index + 1)")
                        .font(.system(size: 16, weight: .bold))
                    Text("Deslize na linha do tempo ou use os ajustes finos e clique em Aplicar.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Pré-visualização da captura em edição
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.88))

                if let image = viewModel.editingPreviewImage ?? initialFrame.image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(10)
                }

                if viewModel.isUpdatingSingleFrame {
                    ProgressView()
                        .controlSize(.large)
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .frame(minHeight: 300, maxHeight: 400)

            // Controles de Linha do Tempo e Ajuste Fino
            VStack(spacing: 12) {
                HStack {
                    Text("Tempo selecionado:")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text(TimeFormatter.format(seconds: viewModel.editingSeconds, includeMilliseconds: true))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                    Spacer()
                    Text("Duração total: \(TimeFormatter.format(seconds: duration))")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Slider(value: $viewModel.editingSeconds, in: 0...max(duration - 0.05, 0.1)) { editing in
                    if !editing {
                        triggerPreview(at: viewModel.editingSeconds)
                    }
                }

                HStack(spacing: 8) {
                    Text("Ajuste fino:")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    fineStepButton(label: "-5s", delta: -5.0)
                    fineStepButton(label: "-1s", delta: -1.0)
                    fineStepButton(label: "-0.1s", delta: -0.1)
                    fineStepButton(label: "+0.1s", delta: 0.1)
                    fineStepButton(label: "+1s", delta: 1.0)
                    fineStepButton(label: "+5s", delta: 5.0)

                    Spacer()
                }
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Rodapé com botões Cancelar e Aplicar
            HStack(spacing: 12) {
                Spacer()

                Button {
                    viewModel.editingFrame = nil
                    dismiss()
                } label: {
                    Text("Cancelar")
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 9)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)

                Button {
                    Task {
                        await viewModel.applyEditingFrame(for: videoItem)
                        dismiss()
                    }
                } label: {
                    Text("Aplicar")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 9)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.isUpdatingSingleFrame)
            }
        }
        .padding(22)
        .frame(width: 650, height: 575)
    }

    private func fineStepButton(label: String, delta: Double) -> some View {
        Button {
            let next = min(max(0, viewModel.editingSeconds + delta), max(duration - 0.05, 0))
            viewModel.editingSeconds = next
            triggerPreview(at: next)
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func triggerPreview(at seconds: Double) {
        Task {
            await viewModel.previewEditingFrame(for: videoItem, timestamp: seconds)
        }
    }
}
