# Verification Record

Environment: Xcode 26.0 (17A324), iOS Simulator 26.0.1, Swift 5 language mode, iPhone 17 simulator (`0984D61E-4372-429E-A653-9819870261FF`). The proposal recorded iOS 26.0; the installed runtime reports 26.0.1.

## Commands and exit codes

| Step | Command | Exit | Evidence |
| --- | --- | --- | --- |
| Build | `xcodebuild -project CamCard.xcodeproj -scheme CamCard -destination 'platform=iOS Simulator,id=0984D61E-4372-429E-A653-9819870261FF' build` | 0 | `build.log`, `build.exit` |
| Build for testing | `xcodebuild ... build-for-testing` | 0 | `build-for-testing.log`, `build-for-testing.exit` |
| Unit tests | `xcodebuild test-without-building ... -only-testing:CamCardTests -parallel-testing-enabled NO` | 0 | `unit-tests.log`, `unit-tests.exit` (66 tests, 0 failures) |
| UI tests | `xcodebuild test-without-building ... -only-testing:CamCardUITests/CamCardUITests -parallel-testing-enabled NO` | 0 | `ui-tests.log`, `ui-tests.exit` (12 tests, 0 failures) |
| Kill-Relaunch UI | `xcodebuild test-without-building ... -only-testing:CamCardUITests/CamCardUITests/testKillRelaunchKeepsImagesFieldsTagsAndNotes` | 0 | `kill-relaunch-ui.log`, `kill-relaunch-ui.exit` |
| OpenSpec | `openspec validate replicate-camcard-card-slice --strict` | 0 | `Change 'replicate-camcard-card-slice' is valid` |

These are real executions, not compile-only results. UI assertions read control values (for example `reviewField-name` label/value and detail text) rather than only asserting existence.

## Source and target integrity

- App and unit tests use the same app module: `CamCardTests` has `TEST_HOST`/`BUNDLE_LOADER` pointing at `CamCard.app/CamCard` and imports it with `@testable import CamCard`. There is no separate `BusinessCardCore` target or duplicate sources.
- All new Swift files live under the `CamCard/` folder synchronized group, so the App target compiles all 31 source files; `xcodebuild build` succeeds with no missing-file errors.
- No `ContentView` references remain anywhere; `CamCardApp` opens `RootView`, and `CamCard/ContentView.swift` was deleted.

## Chain retention

`BusinessCard` stores `originalImage`, `processedImage`, final contact values, tags and notes. `CardAudit` stores `originalImage`, `processedImage`, `ocrRecords` (immutable raw text), `structuredFields`, and `corrections` (manual changes). `ReviewViewModel.save()` appends corrections and never overwrites parsed fields or OCR records; repository round-trip tests and the Kill-Relaunch UI test verify all six stages remain readable.

## Field semantics

Field parser tests assert missing `website`/`company`/`jobTitle`/`email`/`address`/`postalCode` stay `nil` or empty, with no derivation from email domains or addresses. Multi-value tests assert Mobile/Office/Fax classification and preservation, multiple emails with the first as primary, duplicate-email dedupe, and literal preservation of case and `www.` prefixes.

## vCard mapping

`testWriterProducesVCardFileWithMappedFields` writes a real `.vcf` and re-parses it: `FN`, `TEL;TYPE=CELL/WORK/FAX`, `EMAIL` with first `PREF`, `URL`, `ADR` street/postal, `CATEGORIES`, `NOTE`, escaping and filenames. The app does not read or write the system Contacts database; mapping is verified through the exported file and round-trip parsing.

## Accessibility

52 accessibility identifiers/labels are present across views. Detail values, review fields (label + value), image type, tags, and delete/edit/export controls expose Chinese labels. UI tests assert real field values for editing (`姓名` → `张三` → `张三丰`) and visible detail values.

## README screenshots

The README uses real simulator screenshots framed inside a device mockup:

- Capture: `xcodebuild test ... -only-testing:CamCardUITests/ScreenshotCaptureTests -resultBundlePath /tmp/camcard-screens.xcresult` (1 test, 0 failures, iPhone 17 Pro / iOS 26.0).
- Export: `xcrun xcresulttool export attachments` produced 4 screenshots.
- Frame: `swift docs/assets/scripts/frame_screenshots.swift` composited each screenshot into the transparent screen cutout of `docs/assets/mockups/iphone-17-pro-silver-portrait.png`.
- Output: `docs/assets/framed/01-card-holder.png`, `02-card-detail.png`, `03-review.png`, `04-empty.png`.
- Alignment verified numerically: 2544 of 2584 sampled pixels in the framed output match the source screenshot at the expected offset (1206 × 2622 inside a 1350 × 2760 canvas).

## Not verified

- Real-device camera capture, real PhotosPicker selection, camera permission recovery on device, and real-device orientation: not executed. Simulator camera paths are unit-tested; UI covers the denial/cancel paths only.
- UI scenarios R02, R05, R06, R07: not executed as UI tests. Capture/retake/unrecognizable branching is covered by unit tests; the detection-failure choice screen no longer exists (every capture opens the crop page), and the OCR-empty path remains unverified end to end.
- Full R01–R20 UI suite and evidence aggregation (tasks 10.1–10.4): not completed.
- Probabilistic accuracy: course fixtures and `ground-truth.json` are absent, so `accuracy-report.json` was not generated and no field-level accuracy or CamCard character-level comparison is claimed (tasks 11.1–11.5 remain unchecked).
- Field-layout coordinate assertions, Locale switching, draft-ID change assertion, and six-stage diff export report: not verified as specified.
- Export success share-sheet presentation: writer output and mapping verified; system share sheet itself not asserted. Export failure path is UI-tested.
- Kill-Relaunch is verified at two levels: the UI test uses `app.terminate()` + relaunch with the same app container, and a direct `xcrun simctl terminate` + `launch` run persisted the file-backed store. Evidence: `kill-relaunch-ui.log`, `kill-relaunch-simctl.png`, `kill-relaunch-store.json` (schema 1, 3 cards, 3 audits, all names/tags/notes present), `kill-relaunch-image-count.txt` (6 image files: original + processed per card).
- Unit persistence test now also asserts the six-stage chain after relaunch: structured fields keep the parsed name, OCR raw text remains non-empty, and manual correction records the edited name.

## Executable follow-up commands

```bash
# Real-device camera/PhotosPicker and orientation checks
xcodebuild test -project CamCard.xcodeproj -scheme CamCard \
  -destination 'platform=iOS,id=<DEVICE_UDID>' \
  -only-testing:CamCardUITests/CamCardUITests

# Probabilistic accuracy after importing fixtures and ground truth
xcodebuild test -project CamCard.xcodeproj -scheme CamCard \
  -destination 'platform=iOS Simulator,id=<SIM_UDID>' \
  -only-testing:CamCardTests/AccuracyTests

# OpenSpec validation
openspec validate replicate-camcard-card-slice --strict
```
