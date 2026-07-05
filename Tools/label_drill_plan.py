#!/usr/bin/env python3
import argparse
import csv
from pathlib import Path


VALID_STROKES = {"", "overhead", "underhand"}
VALID_DIRECTIONS = {"", "forehand", "backhand"}
VALID_POWER = {"", "smash", "non_smash"}


def normalize(value):
    return (value or "").strip().lower()


def parse_int(row, key):
    try:
        return int(row[key])
    except (KeyError, TypeError, ValueError) as exc:
        raise SystemExit(f"Invalid or missing {key} in drill plan row: {row}") from exc


def validate_label(row, key, allowed):
    value = normalize(row.get(key, ""))
    if value not in allowed:
        raise SystemExit(f"Invalid {key}={value!r}. Allowed: {sorted(allowed)}")
    return value


def load_plan(path: Path):
    ranges = []
    with path.open("r", encoding="utf-8", newline="") as input_file:
        for row in csv.DictReader(input_file):
            start = parse_int(row, "startRow")
            end = parse_int(row, "endRow")
            if start < 1 or end < start:
                raise SystemExit(f"Invalid row range {start}-{end}")

            ranges.append(
                {
                    "start": start,
                    "end": end,
                    "labelStrokeType": validate_label(row, "labelStrokeType", VALID_STROKES),
                    "labelDirection": validate_label(row, "labelDirection", VALID_DIRECTIONS),
                    "labelPower": validate_label(row, "labelPower", VALID_POWER),
                }
            )

    return ranges


def labels_for(row_number, ranges):
    labels = {}
    for item in ranges:
        if item["start"] <= row_number <= item["end"]:
            for key in ["labelStrokeType", "labelDirection", "labelPower"]:
                if item[key]:
                    labels[key] = item[key]

    return labels


def main():
    parser = argparse.ArgumentParser(description="Apply drill-plan labels to Kinetic Velocity feature CSV rows.")
    parser.add_argument("input_csv", type=Path)
    parser.add_argument("plan_csv", type=Path)
    parser.add_argument("output_csv", type=Path)
    args = parser.parse_args()

    ranges = load_plan(args.plan_csv)

    with args.input_csv.open("r", encoding="utf-8", newline="") as input_file:
        rows = list(csv.DictReader(input_file))
        fieldnames = list(rows[0].keys()) if rows else []

    if "rowNumber" not in fieldnames:
        fieldnames = ["rowNumber"] + fieldnames

    for index, row in enumerate(rows, start=1):
        row["rowNumber"] = str(index)
        row.update(labels_for(index, ranges))

    args.output_csv.parent.mkdir(parents=True, exist_ok=True)
    with args.output_csv.open("w", encoding="utf-8", newline="") as output_file:
        writer = csv.DictWriter(output_file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Labeled {len(rows)} rows using {len(ranges)} drill ranges -> {args.output_csv}")


if __name__ == "__main__":
    main()
