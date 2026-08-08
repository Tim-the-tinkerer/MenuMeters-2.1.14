# MenuMeters 2.1.14

CPU, GPU, memory, disk, and network monitoring in the macOS menu bar — modernized for **macOS Tahoe (26.x)** and Apple Silicon.

This tree is based on [yujitach/MenuMeters](https://github.com/yujitach/MenuMeters) (the El Capitan+ faceless-app port of [Alex Harper’s original MenuMeters](http://www.ragingmenace.com/software/menumeters/)).

**Current version:** 2.1.14  
**Minimum macOS:** 12.0  
**Tested:** macOS Tahoe 26.5.2, Apple M4 Pro (arm64)

---

## Features

| Meter | Menu bar | Notes |
|-------|----------|--------|
| **CPU** | Overall % (default), graph, thermometer; optional temperature | Performance / Efficiency core awareness on Apple Silicon |
| **GPU** | % / graph / thermometer; optional memory | Via `IOAccelerator` PerformanceStatistics |
| **Memory** | Pie, numbers, bar, graph; pressure mode | Wired / active / compressed / swap details in menu |
| **Disk** | Activity arrows / lights | Volume free space for **visible** volumes only |
| **Network** | Throughput, graph, arrows | Primary or chosen interface |

Every meter menu includes:

- Open Activity Monitor  
- Open MenuMeters preferences  
- **Quit MenuMeters** (⌘Q)


---

## Install

1. Copy `MenuMeters.app` to `/Applications` (this project’s Release build installs there).
2. Launch **MenuMeters**. It is menu-bar only (`LSUIElement`) — no Dock icon.
3. Open preferences: click any meter → **Open MenuMeters preferences**, or launch the app again while it is running.
4. On Ventura and later (including Tahoe): **System Settings → Menu Bar** and allow **MenuMeters**.
5. Ad-hoc signed builds: right-click → **Open** if Gatekeeper blocks the first launch.

### Uninstall

Quit MenuMeters (any meter menu → **Quit MenuMeters**), then delete `/Applications/MenuMeters.app`. Optional: remove prefs with  
`defaults delete com.yujitach.MenuMeters`.

---

## Build

Requires full **Xcode** (not Command Line Tools alone):

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
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
open /Applications/MenuMeters.app
```

Use the **MenuMeters No Sparkle** scheme for local builds (no auto-updater).

---

## Preferences overview

| Tab | Highlights |
|-----|------------|
| **CPU** | Display modes; **Show:** overall % / P-cores / E-cores / all cores; temperature sensor (default **CPU Die (max)** on Apple Silicon) |
| **GPU** | Enable meter; percent / graph / thermometer; interval; color; menu-bar memory |
| **Disk** | Icon set; update interval; click action |
| **Memory** | Display style; pressure; page indicator; colors |
| **Network** | Interface; graph style; throughput units |
| **About** | Credits / welcome text |

---

## Documentation

| File | Description |
|------|-------------|
| [CHANGELOG.md](CHANGELOG.md) | Full change history for the Tahoe modernization (2.1.7+) |
| [Docs/History.txt](Docs/History.txt) | Classic release history (includes 2.1.7+ and upstream) |
| [releases.html](releases.html) | HTML release notes (autoupdater-era style) |
| [Docs/FAQ.md](Docs/FAQ.md) | Frequently asked questions |
| [Docs/UserGuide.md](Docs/UserGuide.md) | End-user guide |
| [Docs/Building.md](Docs/Building.md) | Build and architecture notes for developers |
| [LICENSE](LICENSE) | GPL-2 |

Legacy RTF files under `Docs/` (original 1.8-era) are superseded by the Markdown guides above.

---

## Tahoe / modern macOS notes

- Meters are `NSStatusItem`s with `autosaveName` (System Settings can hide/show them).
- If icons disappear: free menu-bar space, toggle MenuMeters in **System Settings → Menu Bar**, or check for menu-bar managers.
- Apple Silicon temperature uses HID die sensors; Intel still uses SMC keys (e.g. `TC0P`).
- GPU stats depend on the driver exposing `PerformanceStatistics` (present on AGX / typical Mac GPUs).

---

## Alternatives

Actively maintained menu-bar monitors:

- [Stats](https://github.com/exelban/stats)
- [iGlance](https://iglance.github.io)
- [eul](https://github.com/gao-sun/eul)

---

## License

GNU General Public License version 2. See `LICENSE` and `Docs/GNU General Public License.rtf`.

Original MenuMeters © Alex Harper. El Capitan+ port by Yuji Tachikawa and contributors. Tahoe modernization and GPU meter in this tree by local contributors (2026).
