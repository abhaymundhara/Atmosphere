# Atmosphere

Atmosphere is a SwiftPM-based macOS desktop weather simulator. It runs as a menu bar app and renders a transparent, click-through weather overlay above normal windows.

The MVP uses:

- CoreLocation for approximate local coordinates.
- Open-Meteo for current weather conditions.
- CoreGraphics Quartz Window Services for visible window geometry.
- AppKit and SpriteKit for transparent overlay windows and particle rendering.

## Features

- Rain, snow, wind, and sun visual modes.
- Rain collision against detected window top edges, with splash and runoff effects.
- Snow accumulation visuals on window tops.
- Live weather mode plus manual debug modes.
- Multi-screen overlay windows.
- No private macOS APIs and no third-party dependencies.

## Requirements

- macOS 14 or later.
- Swift 5.9 or later.

## Build And Test

```bash
swift test
```

## Run

```bash
./script/build_and_run.sh
```

The run script builds a SwiftPM executable, stages a local `.app` bundle under `dist/`, and launches it as a foreground macOS app.

Useful modes:

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
./script/build_and_run.sh --debug
```

## Notes

macOS does not provide a supported public layer exactly between the desktop wallpaper and third-party app window frames. Atmosphere therefore uses a click-through overlay above normal windows for v1 while using public CoreGraphics window geometry for collision behavior.
