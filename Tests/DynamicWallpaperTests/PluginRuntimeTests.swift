import Foundation
import DynamicWallpaperCore

public struct PluginRuntimeTests {
    public static func runAllTests() {
        testPluginMetadataSerialization()
        testJSPluginRuntimeExecution()
    }

    private static func testPluginMetadataSerialization() {
        let metadata = PluginMetadata(
            id: "tw.soda916.clock.minimal",
            name: "Minimalist Digital Clock",
            author: "Antigravity Team",
            type: .clock
        )

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(metadata) else {
            fatalError("Failed to encode PluginMetadata")
        }

        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(PluginMetadata.self, from: data) else {
            fatalError("Failed to decode PluginMetadata")
        }

        assert(decoded.id == "tw.soda916.clock.minimal", "ID should match")
        assert(decoded.name == "Minimalist Digital Clock", "Name should match")
        assert(decoded.type == .clock, "Type should be .clock")
        print("✓ testPluginMetadataSerialization passed")
    }

    private static func testJSPluginRuntimeExecution() {
        let metadata = PluginMetadata(
            id: "test.clock",
            name: "Test Clock"
        )
        let runtime = JSPluginRuntime(metadata: metadata)

        var lastRender: String?
        runtime.onWidgetRenderUpdate = { renderOutput in
            lastRender = renderOutput
        }

        runtime.start(script: "console.log('init clock');")
        assert(runtime.isRunning == true, "Runtime should be running")
        assert(lastRender != nil, "Render output should not be nil after start")

        runtime.stop()
        assert(runtime.isRunning == false, "Runtime should be stopped")
        print("✓ testJSPluginRuntimeExecution passed")
    }
}
