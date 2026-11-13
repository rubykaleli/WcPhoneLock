# WcPhoneLock

A personal iOS focus prototype that locks distracting apps when you're in the bathroom so you don't get stuck scrolling and can leave earlier.

---

## How It Works

1. **Teach it your rooms:** You take a quick sensor snapshot in your living room/bedroom and another in your bathroom.
2. **Sensor signatures:** It samples the barometer (air pressure changes), magnetometer (magnetic flux), geofence location, and optional Wi-Fi signal/RSSI, then saves the calibrated room profiles locally into the App Group (`AppGroupStore`).
3. **Smart app lock:** When the sensors detect you're in the washroom, it arms iOS Screen Time shields to lock selected apps.
4. **Unlock windows:** Once you walk out into another room, run a quick check to unlock your apps.

> **Note:** This is a personal prototype and focus experiment exploring multi-sensor room classification with SwiftUI and Apple Screen Time APIs.

---

## Build Schemes

- **`RestroomRestrictionLocal`** *(Recommended for testing)*: Builds on the iOS Simulator or a free Apple ID without special developer entitlements. Uses simulated shields and full sensor/timer logic.
- **`RestroomRestriction`**: Uses official Apple Screen Time frameworks (`FamilyControls`, `ManagedSettings`, `DeviceActivity`). Requires an Apple Developer account with Family Controls entitlement approval.

---

## Running Locally

Generate the Xcode project using [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
xcodegen generate
open RestroomRestriction.xcodeproj
```

Select the **`RestroomRestrictionLocal`** scheme and run on any iOS Simulator or connected iPhone.

---

## Project Layout

- `App/Features/` — SwiftUI screens: Home dashboard, calibration sheet, room verification, and settings.
- `App/Services/` — Sensor scanner (`CoreMotion`), location manager (`CoreLocation`), and shield controller protocols.
- `Extensions/` — Screen Time extensions (`ShieldConfiguration`, `ShieldAction`, `DeviceActivityMonitor`).
- `Shared/` — Local App Group storage (`AppGroupStore`) and sensor payload models.

---

## License

MIT — see [LICENSE](LICENSE).
