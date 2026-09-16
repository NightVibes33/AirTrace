# AirTrace

AirTrace is an **AirPods-only spatial finder for iOS 15+**. It combines Apple Proximity Pairing BLE observations with ARKit world tracking to estimate a 3D probability region for hidden AirPods while the user walks around a room.

## What it does

- Rejects generic Bluetooth devices and known non-AirPods Apple proximity packets.
- Recognizes AirPods generations by Apple Proximity Pairing model code, including AirPods 4, AirPods Pro 2 USB-C, AirPods Max USB-C and AirPods Pro 3.
- Lets the user enroll one AirPods target.
- Captures repeated AirPods RSSI observations and attaches them to ARKit camera poses.
- Runs a particle-filter localization model rather than treating RSSI as exact distance.
- Renders a shrinking 3D probability region in AR.
- Uses ARKit plane classification / LiDAR scene reconstruction when supported to add nearby surface hints.
- Includes Guided 3D, Precision Search, Quick Radar, 1-meter calibration and search history.
- Explicitly reports uncertainty instead of claiming false centimeter-level precision.

## Reality / limitations

Bluetooth RSSI is strongly affected by multipath, walls, people, orientation and RF interference. AirTrace therefore estimates the **most likely region**, not an exact coordinate. If AirPods are not emitting an advertisement that public iOS Bluetooth APIs expose, live localization cannot proceed until a usable signal returns.

The first real-device validation target is to measure median and 90th-percentile localization error across multiple AirPods models and indoor rooms.

## Build

The repository uses XcodeGen so the Xcode project is generated on CI.

```bash
brew install xcodegen
xcodegen generate
xcodebuild \
  -project AirTrace.xcodeproj \
  -scheme AirTrace \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build
```

Deployment target: **iOS 15.0**. The app uses runtime feature detection for LiDAR/scene reconstruction and remains forward-compatible with newer iOS releases.

## Unsigned IPA

Every push to `main` runs `.github/workflows/build-unsigned.yml`. The workflow generates the Xcode project, compiles a simulator build for compatibility checking, compiles the unsigned device build, packages `Payload/AirTrace.app` as `AirTrace-unsigned.ipa`, computes SHA-256 and uploads the IPA as a GitHub Actions artifact.

Unsigned IPAs must be signed by an appropriate signing tool/profile before installation on stock iOS.
