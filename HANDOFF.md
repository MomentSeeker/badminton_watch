# Kinetic Velocity Watch Handoff

This is the current handoff state after reverting the overfit runtime stroke-type model.

## Project

- Workspace root: `/Users/bytedance/Documents/Codex/2026-07-04/context-prd-kinetic-velocity-design-system`
- Watch app: `/Users/bytedance/Documents/Codex/2026-07-04/context-prd-kinetic-velocity-design-system/outputs/KineticVelocityWatch`
- Latest zip: `/Users/bytedance/Documents/Codex/2026-07-04/context-prd-kinetic-velocity-design-system/outputs/KineticVelocityWatch.zip`

This is a watch-only Apple Watch app. There is no iPhone companion app yet.

## Device / Signing

- Physical Apple Watch CoreDevice id: `7C330DF2-36A6-50A2-A267-B86F69AC7FDD`
- Physical install bundle id: `com.lichaochen.kineticvelocity.watch`
- Team id: `QF8C3873KU`

Build and install:

```sh
cd /Users/bytedance/Documents/Codex/2026-07-04/context-prd-kinetic-velocity-design-system/outputs/KineticVelocityWatch

xcodegen generate

xcodebuild -quiet -project KineticVelocityWatch.xcodeproj \
  -scheme KineticVelocityWatch \
  -destination 'generic/platform=watchOS' \
  PRODUCT_BUNDLE_IDENTIFIER=com.lichaochen.kineticvelocity.watch \
  DEVELOPMENT_TEAM=QF8C3873KU \
  -allowProvisioningUpdates build

xcrun devicectl device install app \
  --device 7C330DF2-36A6-50A2-A267-B86F69AC7FDD \
  /Users/bytedance/Library/Developer/Xcode/DerivedData/KineticVelocityWatch-alvexnbeivuczofyvauwhvkyoggg/Build/Products/Debug-watchos/KineticVelocityWatch.app \
  --timeout 120
```

## Current App Features

- SwiftUI watchOS app.
- Start screen with racket-hand selector.
- Live pages: body load, badminton data, action map.
- End confirmation page.
- Custom shuttlecock app icon.
- HealthKit workout session for heart rate, active energy, and formal workout saving.
- Core Motion IMU swing detection.
- Debug Mode for labeled stroke collection.
- JSONL export and CSV feature conversion tools.

## Important Source Files

- `KineticVelocityWatch/Models.swift`
- `KineticVelocityWatch/Views.swift`
- `KineticVelocityWatch/Components.swift`
- `KineticVelocityWatch/HealthKitWorkoutManager.swift`
- `KineticVelocityWatch/MotionSwingDetector.swift`
- `KineticVelocityWatch/CalibrationDebug.swift`
- `KineticVelocityWatch/SwingWindowRecorder.swift`
- `KineticVelocityWatch/SwingCalibration.swift`
- `KineticVelocityWatch/swing_calibration.json`

## Current Runtime Algorithm

Runtime has been intentionally reverted to a simple, sensitive IMU baseline.

Important current values:

- Target sample rate: `100Hz`.
- Rolling IMU buffer: `0.55s`.
- Candidate window: `0.42s`.
- Cooldown: `0.42s`.
- Detection thresholds:
  - peak acceleration: `0.95g`
  - peak rotation: `4.6 rad/s`
  - acceleration impulse: `0.08`
  - peak score: `7.4`
- Local peak guard:
  - max delay: `0.10s`
  - score ratio: `0.85`
  - re-arm ratio: `0.68`

Formal training detection is still based on basic IMU values:

- acceleration magnitude
- rotation magnitude
- acceleration impulse
- local peak score
- signed vertical/lateral rotation

Current classification:

- Overhead/underhand: simple `signedVerticalRotation >= overheadVerticalThreshold`.
- Forehand/backhand: simple `signedLateralRotation`, corrected by racket hand.
- Smash/non-smash: peak acceleration + peak rotation + impulse threshold.

There is no runtime machine-learning stroke-type model in the current app build.

## Important Revert Note

An earlier experiment bundled a nearest-centroid `StrokeTypeModel` and `stroke_type_model.json` into the watch app. This made live overhead/underhand counts worse because weak/normal-mode windows were classified as low-confidence `unknown`, so overhead/underhand counters often stayed at zero.

That runtime model has been removed:

- `KineticVelocityWatch/StrokeTypeModel.swift` deleted.
- `KineticVelocityWatch/stroke_type_model.json` deleted.
- `project.yml` no longer bundles `stroke_type_model.json`.
- `MotionSwingDetector` no longer loads a stroke type model.

Do not reintroduce derived-feature runtime ML without a separate validation set.

## Debug Mode

Entry:

- Open the watch app start screen.
- Long-press the center shuttlecock mark for about 1.2 seconds.

Tasks:

- Forehand 20.
- Backhand 20.
- Overhead 20.
- Underhand 20.
- Smash 20.
- Normal 20.
- False-trigger 10.

Debug Mode behavior:

- Shows large Chinese cue text and uses haptic/voice cues.
- Cue sequence:
  - `准备，挥拍`
  - `恢复`
  - `完成`
- Records one dominant peak window as:

```text
windowRole=stroke_peak
labelSwing=yes
```

- Records follow-through/recovery as:

```text
windowRole=recovery
labelSwing=no
```

Debug Mode starts a HealthKit workout session for foreground persistence and discards it on exit.

## Data Files

Watch sandbox path:

```text
Documents/KineticVelocity/swing_windows.jsonl
```

Local calibration files:

- `CalibrationData/swing_windows.jsonl`
- `CalibrationData/swing_windows_features.csv`
- `CalibrationData/swing_windows_debug_labeled.csv`
- `CalibrationData/debug_session_summary.txt`

Export and convert:

```sh
Tools/export_swing_windows.sh ./CalibrationData

python3 Tools/jsonl_to_training_csv.py \
  ./CalibrationData/swing_windows.jsonl \
  ./CalibrationData/swing_windows_features.csv
```

Install current simple calibration to the correct physical app container:

```sh
Tools/install_calibration.sh KineticVelocityWatch/swing_calibration.json
```

`Tools/install_calibration.sh` now defaults to `com.lichaochen.kineticvelocity.watch`.

## Latest Labeled Data

The user recorded:

- Overhead / 上手.
- Underhand / 下手.

The user did not record forehand/backhand because they felt reasonably accurate.

Latest exported debug summary:

- Total windows: `317`.
- Debug labeled windows: `97`.
- `stroke_peak`: `50`.
- `recovery`: `47`.
- Overhead stroke peaks: `30`.
- Underhand stroke peaks: `20`.

## Current Findings

The old single-axis overhead/underhand heuristic was poor on the recorded Debug data:

```text
Bundled calibration on debug rows: 19/50 = 38%
Threshold-only retrain: 29/50 = 58%
```

Offline feature experiments looked promising, but they used derived summary features and likely overfit the small data set:

- `rotationYMean` alone looked around 90% on the small set.
- A 4-feature nearest-centroid probe looked around 92%.

The user explicitly asked not to deploy derived-feature ML now. Keep those experiments offline only.

## Recommended Next Steps

1. Validate the newly installed simple sensitive baseline on the watch.
   - First goal: swings should be detected again; overhead/underhand counters should not stay at zero.
2. If detection is too sensitive, tune only basic detection thresholds first.
   - Do not re-enable runtime ML.
3. Preserve the previous overhead/underhand Debug data.
4. If needed, collect more Debug data:
   - At least 30 clean overhead peaks.
   - At least 30 clean underhand peaks.
   - Keep recovery/negative samples.
5. For future ML, train on raw IMU sequence/windows or very simple physically meaningful factors, and validate on a separate recording session before installing.
6. Optional later: iPhone companion app for coach-style data collection.

## Build Verification

After the revert:

- `xcodegen generate` succeeded.
- Simulator build succeeded.
- Physical watch build succeeded.
- App install succeeded.
- Current simple calibration was also copied to the physical app Documents container.

## Notes

- The user is now focused on data truth and recognition sensitivity, not UI polish.
- Be careful not to overwrite or discard `CalibrationData/swing_windows_debug_labeled.csv`.
- Do not install `CalibrationData/swing_calibration_debug.json`; it was only a threshold experiment and is not good enough.
