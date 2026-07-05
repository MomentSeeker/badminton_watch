import Foundation

struct SwingCalibration: Codable {
    var sampleRateHz: Double = 100.0
    var windowSeconds: Double = 0.42
    var sampleBufferSeconds: Double = 0.55
    var cooldownSeconds: Double = 0.42
    var activeAccelerationG: Double = 0.18
    var activeRotationRads: Double = 1.25
    var minimumWindowSampleCount: Int = 12
    var detectionPeakAccelerationG: Double = 0.95
    var detectionPeakRotationRads: Double = 4.6
    var detectionAccelerationImpulse: Double = 0.08
    var detectionPeakScore: Double = 7.4
    var localPeakMaxDelaySeconds: Double = 0.10
    var localPeakScoreRatio: Double = 0.85
    var detectionRearmPeakScoreRatio: Double = 0.68
    var smashPeakAccelerationG: Double = 1.9
    var smashPeakRotationRads: Double = 8.8
    var smashAccelerationImpulse: Double = 0.22
    var overheadVerticalThreshold: Double = 0.0
    var forehandLateralThreshold: Double = 0.0
    var estimatedRacketRadiusMeters: Double = 1.35
    var rallyGapSeconds: Double = 8.0

    static let fallback = SwingCalibration()

    static func load() -> SwingCalibration {
        let decoder = JSONDecoder()

        for url in candidateURLs() {
            guard let data = try? Data(contentsOf: url),
                  let calibration = try? decoder.decode(SwingCalibration.self, from: data) else {
                continue
            }

            return calibration
        }

        return .fallback
    }

    private static func candidateURLs() -> [URL] {
        var urls: [URL] = []

        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            urls.append(
                documentsURL
                    .appendingPathComponent("KineticVelocity", isDirectory: true)
                    .appendingPathComponent("swing_calibration.json")
            )
        }

        if let bundleURL = Bundle.main.url(forResource: "swing_calibration", withExtension: "json") {
            urls.append(bundleURL)
        }

        return urls
    }
}
