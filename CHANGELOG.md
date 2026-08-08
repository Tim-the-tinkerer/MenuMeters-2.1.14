# Changelog

All notable changes to this MenuMeters tree (macOS Tahoe modernization fork) are documented here.

Format loosely follows [Keep a Changelog](https://keepachangelog.com/). Version numbers continue from the yujitach 2.1.x line.

## [2.1.14] — 2026-07-27

### Removed
- All widget support: WidgetKit extension, floating desktop widget, menu items, stats publisher, and related docs/build steps

## [2.1.12]–[2.1.13] — 2026-07-27 (reverted)

Briefly experimented with WidgetKit + a floating desktop card; **fully removed in 2.1.14**.

---

## [2.1.11] — 2026-07-27

### Added
- **GPU meter** — new menu-bar extra reading utilization from `IOAccelerator` `PerformanceStatistics` (Apple Silicon AGX and modern discrete GPUs).
  - Menu bar: percent, graph, and/or thermometer
  - Dropdown: device / renderer / tiler %, GPU name, core summary, memory in use / allocated
  - Preferences **GPU** tab: enable, display modes, interval, graph width, color, optional memory in menu bar
- **Quit MenuMeters** item on every meter menu (with **⌘Q**)

### Changed
- App version string and copyright preprocessor set to **2.1.11**

---

## [2.1.10] — 2026-07-27

### Fixed
- **Disk menu listed hidden APFS system volumes** (Preboot, VM, Update, xarts, Hardware, iSCPreboot, Data, etc.)
  - Volume list now uses `NSFileManager` + `NSVolumeEnumerationSkipHiddenVolumes`
  - Also filters `MNT_DONTBROWSE` and `/System/Volumes/…` mounts
  - Matches Finder-visible volumes (boot volume, external drives, user mounts)

### Changed
- Removed Carbon `FSPathMakeRef` / `FSGetVolumeInfo` volume naming path
- Disk space formatting supports terabyte scale

---

## [2.1.9] — 2026-07-27

### Fixed
- **CPU temperature wrong on modern Apple Silicon (e.g. M3/M4)**  
  Legacy default sensor `SOC MTR Temp Sensor0` is missing; fallback was alphabetical first sensor (**NAND** ≈ storage temp), not CPU die.

### Added
- Composite sensors:
  - **CPU Die (max)** — hottest SoC die reading (default; matches most system monitors)
  - **CPU Die (avg)** — average of die-like sensors (`PMU tdie*`, SOC MTR, etc.)
- Filters implausible HID temps (e.g. −9000 °C)
- Dedupes multiple HID services with the same Product name (keeps hottest)

---

## [2.1.8] — 2026-07-27

### Added
- **Performance / Efficiency core recognition** (Apple Silicon hybrid CPUs) via `hw.perflevel*`
  - Core description: e.g. `10 Performance + 4 Efficiency`
  - Live menu lines: Performance (N): xx% / Efficiency (M): yy%
- CPU multiproc **Show:** modes:
  - Overall percentage (average of all cores) — **new default**
  - Performance cores average
  - Efficiency cores average
  - Performance + Efficiency (two meters)
  - All logical cores / physical only / sum / sorted

### Changed
- Default CPU display is a **single overall %** instead of one meter per logical core (important on 10–14+ core chips)

---

## [2.1.7] — 2026-07-27

### Added
- Build and run on **macOS Tahoe (26.x)** with Xcode 26 / macOS 26.5 SDK
- Deployment target raised to **macOS 12.0+**
- Hidden-by-system status item detection (notch / overcrowded menu bar) with user alert
- `NSApplicationSupportsSecureRestorableState` in Info.plist

### Fixed
- Compile with modern clang (`-Wstrict-prototypes` on SMC / Apple Silicon readers)
- Crash in `isInstalledButHiddenBySystem` (`CGWindowListCreate` stores raw window IDs, not objects)
- Status item creation/visibility for Tahoe Menu Bar settings (`autosaveName`, force visible, no zero-size images)
- IOKit: use `kIOMainPortDefault` instead of deprecated master port APIs
- Login-item resolve flags (`kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes`)
- NumberFormatter no longer uses obsolete `NSArchiver` round-trip

### Changed
- Prefer **MenuMeters No Sparkle** scheme for local ad-hoc builds
- App activation policy set to accessory at launch

---

## [2.1.6.1] — 2021-11-13 (upstream yujitach)

- Fixed a bug in the memory meter menu introduced while refactoring

## [2.1.6] — 2021-11-11 (upstream)

- Minor fixes; improvements from @schriftgestalt

## [2.1.5] — 2021-10-28 (upstream)

- Crashing bug on new MacBook Pros fixed (@agraf)

## [2.1.4] — 2021-02-01 (upstream)

- Selectable temperature sensor

## [2.1.3] — 2021-01-25 (upstream)

- CPU temperature on Apple Silicon

## Earlier 2.x / 1.x

See `Docs/History.txt` and `releases.html` for the full historical log from Alex Harper’s original MenuMeters and the yujitach El Capitan+ port.

---

## Upgrade notes

| From | Action |
|------|--------|
| 2.1.6.1 binary | Replace app with 2.1.11; prefs migrate automatically under `com.yujitach.MenuMeters` |
| CPU temp looks low on M3/M4 | Reset sensor to default, or pick **CPU Die (max)** in Preferences → CPU |
| Disk list was huge | Fixed in 2.1.10; no action needed |
| Want GPU | Enabled by default in 2.1.11; Preferences → GPU |
| Menu bar empty (Tahoe) | System Settings → Menu Bar → enable MenuMeters; free space if many third-party items |

## License

GPL-2. See `LICENSE` and `Docs/GNU General Public License.rtf`.
