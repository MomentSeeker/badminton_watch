import Foundation
import SwiftUI
import WatchKit

enum RacketHand: String, CaseIterable, Identifiable, Codable {
    case left
    case right

    var id: String { rawValue }
    var shortTitle: String { self == .left ? "L" : "R" }
    var title: String { self == .left ? "Left" : "Right" }
    var chineseTitle: String { self == .left ? "左手持拍" : "右手持拍" }
}

enum RecordingState {
    case idle
    case recording
    case pendingEndConfirm
    case saving
    case saved
    case calibrating
}

enum LiveTab: Int, CaseIterable, Identifiable {
    case body
    case badminton
    case action

    var id: Int { rawValue }
}

struct TrainingSession {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var racketHand: RacketHand = .right
    var elapsedSeconds: Int = 0
    var activeSeconds: Int = 0
    var currentHeartRate: Int?
    var heartZone: Int?
    var calories: Int = 0
    var swingCount: Int = 0
    var maxSwingSpeedKph: Int = 0
    var maxRallyStreak: Int = 0
    var smashCount: Int = 0
    var overheadCount: Int = 0
    var underhandCount: Int = 0
    var forehandCount: Int = 0
    var backhandCount: Int = 0

    static func started(hand: RacketHand, at date: Date = Date()) -> TrainingSession {
        TrainingSession(startedAt: date, racketHand: hand)
    }

    mutating func updateTiming(now: Date = Date()) {
        elapsedSeconds = max(0, Int(now.timeIntervalSince(startedAt)))
    }

    mutating func apply(_ metrics: LiveWorkoutMetrics) {
        currentHeartRate = metrics.heartRate
        calories = metrics.activeEnergyKilocalories

        if let heartRate = metrics.heartRate {
            heartZone = HeartRateZone.estimatedZone(for: heartRate, birthDate: metrics.birthDate)
        }
    }

    mutating func apply(_ metrics: SwingMetrics) {
        activeSeconds = metrics.activeSeconds
        swingCount = metrics.swingCount
        maxSwingSpeedKph = metrics.maxSwingSpeedKph
        maxRallyStreak = metrics.maxRallyStreak
        smashCount = metrics.smashCount
        overheadCount = metrics.overheadCount
        underhandCount = metrics.underhandCount
        forehandCount = metrics.forehandCount
        backhandCount = metrics.backhandCount
    }

    var snapshot: SessionSnapshot {
        SessionSnapshot(
            durationSeconds: elapsedSeconds,
            swingCount: swingCount,
            calories: calories,
            maxSwingSpeedKph: maxSwingSpeedKph
        )
    }
}

struct SessionSnapshot {
    let durationSeconds: Int
    let swingCount: Int
    let calories: Int
    let maxSwingSpeedKph: Int
}

struct HeartRateZone {
    static func estimatedZone(for heartRate: Int, birthDate: Date?) -> Int {
        let age = birthDate.map { Calendar.current.dateComponents([.year], from: $0, to: Date()).year ?? 30 } ?? 30
        let estimatedMax = max(120, Int((208.0 - 0.7 * Double(age)).rounded()))
        let ratio = Double(heartRate) / Double(estimatedMax)

        switch ratio {
        case ..<0.60:
            return 1
        case ..<0.70:
            return 2
        case ..<0.80:
            return 3
        case ..<0.90:
            return 4
        default:
            return 5
        }
    }
}

@MainActor
final class TrainingSessionStore: ObservableObject {
    @Published var racketHand: RacketHand = .right
    @Published var state: RecordingState = .idle
    @Published var activeTab: LiveTab = .body
    @Published var session: TrainingSession = .started(hand: .right)
    let calibrationStore = CalibrationDrillStore()

    private let workoutManager: HealthKitWorkoutManager
    private let calibrationWorkoutManager = HealthKitWorkoutManager()
    private let swingDetector: MotionSwingDetector
    private let runtimeKeeper = TrainingRuntimeKeeper()
    private var timer: Timer?

    init(
        workoutManager: HealthKitWorkoutManager = HealthKitWorkoutManager(),
        swingDetector: MotionSwingDetector = MotionSwingDetector()
    ) {
        self.workoutManager = workoutManager
        self.swingDetector = swingDetector

        self.workoutManager.onMetrics = { [weak self] metrics in
            Task { @MainActor in
                self?.session.apply(metrics)
            }
        }

        self.swingDetector.onMetrics = { [weak self] metrics in
            Task { @MainActor in
                self?.session.apply(metrics)
            }
        }

        self.workoutManager.onStateChange = { toState, fromState in
            DiagnosticsLogger.log("training.healthkit.state \(fromState.rawValue)->\(toState.rawValue)")
        }

        self.workoutManager.onError = { error in
            DiagnosticsLogger.log("training.healthkit.error \(error.localizedDescription)")
        }

        if ProcessInfo.processInfo.environment["KV_START_RECORDING"] == "1" {
            state = ProcessInfo.processInfo.environment["KV_CONFIRM_SCREEN"] == "1" ? .pendingEndConfirm : .recording
            session = .started(hand: racketHand)
            applyPreviewMetricsFromEnvironment()

            if let rawTab = ProcessInfo.processInfo.environment["KV_ACTIVE_TAB"].flatMap(Int.init),
               let tab = LiveTab(rawValue: rawTab) {
                activeTab = tab
            }

            startTimer()
        }
    }

    deinit {
        timer?.invalidate()
        runtimeKeeper.stop()
        swingDetector.stop()
    }

    func start() {
        DiagnosticsLogger.log("training.start requested hand=\(racketHand.rawValue)")
        session = .started(hand: racketHand)
        activeTab = .body
        state = .recording
        startTimer()
        runtimeKeeper.start()
        swingDetector.start(hand: racketHand)

        Task {
            let authorized = await workoutManager.requestAuthorization()
            DiagnosticsLogger.log("training.healthkit.authorized \(authorized)")
            do {
                try await workoutManager.begin(hand: racketHand)
                DiagnosticsLogger.log("training.healthkit.begin success")
            } catch {
                DiagnosticsLogger.log("training.healthkit.begin failed \(error.localizedDescription)")
            }
        }
    }

    func enterCalibration() {
        timer?.invalidate()
        timer = nil
        swingDetector.stop()
        calibrationStore.configure(hand: racketHand)
        state = .calibrating

        Task {
            _ = await calibrationWorkoutManager.requestAuthorization()
            do {
                try await calibrationWorkoutManager.begin(hand: racketHand)
            } catch {
                // Debug mode still records IMU samples if HealthKit cannot start.
            }
        }
    }

    func exitCalibration() {
        calibrationStore.stop()
        Task {
            await calibrationWorkoutManager.finish(discard: true)
        }
        state = .idle
    }

    func requestEndConfirmation() {
        state = .pendingEndConfirm
    }

    func continueRecording() {
        state = .recording
    }

    func endAndSave() {
        DiagnosticsLogger.log("training.endAndSave requested")
        state = .saving
        timer?.invalidate()
        timer = nil
        runtimeKeeper.stop()
        swingDetector.stop()

        Task {
            await workoutManager.finish()

            try? await Task.sleep(nanoseconds: 350_000_000)
            state = .saved

            try? await Task.sleep(nanoseconds: 1_100_000_000)
            state = .idle
            DiagnosticsLogger.log("training.state idle after save")
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state == .recording || self.state == .pendingEndConfirm else { return }
                self.session.updateTiming()
            }
        }
    }

    private func applyPreviewMetricsFromEnvironment() {
        let environment = ProcessInfo.processInfo.environment

        func intValue(_ key: String) -> Int? {
            environment[key].flatMap(Int.init)
        }

        if let elapsedSeconds = intValue("KV_SAMPLE_ELAPSED") {
            session.startedAt = Date().addingTimeInterval(TimeInterval(-elapsedSeconds))
            session.elapsedSeconds = elapsedSeconds
        }

        session.activeSeconds = intValue("KV_SAMPLE_ACTIVE") ?? session.activeSeconds
        session.currentHeartRate = intValue("KV_SAMPLE_HR") ?? session.currentHeartRate
        session.heartZone = intValue("KV_SAMPLE_ZONE") ?? session.heartZone
        session.calories = intValue("KV_SAMPLE_CALORIES") ?? session.calories
        session.swingCount = intValue("KV_SAMPLE_SWINGS") ?? session.swingCount
        session.maxSwingSpeedKph = intValue("KV_SAMPLE_SPEED") ?? session.maxSwingSpeedKph
        session.maxRallyStreak = intValue("KV_SAMPLE_RALLY") ?? session.maxRallyStreak
        session.smashCount = intValue("KV_SAMPLE_SMASH") ?? session.smashCount
        session.overheadCount = intValue("KV_SAMPLE_OVERHEAD") ?? session.overheadCount
        session.underhandCount = intValue("KV_SAMPLE_UNDERHAND") ?? session.underhandCount
        session.forehandCount = intValue("KV_SAMPLE_FOREHAND") ?? session.forehandCount
        session.backhandCount = intValue("KV_SAMPLE_BACKHAND") ?? session.backhandCount
    }
}

private final class TrainingRuntimeKeeper: NSObject, WKExtendedRuntimeSessionDelegate {
    private var session: WKExtendedRuntimeSession?

    func start() {
        guard session?.state != .running,
              session?.state != .scheduled else {
            return
        }

        let session = WKExtendedRuntimeSession()
        session.delegate = self
        self.session = session
        session.start()
        DiagnosticsLogger.log("runtime.session.start requested")
    }

    func stop() {
        session?.invalidate()
        session = nil
        DiagnosticsLogger.log("runtime.session.stop")
    }

    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        DiagnosticsLogger.log("runtime.session.didStart")
    }

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        DiagnosticsLogger.log("runtime.session.willExpire")
    }

    func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        DiagnosticsLogger.log("runtime.session.invalidated reason=\(reason.rawValue) error=\(error?.localizedDescription ?? "nil")")
        if session === extendedRuntimeSession {
            session = nil
        }
    }
}

extension Int {
    var clockString: String {
        let hours = self / 3600
        let minutes = (self % 3600) / 60
        let seconds = self % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }

    var groupedString: String {
        "\(self)"
    }

    var compactClockString: String {
        let minutes = self / 60
        let seconds = self % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
