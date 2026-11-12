# WcPhoneLock (`RestroomRestriction`)

iOS focus app that blocks distracting apps when you are inside your home geofence and only grants temporary unlock windows after verifying that your phone is not in the bathroom.

Room checks combine **CoreMotion** magnetometer signatures, barometric pressure deltas, and optional Wi-Fi telemetry (on-device `NEHotspotNetwork` or Apple Shortcuts via `pooplock://wifi`).

## Layout

- `App/Features/` — SwiftUI views split by screen (`Home/`, `Calibration/`, `Verification/`, `Settings/`, `History/`, `Components/`).
- `App/Services/` — Protocol-backed controllers (`ProtectionController`, `ProtectionContracts`, `RoomVerificationManager`, `HomeLocationManager`, `ScreenTimeManager`, `SensorScanner`).
- `Extensions/` — `ShieldConfiguration`, `ShieldAction`, and `DeviceActivityMonitor` targets.
- `Shared/` — App Group persistence (`AppGroupStore`), settings, identifiers, and Shortcut payload parsing.
- `Shortcuts/` — Recipe and export notes for the optional `PoopLockWIFI` Apple Shortcut.

## Build Targets

- **`RestroomRestrictionLocal`** (`LOCAL_TESTING`): Builds on iOS Simulator or a free Personal Team. Runs geofencing, CoreMotion scans, notifications, and unlock timers with simulated shielding.
- **`RestroomRestriction`**: Full Screen Time build (`FamilyControls`, `ManagedSettings`, `DeviceActivity`) requiring a paid Apple Developer Program account with the Family Controls entitlement.

## Running Locally

```bash
xcodegen generate   # regenerate .xcodeproj from project.yml
open RestroomRestriction.xcodeproj
```

Choose the `RestroomRestrictionLocal` scheme for simulator or personal device testing.

## License

MIT — see [LICENSE](LICENSE).
