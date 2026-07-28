import Foundation
import AVFoundation
import CoreAudio
import AppKit

public final class AudioDuckingDetector {
    public static let shared = AudioDuckingDetector()

    public var onAudioStateChanged: ((Bool, [String]) -> Void)?
    private var timer: Timer?
    private(set) public var isOtherAudioPlaying: Bool = false
    private(set) public var activeAudioAppNames: [String] = []

    private let ignoredProcessNames: Set<String> = [
        "systemsoundserverd",
        "coreaudiod",
        "ControlCenter",
        "NotificationCenter",
        "screencapture",
        "audioaccessoryd",
        "bluetoothd",
        "launchd"
    ]

    private init() {}

    public func startMonitoring() {
        timer?.invalidate()
        checkAudioState()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkAudioState()
        }
        AppLogger.shared.info("[AUDIO-DUCKING] System audio output detector started monitoring.")
    }

    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isOtherAudioPlaying = false
        activeAudioAppNames = []
        AppLogger.shared.info("[AUDIO-DUCKING] System audio output detector stopped monitoring.")
    }

    public func checkAudioState() {
        let activeApps = getActiveAudioAppNames()
        let isUserAudioActive = !activeApps.isEmpty

        if isUserAudioActive != isOtherAudioPlaying || activeApps != activeAudioAppNames {
            isOtherAudioPlaying = isUserAudioActive
            activeAudioAppNames = activeApps

            if isUserAudioActive {
                let namesString = activeApps.joined(separator: ", ")
                AppLogger.shared.info("[AUDIO-DUCKING] Ducking wallpaper volume -> Active user audio process: '\(namesString)'")
            } else {
                AppLogger.shared.info("[AUDIO-DUCKING] User audio processes idle -> Restoring wallpaper volume")
            }

            onAudioStateChanged?(isUserAudioActive, activeApps)
        }
    }

    public func getActiveAudioAppNames() -> [String] {
        let ownPID = NSRunningApplication.current.processIdentifier
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == 0, size > 0 else {
            return []
        }

        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var processIDs = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &processIDs) == 0 else {
            return []
        }

        var appNames: [String] = []

        for procObjID in processIDs {
            var pidAddr = AudioObjectPropertyAddress(
                mSelector: kAudioProcessPropertyPID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var pid: pid_t = 0
            var pidSize = UInt32(MemoryLayout<pid_t>.size)
            guard AudioObjectGetPropertyData(procObjID, &pidAddr, 0, nil, &pidSize, &pid) == 0 else { continue }

            if pid == ownPID || pid == 0 { continue }

            var isRunningAddr = AudioObjectPropertyAddress(
                mSelector: kAudioProcessPropertyIsRunning,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var isRunning: UInt32 = 0
            var isRunningSize = UInt32(MemoryLayout<UInt32>.size)
            guard AudioObjectGetPropertyData(procObjID, &isRunningAddr, 0, nil, &isRunningSize, &isRunning) == 0 else { continue }

            if isRunning == 1 {
                let name = resolveProcessName(pid: pid)
                if !ignoredProcessNames.contains(name) && !appNames.contains(name) {
                    appNames.append(name)
                }
            }
        }
        return appNames
    }

    private func resolveProcessName(pid: pid_t) -> String {
        if let app = NSRunningApplication(processIdentifier: pid), let name = app.localizedName, !name.isEmpty {
            return name
        }
        var buffer = [CChar](repeating: 0, count: 1024)
        let ret = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        if ret > 0 {
            let path = String(cString: buffer)
            return (path as NSString).lastPathComponent
        }
        return "PID \(pid)"
    }
}


/// Core media player encapsulating AVPlayer streaming playback with automatic looping, volume control, audio ducking, and resource cleanup.
public final class MediaPlaybackCore: @unchecked Sendable {
    public private(set) var player: AVPlayer
    private var playerItemObserver: NSKeyValueObservation?
    private var loopObserver: NSObjectProtocol?

    public private(set) var currentURL: URL?
    public private(set) var userVolume: Float = 1.0
    public private(set) var isDucked: Bool = false

    private var targetVolume: Float = 1.0
    private var currentFadedVolume: Float = 1.0
    private var fadeTimer: Timer?

    /// Callback invoked when the current item finishes playing.
    public var onItemDidEnd: (() -> Void)?

    public var isPlaying: Bool {
        return player.timeControlStatus == .playing || player.rate > 0
    }

    public var durationSeconds: Double {
        guard let item = player.currentItem else { return 0 }
        let duration = item.duration.seconds
        return (duration.isNaN || duration.isInfinite) ? 0 : duration
    }

    public var currentTimeSeconds: Double {
        let time = player.currentTime().seconds
        return (time.isNaN || time.isInfinite) ? 0 : time
    }

    public init() {
        self.player = AVPlayer()
        self.player.actionAtItemEnd = .none
        setupAudioDuckingObserver()
    }

    deinit {
        stop()
    }

    private func setupAudioDuckingObserver() {
        AudioDuckingDetector.shared.onAudioStateChanged = { [weak self] active, activeApps in
            self?.applyActualVolume(animated: true)
            NotificationCenter.default.post(name: NSNotification.Name("wallpaperAudioDuckingActiveAppsDidChange"), object: activeApps)
        }
    }


    /// Load and stream video from a file URL without reading entire video into RAM.
    public func loadVideo(url: URL) {
        stop()

        self.currentURL = url
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: false])
        let item = AVPlayerItem(asset: asset)

        player.replaceCurrentItem(with: item)
        setupLooping(for: item)
        applyActualVolume(animated: false)
        AppLogger.shared.info("MediaPlaybackCore: Loaded video asset from \(url.path)")
    }

    public func play() {
        player.play()
        AppLogger.shared.debug("MediaPlaybackCore: Playback rate set to 1.0 for \(currentURL?.lastPathComponent ?? "unknown")")
    }

    public func pause() {
        player.pause()
        AppLogger.shared.debug("MediaPlaybackCore: Playback paused")
    }

    public func stop() {
        fadeTimer?.invalidate()
        fadeTimer = nil

        player.pause()
        player.replaceCurrentItem(with: nil)

        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
        playerItemObserver?.invalidate()
        playerItemObserver = nil

        AppLogger.shared.debug("MediaPlaybackCore: Stopped and resources released")
    }

    public func seek(toSeconds seconds: Double) {
        let targetTime = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        AppLogger.shared.debug("MediaPlaybackCore: Seeked to \(String(format: "%.2f", seconds))s")
    }

    public func seek(toProgress progress: Double) {
        let dur = durationSeconds
        guard dur > 0 else { return }
        let targetSeconds = max(0, min(dur, progress * dur))
        seek(toSeconds: targetSeconds)
    }

    public func setVolume(_ volume: Float) {
        self.userVolume = max(0.0, min(1.0, volume))
        applyActualVolume(animated: true)
        AppLogger.shared.debug("MediaPlaybackCore: User volume set to \(self.userVolume)")
    }

    public func setDucked(_ ducked: Bool) {
        self.isDucked = ducked
        if ducked {
            AudioDuckingDetector.shared.startMonitoring()
        } else {
            AudioDuckingDetector.shared.stopMonitoring()
        }
        applyActualVolume(animated: true)
        AppLogger.shared.info("MediaPlaybackCore: Audio ducking mode set to \(ducked)")
    }

    public func setMuted(_ isMuted: Bool) {
        player.isMuted = isMuted
    }

    private func applyActualVolume(animated: Bool = true) {
        let isOtherActive = isDucked && AudioDuckingDetector.shared.isOtherAudioPlaying
        let desired = isOtherActive ? (userVolume * 0.05) : userVolume

        if !animated {
            fadeTimer?.invalidate()
            fadeTimer = nil
            currentFadedVolume = desired
            player.volume = desired
            return
        }

        targetVolume = desired
        startVolumeFadeRamp()
    }

    private func startVolumeFadeRamp() {
        guard fadeTimer == nil else { return }

        fadeTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let diff = self.targetVolume - self.currentFadedVolume
            if abs(diff) < 0.005 {
                self.currentFadedVolume = self.targetVolume
                self.player.volume = self.targetVolume
                self.fadeTimer?.invalidate()
                self.fadeTimer = nil
            } else {
                self.currentFadedVolume += diff * 0.15
                self.player.volume = self.currentFadedVolume
            }
        }
    }

    private func setupLooping(for item: AVPlayerItem) {
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            if let callback = self.onItemDidEnd {
                callback()
            } else {
                self.player.seek(to: .zero) { _ in
                    self.player.play()
                    self.player.rate = 1.0
                }
            }
        }
    }
}



