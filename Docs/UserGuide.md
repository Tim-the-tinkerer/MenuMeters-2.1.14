# MenuMeters User Guide

**Version 2.1.14** — macOS 12+ (Tahoe tested)

MenuMeters shows live system stats in the menu bar: **CPU**, **GPU**, **memory**, **disk**, and **network**.

---

## Getting started

1. Install `MenuMeters.app` in `/Applications` and open it.
2. Icons appear on the right side of the menu bar.
3. Click an icon for a detail menu; use **Open MenuMeters preferences** to configure.
4. Use **Quit MenuMeters** (or ⌘Q while a meter menu is open) to exit.

There is no Dock icon by default (menu-bar utility app).

### First launch (unsigned / ad-hoc builds)

If macOS refuses to open the app: right-click → **Open**, or allow it under **System Settings → Privacy & Security**.

### Tahoe menu bar

**System Settings → Menu Bar** — ensure MenuMeters is enabled. If many apps pin icons, some may hide behind the notch or overflow control; hide unused items or reduce CPU core display density.

---

## CPU meter

**Default:** one overall utilization percentage (average of all logical cores).

### Preferences → CPU

- **Percent / Graph / Thermometer / Horizontal thermometer** — menubar styles (combinable except horizontal vs others).
- **Show:**  
  - **Overall percentage** (default)  
  - **Performance cores average** (Apple Silicon)  
  - **Efficiency cores average** (Apple Silicon)  
  - **Performance + Efficiency (two meters)**  
  - All logical cores / physical only / sum / sorted  
- **Temperature** — show die temperature; pick sensor (default **CPU Die (max)** on Apple Silicon).
- **Update interval**, graph width, colors, top processes count.

### Dropdown highlights

- Processor name and core topology (e.g. 10 Performance + 4 Efficiency)
- Live P-core and E-core averages (hybrid chips)
- Uptime, tasks/threads, load average
- Top CPU processes (if enabled)

---

## GPU meter

**Default:** utilization percentage for the primary GPU.

### Preferences → GPU

- Enable/disable menu bar meter  
- **Percent**, **Graph**, **Thermometer**  
- **Show memory in menu bar** (compact form, e.g. `12% 1.5G`)  
- Update interval, graph width, color  

### Dropdown

- GPU name (e.g. Apple M4 Pro)  
- Device / Renderer / Tiler utilization  
- Memory in use and allocated (unified memory on Apple Silicon)  

Data comes from the graphics driver’s `PerformanceStatistics`. If the driver does not expose stats, the meter shows “No GPU statistics available.”

---

## Memory meter

Configurable pie / numbers / bar / history graph. Optional **memory pressure** mode and page-in/out indicator. Menu lists usage breakdown, VM stats, swap files.

---

## Disk meter

**Activity** icons show read/write to local disks.  
**Menu** lists free/used/total space for volumes that Finder would show — **not** hidden APFS system volumes (Preboot, VM, Update, etc.).

Click a volume to open it (or eject, depending on preferences and Option key).

---

## Network meter

Throughput and/or graph for the preferred interface. Configure interface, graph style, and units in Preferences → Network.

---


## Tips

| Goal | What to do |
|------|------------|
| Less CPU use by MenuMeters | Disable unused meters; increase update intervals |
| Cleaner menu bar | Overall CPU % (not all cores); hide unused meters |
| Accurate temp on M3/M4 | Preferences → CPU → sensor **CPU Die (max)** |
| Fewer disk rows | Already filtered; only user-visible volumes |
| Quit completely | Any meter → **Quit MenuMeters** |

---

## Privacy / permissions

- **Accessibility / Automation** only needed if you enable “open specific Activity Monitor panes.”  
- Temperature and GPU use public/semi-public system APIs (IOKit HID / IOAccelerator); no network upload in the “No Sparkle” build.

---

## Support

See [FAQ.md](FAQ.md) and [CHANGELOG.md](../CHANGELOG.md). Report issues against the repository that ships this fork.
