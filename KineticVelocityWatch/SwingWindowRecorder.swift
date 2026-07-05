import Foundation

struct SwingWindowRecord: Codable {
    struct Features: Codable {
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
    }

    struct Sample: Codable {
        let timestamp: Double
        let accelerationX: Double
        let accelerationY: Double
        let accelerationZ: Double
        let rotationX: Double
        let rotationY: Double
        let rotationZ: Double
    }

    let recordedAt: Date
    let hand: RacketHand
    let predictedStrokeType: String
    let predictedDirection: String
    let predictedPower: String
    var labelSwing: String? = nil
    var labelStrokeType: String? = nil
    var labelDirection: String? = nil
    var labelPower: String? = nil
    var drillId: String? = nil
    var drillName: String? = nil
    var drillRepIndex: Int? = nil
    var windowRole: String? = nil
    let features: Features
    let samples: [Sample]
}

final class SwingWindowRecorder {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private lazy var outputURL: URL? = {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let directoryURL = documentsURL.appendingPathComponent("KineticVelocity", isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL.appendingPathComponent("swing_windows.jsonl")
    }()

    func record(_ record: SwingWindowRecord) {
        guard let outputURL,
              let data = try? encoder.encode(record) else {
            return
        }

        var line = data
        line.append(0x0A)

        if !FileManager.default.fileExists(atPath: outputURL.path) {
            FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        }

        guard let handle = try? FileHandle(forWritingTo: outputURL) else { return }

        defer {
            try? handle.close()
        }

        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
        } catch {}
    }
}
