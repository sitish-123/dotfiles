#!/usr/bin/env python3
"""Per-process power snapshot for the quickshell ii "What's using power" panel.

Prints ONE JSON object and exits. The Settings UI invokes it every few seconds
while the Battery page is open (it is NOT a daemon — no point sampling when nobody
is looking).

WHY THIS EXISTS (what it fixes vs. the old inline `ps` version)
--------------------------------------------------------------
1. `ps -eo %cpu` reports CPU averaged over each process's WHOLE LIFETIME, not what
   it's doing now — so a process busy at launch but idle since looked like a power
   hog forever. We instead diff /proc/<pid>/stat over a short interval for TRUE
   instantaneous CPU.
2. The old version apportioned the *total battery draw* (screen + GPU + radios +
   CPU) purely by CPU%, blaming CPU-heavy apps for power they didn't use. When the
   CPU's real energy counter is available we use THAT for the per-app numbers and
   report the rest ("screen + other") separately.

PORTABLE BY CAPABILITY, not by chip — no Lunar Lake / Intel assumptions:
  * source "rapl"    : any CPU exposing a powercap "package-*" energy domain
                       (Intel RAPL ~2011+, AMD Zen amd_energy, multi-socket) that
                       is readable. Truest — a measured energy counter.
  * source "battery" : no readable RAPL, but a battery power_now exists. Falls back
                       to apportioning total draw by (now-accurate) CPU share.
  * source "cpu"     : neither (desktop on AC without RAPL, some VMs/ARM). Ranks by
                       CPU only, no watts.

RAPL energy_uj is root-only on modern kernels (post-"PLATYPUS" side-channel
lockdown). system/etc/udev/rules.d/99-rapl-readable.rules relaxes it to group-
readable; without that rule this simply falls back to the battery source.
"""

import glob
import json
import os
import time

CLK_TCK = os.sysconf("SC_CLK_TCK") or 100
INTERVAL = 0.7          # sampling window (s) — long enough to be stable, short enough to feel live
TOP_N = 8


# --- CPU energy (RAPL via the generic powercap interface) -------------------
def rapl_packages():
    """Every readable powercap 'package-*' domain: [(energy_path, max_range_uj)]."""
    pkgs = []
    for name_file in glob.glob("/sys/class/powercap/*/name"):
        try:
            if not open(name_file).read().strip().startswith("package"):
                continue
        except OSError:
            continue
        d = os.path.dirname(name_file)
        e = os.path.join(d, "energy_uj")
        try:
            with open(e) as f:
                f.read()                    # confirm we can actually read it
        except OSError:
            continue                        # locked down → skip (falls back to battery)
        mx = 0
        try:
            mx = int(open(os.path.join(d, "max_energy_range_uj")).read().strip())
        except (OSError, ValueError):
            pass
        pkgs.append((e, mx))
    return pkgs


def read_rapl(pkgs):
    total = 0
    for e, _ in pkgs:
        try:
            total += int(open(e).read().strip())
        except (OSError, ValueError):
            return None
    return total


# --- CPU time (universal, from /proc) ---------------------------------------
def read_cpu_total():
    """(total_jiffies, busy_jiffies) across all cores from /proc/stat."""
    with open("/proc/stat") as f:
        parts = f.readline().split()
    vals = [int(x) for x in parts[1:]]
    total = sum(vals)
    idle = vals[3] + (vals[4] if len(vals) > 4 else 0)   # idle + iowait
    return total, total - idle


PAGE = os.sysconf("SC_PAGE_SIZE") or 4096


def app_name(pid, comm):
    """Group multi-process apps under one name. Chromium-family browsers name every
    child after the binary (so they already aggregate), but Firefox-family ones (Zen,
    Firefox, LibreWolf) name each worker by ROLE — "Web Content", "Isolated Web Co",
    "RDD Process", "Utility Process" — so the browser's usage scatters across a dozen
    entries and never shows up. A space in comm is the tell of such a role-named
    worker; attribute it to its executable instead (all Zen procs share zen-bin)."""
    if " " not in comm:
        return comm
    try:
        b = os.path.basename(os.readlink(f"/proc/{pid}/exe"))
    except OSError:
        return comm
    for suf in ("-bin", "-wrapped", ".bin"):
        if b.endswith(suf):
            b = b[:-len(suf)]
    return b or comm


def mem_total_bytes():
    try:
        for line in open("/proc/meminfo"):
            if line.startswith("MemTotal:"):
                return int(line.split()[1]) * 1024
    except (OSError, ValueError):
        pass
    return 0


def read_procs():
    """{pid: (comm, utime+stime jiffies, rss_bytes)} for every process."""
    out = {}
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/stat") as f:
                line = f.read()
        except OSError:
            continue
        rp = line.rfind(")")
        if rp < 0:
            continue
        comm = line[line.find("(") + 1: rp]
        fields = line[rp + 2:].split()
        try:
            jiff = int(fields[11]) + int(fields[12])   # utime (f14) + stime (f15)
        except (IndexError, ValueError):
            continue
        rss = 0
        try:
            rss = int(open(f"/proc/{pid}/statm").read().split()[1]) * PAGE  # resident pages
        except (OSError, ValueError, IndexError):
            pass
        out[pid] = (comm, jiff, rss)
    return out


def battery_watts():
    for base in glob.glob("/sys/class/power_supply/*"):
        try:
            if open(os.path.join(base, "type")).read().strip() != "Battery":
                continue
            pw = int(open(os.path.join(base, "power_now")).read().strip())
            return abs(pw) / 1e6
        except (OSError, ValueError):
            continue
    return None


def main():
    pkgs = rapl_packages()

    # T0
    t0 = time.monotonic()
    cpu_total0, cpu_busy0 = read_cpu_total()
    procs0 = read_procs()
    rapl0 = {}
    for e, _ in pkgs:
        try:
            rapl0[e] = int(open(e).read().strip())
        except (OSError, ValueError):
            pass

    time.sleep(INTERVAL)

    # T1
    dt = time.monotonic() - t0
    cpu_total1, cpu_busy1 = read_cpu_total()
    procs1 = read_procs()

    dtotal = max(1, cpu_total1 - cpu_total0)
    dbusy = max(1, cpu_busy1 - cpu_busy0)

    # RAPL package watts (measured), with per-domain wraparound correction.
    cpu_w = None
    if pkgs:
        try:
            uj = 0
            for e, mx in pkgs:
                a = rapl0[e]
                b = int(open(e).read().strip())
                d = b - a
                if d < 0 and mx:            # counter wrapped
                    d += mx
                uj += max(0, d)
            cpu_w = (uj / 1e6) / dt
        except (OSError, ValueError, KeyError):
            cpu_w = None

    batt_w = battery_watts()

    # Decide the power source and the pool of watts to attribute to processes.
    if cpu_w is not None:
        source = "rapl"
        pool_w = cpu_w
        # "other" = screen + GPU + radios + rest = total(battery) − CPU(RAPL). RAPL is
        # a sharp 0.7s window while battery power_now is EC-smoothed, so a CPU burst can
        # momentarily read higher than total; clamp so we never show negative "other".
        other_w = max(0.0, batt_w - cpu_w) if batt_w is not None else None
        total_w = batt_w if batt_w is not None else cpu_w
    elif batt_w is not None:
        source = "battery"
        pool_w = batt_w
        other_w = None
        total_w = batt_w
    else:
        source = "cpu"
        pool_w = None
        other_w = None
        total_w = None

    # Per-process CPU deltas + current RSS → aggregate by command name.
    memtotal = mem_total_bytes()
    agg = {}
    for pid, (comm, j1, rss1) in procs1.items():
        if pid not in procs0:
            continue
        dj = j1 - procs0[pid][1]
        if dj <= 0:
            continue
        name = app_name(pid, comm)
        a = agg.setdefault(name, {"name": name, "jiff": 0, "rss": 0})
        a["jiff"] += dj
        a["rss"] += rss1

    procs = []
    for a in agg.values():
        cpu_pct = 100.0 * a["jiff"] / dtotal          # share of the whole machine
        watts = (pool_w * a["jiff"] / dbusy) if pool_w is not None else None
        mem_pct = (100.0 * a["rss"] / memtotal) if memtotal else 0.0
        procs.append({
            "name": a["name"],
            "cpu": round(cpu_pct, 1),
            "mem": round(mem_pct, 1),
            "watts": round(watts, 2) if watts is not None else None,
        })
    procs.sort(key=lambda p: -p["cpu"])
    procs = [p for p in procs if p["cpu"] > 0.1][:TOP_N]

    print(json.dumps({
        "source": source,
        "interval": round(dt, 3),
        "cpuWatts": round(cpu_w, 2) if cpu_w is not None else None,
        "otherWatts": round(other_w, 2) if other_w is not None else None,
        "totalWatts": round(total_w, 2) if total_w is not None else None,
        "procs": procs,
    }))


if __name__ == "__main__":
    main()
