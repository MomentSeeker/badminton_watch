# Kinetic Velocity Watch

Native SwiftUI watchOS app scaffold based on:

- `docs/kinetic_velocity_design_system.md`
- `docs/watch_only_training_prd.md`
- `sample/` Google AI prototype

For current architecture, calibration status, and next steps, see `HANDOFF.md`.

## Run

```sh
xcodegen generate
open KineticVelocityWatch.xcodeproj
```

Choose a watchOS simulator and run the `KineticVelocityWatch` target.

Verified with:

```sh
xcodebuild -quiet -project KineticVelocityWatch.xcodeproj -scheme KineticVelocityWatch -destination 'generic/platform=watchOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Scope

- Start setup with racket-hand selection
- Three live horizontal tabs: body telemetry, badminton data, action stats
- Slide-to-end control to prevent accidental stops
- End confirmation snapshot with Continue priority
- Saving success state returning to start
- Real HealthKit workout session for heart rate, active energy, and workout saving
- Real Core Motion device-motion sampling for badminton swing metrics

## Data Pipeline

- `HealthKitWorkoutManager` starts an `HKWorkoutSession` with `.badminton` and reads live metrics through `HKLiveWorkoutBuilder`.
- `MotionSwingDetector` samples `CMDeviceMotion` at the calibrated rate, currently 100 Hz. It detects strokes with a local-peak IMU window instead of a timer or mock counter.
- `activeSeconds` is accumulated only while wrist motion exceeds training-motion thresholds.
- `swingCount`, `maxRallyStreak`, `maxSwingSpeedKph`, and action buckets are derived from detected IMU windows.
- Each detected swing window is appended as JSONL at:

```text
Documents/KineticVelocity/swing_windows.jsonl
```

Each row contains the racket hand, predicted buckets, summary features, and raw accelerometer/gyroscope samples for that window. Debug-mode rows also contain drill labels and window roles for calibration and future Core ML training.

## Debug Calibration Mode

Long-press the shuttlecock mark on the start screen to enter Debug Mode.

Debug Mode records labeled, single-stroke drill data:

- Choose a drill such as forehand, backhand, overhead, underhand, smash, normal, or false-trigger.
- The watch haptics once, enters `ARMED`, and waits for one stroke.
- It records only the dominant peak window as `windowRole=stroke_peak`.
- It locks after the peak and records the follow-through/recovery window as `labelSwing=no`, `windowRole=recovery`.
- After the lock, it haptics again and arms the next repetition.

This avoids labeling preparation and recovery motions as the target stroke. It is intentionally slower than continuous recording, but produces much cleaner training rows.

## Calibration Export

After recording real swings on the Apple Watch, export the captured windows:

```sh
cd outputs/KineticVelocityWatch
chmod +x Tools/export_swing_windows.sh
Tools/export_swing_windows.sh ./CalibrationData
```

The default script values match the local development watch used in this project:

- `DEVICE_ID=00008310-0008A59034E0E01E`
- `BUNDLE_ID=com.lichaochen.kineticvelocity.watch`

Convert the exported JSONL into a feature CSV:

```sh
python3 Tools/jsonl_to_training_csv.py \
  ./CalibrationData/swing_windows.jsonl \
  ./CalibrationData/swing_windows_features.csv
```

The CSV includes empty label columns:

- `labelSwing`
- `labelStrokeType`
- `labelDirection`
- `labelPower`

Debug-mode recordings fill these labels automatically for drill rows. For normal training recordings, fill them from a real training session video or manual drill plan. The labeled CSV can then be used to tune thresholds or train a Core ML classifier.

For structured drills, copy and edit the template:

```sh
cp ./CalibrationData/drill_plan_template.csv ./CalibrationData/my_drill_plan.csv
```

Apply row-range labels from the drill plan:

```sh
python3 Tools/label_drill_plan.py \
  ./CalibrationData/swing_windows_features.csv \
  ./CalibrationData/my_drill_plan.csv \
  ./CalibrationData/swing_windows_labeled.csv
```

Generate a calibration file from the labeled CSV:

```sh
python3 Tools/train_calibration.py \
  ./CalibrationData/swing_windows_labeled.csv \
  ./CalibrationData/swing_calibration.json
```

Validate the generated calibration before installing it:

```sh
python3 Tools/validate_calibration.py ./CalibrationData/swing_calibration.json
```

Evaluate calibration accuracy on labeled rows:

```sh
python3 Tools/evaluate_calibration.py \
  ./CalibrationData/swing_windows_labeled.csv \
  ./CalibrationData/swing_calibration.json
```

Train SVM candidates from labeled rows:

```sh
python3 -m pip install scikit-learn joblib
python3 Tools/train_svm_candidate.py \
  ./CalibrationData/swing_windows_labeled.csv \
  ./CalibrationData/Models
```

Install the calibration back to the watch app:

```sh
chmod +x Tools/install_calibration.sh
Tools/install_calibration.sh ./CalibrationData/swing_calibration.json
```

At the next training start, `MotionSwingDetector` loads:

```text
Documents/KineticVelocity/swing_calibration.json
```

If the file is missing, the app uses the built-in baseline thresholds.

## Algorithm Notes

The current on-device classifier is an explainable baseline: detect a local-peak swing window from peak acceleration, peak rotation, and acceleration impulse; classify coarse buckets from dominant signed wrist axes and power thresholds. The detector uses a re-arm threshold and cooldown to reduce duplicate counts from one wrist action.

This follows the sensor setup used by badminton IMU research and open-source projects:

- Apple HealthKit workout APIs: `HKWorkoutSession` and `HKLiveWorkoutBuilder`.
- Apple Core Motion: `CMDeviceMotion` from `CMMotionManager`.
- Badminton Activity Recognition Using Accelerometer Data reports 50 Hz wearable accelerometer/gyroscope windows for badminton movement recognition.
- `mr-easy/Badminton-Stroke-Classification` uses wrist accelerometer/gyroscope time series and feature extraction such as averages, maxima, skewness, and other statistical features.
- BadminSense targets fine-grained badminton analysis with a single smartwatch and a labeled stroke dataset.

The displayed values are no longer generated by mock timers. Fine-grained labels such as forehand/backhand/smash still require personal labeled data and a learned classifier to reach production accuracy.
