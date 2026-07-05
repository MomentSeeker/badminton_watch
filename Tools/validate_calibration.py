#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


REQUIRED_FIELDS = {
    "sampleRateHz",
    "windowSeconds",
    "sampleBufferSeconds",
    "cooldownSeconds",
    "activeAccelerationG",
    "activeRotationRads",
    "minimumWindowSampleCount",
    "detectionPeakAccelerationG",
    "detectionPeakRotationRads",
    "detectionAccelerationImpulse",
    "detectionPeakScore",
    "localPeakMaxDelaySeconds",
    "localPeakScoreRatio",
    "detectionRearmPeakScoreRatio",
    "smashPeakAccelerationG",
    "smashPeakRotationRads",
    "smashAccelerationImpulse",
    "overheadVerticalThreshold",
    "forehandLateralThreshold",
    "estimatedRacketRadiusMeters",
    "rallyGapSeconds",
}


def fail(message):
    raise SystemExit(f"Calibration invalid: {message}")


def require_number(data, key):
    value = data.get(key)
    if not isinstance(value, (int, float)):
        fail(f"{key} must be numeric")
    return float(value)


def main():
    parser = argparse.ArgumentParser(description="Validate Kinetic Velocity swing calibration JSON.")
    parser.add_argument("json", type=Path)
    args = parser.parse_args()

    data = json.loads(args.json.read_text(encoding="utf-8"))
    missing = sorted(REQUIRED_FIELDS - set(data.keys()))
    if missing:
        fail(f"missing fields: {', '.join(missing)}")

    sample_rate = require_number(data, "sampleRateHz")
    window = require_number(data, "windowSeconds")
    buffer = require_number(data, "sampleBufferSeconds")
    cooldown = require_number(data, "cooldownSeconds")
    min_samples = require_number(data, "minimumWindowSampleCount")

    if not 25 <= sample_rate <= 100:
        fail("sampleRateHz should be between 25 and 100")
    if not 0.15 <= window <= 1.0:
        fail("windowSeconds should be between 0.15 and 1.0")
    if buffer < window:
        fail("sampleBufferSeconds must be >= windowSeconds")
    if not 0.15 <= cooldown <= 1.2:
        fail("cooldownSeconds should be between 0.15 and 1.2")
    if min_samples < 4:
        fail("minimumWindowSampleCount should be at least 4")

    for key in [
        "activeAccelerationG",
        "activeRotationRads",
        "detectionPeakAccelerationG",
        "detectionPeakRotationRads",
        "detectionAccelerationImpulse",
        "detectionPeakScore",
        "localPeakMaxDelaySeconds",
        "localPeakScoreRatio",
        "detectionRearmPeakScoreRatio",
        "smashPeakAccelerationG",
        "smashPeakRotationRads",
        "smashAccelerationImpulse",
        "estimatedRacketRadiusMeters",
        "rallyGapSeconds",
    ]:
        if require_number(data, key) <= 0:
            fail(f"{key} must be positive")

    if data["smashPeakAccelerationG"] < data["detectionPeakAccelerationG"]:
        fail("smashPeakAccelerationG should be >= detectionPeakAccelerationG")
    if data["smashPeakRotationRads"] < data["detectionPeakRotationRads"]:
        fail("smashPeakRotationRads should be >= detectionPeakRotationRads")
    if data["smashAccelerationImpulse"] < data["detectionAccelerationImpulse"]:
        fail("smashAccelerationImpulse should be >= detectionAccelerationImpulse")
    if not 0.02 <= data["localPeakMaxDelaySeconds"] <= 0.2:
        fail("localPeakMaxDelaySeconds should be between 0.02 and 0.2")
    if not 0.75 <= data["localPeakScoreRatio"] <= 1.0:
        fail("localPeakScoreRatio should be between 0.75 and 1.0")
    if not 0.25 <= data["detectionRearmPeakScoreRatio"] <= 0.8:
        fail("detectionRearmPeakScoreRatio should be between 0.25 and 0.8")

    print(f"Calibration valid: {args.json}")


if __name__ == "__main__":
    main()
