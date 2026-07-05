import CoreMotion
import AVFAudio
import SwiftUI
import WatchKit

struct CalibrationDrillTask: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let targetReps: Int
    let systemImage: String
    let accent: Color
    let labelSwing: String
    let labelStrokeType: String?
    let labelDirection: String?
    let labelPower: String?

    static let all: [CalibrationDrillTask] = [
        CalibrationDrillTask(
            id: "forehand_20",
            title: "正手",
            subtitle: "主峰贴正手",
            targetReps: 20,
            systemImage: "arrow.right",
            accent: KVColor.courtAmber,
            labelSwing: "yes",
            labelStrokeType: nil,
            labelDirection: "forehand",
            labelPower: nil
        ),
        CalibrationDrillTask(
            id: "backhand_20",
            title: "反手",
            subtitle: "主峰贴反手",
            targetReps: 20,
            systemImage: "arrow.left",
            accent: KVColor.courtAmber,
            labelSwing: "yes",
            labelStrokeType: nil,
            labelDirection: "backhand",
            labelPower: nil
        ),
        CalibrationDrillTask(
            id: "overhead_20",
            title: "上手",
            subtitle: "高点击球",
            targetReps: 20,
            systemImage: "arrow.up.right",
            accent: KVColor.load,
            labelSwing: "yes",
            labelStrokeType: "overhead",
            labelDirection: nil,
            labelPower: nil
        ),
        CalibrationDrillTask(
            id: "underhand_20",
            title: "下手",
            subtitle: "低点击球",
            targetReps: 20,
            systemImage: "arrow.down.right",
            accent: KVColor.load,
            labelSwing: "yes",
            labelStrokeType: "underhand",
            labelDirection: nil,
            labelPower: nil
        ),
        CalibrationDrillTask(
            id: "smash_20",
            title: "杀球",
            subtitle: "强力挥拍",
            targetReps: 20,
            systemImage: "bolt.fill",
            accent: KVColor.lime,
            labelSwing: "yes",
            labelStrokeType: "overhead",
            labelDirection: nil,
            labelPower: "smash"
        ),
        CalibrationDrillTask(
            id: "normal_20",
            title: "普通",
            subtitle: "非杀球",
            targetReps: 20,
            systemImage: "figure.badminton",
            accent: KVColor.cyan,
            labelSwing: "yes",
            labelStrokeType: nil,
            labelDirection: nil,
            labelPower: "non_smash"
        ),
        CalibrationDrillTask(
            id: "negative_10",
            title: "误触发",
            subtitle: "回位/举拍/走动",
            targetReps: 10,
            systemImage: "xmark",
            accent: KVColor.pink,
            labelSwing: "no",
            labelStrokeType: nil,
            labelDirection: nil,
            labelPower: nil
        )
    ]
}

enum CalibrationDrillPhase {
    case select
    case armed
    case locked
    case complete
}

struct CalibrationCaptureResult {
    let task: CalibrationDrillTask
    let repIndex: Int
    let peakScore: Double
}

@MainActor
final class CalibrationDrillStore: NSObject, ObservableObject {
    @Published var hand: RacketHand = .right
    @Published var selectedTask: CalibrationDrillTask?
    @Published var phase: CalibrationDrillPhase = .select
    @Published var completedReps: Int = 0
    @Published var lastPeakScore: Double?
    @Published var statusText: String = "选择采集动作"
    @Published var cueText: String = "选择"

    private let capture = CalibrationMotionCapture()
    private let speech = CalibrationSpeechCuePlayer()
    private var runtimeSession: WKExtendedRuntimeSession?

    override init() {
        super.init()
        capture.onCapture = { [weak self] result in
            Task { @MainActor in
                self?.handleCapture(result)
            }
        }
    }

    func configure(hand: RacketHand) {
        self.hand = hand
        startRuntimeSession()
        capture.start(hand: hand)
        if phase == .select {
            statusText = "选择采集动作"
            cueText = "选择"
        }
    }

    func start(task: CalibrationDrillTask) {
        selectedTask = task
        completedReps = 0
        lastPeakScore = nil
        cueText = "准备"
        capture.start(hand: hand)
        armNextRep()
    }

    func armNextRep() {
        guard let selectedTask else { return }
        let nextRep = completedReps + 1
        phase = .armed
        cueText = "挥拍"
        statusText = "\(selectedTask.title) \(nextRep)/\(selectedTask.targetReps) 现在打一拍"
        WKInterfaceDevice.current().play(.start)
        speech.say("准备，挥拍")
        capture.arm(task: selectedTask, repIndex: nextRep)
    }

    func stop() {
        capture.stop()
        stopRuntimeSession()
        selectedTask = nil
        completedReps = 0
        lastPeakScore = nil
        phase = .select
        statusText = "选择采集动作"
        cueText = "选择"
    }

    func backToMenu() {
        capture.cancelCurrentRep()
        selectedTask = nil
        completedReps = 0
        lastPeakScore = nil
        phase = .select
        statusText = "选择采集动作"
        cueText = "选择"
    }

    private func handleCapture(_ result: CalibrationCaptureResult) {
        guard selectedTask == result.task else { return }

        completedReps = max(completedReps, result.repIndex)
        lastPeakScore = result.peakScore
        phase = completedReps >= result.task.targetReps ? .complete : .locked
        cueText = completedReps >= result.task.targetReps ? "完成" : "恢复"
        statusText = completedReps >= result.task.targetReps ? "采集完成，数据已保存" : "自然回位，等待下一次提示"
        WKInterfaceDevice.current().play(completedReps >= result.task.targetReps ? .success : .click)
        speech.say(completedReps >= result.task.targetReps ? "完成" : "恢复")

        guard completedReps < result.task.targetReps else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) { [weak self] in
            Task { @MainActor in
                guard let self, self.selectedTask == result.task, self.phase == .locked else { return }
                self.armNextRep()
            }
        }
    }

    private func startRuntimeSession() {
        guard runtimeSession?.state != .running,
              runtimeSession?.state != .scheduled else {
            return
        }

        let session = WKExtendedRuntimeSession()
        session.delegate = self
        runtimeSession = session
        session.start()
    }

    private func stopRuntimeSession() {
        runtimeSession?.invalidate()
        runtimeSession = nil
    }
}

extension CalibrationDrillStore: WKExtendedRuntimeSessionDelegate {
    nonisolated func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    nonisolated func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    nonisolated func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        Task { @MainActor in
            if self.runtimeSession === extendedRuntimeSession {
                self.runtimeSession = nil
            }
        }
    }
}

private final class CalibrationSpeechCuePlayer {
    private let synthesizer = AVSpeechSynthesizer()

    func say(_ text: String) {
        guard !text.isEmpty else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.46
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }
}

private final class CalibrationMotionCapture {
    var onCapture: ((CalibrationCaptureResult) -> Void)?

    private struct MotionSample {
        let timestamp: TimeInterval
        let accelerationX: Double
        let accelerationY: Double
        let accelerationZ: Double
        let rotationX: Double
        let rotationY: Double
        let rotationZ: Double
        let accelerationMagnitude: Double
        let rotationMagnitude: Double

        var swingScore: Double {
            accelerationMagnitude * 3.0 + rotationMagnitude
        }

        var recordSample: SwingWindowRecord.Sample {
            SwingWindowRecord.Sample(
                timestamp: timestamp,
                accelerationX: accelerationX,
                accelerationY: accelerationY,
                accelerationZ: accelerationZ,
                rotationX: rotationX,
                rotationY: rotationY,
                rotationZ: rotationZ
            )
        }
    }

    private struct PendingStroke {
        let task: CalibrationDrillTask
        let repIndex: Int
        let peakTimestamp: TimeInterval
        let peakScore: Double
    }

    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    private let recorder = SwingWindowRecorder()
    private var calibration = SwingCalibration.fallback
    private var hand: RacketHand = .right
    private var samples: [MotionSample] = []
    private var armedTask: CalibrationDrillTask?
    private var armedRepIndex = 0
    private var candidateSamples: [MotionSample] = []
    private var candidateStartTimestamp: TimeInterval?
    private var candidatePeakSample: MotionSample?
    private var pendingStroke: PendingStroke?

    init() {
        queue.name = "KineticVelocity.CalibrationIMU"
        queue.qualityOfService = .userInitiated
    }

    func start(hand: RacketHand) {
        self.hand = hand
        calibration = SwingCalibration.load()

        guard !motionManager.isDeviceMotionActive else { return }
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / calibration.sampleRateHz
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.process(motion)
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        cancelCurrentRep()
        samples.removeAll(keepingCapacity: false)
    }

    func arm(task: CalibrationDrillTask, repIndex: Int) {
        armedTask = task
        armedRepIndex = repIndex
        candidateSamples.removeAll(keepingCapacity: true)
        candidateStartTimestamp = nil
        candidatePeakSample = nil
        pendingStroke = nil
    }

    func cancelCurrentRep() {
        armedTask = nil
        armedRepIndex = 0
        candidateSamples.removeAll(keepingCapacity: true)
        candidateStartTimestamp = nil
        candidatePeakSample = nil
        pendingStroke = nil
    }

    private func process(_ motion: CMDeviceMotion) {
        let acceleration = motion.userAcceleration
        let rotation = motion.rotationRate
        let timestamp = motion.timestamp
        let sample = MotionSample(
            timestamp: timestamp,
            accelerationX: acceleration.x,
            accelerationY: acceleration.y,
            accelerationZ: acceleration.z,
            rotationX: rotation.x,
            rotationY: rotation.y,
            rotationZ: rotation.z,
            accelerationMagnitude: magnitude(acceleration.x, acceleration.y, acceleration.z),
            rotationMagnitude: magnitude(rotation.x, rotation.y, rotation.z)
        )

        samples.append(sample)
        samples.removeAll { timestamp - $0.timestamp > 1.15 }

        if let pendingStroke {
            collectRecoveryIfReady(now: sample.timestamp, pending: pendingStroke)
            return
        }

        guard let armedTask else { return }
        updateCandidate(with: sample, task: armedTask)
    }

    private func updateCandidate(with sample: MotionSample, task: CalibrationDrillTask) {
        let hardThresholdPassed = sample.accelerationMagnitude > calibration.detectionPeakAccelerationG
            && sample.rotationMagnitude > calibration.detectionPeakRotationRads
            && sample.swingScore > calibration.detectionPeakScore

        if candidateStartTimestamp == nil {
            guard hardThresholdPassed else { return }
            candidateStartTimestamp = sample.timestamp
            candidateSamples = samples.filter { sample.timestamp - $0.timestamp <= 0.24 }
            candidatePeakSample = candidateSamples.max { $0.swingScore < $1.swingScore } ?? sample
            return
        }

        candidateSamples.append(sample)
        if let candidatePeakSample {
            self.candidatePeakSample = sample.swingScore > candidatePeakSample.swingScore ? sample : candidatePeakSample
        } else {
            candidatePeakSample = sample
        }

        let elapsed = sample.timestamp - (candidateStartTimestamp ?? sample.timestamp)
        let rearmScore = calibration.detectionPeakScore * calibration.detectionRearmPeakScoreRatio
        let scoreFell = elapsed > 0.16 && sample.swingScore < rearmScore
        let timedOut = elapsed > calibration.windowSeconds + 0.20

        guard scoreFell || timedOut else { return }
        finalizeCandidate(task: task)
    }

    private func finalizeCandidate(task: CalibrationDrillTask) {
        guard let peak = candidatePeakSample else {
            cancelCurrentRep()
            return
        }

        let window = samples.filter { sample in
            sample.timestamp >= peak.timestamp - 0.28 && sample.timestamp <= peak.timestamp + 0.16
        }

        let usableWindow = window.count >= calibration.minimumWindowSampleCount ? window : candidateSamples
        guard usableWindow.count >= max(8, calibration.minimumWindowSampleCount / 2),
              let features = makeFeatures(from: usableWindow, peak: peak) else {
            candidateSamples.removeAll(keepingCapacity: true)
            candidateStartTimestamp = nil
            candidatePeakSample = nil
            return
        }

        let labels = predictedLabels(for: features)
        let repIndex = armedRepIndex
        recorder.record(
            SwingWindowRecord(
                recordedAt: Date(),
                hand: hand,
                predictedStrokeType: labels.strokeType,
                predictedDirection: labels.direction,
                predictedPower: labels.power,
                labelSwing: task.labelSwing,
                labelStrokeType: task.labelStrokeType,
                labelDirection: task.labelDirection,
                labelPower: task.labelPower,
                drillId: task.id,
                drillName: task.title,
                drillRepIndex: repIndex,
                windowRole: "stroke_peak",
                features: features,
                samples: usableWindow.map(\.recordSample)
            )
        )

        pendingStroke = PendingStroke(
            task: task,
            repIndex: repIndex,
            peakTimestamp: peak.timestamp,
            peakScore: peak.swingScore
        )
        armedTask = nil
        candidateSamples.removeAll(keepingCapacity: true)
        candidateStartTimestamp = nil
        candidatePeakSample = nil
    }

    private func collectRecoveryIfReady(now: TimeInterval, pending: PendingStroke) {
        guard now - pending.peakTimestamp >= 0.92 else { return }

        let recovery = samples.filter { sample in
            sample.timestamp >= pending.peakTimestamp + 0.34 && sample.timestamp <= pending.peakTimestamp + 0.92
        }

        if recovery.count >= 8,
           let peak = recovery.max(by: { $0.swingScore < $1.swingScore }),
           let features = makeFeatures(from: recovery, peak: peak) {
            let labels = predictedLabels(for: features)
            recorder.record(
                SwingWindowRecord(
                    recordedAt: Date(),
                    hand: hand,
                    predictedStrokeType: labels.strokeType,
                    predictedDirection: labels.direction,
                    predictedPower: labels.power,
                    labelSwing: "no",
                    labelStrokeType: nil,
                    labelDirection: nil,
                    labelPower: nil,
                    drillId: pending.task.id,
                    drillName: pending.task.title,
                    drillRepIndex: pending.repIndex,
                    windowRole: "recovery",
                    features: features,
                    samples: recovery.map(\.recordSample)
                )
            )
        }

        pendingStroke = nil
        onCapture?(
            CalibrationCaptureResult(
                task: pending.task,
                repIndex: pending.repIndex,
                peakScore: pending.peakScore
            )
        )
    }

    private func makeFeatures(from window: [MotionSample], peak: MotionSample) -> SwingWindowRecord.Features? {
        guard !window.isEmpty else { return nil }

        let accelerationValues = window.map(\.accelerationMagnitude)
        let rotationValues = window.map(\.rotationMagnitude)
        let meanAcceleration = mean(accelerationValues)
        let meanRotation = mean(rotationValues)
        let standardDeviationAcceleration = standardDeviation(accelerationValues, mean: meanAcceleration)
        let standardDeviationRotation = standardDeviation(rotationValues, mean: meanRotation)
        let accelerationImpulse = window.reduce(0.0) { partial, sample in
            partial + max(0, sample.accelerationMagnitude - calibration.activeAccelerationG) * (1.0 / calibration.sampleRateHz)
        }

        return SwingWindowRecord.Features(
            peakAccelerationG: window.map(\.accelerationMagnitude).max() ?? 0,
            peakRotationRads: window.map(\.rotationMagnitude).max() ?? 0,
            accelerationImpulse: accelerationImpulse,
            meanAccelerationG: meanAcceleration,
            meanRotationRads: meanRotation,
            standardDeviationAccelerationG: standardDeviationAcceleration,
            standardDeviationRotationRads: standardDeviationRotation,
            skewnessAccelerationG: skewness(accelerationValues, mean: meanAcceleration, standardDeviation: standardDeviationAcceleration),
            skewnessRotationRads: skewness(rotationValues, mean: meanRotation, standardDeviation: standardDeviationRotation),
            signedVerticalRotation: window.reduce(0.0) { $0 + $1.rotationZ },
            signedLateralRotation: window.reduce(0.0) { $0 + $1.rotationY },
            peakScore: peak.swingScore
        )
    }

    private func predictedLabels(for features: SwingWindowRecord.Features) -> (strokeType: String, direction: String, power: String) {
        let strokeType = features.signedVerticalRotation >= calibration.overheadVerticalThreshold ? "overhead" : "underhand"
        let lateralSign = hand == .right ? features.signedLateralRotation : -features.signedLateralRotation
        let direction = lateralSign >= calibration.forehandLateralThreshold ? "forehand" : "backhand"
        let power = features.peakAccelerationG > calibration.smashPeakAccelerationG
            && features.peakRotationRads > calibration.smashPeakRotationRads
            && features.accelerationImpulse > calibration.smashAccelerationImpulse ? "smash" : "non_smash"

        return (strokeType, direction, power)
    }

    private func magnitude(_ x: Double, _ y: Double, _ z: Double) -> Double {
        sqrt(x * x + y * y + z * z)
    }

    private func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func standardDeviation(_ values: [Double], mean: Double) -> Double {
        guard values.count > 1 else { return 0 }
        let variance = values.reduce(0) { partial, value in
            let diff = value - mean
            return partial + diff * diff
        } / Double(values.count - 1)

        return sqrt(variance)
    }

    private func skewness(_ values: [Double], mean: Double, standardDeviation: Double) -> Double {
        guard values.count > 2, standardDeviation > 0 else { return 0 }

        let moment = values.reduce(0) { partial, value in
            partial + pow((value - mean) / standardDeviation, 3)
        }

        return moment / Double(values.count)
    }
}

struct CalibrationDebugView: View {
    @ObservedObject var store: CalibrationDrillStore
    let onExit: () -> Void

    var body: some View {
        ZStack {
            KVColor.background.ignoresSafeArea(.all)
            TelemetryGridBackground(
                gridColor: KVColor.lime.opacity(0.07),
                waveColor: (store.selectedTask?.accent ?? KVColor.cyan).opacity(0.18)
            )

            switch store.phase {
            case .select:
                calibrationMenu
            case .armed, .locked, .complete:
                drillSession
            }
        }
        .ignoresSafeArea(.all)
        .simultaneousGesture(exitSwipeGesture)
    }

    private var exitSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard store.phase == .select else { return }

                let horizontal = value.translation.width
                let vertical = abs(value.translation.height)
                guard horizontal > 34, abs(horizontal) > vertical * 1.25 else { return }

                onExit()
            }
    }

    private var calibrationMenu: some View {
        VStack(spacing: 6) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("DEBUG MODE")
                        .font(KVFont.headline(13))
                        .italic()
                        .foregroundStyle(KVColor.text)
                    Text("单拍主峰采集")
                        .font(KVFont.body(9, weight: .semibold))
                        .foregroundStyle(KVColor.lime)
                }

                Spacer(minLength: 4)

                Button(action: onExit) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(KVColor.text)
                        .frame(width: 28, height: 28)
                        .background(KVColor.surface.opacity(0.82), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 15)

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(CalibrationDrillTask.all) { task in
                        Button {
                            store.start(task: task)
                        } label: {
                            CalibrationTaskRow(task: task)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
    }

    private var drillSession: some View {
        let task = store.selectedTask
        let progress = task.map { Double(store.completedReps) / Double($0.targetReps) } ?? 0
        let accent = task?.accent ?? KVColor.lime

        return VStack(spacing: 7) {
            HStack {
                Button {
                    store.backToMenu()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(KVColor.text)
                        .frame(width: 28, height: 28)
                        .background(KVColor.surface.opacity(0.82), in: Circle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 4)

                VStack(spacing: 1) {
                    Text(task?.title.uppercased() ?? "DEBUG")
                        .font(KVFont.headline(14))
                        .italic()
                        .foregroundStyle(KVColor.text)
                    Text(task?.subtitle ?? "采集中")
                        .font(KVFont.body(9, weight: .semibold))
                        .foregroundStyle(accent)
                }

                Spacer(minLength: 4)

                Image(systemName: task?.systemImage ?? "scope")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color.black)
                    .frame(width: 28, height: 28)
                    .background(accent, in: Circle())
            }
            .padding(.horizontal, 12)
            .padding(.top, 15)

            ZStack {
                Circle()
                    .stroke(KVColor.surfaceHigh.opacity(0.82), lineWidth: 10)

                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .telemetryGlow(accent)

                VStack(spacing: -2) {
                    Text("\(store.completedReps)")
                        .font(KVFont.data(44))
                        .foregroundStyle(KVColor.text)
                    Text("/ \(task?.targetReps ?? 0)")
                        .font(KVFont.data(11, weight: .medium))
                        .foregroundStyle(accent)
                }
            }
            .frame(width: 108, height: 108)

            VStack(spacing: 3) {
                Text(store.cueText)
                    .font(KVFont.headline(25))
                    .italic()
                    .foregroundStyle(statusColor(accent: accent))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text(store.statusText)
                    .font(KVFont.body(10, weight: .bold))
                    .foregroundStyle(KVColor.text.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                if let score = store.lastPeakScore {
                    Text("PEAK \(Int(score.rounded()))")
                        .font(KVFont.data(8, weight: .medium))
                        .foregroundStyle(accent.opacity(0.82))
                }
            }

            if store.phase == .complete, let task {
                Button {
                    store.start(task: task)
                } label: {
                    Text("REPEAT")
                        .font(KVFont.headline(11))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(accent, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            } else {
                HStack(spacing: 5) {
                    Circle()
                        .fill(accent)
                        .frame(width: 5, height: 5)
                Text(instructionText)
                        .font(KVFont.body(8, weight: .semibold))
                        .foregroundStyle(KVColor.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                }
                .padding(.horizontal, 12)
            }

            Spacer(minLength: 6)
        }
    }

    private var statusTitle: String {
        switch store.phase {
        case .select:
            return "SELECT"
        case .armed:
            return "ARMED"
        case .locked:
            return "LOCKED"
        case .complete:
            return "DONE"
        }
    }

    private var instructionText: String {
        switch store.phase {
        case .armed:
            return "现在打一拍，打完自然回位"
        case .locked:
            return "回位中，等下一次震动"
        case .complete:
            return "数据已写入手表，可导出分析"
        case .select:
            return "选择动作后按震动节奏采集"
        }
    }

    private func statusColor(accent: Color) -> Color {
        switch store.phase {
        case .armed, .complete:
            return accent
        case .locked:
            return KVColor.courtAmber
        case .select:
            return KVColor.muted
        }
    }
}

private struct CalibrationTaskRow: View {
    let task: CalibrationDrillTask

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: task.systemImage)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(task.labelSwing == "no" ? KVColor.text : Color.black)
                .frame(width: 24, height: 24)
                .background(task.labelSwing == "no" ? task.accent.opacity(0.22) : task.accent, in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(KVFont.body(10, weight: .bold))
                    .foregroundStyle(KVColor.text)
                    .lineLimit(1)

                Text(task.subtitle)
                    .font(KVFont.body(8, weight: .semibold))
                    .foregroundStyle(task.accent)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text("\(task.targetReps)")
                .font(KVFont.data(12))
                .foregroundStyle(task.accent)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 39)
        .background(KVColor.surface.opacity(0.80), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(task.accent.opacity(0.24), lineWidth: 1)
        }
    }
}
