import CoreMotion
import Foundation

struct SwingMetrics {
    var activeSeconds: Int = 0
    var swingCount: Int = 0
    var maxSwingSpeedKph: Int = 0
    var maxRallyStreak: Int = 0
    var smashCount: Int = 0
    var overheadCount: Int = 0
    var underhandCount: Int = 0
    var forehandCount: Int = 0
    var backhandCount: Int = 0
}

final class MotionSwingDetector {
    var onMetrics: ((SwingMetrics) -> Void)?

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

    private struct SwingWindowFeatures {
        let timestamp: TimeInterval
        let peakTimestamp: TimeInterval
        let peakAccelerationG: Double
        let peakRotationRads: Double
        let accelerationImpulse: Double
        let meanAccelerationG: Double
        let meanRotationRads: Double
        let standardDeviationAccelerationG: Double
        let standardDeviationRotationRads: Double
        let skewnessAccelerationG: Double
        let skewnessRotationRads: Double
        let signedVerticalRotation: Double
        let signedLateralRotation: Double
        let peakScore: Double
        let samples: [MotionSample]

        var recordFeatures: SwingWindowRecord.Features {
            SwingWindowRecord.Features(
                peakAccelerationG: peakAccelerationG,
                peakRotationRads: peakRotationRads,
                accelerationImpulse: accelerationImpulse,
                meanAccelerationG: meanAccelerationG,
                meanRotationRads: meanRotationRads,
                standardDeviationAccelerationG: standardDeviationAccelerationG,
                standardDeviationRotationRads: standardDeviationRotationRads,
                skewnessAccelerationG: skewnessAccelerationG,
                skewnessRotationRads: skewnessRotationRads,
                signedVerticalRotation: signedVerticalRotation,
                signedLateralRotation: signedLateralRotation,
                peakScore: peakScore
            )
        }
    }

    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    private let recorder = SwingWindowRecorder()
    private var calibration = SwingCalibration.fallback
    private var hand: RacketHand = .right
    private var metrics = SwingMetrics()
    private var samples: [MotionSample] = []
    private var lastSwingTimestamp: TimeInterval?
    private var currentRallyStreak = 0
    private var lastPeakTimestamp: TimeInterval = 0
    private var lastMotionTimestamp: TimeInterval?
    private var activeDurationSeconds: Double = 0
    private var detectorArmed = true

    init() {
        queue.name = "KineticVelocity.IMU"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1
    }

    func start(hand: RacketHand) {
        self.hand = hand
        metrics = SwingMetrics()
        samples.removeAll(keepingCapacity: true)
        lastSwingTimestamp = nil
        currentRallyStreak = 0
        lastPeakTimestamp = 0
        lastMotionTimestamp = nil
        activeDurationSeconds = 0
        detectorArmed = true
        calibration = SwingCalibration.load()

        guard motionManager.isDeviceMotionAvailable else {
            publish()
            return
        }

        motionManager.deviceMotionUpdateInterval = 1.0 / calibration.sampleRateHz
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.process(motion)
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }

    private func process(_ motion: CMDeviceMotion) {
        let acceleration = motion.userAcceleration
        let rotation = motion.rotationRate
        let accelerationMagnitude = magnitude(acceleration.x, acceleration.y, acceleration.z)
        let rotationMagnitude = magnitude(rotation.x, rotation.y, rotation.z)
        let timestamp = motion.timestamp

        let sample = MotionSample(
            timestamp: timestamp,
            accelerationX: acceleration.x,
            accelerationY: acceleration.y,
            accelerationZ: acceleration.z,
            rotationX: rotation.x,
            rotationY: rotation.y,
            rotationZ: rotation.z,
            accelerationMagnitude: accelerationMagnitude,
            rotationMagnitude: rotationMagnitude
        )

        samples.append(sample)
        samples.removeAll { timestamp - $0.timestamp > calibration.sampleBufferSeconds }

        updateActiveDuration(with: sample)
        detectSwing(endingAt: sample)
    }

    private func updateActiveDuration(with sample: MotionSample) {
        defer { lastMotionTimestamp = sample.timestamp }

        guard let lastMotionTimestamp else { return }

        let delta = min(max(sample.timestamp - lastMotionTimestamp, 0), 0.1)
        let isTrainingMotion = sample.accelerationMagnitude > calibration.activeAccelerationG
            || sample.rotationMagnitude > calibration.activeRotationRads

        guard isTrainingMotion else { return }

        activeDurationSeconds += delta
        let activeSeconds = Int(activeDurationSeconds.rounded(.down))

        if activeSeconds != metrics.activeSeconds {
            metrics.activeSeconds = activeSeconds
            publish()
        }
    }

    private func detectSwing(endingAt sample: MotionSample) {
        let rearmThreshold = calibration.detectionPeakScore * calibration.detectionRearmPeakScoreRatio
        if !detectorArmed {
            detectorArmed = sample.swingScore < rearmThreshold
            return
        }

        guard sample.timestamp - lastPeakTimestamp > calibration.cooldownSeconds else { return }

        guard let features = makeFeatures(endingAt: sample),
              sample.timestamp - features.peakTimestamp <= calibration.localPeakMaxDelaySeconds,
              sample.swingScore >= features.peakScore * calibration.localPeakScoreRatio,
              features.peakAccelerationG > calibration.detectionPeakAccelerationG,
              features.peakRotationRads > calibration.detectionPeakRotationRads,
              features.accelerationImpulse > calibration.detectionAccelerationImpulse,
              features.peakScore > calibration.detectionPeakScore else {
            return
        }

        lastPeakTimestamp = features.peakTimestamp
        detectorArmed = false
        registerSwing(features)
    }

    private func makeFeatures(endingAt sample: MotionSample) -> SwingWindowFeatures? {
        let window = samples.filter { sample.timestamp - $0.timestamp <= calibration.windowSeconds }
        guard window.count >= calibration.minimumWindowSampleCount else { return nil }

        let peakAcceleration = window.map(\.accelerationMagnitude).max() ?? 0
        let peakRotation = window.map(\.rotationMagnitude).max() ?? 0
        let peakScore = window.map(\.swingScore).max() ?? 0
        let peakSample = window.max { lhs, rhs in
            lhs.swingScore < rhs.swingScore
        } ?? sample
        let accelerationValues = window.map(\.accelerationMagnitude)
        let rotationValues = window.map(\.rotationMagnitude)
        let meanAcceleration = mean(accelerationValues)
        let meanRotation = mean(rotationValues)
        let standardDeviationAcceleration = standardDeviation(accelerationValues, mean: meanAcceleration)
        let standardDeviationRotation = standardDeviation(rotationValues, mean: meanRotation)
        let impulse = window.reduce(0.0) { partial, sample in
            partial + max(0, sample.accelerationMagnitude - calibration.activeAccelerationG) * (1.0 / calibration.sampleRateHz)
        }
        let verticalRotation = window.reduce(0.0) { $0 + $1.rotationZ }
        let lateralRotation = window.reduce(0.0) { $0 + $1.rotationY }

        return SwingWindowFeatures(
            timestamp: sample.timestamp,
            peakTimestamp: peakSample.timestamp,
            peakAccelerationG: peakAcceleration,
            peakRotationRads: peakRotation,
            accelerationImpulse: impulse,
            meanAccelerationG: meanAcceleration,
            meanRotationRads: meanRotation,
            standardDeviationAccelerationG: standardDeviationAcceleration,
            standardDeviationRotationRads: standardDeviationRotation,
            skewnessAccelerationG: skewness(accelerationValues, mean: meanAcceleration, standardDeviation: standardDeviationAcceleration),
            skewnessRotationRads: skewness(rotationValues, mean: meanRotation, standardDeviation: standardDeviationRotation),
            signedVerticalRotation: verticalRotation,
            signedLateralRotation: lateralRotation,
            peakScore: peakScore,
            samples: window
        )
    }

    private func registerSwing(_ features: SwingWindowFeatures) {
        metrics.swingCount += 1

        if let lastSwingTimestamp, features.timestamp - lastSwingTimestamp < calibration.rallyGapSeconds {
            currentRallyStreak += 1
        } else {
            currentRallyStreak = 1
        }

        lastSwingTimestamp = features.timestamp
        metrics.maxRallyStreak = max(metrics.maxRallyStreak, currentRallyStreak)

        // Published badminton IMU work uses 50 Hz accelerometer/gyroscope windows
        // for stroke recognition. Until player-labeled data is available, this
        // app keeps classification explainable: detect swing windows from peak
        // acceleration + rotation, then classify by dominant signed wrist axes.
        let speedKph = Int((features.peakRotationRads * calibration.estimatedRacketRadiusMeters * 3.6).rounded())
        metrics.maxSwingSpeedKph = max(metrics.maxSwingSpeedKph, speedKph)

        let predictedPower: String
        if features.peakAccelerationG > calibration.smashPeakAccelerationG
            && features.peakRotationRads > calibration.smashPeakRotationRads
            && features.accelerationImpulse > calibration.smashAccelerationImpulse {
            metrics.smashCount += 1
            predictedPower = "smash"
        } else {
            predictedPower = "non_smash"
        }

        let predictedStrokeType: String
        if features.signedVerticalRotation >= calibration.overheadVerticalThreshold {
            metrics.overheadCount += 1
            predictedStrokeType = "overhead"
        } else {
            metrics.underhandCount += 1
            predictedStrokeType = "underhand"
        }

        let lateralSign = hand == .right ? features.signedLateralRotation : -features.signedLateralRotation
        let predictedDirection: String
        if lateralSign >= calibration.forehandLateralThreshold {
            metrics.forehandCount += 1
            predictedDirection = "forehand"
        } else {
            metrics.backhandCount += 1
            predictedDirection = "backhand"
        }

        recorder.record(
            SwingWindowRecord(
                recordedAt: Date(),
                hand: hand,
                predictedStrokeType: predictedStrokeType,
                predictedDirection: predictedDirection,
                predictedPower: predictedPower,
                features: features.recordFeatures,
                samples: features.samples.map(\.recordSample)
            )
        )

        publish()
    }

    private func publish() {
        let metrics = metrics
        DispatchQueue.main.async { [onMetrics] in
            onMetrics?(metrics)
        }
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
