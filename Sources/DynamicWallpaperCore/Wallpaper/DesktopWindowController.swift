import AppKit
import AVFoundation
import WebKit

/// Manages a borderless, non-activating desktop layer window for playing wallpaper media on a specific NSScreen,
/// with integrated WebKit overlay for rendering interactive JS plugins & desktop widgets.
public final class DesktopWindowController: NSWindowController {
    public let targetScreen: NSScreen
    private var playerLayer: AVPlayerLayer?
    private var webOverlayView: WKWebView?

    public init(screen: NSScreen) {
        self.targetScreen = screen
        
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        
        super.init(window: window)
        setupWindowProperties(window)
        setupPluginOverlay()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupWindowProperties(_ window: NSWindow) {
        // Position window directly behind desktop icons, above Finder's static background image
        window.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)
        
        // Multi-Space & Mission Control behavior: stay on all spaces, stationary, ignore cycle
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenDisallowsTiling
        ]

        // Pass through mouse events to the actual Finder desktop unless interactive overlay is focused
        window.ignoresMouseEvents = true
        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false
        window.setFrame(targetScreen.frame, display: true)
        window.orderFrontRegardless()
    }

    /// Attach an AVPlayer to render full-screen video on this desktop window.
    public func setPlayer(_ player: AVPlayer) {
        guard let window = window, let contentView = window.contentView else { return }

        contentView.wantsLayer = true
        guard let layer = contentView.layer else { return }

        let newPlayerLayer = AVPlayerLayer(player: player)
        newPlayerLayer.frame = layer.bounds
        newPlayerLayer.videoGravity = .resizeAspectFill
        newPlayerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]

        // Remove existing video player sublayers while retaining webOverlayView subview
        layer.sublayers?.filter { $0 is AVPlayerLayer }.forEach { $0.removeFromSuperlayer() }
        layer.insertSublayer(newPlayerLayer, at: 0)
        self.playerLayer = newPlayerLayer

        window.orderFrontRegardless()
    }

    /// Load transparent WebKit overlay for running active JS plugins (clock/widget/overlay)
    public func reloadPluginOverlay() {
        guard let contentView = window?.contentView else { return }
        
        if webOverlayView == nil {
            let config = WKWebViewConfiguration()
            config.setValue(false, forKey: "drawsBackground")
            
            let webView = WKWebView(frame: contentView.bounds, configuration: config)
            webView.autoresizingMask = [.width, .height]
            webView.setValue(true, forKey: "drawsTransparentBackground")
            webView.isOpaque = false
            
            contentView.addSubview(webView, positioned: .above, relativeTo: nil)
            self.webOverlayView = webView
        }

        if let clockHTML = PluginManager.shared.getPluginHTML(for: "digital_clock") {
            webOverlayView?.loadHTMLString(clockHTML, baseURL: PluginManager.shared.pluginsDirectory.appendingPathComponent("digital_clock"))
            AppLogger.shared.info("[DESKTOP-WINDOW] Loaded plugin overlay into desktop layer.")
        }
    }

    private func setupPluginOverlay() {
        DispatchQueue.main.async { [weak self] in
            self?.reloadPluginOverlay()
        }
    }
}

