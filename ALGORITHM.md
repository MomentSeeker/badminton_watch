# Kinetic Velocity Algorithm Notes

## Current Signals

- Heart rate and active energy come from `HKWorkoutSession` and `HKLiveWorkoutBuilder`.
- Stroke windows come from `CMDeviceMotion` sampled at the calibrated rate, currently 100 Hz.
- Each detected stroke stores 6-axis IMU samples plus derived window features in `Documents/KineticVelocity/swing_windows.jsonl`.
- Runtime thresholds are loaded from `Documents/KineticVelocity/swing_calibration.json`, falling back to the bundled `swing_calibration.json`.

## Evidence Used

- Apple HealthKit workout APIs provide live workout collection through `HKWorkoutSession` and `HKLiveWorkoutBuilder`.
- Apple Core Motion provides watch motion samples through `CMMotionManager` and `CMDeviceMotion`.
- `mr-easy/Badminton-Stroke-Classification` uses wrist accelerometer and gyroscope time series, then generates statistical window features including average, maximum, and skewness before model evaluation.
- Badminton Activity Recognition Using Accelerometer Data reports badminton movement recognition with off-the-shelf accelerometer and gyroscope data at 50 Hz.
- BadminSense shows a single smartwatch can segment and classify fine-grained badminton strokes when trained with a labeled dataset, using 100 Hz IMU capture in its data collection.

## Runtime Baseline

The on-watch model is intentionally simple and explainable until enough labeled personal data exists:

1. Keep a rolling 0.55 s IMU buffer.
2. Build a 0.42 s candidate window.
3. Detect stroke windows only around local peaks:
   - the current sample must be close to the window peak
   - the peak score must cross the detection threshold
   - the signal must fall below a re-arm threshold before the next stroke can be counted
   - a 0.58 s cooldown prevents duplicate counts from the same wrist action
4. Detect stroke windows from:
   - peak acceleration
   - peak rotation
   - acceleration impulse
   - combined peak score
5. Estimate racket-head speed from peak wrist angular velocity and a calibrated effective radius.
6. Classify coarse buckets from:
   - signed vertical wrist rotation: overhead vs underhand
   - signed lateral wrist rotation corrected by racket hand: forehand vs backhand
   - peak acceleration + rotation + impulse: smash vs non-smash

This baseline is deliberately conservative. It should reduce false positives and duplicate counts, but it is not expected to reach high-accuracy stroke labels by itself.

## Calibration Workflow

1. Record drills on Apple Watch. Prefer Debug Mode for labeled data: long-press the start-screen shuttlecock, choose a drill, and record one peak window per haptic cue.
2. Export `swing_windows.jsonl`.
3. Convert JSONL to CSV with `Tools/jsonl_to_training_csv.py`.
4. For Debug Mode rows, use the generated `labelSwing`, action labels, `drillId`, and `windowRole`. For normal rows, fill label columns from a known drill plan or synchronized video.
5. Run `Tools/train_calibration.py`.
6. Validate with `Tools/validate_calibration.py`.
7. Evaluate labeled-row accuracy with `Tools/evaluate_calibration.py`.
8. Install `swing_calibration.json`, or bundle it into the app.

This makes the displayed metrics real sensor-derived values while keeping a path to validated, player-specific classification.

## Debug Mode Segmentation

Debug Mode is designed to avoid corrupting labels with preparation and recovery motion:

1. The app arms only after a haptic cue.
2. A candidate starts when acceleration, rotation, and peak score cross conservative thresholds.
3. The app waits for the signal to fall, then selects the strongest peak window.
4. That peak window is saved with the selected drill label and `windowRole=stroke_peak`.
5. The follow-through/recovery window is saved as `labelSwing=no`, `windowRole=recovery`.
6. The next repetition is not armed until after the lock period.

This means a forehand drill labels the forehand impact/primary swing, while the return-to-ready motion becomes a negative example rather than a mislabeled backhand.

## 90% Accuracy Path

Published high-accuracy systems rely on labeled data and learned classifiers rather than fixed thresholds:

- BadminSense reports 91.43% user-independent stroke classification on a single smartwatch with a labeled dataset and SVM.
- Badminton Activity Recognition Using Accelerometer Data reports that combining accelerometer and gyroscope data substantially improves performance compared with accelerometer-only models.
- The wrist-based open-source baseline from `mr-easy/Badminton-Stroke-Classification` uses many statistical window features and model evaluation rather than single-axis rules.

For Kinetic Velocity, the next target pipeline is:

1. Collect controlled drills with synced notes or video.
2. Export JSONL and convert it to CSV. The converter now expands raw 6-axis samples into additional statistics such as mean, standard deviation, range, absolute mean, RMS, duration, and peak offset.
3. Train candidate SVM models with `Tools/train_svm_candidate.py`.
4. Keep the threshold calibration for stroke segmentation, but move fine-grained labels to a learned model once enough labeled data exists.
5. Export the winning model to Core ML for on-watch inference.

Expected data volume for a serious first pass: at least 40-60 valid samples per class for one player, then a separate holdout set. The 90% target should be judged on holdout drills, not on the same rows used for training.
