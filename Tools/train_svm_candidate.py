#!/usr/bin/env python3
import argparse
import csv
import json
from pathlib import Path


LABEL_COLUMNS = ["labelSwing", "labelStrokeType", "labelDirection", "labelPower"]
META_COLUMNS = {
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
}


def load_rows(path):
    with path.open("r", encoding="utf-8", newline="") as input_file:
        return list(csv.DictReader(input_file))


def numeric_feature_names(rows):
    names = []
    for key in rows[0].keys():
        if key in META_COLUMNS:
            continue

        values = []
        for row in rows:
            raw = row.get(key, "")
            if raw == "":
                continue
            try:
                values.append(float(raw))
            except ValueError:
                values = []
                break

        if values:
            names.append(key)

    return names


def matrix(rows, feature_names):
    return [[float(row.get(name, 0) or 0) for name in feature_names] for row in rows]


def report_for_label(rows, label_column, feature_names, output_dir):
    try:
        from sklearn.metrics import classification_report, confusion_matrix
        from sklearn.model_selection import StratifiedKFold, cross_val_predict
        from sklearn.pipeline import make_pipeline
        from sklearn.preprocessing import StandardScaler
        from sklearn.svm import SVC
    except ImportError as exc:
        raise SystemExit(
            "scikit-learn is required. Install with: python3 -m pip install scikit-learn"
        ) from exc

    labeled = [row for row in rows if (row.get(label_column) or "").strip()]
    labels = [(row.get(label_column) or "").strip().lower() for row in labeled]
    unique_labels = sorted(set(labels))
    if len(unique_labels) < 2:
        return {"label": label_column, "error": "need at least two classes"}

    min_class_count = min(labels.count(label) for label in unique_labels)
    if min_class_count < 3:
        return {"label": label_column, "error": "need at least three samples per class"}

    splits = min(5, min_class_count)
    model = make_pipeline(
        StandardScaler(),
        SVC(kernel="rbf", C=10.0, gamma="scale", class_weight="balanced", probability=True),
    )
    x = matrix(labeled, feature_names)
    cv = StratifiedKFold(n_splits=splits, shuffle=True, random_state=42)
    predicted = cross_val_predict(model, x, labels, cv=cv)
    report = classification_report(labels, predicted, output_dict=True, zero_division=0)
    confusion = confusion_matrix(labels, predicted, labels=unique_labels).tolist()

    model.fit(x, labels)
    output_dir.mkdir(parents=True, exist_ok=True)
    model_path = output_dir / f"{label_column}_svm.joblib"

    try:
        import joblib

        joblib.dump(
            {
                "model": model,
                "featureNames": feature_names,
                "labels": unique_labels,
                "labelColumn": label_column,
            },
            model_path,
        )
    except ImportError:
        model_path = None

    return {
        "label": label_column,
        "classes": unique_labels,
        "samples": len(labeled),
        "cvSplits": splits,
        "accuracy": report.get("accuracy"),
        "macroF1": report.get("macro avg", {}).get("f1-score"),
        "weightedF1": report.get("weighted avg", {}).get("f1-score"),
        "confusionLabels": unique_labels,
        "confusionMatrix": confusion,
        "modelPath": str(model_path) if model_path else "",
    }


def main():
    parser = argparse.ArgumentParser(description="Train SVM candidates from labeled Kinetic Velocity feature CSV.")
    parser.add_argument("csv", type=Path, help="Labeled CSV produced by jsonl_to_training_csv.py.")
    parser.add_argument("output_dir", type=Path, help="Directory for reports and optional joblib models.")
    args = parser.parse_args()

    rows = load_rows(args.csv)
    if not rows:
        raise SystemExit("No rows found.")

    feature_names = numeric_feature_names(rows)
    if not feature_names:
        raise SystemExit("No numeric features found.")

    results = [report_for_label(rows, label, feature_names, args.output_dir) for label in LABEL_COLUMNS]
    report = {
        "featureCount": len(feature_names),
        "featureNames": feature_names,
        "results": results,
    }
    args.output_dir.mkdir(parents=True, exist_ok=True)
    report_path = args.output_dir / "svm_report.json"
    report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
