import Foundation
import HealthKit

struct LiveWorkoutMetrics {
    var heartRate: Int?
    var activeEnergyKilocalories: Int
    var birthDate: Date?
}

final class HealthKitWorkoutManager: NSObject, @unchecked Sendable {
    var onMetrics: ((LiveWorkoutMetrics) -> Void)?
    var onStateChange: ((HKWorkoutSessionState, HKWorkoutSessionState) -> Void)?
    var onError: ((Error) -> Void)?

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var birthDate: Date?

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable(),
              let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate),
              let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return false
        }

        let readTypes: Set<HKObjectType> = [heartRate, activeEnergy]
        let shareTypes: Set<HKSampleType> = [HKObjectType.workoutType()]

        return await withCheckedContinuation { continuation in
            healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { [weak self] success, _ in
                self?.birthDate = try? self?.healthStore.dateOfBirthComponents().date
                DiagnosticsLogger.log("healthkit.authorization success=\(success)")
                continuation.resume(returning: success)
            }
        }
    }

    func begin(hand: RacketHand) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        DiagnosticsLogger.log("healthkit.begin requested hand=\(hand.rawValue)")

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .badminton
        configuration.locationType = .indoor

        let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
        builder.delegate = self
        session.delegate = self

        self.session = session
        self.builder = builder

        let startDate = Date()
        session.startActivity(with: startDate)
        DiagnosticsLogger.log("healthkit.session.startActivity")

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.beginCollection(withStart: startDate) { _, error in
                if let error {
                    DiagnosticsLogger.log("healthkit.builder.beginCollection error=\(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    DiagnosticsLogger.log("healthkit.builder.beginCollection success")
                    continuation.resume()
                }
            }
        }
    }

    func finish(discard: Bool = false, timeoutSeconds: TimeInterval = 4.0) async {
        let endDate = Date()
        DiagnosticsLogger.log("healthkit.finish requested discard=\(discard)")
        session?.end()

        guard let builder else {
            DiagnosticsLogger.log("healthkit.finish no builder")
            session = nil
            return
        }

        await withCheckedContinuation { continuation in
            let gate = ContinuationGate(continuation)

            DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds) {
                DiagnosticsLogger.log("healthkit.finish timeout after \(timeoutSeconds)s")
                gate.resume()
            }

            builder.endCollection(withEnd: endDate) { _, _ in
                DiagnosticsLogger.log("healthkit.builder.endCollection")
                if discard {
                    builder.discardWorkout()
                    DiagnosticsLogger.log("healthkit.builder.discardWorkout")
                    gate.resume()
                } else {
                    builder.finishWorkout { _, _ in
                        DiagnosticsLogger.log("healthkit.builder.finishWorkout")
                        gate.resume()
                    }
                }
            }
        }

        session = nil
        self.builder = nil
    }

    private func publishLatestMetrics() {
        guard let builder,
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate),
              let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return
        }

        let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
        let latestHeartRate = builder.statistics(for: heartRateType)?
            .mostRecentQuantity()?
            .doubleValue(for: heartRateUnit)

        let activeEnergy = builder.statistics(for: activeEnergyType)?
            .sumQuantity()?
            .doubleValue(for: .kilocalorie()) ?? 0

        let metrics = LiveWorkoutMetrics(
            heartRate: latestHeartRate.map { Int($0.rounded()) },
            activeEnergyKilocalories: max(0, Int(activeEnergy.rounded())),
            birthDate: birthDate
        )

        DispatchQueue.main.async { [onMetrics] in
            onMetrics?(metrics)
        }
    }
}

private final class ContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?

    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func resume() {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()

        continuation?.resume()
    }
}

extension HealthKitWorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        publishLatestMetrics()
    }
}

extension HealthKitWorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        DiagnosticsLogger.log("healthkit.session.state \(fromState.rawValue)->\(toState.rawValue)")
        DispatchQueue.main.async { [onStateChange] in
            onStateChange?(toState, fromState)
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DiagnosticsLogger.log("healthkit.session.error \(error.localizedDescription)")
        DispatchQueue.main.async { [onError] in
            onError?(error)
        }
    }
}
