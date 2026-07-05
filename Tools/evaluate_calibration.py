#!/usr/bin/env python3
import argparse
import csv
import json
from collections import Counter, defaultdict
from pathlib import Path


def as_float(row, key):
    try:
        return float(row[key])
    except (KeyError, TypeError, ValueError):
        return None


def predict(row, calibration):
    peak_acceleration = as_float(row, "peakAccelerationG") or 0
    peak_rotation = as_float(row, "peakRotationRads") or 0
    impulse = as_float(row, "accelerationImpulse") or 0
    vertical = as_float(row, "signedVerticalRotation") or 0
    lateral = as_float(row, "signedLateralRotation") or 0

    if row.get("hand") == "left":
        lateral = -lateral

    stroke = "overhead" if vertical >= calibration["overheadVerticalThreshold"] else "underhand"
    direction = "forehand" if lateral >= calibration["forehandLateralThreshold"] else "backhand"
    power = (
        "smash"
        if peak_acceleration >= calibration["smashPeakAccelerationG"]
        and peak_rotation >= calibration["smashPeakRotationRads"]
        and impulse >= calibration["smashAccelerationImpulse"]
        else "non_smash"
    )

    return {
        "labelStrokeType": stroke,
        "labelDirection": direction,
        "labelPower": power,
    }


def load_csv(path):
    with path.open("r", encoding="utf-8", newline="") as input_file:
        return list(csv.DictReader(input_file))


def evaluate(rows, calibration):
    totals = Counter()
    correct = Counter()
    confusion = defaultdict(Counter)

    for row in rows:
        predictions = predict(row, calibration)

        for key, predicted in predictions.items():
            expected = (row.get(key) or "").strip().lower()
            if not expected:
                continue

            totals[key] += 1
            if predicted == expected:
                correct[key] += 1
            confusion[key][(expected, predicted)] += 1

    return totals, correct, confusion


def print_report(rows, totals, correct, confusion):
    print(f"Rows: {len(rows)}")

    if not totals:
        print("No labeled rows found. Fill labelStrokeType/labelDirection/labelPower before evaluating accuracy.")
        return

    for key in ["labelStrokeType", "labelDirection", "labelPower"]:
        total = totals[key]
        if not total:
            print(f"{key}: no labels")
            continue

        accuracy = correct[key] / total
        print(f"{key}: {correct[key]}/{total} = {accuracy:.3f}")

        for (expected, predicted), count in sorted(confusion[key].items()):
            print(f"  {expected:12s} -> {predicted:12s}: {count}")


def main():
    parser = argparse.ArgumentParser(description="Evaluate Kinetic Velocity calibration against labeled feature CSV.")
    parser.add_argument("csv", type=Path)
    parser.add_argument("calibration_json", type=Path)
    args = parser.parse_args()

    rows = load_csv(args.csv)
    calibration = json.loads(args.calibration_json.read_text(encoding="utf-8"))
    totals, correct, confusion = evaluate(rows, calibration)
    print_report(rows, totals, correct, confusion)


if __name__ == "__main__":
    main()
