# Building MenuMeters

**Version 2.1.11** — for developers

---

## Requirements

- **Xcode** 15+ recommended; tested with **Xcode 26** / macOS **26.5** SDK  
- macOS 12+ deployment target  
- Full Xcode.app (Command Line Tools alone are not enough for this project)

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

---

## Schemes

| Scheme | Purpose |
|--------|---------|
| **MenuMeters No Sparkle** | Local Release builds without Sparkle auto-update (recommended) |
| **MenuMeters** | Includes Sparkle (needs valid signing for distribution) |

---

## Build & install (arm64 Release)

```bash
cd /path/to/MenuMeters-2.1.6.1

xcodebuild -project MenuMeters.xcodeproj \
  -scheme "MenuMeters No Sparkle" \
  -configuration Release \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM= \
  ONLY_ACTIVE_ARCH=YES ARCHS=arm64 \
  -derivedDataPath /tmp/MenuMetersBuild \
  build

cp -R /tmp/MenuMetersBuild/Build/Products/Release/MenuMeters.app /Applications/
codesign --force --deep --sign - /Applications/MenuMeters.app
```

Universal binary: omit `ONLY_ACTIVE_ARCH` / set `ARCHS="arm64 x86_64"` if desired.

Version is defined in `InfoPlistPreprocessor.h` (`MM_VERSION`).

---

## Project layout

```
Common/                 Shared headers, defaults, PowerMate, GPU prefs constants
MenuExtras/
  MenuMeterCPU/         CPU extra + stats + top processes + uptime
  MenuMeterGPU/         GPU extra + IOAccelerator stats
  MenuMeterDisk/        Disk I/O + volume space
  MenuMeterMem/         Memory extra + stats
  MenuMeterNet/         Network extra + config/stats/PPP
MenuMetersApp/          AppDelegate, main, localizations, icon
PrefPane/               Preferences window (still named PrefPane; is an NSWindowController)
hardware_reader/        SMC (Intel) + HID temperature (Apple Silicon)
MenuMetersMenuExtraBase.*   NSStatusItem base class (shared by all meters)
```

Bundle IDs for each meter (prefs keys for on/off):

- `com.ragingmenace.MenuMeterCPU`
- `com.ragingmenace.MenuMeterGPU`
- `com.ragingmenace.MenuMeterDisk`
- `com.ragingmenace.MenuMeterMem`
- `com.ragingmenace.MenuMeterNet`

App defaults domain: **`com.yujitach.MenuMeters`** (migrates older `com.ragingmenace.MenuMeters` once).

---

## Architecture notes

- Each meter subclasses `MenuMetersMenuExtraBase`, which owns an `NSStatusItem`, timer, and menu.
- Prefs changes post `NSNotification` named with the meter’s bundle ID and object `kPrefChangeNotification`.
- Enabling/disabling a meter is `loadBoolPref:bundleID` (default YES).
- GPU: `IOServiceMatching("IOAccelerator")` → `PerformanceStatistics` dictionary.
- CPU hybrid cores: `sysctl hw.nperflevels` / `hw.perflevelN.{name,logicalcpu}`; E-cores first in `host_processor_info` order on Apple Silicon.
- Temperature (AS): HID vendor page sensors; composites `CPU Die (max|avg)`.
- Disk volumes: `mountedVolumeURLs…options:NSVolumeEnumerationSkipHiddenVolumes` + `MNT_DONTBROWSE` filter.

---

## Adding a meter (checklist)

1. `MenuExtras/MenuMeterXxx/` stats + extra classes  
2. Constants in `Common/MenuMeterXxx.h`  
3. Defaults accessors in `MenuMeterDefaults`  
4. `AppDelegate` alloc/init  
5. Prefs tab or controls  
6. Xcode target membership (both schemes if dual-target)  
7. Bundle ID in `MenuMeters.h`  
8. Changelog / docs  

---

## Historical build notes

Original 1.x sources targeted Xcode 3.x / 10.4–10.5 SDKs and true MenuExtras. That path is obsolete. Do not expect the old MenuCracker-based load process to work on modern macOS.

---

## License

GPL-2. When redistributing modified versions, preserve license notices and preferably contribute improvements upstream to reduce fork fragmentation.
