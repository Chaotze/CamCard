# Assets

Generated and source imagery used by the READMEs and verification notes.

```
docs/assets/
├── mockups/       Device mockups with a transparent screen cutout
├── screenshots/   Raw simulator screenshots
├── framed/        Screenshots composited into the mockup
└── scripts/       Screenshot capture + framing tooling
```

## Mockup

`mockups/iphone-17-pro-silver-portrait.png` — 1350 × 2760, iPhone 17 Pro, Silver, portrait. The screen is a transparent region at `x=72, y=69, w=1206, h=2622`; the framing script detects it automatically by flood-filling from the image centre.

## Screenshots

Captured on an iPhone 17 Pro simulator (iOS 26.0) by `CamCardUITests/ScreenshotCaptureTests`. The test seeds three demo cards, then captures:

| File | Screen |
| --- | --- |
| `01-card-holder.png` | Card holder with seeded cards |
| `02-card-detail.png` | Card detail |
| `03-review.png` | Review / edit form |
| `04-empty.png` | Empty card holder |

Regenerate with:

```bash
xcodebuild test -project CamCard.xcodeproj -scheme CamCard \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:CamCardUITests/ScreenshotCaptureTests \
  -resultBundlePath /tmp/camcard-screens.xcresult
xcrun xcresulttool export attachments \
  --path /tmp/camcard-screens.xcresult --output-path /tmp/camcard-attachments
```

Copy the exported PNGs (names are listed in `manifest.json`) into `screenshots/` using the names above.

## Framing

```bash
swift docs/assets/scripts/frame_screenshots.swift
```

Options:

- `--mockup` path to the device mockup (default `docs/assets/mockups/iphone-17-pro-silver-portrait.png`)
- `--screenshots` input directory (default `docs/assets/screenshots`)
- `--out` output directory (default `docs/assets/framed`)
- `--screen x,y,w,h` explicit screen rect in mockup pixels (auto-detected when omitted)

The script renders the screenshot into the transparent cutout, draws the mockup frame on top, and writes a full-resolution PNG with transparency preserved.