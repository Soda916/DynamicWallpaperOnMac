import Foundation
import IOKit.ps

public extension Notification.Name {
    static let batteryStateDidChange = Notification.Name("batteryStateDidChange")
}

/// Native Apple IOKit Power Sources Manager monitoring real-time battery status, AC power connection, and percentage capacity.
public final class BatteryManager: @unchecked Sendable {
    public static let shared = BatteryManager()

    public struct BatteryInfo: Equatable {
        public let isOnBattery: Bool
        public let capacityPercent: Int
        public let isCharging: Bool

        public init(isOnBattery: Bool, capacityPercent: Int, isCharging: Bool) {
            self.isOnBattery = isOnBattery
            self.capacityPercent = capacityPercent
            self.isCharging = isCharging
        }
    }

    private var runLoopSource: CFRunLoopSource?
    private(set) public var currentInfo: BatteryInfo = BatteryInfo(isOnBattery: false, capacityPercent: 100, isCharging: false)

    private init() {
        refreshBatteryInfo()
        registerPowerSourceCallback()
    }

    deinit {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .defaultMode)
        }
    }

    @discardableResult
    public func refreshBatteryInfo() -> BatteryInfo {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            let defaultInfo = BatteryInfo(isOnBattery: false, capacityPercent: 100, isCharging: false)
            self.currentInfo = defaultInfo
            return defaultInfo
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            let currentState = description[kIOPSPowerSourceStateKey as String] as? String
            let isOnBattery = (currentState == kIOPSBatteryPowerValue)
            let isCharging = (description[kIOPSIsChargingKey as String] as? Bool) ?? false
            let currentCap = (description[kIOPSCurrentCapacityKey as String] as? Int) ?? 100
            let maxCap = (description[kIOPSMaxCapacityKey as String] as? Int) ?? 100
            let percent = maxCap > 0 ? Int(Double(currentCap) / Double(maxCap) * 100.0) : 100

            let newInfo = BatteryInfo(isOnBattery: isOnBattery, capacityPercent: percent, isCharging: isCharging)
            if newInfo != self.currentInfo {
                self.currentInfo = newInfo
                NotificationCenter.default.post(name: .batteryStateDidChange, object: newInfo)
            }
            return newInfo
        }

        let defaultInfo = BatteryInfo(isOnBattery: false, capacityPercent: 100, isCharging: false)
        self.currentInfo = defaultInfo
        return defaultInfo
    }

    private func registerPowerSourceCallback() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let loopSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context = context else { return }
            let manager = Unmanaged<BatteryManager>.fromOpaque(context).takeUnretainedValue()
            manager.refreshBatteryInfo()
        }, context)?.takeRetainedValue() {
            self.runLoopSource = loopSource
            CFRunLoopAddSource(CFRunLoopGetCurrent(), loopSource, .defaultMode)
        }
    }
}
