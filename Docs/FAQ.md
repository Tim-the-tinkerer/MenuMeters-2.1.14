# MenuMeters FAQ

**Version 2.1.11**

---

### Is this still “menu extras” / SystemUIServer plugins?

**No.** On El Capitan and later, third-party NSMenuExtras no longer load. This app runs as a normal (faceless) application and draws **NSStatusItem**s in the menu bar—the approach used by the yujitach port and this Tahoe modernization.

---

### How do I uninstall?

1. Quit via any meter menu → **Quit MenuMeters**.  
2. Delete `/Applications/MenuMeters.app`.  
3. Optional: `defaults delete com.yujitach.MenuMeters`

No logout is required for the modern app build.

---

### How much CPU does MenuMeters use? How do I reduce it?

Use Activity Monitor and filter for **MenuMeters**. Usage is usually low.

To reduce it:

- Turn off meters you do not need (including GPU).  
- Increase each meter’s update interval.  
- Prefer overall CPU % over per-core displays.  
- Avoid very short disk/GPU intervals if you do not need them.

---

### I have 10 or 14 cores — why did I used to see so many CPU meters?

Each **logical** CPU was drawn separately (and Hyper-Threading multiplies counts on Intel).  

**Default is now overall average percentage.** Use Preferences → CPU → **Show** for P-core / E-core averages or dual P+E meters on Apple Silicon.

---

### CPU temperature does not match iStat / Stats / Activity Monitor

On Apple Silicon, MenuMeters once fell back to a **NAND** (SSD) sensor when the old default name was missing.  

**2.1.9+** defaults to **CPU Die (max)** (hottest PMU die / SoC sensor). Pick another sensor in Preferences → CPU if you prefer average die or a specific named sensor.

Intel Macs still use SMC temperature keys (e.g. `TC0P`).

Different apps weight different sensors; small differences are normal.

---

### Disk menu showed Preboot / VM / Update / dozens of volumes

Fixed in **2.1.10**. Only Finder-visible volumes are listed.

---

### Where is the GPU meter?

**2.1.11+.** Preferences → **GPU**, or look for the green/percent GPU status item. Enabled by default when the app is installed fresh.

---

### Icons vanished after a macOS update (Tahoe)

1. Confirm MenuMeters is running (Activity Monitor).  
2. **System Settings → Menu Bar** → enable MenuMeters.  
3. Free menu-bar space (other monitors, Bartender/Ice, etc.).  
4. Relaunch MenuMeters; try **Quit** then open again.

---

### Net meter shows interfaces I never use

Interfaces come from System Configuration. Disable unused interfaces in **System Settings → Network**, or choose a preferred interface in Preferences → Network.

---

### Open source?

Yes — **GPL version 2**. See `LICENSE` and `Docs/GNU General Public License.rtf`.

---

### Relation to ragingmenace / yujitach builds?

- Original: Alex Harper (ragingmenace).  
- El Capitan–Big Sur era app port: Yuji Tachikawa and contributors.  
- This tree: continued fixes for Sequoia/Tahoe, Apple Silicon topology, disk filtering, GPU meter, and docs (2.1.7–2.1.11).
