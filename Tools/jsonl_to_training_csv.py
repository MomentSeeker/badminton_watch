#!/usr/bin/env python3
import argparse
import csv
import json
import math
from pathlib import Path


FEATURE_FIELDS = [
    "peakAccelerationG",
    "peakRotationRads",
    "accelerationImpulse",
    "meanAccelerationG",
    "meanRotationRads",
    "standardDeviationAccelerationG",
    "standardDeviationRotationRads",
    "skewnessAccelerationG",
    "skewnessRotationRads",
    "signedVerticalRotation",
    "signedLateralRotation",
    "peakScore",
]

SAMPLE_AXES = [
    "accelerationX",
    "accelerationY",
    "accelerationZ",
    "rotationX",
    "rotationY",
    "rotationZ",
]

DERIVED_FEATURE_FIELDS = [
    "durationSeconds",
    "peakOffsetSeconds",
    "accelerationMagnitudeMean",
    "accelerationMagnitudeStd",
    "accelerationMagnitudeRms",
    "rotationMagnitudeMean",
    "rotationMagnitudeStd",
    "rotationMagnitudeRms",
]

for axis in SAMPLE_AXES:
    for suffix in ["Mean", "Std", "Min", "Max", "Range", "AbsMean", "Rms"]:
        DERIVED_FEATURE_FIELDS.append(f"{axis}{suffix}")


def magnitude(sample, fields):
    return math.sqrt(sum(float(sample.get(field, 0) or 0) ** 2 for field in fields))


def mean(values):
    return sum(values) / len(values) if values else ""


def std(values):
    if len(values) < 2:
        return 0 if values else ""

    avg = mean(values)
    variance = sum((value - avg) ** 2 for value in values) / (len(values) - 1)
    return math.sqrt(variance)


def rms(values):
    if not values:
        return ""

    return math.sqrt(sum(value * value for value in values) / len(values))


def sample_stats(samples):
    if not samples:
        return {field: "" for field in DERIVED_FEATURE_FIELDS}

    timestamps = [float(sample.get("timestamp", 0) or 0) for sample in samples]
    start = min(timestamps)
    end = max(timestamps)
    acc_magnitude = [magnitude(sample, ["accelerationX", "accelerationY", "accelerationZ"]) for sample in samples]
    rot_magnitude = [magnitude(sample, ["rotationX", "rotationY", "rotationZ"]) for sample in samples]
    peak_scores = [acc * 3.0 + rot for acc, rot in zip(acc_magnitude, rot_magnitude)]
    peak_index = max(range(len(samples)), key=lambda index: peak_scores[index])

    stats = {
        "durationSeconds": end - start,
        "peakOffsetSeconds": timestamps[peak_index] - start,
        "accelerationMagnitudeMean": mean(acc_magnitude),
        "accelerationMagnitudeStd": std(acc_magnitude),
        "accelerationMagnitudeRms": rms(acc_magnitude),
        "rotationMagnitudeMean": mean(rot_magnitude),
        "rotationMagnitudeStd": std(rot_magnitude),
        "rotationMagnitudeRms": rms(rot_magnitude),
    }

    for axis in SAMPLE_AXES:
        values = [float(sample.get(axis, 0) or 0) for sample in samples]
        stats[f"{axis}Mean"] = mean(values)
        stats[f"{axis}Std"] = std(values)
        stats[f"{axis}Min"] = min(values)
        stats[f"{axis}Max"] = max(values)
        stats[f"{axis}Range"] = max(values) - min(values)
        stats[f"{axis}AbsMean"] = mean([abs(value) for value in values])
        stats[f"{axis}Rms"] = rms(values)

    return stats


def load_records(path: Path):
    with path.open("r", encoding="utf-8") as input_file:
        for line_number, line in enumerate(input_file, start=1):
            line = line.strip()
            if not line:
                continue

            try:
                yield json.loads(line)
            except json.JSONDecodeError as exc:
                raise SystemExit(f"Invalid JSON on line {line_number}: {exc}") from exc


def main():
    parser = argparse.ArgumentParser(description="Convert Kinetic Velocity swing JSONL to training CSV.")
    parser.add_argument("jsonl", type=Path, help="Path to swing_windows.jsonl exported from the watch app.")
    parser.add_argument("csv", type=Path, help="Output CSV path.")
    args = parser.parse_args()

    fieldnames = [
        "recordedAt",
        "hand",
        "predictedStrokeType",
        "predictedDirection",
        "predictedPower",
        "drillId",
        "drillName",
        "drillRepIndex",
        "windowRole",
        "labelSwing",
        "labelStrokeType",
        "labelDirection",
        "labelPower",
        "sampleCount",
    ] + FEATURE_FIELDS + DERIVED_FEATURE_FIELDS

    args.csv.parent.mkdir(parents=True, exist_ok=True)
    count = 0

    with args.csv.open("w", encoding="utf-8", newline="") as output_file:
        writer = csv.DictWriter(output_file, fieldnames=fieldnames)
        writer.writeheader()

        for record in load_records(args.jsonl):
            features = record.get("features", {})
            samples = record.get("samples", [])
            row = {
                "recordedAt": record.get("recordedAt", ""),
                "hand": record.get("hand", ""),
                "predictedStrokeType": record.get("predictedStrokeType", ""),
                "predictedDirection": record.get("predictedDirection", ""),
                "predictedPower": record.get("predictedPower", ""),
                "drillId": record.get("drillId", ""),
                "drillName": record.get("drillName", ""),
                "drillRepIndex": record.get("drillRepIndex", ""),
                "windowRole": record.get("windowRole", ""),
                "labelSwing": record.get("labelSwing", ""),
                "labelStrokeType": record.get("labelStrokeType", ""),
                "labelDirection": record.get("labelDirection", ""),
                "labelPower": record.get("labelPower", ""),
                "sampleCount": len(samples),
            }

            for field in FEATURE_FIELDS:
                row[field] = features.get(field, "")

            row.update(sample_stats(samples))
            writer.writerow(row)
            count += 1

    print(f"Wrote {count} rows to {args.csv}")


if __name__ == "__main__":
    main()
