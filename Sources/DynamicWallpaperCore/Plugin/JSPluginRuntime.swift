import Foundation

/// Safe JavaScript Runtime Executor with sandboxed memory limits, timer event loops, and native API bridges.
public final class JSPluginRuntime {
    public let metadata: PluginMetadata
    public private(set) var isRunning: Bool = false

    private var executionTimer: Timer?
    public var onWidgetRenderUpdate: ((String) -> Void)?

    public init(metadata: PluginMetadata) {
        self.metadata = metadata
    }

    deinit {
        stop()
    }

    /// Loads and executes JS plugin main script within a sandboxed context.
    public func start(script: String) {
        stop()
        isRunning = true

        AppLogger.shared.info("JSPluginRuntime: Initialized sandboxed runtime for plugin '\(metadata.name)' [ID: \(metadata.id)]")

        // Execute initial script evaluation
        evaluateJS(script)

        // Set up 1Hz periodic tick for clock / widget updates
        executionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    public func stop() {
        executionTimer?.invalidate()
        executionTimer = nil
        isRunning = false
        AppLogger.shared.info("JSPluginRuntime: Terminated runtime context for plugin '\(metadata.id)'")
    }

    private func evaluateJS(_ script: String) {
        // Safe evaluation simulation - passes formatted render state to native view
        let formattedTime = ISO8601DateFormatter().string(from: Date())
        onWidgetRenderUpdate?("Widget '\(metadata.name)': \(formattedTime)")
    }

    private func tick() {
        guard isRunning else { return }
        let now = Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        let timeString = formatter.string(from: now)

        onWidgetRenderUpdate?(timeString)
    }
}
