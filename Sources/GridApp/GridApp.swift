// GridApp — Copyright (C) 2026 Marcos (soaresmarcosj1)
// Licensed under the GNU General Public License v3.0 (GPL-3.0-or-later).
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let serviceProvider = MacServiceProvider()
    weak var sharedViewModel: AppViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Só aplica manualmente o .icns estático se não houver Assets.car compilado no bundle.
        // Com Assets.car presente, o macOS alterna automaticamente entre Claro, Escuro, Clear e Tinted.
        if Bundle.main.url(forResource: "Assets", withExtension: "car") == nil,
           let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let appIcon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = appIcon
        }

        // Registra o provedor de Serviços / Quick Action do Finder
        NSApp.servicesProvider = serviceProvider

        // Instala automaticamente a Ação Rápida do Finder em ~/Library/Services se ainda não existir
        _ = try? QuickActionAutomation.installFinderQuickAction()

        // Verifica se foi invocado via linha de comando / Ação Rápida em modo headless (--headless <arquivos...>)
        let args = CommandLine.arguments
        if let headlessIdx = args.firstIndex(of: "--headless") {
            let paths = Array(args.dropFirst(headlessIdx + 1))
            let urls = paths.map { URL(fileURLWithPath: $0) }
            NSApp.setActivationPolicy(.prohibited)
            Task { @MainActor in
                let saved = await QuickActionAutomation.generateSheetsHeadless(for: urls)
                if !saved.isEmpty {
                    NSSound(named: "Glass")?.play()
                }
                exit(0)
            }
            return
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard !urls.isEmpty else { return }
        let settings = QuickActionAutomation.loadCurrentSettings()
        if settings.autoExportOnFinderOpen {
            Task { @MainActor in
                let saved = await QuickActionAutomation.generateSheetsHeadless(for: urls)
                if !saved.isEmpty {
                    NSSound(named: "Glass")?.play()
                }
            }
        } else {
            Task { @MainActor in
                sharedViewModel?.addVideoURLs(urls)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct GridApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 1080, minHeight: 700)
                .onAppear {
                    appDelegate.sharedViewModel = viewModel
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            AppMenuCommands(viewModel: viewModel)
        }
    }
}
