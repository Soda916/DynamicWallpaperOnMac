import AppKit
import AVFoundation

/// Manages a borderless, non-activating desktop layer window for playing wallpaper media on a specific NSScreen.
public final class DesktopWindowController: NSWindowController {
    public let targetScreen: NSScreen
    private var playerLayer: AVPlayerLayer?

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
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupWindowProperties(_ window: NSWindow) {
        // Position window at the desktop window level (below desktop icons)
        window.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow)))
        
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

        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        layer.addSublayer(newPlayerLayer)
        self.playerLayer = newPlayerLayer
    }
}
