#!/usr/bin/env python3
import argparse
import csv
import json
import math
from collections import Counter
from pathlib import Path


DEFAULT_FEATURES = [
    "rotationYMean",
    "accelerationXMax",
    "signedLateralRotation",
    "accelerationZMin",
]


def load_rows(path):
    with path.open("r", encoding="utf-8", newline="") as input_file:
        return list(csv.DictReader(input_file))


def usable_rows(rows):
    usable = []
    for row in rows:
        if (row.get("windowRole") or "").strip() != "stroke_peak":
            continue
        if (row.get("labelSwing") or "").strip().lower() not in {"yes", "true", "1", ""}:
            continue
        if (row.get("labelStrokeType") or "").strip().lower() not in {"overhead", "underhand"}:
            continue
        usable.append(row)
    return usable


def as_float(row, key):
    try:
        value = float(row.get(key, ""))
        if math.isfinite(value):
            return value
    except ValueError:
        pass

    raise ValueError(f"Missing numeric feature {key!r}")


def feature_matrix(rows, features):
    return [[as_float(row, feature) for feature in features] for row in rows]


def mean(values):
    return sum(values) / len(values)


def std(values):
    if len(values) < 2:
        return 1.0

    avg = mean(values)
    variance = sum((value - avg) ** 2 for value in values) / (len(values) - 1)
    return math.sqrt(variance) or 1.0


def normalize_matrix(matrix, means, stds):
    return [
        [(value - means[index]) / stds[index] for index, value in enumerate(row)]
        for row in matrix
    ]


def centroid(rows):
    size = len(rows[0])
    return [sum(row[index] for row in rows) / len(rows) for index in range(size)]


def squared_distance(left, right):
    return sum((a - b) ** 2 for a, b in zip(left, right))


def train_model(rows, features):
    labels = [(row.get("labelStrokeType") or "").strip().lower() for row in rows]
    matrix = feature_matrix(rows, features)
    means = [mean([row[index] for row in matrix]) for index in range(len(features))]
    stds = [std([row[index] for row in matrix]) for index in range(len(features))]
    normalized = normalize_matrix(matrix, means, stds)
    classes = sorted(set(labels))

    centroids = {}
    for label in classes:
        class_rows = [row for row, row_label in zip(normalized, labels) if row_label == label]
        centroids[label] = centroid(class_rows)

    return {
        "modelType": "nearest_centroid",
        "labelColumn": "labelStrokeType",
        "features": features,
        "classes": classes,
        "means": means,
        "stds": stds,
        "centroids": centroids,
        "trainingRows": len(rows),
        "classCounts": dict(Counter(labels)),
    }


def predict_with_model(row, model):
    values = [as_float(row, feature) for feature in model["features"]]
    normalized = [
        (value - model["means"][index]) / model["stds"][index]
        for index, value in enumerate(values)
    ]
    distances = {
        label: squared_distance(normalized, centroid)
        for label, centroid in model["centroids"].items()
    }
    return min(distances, key=distances.get)


def leave_one_out(rows, features):
    correct = 0
    confusion = Counter()

    for index, row in enumerate(rows):
        train_rows = [candidate for candidate_index, candidate in enumerate(rows) if candidate_index != index]
        model = train_model(train_rows, features)
        predicted = predict_with_model(row, model)
        expected = (row.get("labelStrokeType") or "").strip().lower()
        correct += predicted == expected
        confusion[(expected, predicted)] += 1

    return correct / len(rows), confusion


def main():
    parser = argparse.ArgumentParser(description="Train overhead/underhand nearest-centroid model from Debug CSV.")
    parser.add_argument("csv", type=Path, help="CSV produced by jsonl_to_training_csv.py.")
    parser.add_argument("json", type=Path, help="Output model JSON.")
    parser.add_argument(
        "--features",
        nargs="+",
        default=DEFAULT_FEATURES,
        help="Feature names to use. Defaults to the current best overhead/underhand set.",
    )
    args = parser.parse_args()

    rows = usable_rows(load_rows(args.csv))
    if len(rows) < 6:
        raise SystemExit("Need at least 6 labeled stroke_peak rows.")

    labels = Counter((row.get("labelStrokeType") or "").strip().lower() for row in rows)
    if len(labels) < 2:
        raise SystemExit("Need both overhead and underhand labeled rows.")

    model = train_model(rows, args.features)
    accuracy, confusion = leave_one_out(rows, args.features)
    model["leaveOneOutAccuracy"] = accuracy
    model["leaveOneOutConfusion"] = {
        f"{expected}->{predicted}": count
        for (expected, predicted), count in sorted(confusion.items())
    }

    args.json.parent.mkdir(parents=True, exist_ok=True)
    args.json.write_text(json.dumps(model, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Wrote {args.json}")
    print(f"Rows: {len(rows)}")
    print(f"Class counts: {dict(labels)}")
    print(f"LOO accuracy: {accuracy:.3f}")
    for key, value in model["leaveOneOutConfusion"].items():
        print(f"  {key}: {value}")


if __name__ == "__main__":
    main()
