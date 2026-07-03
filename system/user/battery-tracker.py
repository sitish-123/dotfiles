#!/usr/bin/env python3
"""Battery usage tracker for the quickshell ii desktop.

WHY THIS EXISTS
---------------
"On battery for", "Screen on (since unplug)", "Last full charge" and the battery
history graph used to be tracked *inside* the quickshell bar process (services/
Battery.qml). That was the wrong layer:

  * quickshell SIGSEGVs several times a day; every restart was a chance to misread
    the power state and RESET the clocks to zero.
  * the singleton is imported by multiple quickshell processes at once (bar +
    every Settings window), so it needed an flock election just to decide who was
    allowed to write the file — a whole subsystem that only existed because the
    data lived in the UI.
  * the 15-min history sampler died with the shell, so the graph only ever got
    ~one point per process lifetime.

This daemon is the fix. It is a single, long-lived `systemd --user` process — the
sole owner of the two state files — so there is no election, no reset-on-restart,
and the history keeps sampling regardless of what the UI does. Battery.qml is now
a pure reader of the files this writes.

WHAT LIVES WHERE
----------------
  * Battery % / rate / health history is *also* logged by UPower itself
    (/var/lib/upower/history-*.dat). We seed the graph from there on first run so
    it's populated from day one. The one thing UPower can't give is "which process
    was draining the battery" — that annotation is why we still take our own
    samples (a `ps` snapshot per sample).
  * Screen-on time genuinely cannot come from the kernel: "screen on" == DPMS on
    == a Wayland/Hyprland concept. We poll `hyprctl monitors` for it.

FILES OWNED (in $XDG_STATE_HOME/quickshell/user/, matching Directories.state):
  * battery_usage.json    {onBatterySince, lastFullTime, screenOnSeconds}
  * battery_history.json  {samples: [[epoch, pct, watts, "proc:cpu,...", rx, tx]]}

Pure stdlib; no third-party deps. Reads sysfs directly (dependency-light and
robust to a UPower daemon restart).
"""

import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

# --- Tunables ---------------------------------------------------------------
POLL = 20                       # seconds between ticks
SUSPEND_CAP = 45                # max seconds of screen-on credited per tick, so a
                                # suspend/hibernate gap (frozen timer) isn't dumped in
HISTORY_INTERVAL = 900          # 15 min: minimum spacing for a time-based sample
PCT_DELTA = 2                   # also sample whenever charge moves this many %
HISTORY_WINDOW = 2 * 365 * 86400   # keep ~2 years of history
PERSIST_EVERY = 15              # force-persist usage at least this many ticks apart

SYS_PS = Path("/sys/class/power_supply")
UPOWER_HIST = Path("/var/lib/upower")


def state_dir() -> Path:
    base = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    d = Path(base) / "quickshell" / "user"
    d.mkdir(parents=True, exist_ok=True)
    return d


def read_int(p: Path):
    try:
        return int(p.read_text().strip())
    except Exception:
        return None


def read_str(p: Path):
    try:
        return p.read_text().strip()
    except Exception:
        return None


# --- Hardware state ---------------------------------------------------------
def find_supplies():
    """Return (battery_dir, [mains_dirs])."""
    batt = None
    mains = []
    try:
        for d in sorted(SYS_PS.iterdir()):
            t = read_str(d / "type")
            if t == "Battery" and batt is None:
                batt = d
            elif t == "Mains":
                mains.append(d)
    except Exception:
        pass
    return batt, mains


def read_power():
    """Snapshot: (plugged: bool|None, pct: int|None, watts: float, full: bool).

    plugged is None when the state is genuinely unknown (keep the previous value).
    Plug state is derived from the battery's own status plus any Mains adapter,
    which is correct for USB-C PD charging and for charge-limit ("Not charging")
    situations where a single AC 'online' flag would lie.
    """
    batt, mains = find_supplies()
    status = read_str(batt / "status") if batt else None
    pct = read_int(batt / "capacity") if batt else None

    mains_online = any(read_int(m / "online") == 1 for m in mains)

    if status == "Discharging":
        plugged = False
    elif status in ("Charging", "Full"):
        plugged = True
    elif mains_online:
        plugged = True
    elif status == "Not charging":
        plugged = True          # plugged but held at a charge limit
    else:
        plugged = None          # "Unknown" / no data → caller keeps last state

    full = (status == "Full") or (pct is not None and pct >= 100)

    watts = 0.0
    if batt:
        pw = read_int(batt / "power_now")           # µW, present on this machine
        if pw is not None:
            watts = abs(pw) / 1e6
        else:
            cur = read_int(batt / "current_now")    # µA * µV fallback
            volt = read_int(batt / "voltage_now")
            if cur is not None and volt is not None:
                watts = abs(cur) * abs(volt) / 1e12
    return plugged, pct, watts, full


def screen_on(last):
    """True if any monitor is DPMS-on. Returns `last` if hyprctl can't be reached
    (transient hiccup shouldn't lose or wrongly credit screen-on time)."""
    his = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not his:
        try:
            hd = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "hypr"
            inst = sorted(hd.iterdir(), key=lambda p: p.stat().st_mtime, reverse=True)
            his = inst[0].name if inst else None
        except Exception:
            his = None
    if not his:
        return last
    env = dict(os.environ, HYPRLAND_INSTANCE_SIGNATURE=his)
    try:
        out = subprocess.run(["hyprctl", "monitors", "-j"], env=env,
                             capture_output=True, text=True, timeout=5)
        mons = json.loads(out.stdout)
        return any(m.get("dpmsStatus") for m in mons)
    except Exception:
        return last


def app_name(pid, comm):
    """Group multi-process apps under one name. Firefox-family browsers (Zen, Firefox)
    name each worker by ROLE ("Web Content", "RDD Process"...) so a browser scatters
    across a dozen entries and never shows up; Chromium names all children after the
    binary. A space in comm marks such a role-named worker → attribute it to its
    executable (all Zen procs share zen-bin)."""
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


def sample_procs_net():
    """(top-proc string, rx bytes, tx bytes) — the annotation UPower can't give.
    Grouped by app (see app_name) so Firefox-family browsers aggregate instead of
    fragmenting across role-named workers. `pid,%cpu,comm` puts comm last since it can
    contain spaces."""
    procs = ""
    try:
        out = subprocess.run(["ps", "-eo", "pid,%cpu,comm", "--sort=-%cpu",
                              "--no-headers"], capture_output=True, text=True, timeout=5)
        agg = {}
        for line in out.stdout.splitlines():
            f = line.split(None, 2)
            if len(f) < 3:
                continue
            try:
                cpu = float(f[1])
            except ValueError:
                continue
            if cpu <= 0.3:
                continue
            name = app_name(f[0], f[2].strip())
            agg[name] = agg.get(name, 0.0) + cpu
        top = sorted(agg.items(), key=lambda kv: -kv[1])[:5]
        procs = ",".join(f"{n}:{c:.1f}" for n, c in top)
    except Exception:
        pass
    rx = tx = 0
    try:
        for line in Path("/proc/net/dev").read_text().splitlines()[2:]:
            name, _, rest = line.partition(":")
            if name.strip() == "lo":
                continue
            cols = rest.split()
            if len(cols) >= 9:
                rx += int(cols[0])
                tx += int(cols[8])
    except Exception:
        pass
    return procs, rx, tx


# --- Persistence ------------------------------------------------------------
def write_atomic(path: Path, text: str):
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(text)
    os.replace(tmp, path)


class Tracker:
    def __init__(self):
        self.dir = state_dir()
        self.usage_path = self.dir / "battery_usage.json"
        self.history_path = self.dir / "battery_history.json"

        self.on_battery_since = 0.0
        self.last_full_time = 0.0
        self.screen_on_seconds = 0
        self.history = []

        self.last_plugged = None
        self.last_tick = time.time()
        self.screen_state = True
        self.last_sample_time = 0.0
        self.last_sampled_pct = -1
        self._ticks_since_persist = 0
        self._running = True

        self._load()

    # ---- load / reconcile --------------------------------------------------
    def _load(self):
        try:
            d = json.loads(self.usage_path.read_text())
            self.on_battery_since = d.get("onBatterySince", 0) or 0
            self.last_full_time = d.get("lastFullTime", 0) or 0
            self.screen_on_seconds = int(d.get("screenOnSeconds", 0) or 0)
        except Exception:
            pass
        try:
            self.history = json.loads(self.history_path.read_text()).get("samples", [])
        except Exception:
            self.history = []

    def _upower_charge_file(self):
        files = [f for f in UPOWER_HIST.glob("history-charge-*.dat")
                 if "generic_id" not in f.name]
        return max(files, key=lambda f: f.stat().st_size) if files else None

    def _charge_rows(self):
        f = self._upower_charge_file()
        if not f:
            return []
        rows = []
        try:
            for line in f.read_text().splitlines():
                p = line.split()
                if len(p) < 3:
                    continue
                try:
                    rows.append((int(p[0]), float(p[1]), p[2]))
                except ValueError:
                    continue
        except Exception:
            return []
        return rows

    def recover_on_battery_since(self):
        """Best-effort true unplug time = start of the current discharge run, read
        from UPower's own charge log. Robust to 'unknown' suspend gaps mid-run: we
        anchor on the last charged marker and take the first discharge after it."""
        rows = self._charge_rows()
        if not rows:
            return None
        last_charged = -1
        for i, (_, _, s) in enumerate(rows):
            if s in ("charging", "fully-charged"):
                last_charged = i
        for t, _, s in rows[last_charged + 1:]:
            if s == "discharging":
                return t if t <= time.time() else None
        return None

    def recover_last_full(self):
        """Most recent time the battery was full (100% or 'fully-charged')."""
        rows = self._charge_rows()
        last = None
        for t, pct, s in rows:
            if (s == "fully-charged" or pct >= 100) and t <= time.time():
                last = t
        return last

    def reconcile(self):
        """Adopt the persisted state against the live hardware, without resetting a
        running clock. This is the whole point of the daemon: because it never
        restarts mid-session, this runs once and there is no settle race to fight.
        A missing/cleared clock is recovered from UPower rather than guessed."""
        plugged, pct, watts, full = read_power()
        if plugged is None:
            plugged = self.on_battery_since <= 0   # best guess from persisted state
        now = time.time()
        if plugged:
            self.on_battery_since = 0
        elif self.on_battery_since <= 0:
            # First run / cleared / corrupt file: recover the true unplug moment from
            # UPower's charge log instead of blindly stamping "now".
            rec = self.recover_on_battery_since()
            self.on_battery_since = rec if rec else now
            self.screen_on_seconds = 0             # screen-on history isn't recoverable
        if self.last_full_time <= 0:               # recover last-full if we have none
            lf = self.recover_last_full()
            if lf:
                self.last_full_time = lf
        if full:
            self.last_full_time = now
        self.last_plugged = plugged
        self.last_tick = now
        self.persist(force=True)

    # ---- history -----------------------------------------------------------
    def seed_history(self):
        """Populate the graph from UPower's own logs so it isn't empty on day one.
        Existing (proc-annotated) samples always win over seeded ones."""
        if any(s and s[0] < time.time() - 86400 for s in self.history):
            return  # already have >1 day of data
        files = [f for f in UPOWER_HIST.glob("history-charge-*.dat")
                 if "generic_id" not in f.name]
        if not files:
            return
        # The laptop battery has by far the most history; earbuds/other devices
        # produce tiny files — pick the largest so we never seed the graph with a
        # Bluetooth device's charge level.
        src = max(files, key=lambda f: f.stat().st_size)
        cutoff = time.time() - HISTORY_WINDOW
        by_time = {}
        try:
            for line in src.read_text().splitlines():
                p = line.split()
                if len(p) < 3 or p[2] == "unknown":
                    continue
                try:
                    t = int(p[0]); pct = int(round(float(p[1])))
                except ValueError:
                    continue
                if pct <= 0 or t < cutoff:
                    continue
                by_time[t] = [t, pct, ""]
        except Exception:
            return
        for s in self.history:      # our samples override seeded ones at same ts
            if s:
                by_time[s[0]] = s
        merged = sorted(by_time.values(), key=lambda s: s[0])
        if len(merged) > len(self.history):
            self.history = merged
            write_atomic(self.history_path, json.dumps({"samples": merged}))

    def add_sample(self, pct, watts):
        procs, rx, tx = sample_procs_net()
        now = time.time()
        cutoff = now - HISTORY_WINDOW
        self.history = [s for s in self.history if s and s[0] >= cutoff]
        self.history.append([int(now), int(pct), round(abs(watts), 2), procs, rx, tx])
        write_atomic(self.history_path, json.dumps({"samples": self.history}))
        self.last_sample_time = now
        self.last_sampled_pct = pct

    # ---- persist -----------------------------------------------------------
    def persist(self, force=False):
        write_atomic(self.usage_path, json.dumps({
            "onBatterySince": int(self.on_battery_since),
            "lastFullTime": int(self.last_full_time),
            "screenOnSeconds": int(self.screen_on_seconds),
        }))
        self._ticks_since_persist = 0

    # ---- main loop ---------------------------------------------------------
    def tick(self):
        plugged, pct, watts, full = read_power()
        now = time.time()
        dirty = False

        if plugged is None:
            plugged = self.last_plugged   # unknown → keep last committed state

        # Plug / unplug edge.
        if plugged != self.last_plugged:
            self.last_plugged = plugged
            if plugged:
                self.on_battery_since = 0
            else:
                self.on_battery_since = now
                self.screen_on_seconds = 0
                self.last_tick = now
            dirty = True

        # Screen-on accumulation (only while on battery + display powered).
        if not plugged:
            self.screen_state = screen_on(self.screen_state)
            delta = now - self.last_tick
            if self.screen_state and delta > 0:
                self.screen_on_seconds += int(min(delta, SUSPEND_CAP))
                dirty = True
        self.last_tick = now

        # Last full charge — captured whenever we observe full while alive.
        if full:
            self.last_full_time = now
            dirty = True

        # History sample: time-based OR on a meaningful charge change.
        if pct is not None:
            due_time = (now - self.last_sample_time) >= HISTORY_INTERVAL
            due_delta = (self.last_sampled_pct >= 0
                         and abs(pct - self.last_sampled_pct) >= PCT_DELTA)
            if self.last_sample_time == 0 or due_time or due_delta:
                self.add_sample(pct, watts)
            elif self.last_sampled_pct < 0:
                self.last_sampled_pct = pct

        self._ticks_since_persist += 1
        if dirty or self._ticks_since_persist >= PERSIST_EVERY:
            self.persist()

    def run(self):
        self.reconcile()
        self.seed_history()
        # Force a first sample so a fresh install shows a point immediately.
        if self.last_sample_time == 0:
            p, pct, w, _ = read_power()
            if pct is not None:
                self.add_sample(pct, w)
        while self._running:
            try:
                self.tick()
            except Exception as e:
                print(f"battery-tracker: tick error: {e}", file=sys.stderr, flush=True)
            time.sleep(POLL)

    def stop(self, *_):
        self._running = False
        try:
            self.persist(force=True)
        except Exception:
            pass
        sys.exit(0)


def main():
    t = Tracker()
    signal.signal(signal.SIGTERM, t.stop)
    signal.signal(signal.SIGINT, t.stop)
    t.run()


if __name__ == "__main__":
    main()
