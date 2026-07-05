#!/usr/bin/env python3
import argparse
import csv
import json
from pathlib import Path
from statistics import median


DEFAULT_CALIBRATION = {
    "sampleRateHz": 100.0,
    "windowSeconds": 0.42,
    "sampleBufferSeconds": 0.55,
    "cooldownSeconds": 0.42,
    "activeAccelerationG": 0.18,
    "activeRotationRads": 1.25,
    "minimumWindowSampleCount": 12,
    "detectionPeakAccelerationG": 0.95,
    "detectionPeakRotationRads": 4.6,
    "detectionAccelerationImpulse": 0.08,
    "detectionPeakScore": 7.4,
    "localPeakMaxDelaySeconds": 0.10,
    "localPeakScoreRatio": 0.85,
    "detectionRearmPeakScoreRatio": 0.68,
    "smashPeakAccelerationG": 1.9,
    "smashPeakRotationRads": 8.8,
    "smashAccelerationImpulse": 0.22,
    "overheadVerticalThreshold": 0.0,
    "forehandLateralThreshold": 0.0,
    "estimatedRacketRadiusMeters": 1.35,
    "rallyGapSeconds": 8.0,
}


def as_float(row, key):
    try:
        return float(row[key])
    except (KeyError, TypeError, ValueError):
        return None


def percentile(values, p):
    ordered = sorted(v for v in values if v is not None)
    if not ordered:
        return None

    if len(ordered) == 1:
        return ordered[0]

    index = (len(ordered) - 1) * p
    lower = int(index)
    upper = min(lower + 1, len(ordered) - 1)
    fraction = index - lower
    return ordered[lower] * (1 - fraction) + ordered[upper] * fraction


def midpoint_between(labels_a, labels_b, field):
    a_values = [as_float(row, field) for row in labels_a]
    b_values = [as_float(row, field) for row in labels_b]
    a_values = [value for value in a_values if value is not None]
    b_values = [value for value in b_values if value is not None]

    if not a_values or not b_values:
        return None

    return (median(a_values) + median(b_values)) / 2.0


def adjusted_lateral(row):
    value = as_float(row, "signedLateralRotation")
    if value is None:
        return None

    return -value if row.get("hand") == "left" else value


def load_rows(path):
    with path.open("r", encoding="utf-8", newline="") as input_file:
        return list(csv.DictReader(input_file))


def labeled(rows, key, value):
    return [row for row in rows if row.get(key, "").strip().lower() == value]


def swing_rows(rows):
    usable = []
    for row in rows:
        value = row.get("labelSwing", "").strip().lower()
        if value in {"no", "false", "0", "non_swing", "negative"}:
            continue
        usable.append(row)

    return usable


def train(rows):
    calibration = dict(DEFAULT_CALIBRATION)
    rows = swing_rows(rows)
    if not rows:
        return calibration

    for output_key, field, multiplier in [
        ("detectionPeakAccelerationG", "peakAccelerationG", 0.92),
        ("detectionPeakRotationRads", "peakRotationRads", 0.92),
        ("detectionAccelerationImpulse", "accelerationImpulse", 0.88),
        ("detectionPeakScore", "peakScore", 0.92),
    ]:
        value = percentile([as_float(row, field) for row in rows], 0.18)
        if value is not None:
            calibration[output_key] = max(0.01, value * multiplier)

    smash_rows = labeled(rows, "labelPower", "smash")
    if not smash_rows:
        smash_rows = [row for row in rows if row.get("predictedPower") == "smash"]

    if smash_rows:
        for output_key, field in [
            ("smashPeakAccelerationG", "peakAccelerationG"),
            ("smashPeakRotationRads", "peakRotationRads"),
            ("smashAccelerationImpulse", "accelerationImpulse"),
        ]:
            value = percentile([as_float(row, field) for row in smash_rows], 0.20)
            if value is not None:
                calibration[output_key] = max(0.01, value * 0.92)

    overhead_rows = labeled(rows, "labelStrokeType", "overhead")
    underhand_rows = labeled(rows, "labelStrokeType", "underhand")
    vertical_threshold = midpoint_between(overhead_rows, underhand_rows, "signedVerticalRotation")
    if vertical_threshold is not None:
        calibration["overheadVerticalThreshold"] = vertical_threshold

    forehand_rows = labeled(rows, "labelDirection", "forehand")
    backhand_rows = labeled(rows, "labelDirection", "backhand")
    forehand_lateral = [adjusted_lateral(row) for row in forehand_rows]
    backhand_lateral = [adjusted_lateral(row) for row in backhand_rows]
    forehand_lateral = [value for value in forehand_lateral if value is not None]
    backhand_lateral = [value for value in backhand_lateral if value is not None]
    if forehand_lateral and backhand_lateral:
        calibration["forehandLateralThreshold"] = (median(forehand_lateral) + median(backhand_lateral)) / 2.0

    sample_counts = [int(float(row["sampleCount"])) for row in rows if row.get("sampleCount")]
    if sample_counts:
        calibration["minimumWindowSampleCount"] = max(8, min(DEFAULT_CALIBRATION["minimumWindowSampleCount"], min(sample_counts)))

    return calibration


def main():
    parser = argparse.ArgumentParser(description="Train Kinetic Velocity swing threshold calibration from labeled CSV.")
    parser.add_argument("csv", type=Path, help="Feature CSV produced by jsonl_to_training_csv.py.")
    parser.add_argument("json", type=Path, help="Output swing_calibration.json path.")
    args = parser.parse_args()

    rows = load_rows(args.csv)
    calibration = train(rows)
    args.json.parent.mkdir(parents=True, exist_ok=True)
    args.json.write_text(json.dumps(calibration, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Wrote calibration from {len(rows)} rows to {args.json}")


if __name__ == "__main__":
    main()
