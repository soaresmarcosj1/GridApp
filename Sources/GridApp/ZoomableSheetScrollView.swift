// GridApp — Copyright (C) 2026 Marcos (soaresmarcosj1)
// Licensed under the GNU General Public License v3.0 (GPL-3.0-or-later).
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import AppKit

/// Visualizador nativo macOS 27 (Apple HIG) com:
/// - Suporte completo a Pinch-to-Zoom no Trackpad (dois dedos) e Smart Magnify (duplo toque com 2 dedos)
/// - NSImageView nativo para renderização nítida na orientação correta (sem inversão vertical)
/// - Camada de sobreposição transparente para hover (destaque visual do frame sob o cursor) e clique direto para edição
struct ZoomableSheetScrollView: NSViewRepresentable {
    let image: NSImage
    let hitBoxes: [RenderedFrameHitBox]
    @Binding var zoomScale: CGFloat
    let onSelectFrame: (UUID) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = TrackpadZoomScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.4
        scrollView.maxMagnification = 4.0
        scrollView.magnification = max(zoomScale, 0.4)

        let containerView = NSView()
        containerView.wantsLayer = true

        // NSImageView nativo renderiza a NSImage sem inverter o eixo Y
        let imageView = NSImageView()
        imageView.imageScaling = .scaleAxesIndependently
        imageView.imageAlignment = .alignCenter
        imageView.wantsLayer = true
        imageView.layer?.shadowColor = NSColor.black.cgColor
        imageView.layer?.shadowOpacity = 0.38
        imageView.layer?.shadowRadius = 18
        imageView.layer?.shadowOffset = CGSize(width: 0, height: -6)

        // Camada transparente apenas para detectar hover e clique sobre cada frame
        let overlayView = SheetHoverOverlayView()
        overlayView.wantsLayer = true
        overlayView.onFrameClicked = { [weak coordinator = context.coordinator] frameID in
            coordinator?.parent.onSelectFrame(frameID)
        }

        containerView.addSubview(imageView)
        containerView.addSubview(overlayView)
        scrollView.documentView = containerView

        context.coordinator.scrollView = scrollView
        context.coordinator.containerView = containerView
        context.coordinator.imageView = imageView
        context.coordinator.overlayView = overlayView

        scrollView.onMagnifyChanged = { [weak coordinator = context.coordinator] newMag in
            coordinator?.handleTrackpadMagnification(newMag)
        }

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidLiveMagnify(_:)),
            name: NSScrollView.didEndLiveMagnifyNotification,
            object: scrollView
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.frameDidChange(_:)),
            name: NSView.frameDidChangeNotification,
            object: scrollView.contentView
        )
        scrollView.contentView.postsFrameChangedNotifications = true

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        if let imageView = context.coordinator.imageView,
           let overlayView = context.coordinator.overlayView {
            let oldSize = imageView.image?.size
            let imageChanged = (imageView.image !== image)
            let hitBoxesChanged = (overlayView.hitBoxes != hitBoxes)

            if imageChanged {
                imageView.image = image
            }
            if hitBoxesChanged {
                overlayView.hitBoxes = hitBoxes
                overlayView.needsDisplay = true
            }
            if imageChanged || oldSize != image.size {
                context.coordinator.layoutImageInScrollView()
            }
        }

        if !context.coordinator.isUpdatingFromTrackpad {
            let clamped = min(max(zoomScale, scrollView.minMagnification), scrollView.maxMagnification)
            if abs(scrollView.magnification - clamped) > 0.01 {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.15
                    scrollView.animator().magnification = clamped
                }
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: ZoomableSheetScrollView
        weak var scrollView: NSScrollView?
        weak var containerView: NSView?
        weak var imageView: NSImageView?
        weak var overlayView: SheetHoverOverlayView?
        var isUpdatingFromTrackpad = false

        init(_ parent: ZoomableSheetScrollView) {
            self.parent = parent
        }

        func handleTrackpadMagnification(_ newMag: CGFloat) {
            isUpdatingFromTrackpad = true
            let rounded = (newMag * 100).rounded() / 100
            if abs(parent.zoomScale - rounded) > 0.01 {
                parent.zoomScale = rounded
            }
            DispatchQueue.main.async { [weak self] in
                self?.isUpdatingFromTrackpad = false
            }
        }

        @objc func scrollViewDidLiveMagnify(_ notification: Notification) {
            guard let sv = scrollView else { return }
            handleTrackpadMagnification(sv.magnification)
        }

        @objc func frameDidChange(_ notification: Notification) {
            layoutImageInScrollView()
        }

        func layoutImageInScrollView() {
            guard let sv = scrollView,
                  let container = containerView,
                  let iv = imageView,
                  let overlay = overlayView,
                  let img = iv.image else { return }

            let viewportSize = sv.contentSize
            guard viewportSize.width > 40, viewportSize.height > 40, img.size.width > 0, img.size.height > 0 else { return }

            let pad: CGFloat = 28
            let availW = max(viewportSize.width - (pad * 2), 200)
            let availH = max(viewportSize.height - (pad * 2), 200)

            let aspect = img.size.width / img.size.height
            var drawW = availW
            var drawH = drawW / aspect

            if drawH > availH {
                drawH = availH
                drawW = drawH * aspect
            }

            let containerW = max(viewportSize.width, drawW + pad * 2)
            let containerH = max(viewportSize.height, drawH + pad * 2)

            container.frame = NSRect(x: 0, y: 0, width: containerW, height: containerH)
            let targetFrame = NSRect(
                x: (containerW - drawW) / 2.0,
                y: (containerH - drawH) / 2.0,
                width: drawW,
                height: drawH
            )
            iv.frame = targetFrame
            overlay.frame = targetFrame
            overlay.needsDisplay = true
        }
    }
}

/// Camada transparente não-invertida (eixo Y padrão do AppKit: 0 na base, 1 no topo)
/// que desenha apenas o destaque de hover e captura o clique nos frames.
final class SheetHoverOverlayView: NSView {
    var hitBoxes: [RenderedFrameHitBox] = []
    var hoveredHitBox: RenderedFrameHitBox? {
        didSet {
            if oldValue != hoveredHitBox {
                needsDisplay = true
                if hoveredHitBox != nil {
                    NSCursor.pointingHand.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
        }
    }
    var onFrameClicked: ((UUID) -> Void)?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        hoveredHitBox = hitBox(at: localPoint)
    }

    override func mouseExited(with event: NSEvent) {
        hoveredHitBox = nil
    }

    override func mouseDown(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        if let box = hitBox(at: localPoint) {
            onFrameClicked?(box.frameID)
        } else {
            super.mouseDown(with: event)
        }
    }

    private func hitBox(at point: NSPoint) -> RenderedFrameHitBox? {
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        for box in hitBoxes {
            let rect = viewRect(for: box)
            if rect.contains(point) {
                return box
            }
        }
        return nil
    }

    private func viewRect(for box: RenderedFrameHitBox) -> NSRect {
        // Como a view usa coordenadas padrão do AppKit (origem no canto inferior-esquerdo)
        // e `normalizedRect.origin.y` foi salvo a partir do topo, convertemos Y:
        let w = box.normalizedRect.size.width * bounds.width
        let h = box.normalizedRect.size.height * bounds.height
        let x = box.normalizedRect.origin.x * bounds.width
        let y = (1.0 - box.normalizedRect.origin.y - box.normalizedRect.size.height) * bounds.height
        return NSRect(x: x, y: y, width: w, height: h)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let hovered = hoveredHitBox else { return }
        let rect = viewRect(for: hovered)
        let corner = max(hovered.normalizedCornerRadius * bounds.width, 6)

        // Película translúcida suave + anel de foco estilo macOS 27
        NSColor.black.withAlphaComponent(0.28).setFill()
        let clipPath = NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner)
        clipPath.fill()

        NSColor.controlAccentColor.setStroke()
        let strokePath = NSBezierPath(roundedRect: rect.insetBy(dx: -1.5, dy: -1.5), xRadius: corner + 1.5, yRadius: corner + 1.5)
        strokePath.lineWidth = 3.0
        strokePath.stroke()

        // Pílula central estilo Liquid Glass ("✎ Ajustar Frame #N")
        let labelText = "✎ Ajustar Frame #\(hovered.index + 1)"
        let fontSize = min(max(rect.width * 0.085, 11), 15)
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let attrStr = NSAttributedString(string: labelText, attributes: attrs)
        let textSize = attrStr.size()

        let pillW = min(textSize.width + 26, rect.width - 8)
        let pillH = textSize.height + 12
        let pillRect = NSRect(
            x: rect.midX - (pillW / 2.0),
            y: rect.midY - (pillH / 2.0),
            width: pillW,
            height: pillH
        )

        NSColor.controlAccentColor.withAlphaComponent(0.94).setFill()
        NSBezierPath(roundedRect: pillRect, xRadius: pillH / 2.0, yRadius: pillH / 2.0).fill()

        NSColor.white.withAlphaComponent(0.38).setStroke()
        let pillBorder = NSBezierPath(roundedRect: pillRect, xRadius: pillH / 2.0, yRadius: pillH / 2.0)
        pillBorder.lineWidth = 1.0
        pillBorder.stroke()

        let textOrigin = NSPoint(
            x: rect.midX - (textSize.width / 2.0),
            y: rect.midY - (textSize.height / 2.0)
        )
        attrStr.draw(at: textOrigin)
    }
}

final class TrackpadZoomScrollView: NSScrollView {
    var onMagnifyChanged: ((CGFloat) -> Void)?

    override func magnify(with event: NSEvent) {
        super.magnify(with: event)
        onMagnifyChanged?(self.magnification)
    }

    override func smartMagnify(with event: NSEvent) {
        let target: CGFloat = (self.magnification > 1.15) ? 1.0 : 1.75
        let pointInClip = contentView.convert(event.locationInWindow, from: nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            self.animator().setMagnification(target, centeredAt: pointInClip)
        }
        onMagnifyChanged?(target)
    }
}
