# Verification Record

Environment: Xcode 26.0 (17A324), iOS Simulator 26.0.1, Swift 5 language mode.
Reference environment note: the proposal recorded iOS 26.0; the installed runtime reports 26.0.1.

## Commands and exit codes

| Step | Command | Exit | Evidence |
| --- | --- | --- | --- |
| Build | `xcodebuild -project CamCard.xcodeproj -scheme CamCard -destination 'platform=iOS Simulator,id=0984D61E-4372-429E-A653-9819870261FF' build` | 0 | `build.log`, `build.exit` |
| Build for testing | `xcodebuild -project CamCard.xcodeproj -scheme CamCard -destination 'platform=iOS Simulator,id=0984D61E-4372-429E-A653-9819870261FF' build-for-testing` | 0 | `build-for-testing.log`, `build-for-testing.exit` |
| Unit tests | `xcodebuild test-without-building -project CamCard.xcodeproj -scheme CamCard -destination 'platform=iOS Simulator,id=0984D61E-4372-429E-A653-9819870261FF' -only-testing:CamCardTests -parallel-testing-enabled NO` | 0 | `unit-tests.log`, `unit-tests.exit` (65 tests, 0 failures) |
| UI tests | `xcodebuild test -project CamCard.xcodeproj -scheme CamCard -destination 'platform=iOS Simulator,id=0984D61E-4372-429E-A653-9819870261FF' -only-testing:CamCardUITests/CamCardUITests -parallel-testing-enabled NO` | 0 | `ui-tests.log` (11 tests, 0 failures) |

The earlier iPhone 17 Pro run failed with test-runner channel errors; the passing record above is from iPhone 17. Failures were infrastructure-level and are not counted as passing evidence.

OpenSpec: `openspec validate replicate-camcard-card-slice --strict` → exit 0, `Change 'replicate-camcard-card-slice' is valid`.

## Actual test coverage

Unit tests (65) cover models/codable, capture state machine, in-memory and file repositories (atomic save, migration, corruption, orphan/shared image cleanup), image store, Vision rectification, Vision OCR structural output, deterministic mock OCR/detection, field parser (missing fields, multi phones, multi email, domain ambiguity, mixed Chinese/English, provenance, determinism), vCard mapping/escaping/round trip, view models (capture, review, detail, export, holder search/tag/sort), and Kill-Relaunch persistence via new repository/image-store instances over the same sandbox directory.

UI tests (11) cover: cold-launch empty holder (R01), camera-permission denial with photo import still available (R03), cancel capture (R04), detail final values and hidden empty fields (R08/R13), edit update (R14), delete confirmation (R15), search and tag filter (R16), sort/tag controls (R17), notes/raw text (R18), and export failure without data loss (R20 partial).

## Not verified

- Camera capture on a real device and Photo Library import UI: not executed; simulator has no camera, and PhotosPicker selection is not automated.
- UI scenarios R02, R05, R06, R07, R19: not executed as UI tests; corresponding behavior is covered only by unit tests (capture, retake/cancel, unrecognizable branching) or not covered at all.
- Kill-Relaunch at simulator process level: simulated with fresh repository/image-store instances over the same directory, not `simctl terminate` + `launch`.
- Probabilistic accuracy: course fixtures and `ground-truth.json` are absent, so `accuracy-report.json` was not generated and no field-level accuracy is claimed. No OCR output is compared against CamCard character-by-character.
- Real camera permission recovery and real-device orientation behavior: pending device validation.
