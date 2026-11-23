#!/usr/bin/env python3
"""Print the hardening numbers that matter as GitHub ::notice annotations.

Run from the repository root after the Tiny Tapeout action (CI does this in the
`gds` job). Reads the LibreLane metrics that tt-support-tools reads:

  runs/wokwi/final/metrics.csv   key,value rows (project.py get_metrics_path)
  runs/wokwi/resolved.json       the resolved config, for CLOCK_PERIOD

Corner-specific metrics are keys with a `__corner:<name>` suffix. Every corner present is
reported. Nothing here fails the job: any problem is printed as a ::warning and the script
exits 0. A missing key is reported with the list of keys that do exist.

Usage: python3 flow/metrics_notice.py [repo_root]
"""

import csv
import glob
import json
import os
import re
import sys

ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".")
MAX_KEYS_SHOWN = 60


def esc(text):
    """Escape a string for a GitHub workflow command message."""
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def emit(level, title, lines):
    """One annotation per call. Lines are joined with %0A so one step gives few messages."""
    message = esc("\n".join(lines))
    print(f"::{level} title={title}::{message}")


def load_metrics(path):
    with open(path, newline="") as fh:
        return {row[0]: row[1] for row in csv.reader(fh) if len(row) >= 2}


def load_clock_period(run_dir):
    for name in ("resolved.json", "config_merged.json"):
        path = os.path.join(run_dir, name)
        if os.path.exists(path):
            try:
                with open(path) as fh:
                    cfg = json.load(fh)
                if "CLOCK_PERIOD" in cfg:
                    return f"{cfg['CLOCK_PERIOD']} ns ({name})"
            except (OSError, ValueError) as err:
                return f"unreadable {name}: {err}"
    return None


def as_float(text):
    try:
        return float(text)
    except (TypeError, ValueError):
        return None


def fmt(value, scale=1.0, digits=3):
    """Format a metric value, or 'missing' when the key was absent."""
    if value is None:
        return "missing"
    number = as_float(value)
    if number is None:
        return str(value)
    return f"{number * scale:.{digits}f}"


def tail(path, n):
    try:
        with open(path, errors="replace") as fh:
            return fh.read().splitlines()[-n:]
    except OSError as err:
        return [f"unreadable: {err}"]


def diagnose(run_dir):
    """When the flow stops early, say where and why: the last step directory, error lines and log tails."""
    if not os.path.isdir(run_dir):
        emit("warning", "Hardening failure", [f"{run_dir} does not exist."])
        return
    steps = sorted(d for d in os.listdir(run_dir) if os.path.isdir(os.path.join(run_dir, d)) and re.match(r"^\d+-", d))
    lines = [f"steps run: {len(steps)}; last 5: " + ", ".join(steps[-5:])]
    errors = []
    for log in sorted(glob.glob(os.path.join(run_dir, "**", "*.log"), recursive=True)):
        try:
            with open(log, errors="replace") as fh:
                for line in fh:
                    if re.search(r"\[ERROR|ERROR:|Error:|GPL-0302|\bFAILED\b", line):
                        errors.append(os.path.relpath(log, run_dir) + ": " + line.strip()[:300])
        except OSError:
            pass
    lines.append(f"error lines found: {len(errors)}")
    lines.extend(errors[-25:])
    emit("warning", "Hardening failure: errors", lines)
    for name in ("error.log", "flow.log"):
        path = os.path.join(run_dir, name)
        if os.path.exists(path):
            emit("warning", f"Hardening failure: tail of {name}", tail(path, 40))
    if steps:
        last = os.path.join(run_dir, steps[-1])
        logs = sorted(glob.glob(os.path.join(last, "*.log")), key=os.path.getmtime)
        if logs:
            emit("warning", f"Hardening failure: tail of {steps[-1]}/{os.path.basename(logs[-1])}", tail(logs[-1], 40))


def synthesis_report(run_dir):
    """Publish the flow's own synthesis numbers: chip area, cell count, top cell types, SYNTH_* settings."""
    lines = []
    for path in sorted(glob.glob(os.path.join(run_dir, "*-yosys-synth*", "**", "*"), recursive=True)):
        if not os.path.isfile(path) or not re.search(r"stat|\.rpt$|\.log$", os.path.basename(path)):
            continue
        try:
            with open(path, errors="replace") as fh:
                text = fh.read().splitlines()
        except OSError:
            continue
        hits = [l.strip() for l in text if re.search(r"Chip area|Number of cells|Number of wire bits", l)]
        cells = []
        for l in text:
            m = re.match(r"^\s+(\d+)\s+([\d.]+)?\s*(\S*sg13\S+)", l) or re.match(r"^\s+(\S*sg13\S+)\s+(\d+)", l)
            if m:
                cells.append(l.strip())
        if hits or cells:
            lines.append(f"-- {os.path.relpath(path, run_dir)}")
            lines.extend(hits[-6:])
            lines.extend(cells[:40])
    cfg = {}
    for name in ("resolved.json", "config_merged.json"):
        p = os.path.join(run_dir, name)
        if os.path.exists(p):
            try:
                with open(p) as fh:
                    cfg = json.load(fh)
            except (OSError, ValueError):
                pass
            break
    synth = {k: v for k, v in cfg.items() if k.startswith("SYNTH") or k in ("PL_TARGET_DENSITY_PCT", "FP_CORE_UTIL", "DIE_AREA", "CLOCK_PERIOD")}
    lines.append("settings: " + json.dumps(synth, sort_keys=True)[:3000])
    emit("notice", "Synthesis report", lines[:120] if lines else ["no synthesis report found"])


def main():
    final_dir = os.path.join(ROOT, "runs", "wokwi", "final")
    metrics_path = os.path.join(final_dir, "metrics.csv")
    if not os.path.exists(metrics_path):
        found = sorted(glob.glob(os.path.join(ROOT, "runs", "**", "metrics.csv"), recursive=True))
        if not found:
            emit("warning", "Hardening metrics",
                 ["metrics.csv not found under runs/wokwi/final.",
                  "runs/ contents: " + ", ".join(sorted(os.listdir(os.path.join(ROOT, "runs"))))
                  if os.path.isdir(os.path.join(ROOT, "runs")) else "runs/ does not exist."])
            diagnose(os.path.join(ROOT, "runs", "wokwi"))
            synthesis_report(os.path.join(ROOT, "runs", "wokwi"))
            return
        metrics_path = found[0]

    metrics = load_metrics(metrics_path)
    run_dir = os.path.join(ROOT, "runs", "wokwi")

    def get(*names):
        """First present key among the candidate names, or None."""
        for name in names:
            if name in metrics:
                return metrics[name]
        return None

    keys = sorted(metrics)
    lines = [f"metrics file: {os.path.relpath(metrics_path, ROOT)} ({len(metrics)} keys)"]

    # Utilisation and area.
    util = get("design__instance__utilization", "design__instance__utilization__stdcell")
    util_pct = fmt(util, 100.0, 2) + "%" if util is not None and as_float(util) is not None else "missing"
    lines.append(f"utilisation: {util_pct} (gate: at most 55%)")
    core = get("design__core__area")
    stdcell = get("design__instance__area__stdcell", "design__instance__area")
    lines.append(f"core area: {fmt(core)} um2; standard-cell area: {fmt(stdcell)} um2")

    # Timing per corner: timing__{setup,hold}__{ws,tns}__corner:<name>, plus the plain keys.
    corner_re = re.compile(r"^timing__(setup|hold)__(ws|tns)__corner:(.+)$")
    missing = []
    corners = sorted({m.group(3) for k in keys for m in [corner_re.match(k)] if m})
    if not corners:
        # Some flows write the timing keys without a corner suffix.
        corners = ["(no corner suffix)"]
    for corner in corners:
        suffix = "" if corner == "(no corner suffix)" else f"__corner:{corner}"
        setup_ws = get(f"timing__setup__ws{suffix}")
        setup_tns = get(f"timing__setup__tns{suffix}")
        hold_ws = get(f"timing__hold__ws{suffix}")
        hold_tns = get(f"timing__hold__tns{suffix}")
        lines.append(
            f"corner {corner}: setup worst slack {fmt(setup_ws)} ns, setup TNS {fmt(setup_tns)} ns; "
            f"hold worst slack {fmt(hold_ws)} ns, hold TNS {fmt(hold_tns)} ns"
        )
        for label, value in (("setup ws", setup_ws), ("setup tns", setup_tns),
                             ("hold ws", hold_ws), ("hold tns", hold_tns)):
            if value is None:
                missing.append(f"{label} ({corner})")

    lines.append(f"clock period used: {load_clock_period(run_dir) or 'missing (no resolved.json)'}")

    # Violation counts: the plain key and every corner-suffixed key.
    for base in ("design__max_slew_violation__count",
                 "design__max_cap_violation__count",
                 "design__max_fanout_violation__count"):
        values = []
        if base in metrics:
            values.append(f"all {metrics[base]}")
        for k in keys:
            if k.startswith(base + "__corner:"):
                values.append(f"{k.split(':', 1)[1]} {metrics[k]}")
        label = base.replace("design__", "").replace("__count", "")
        lines.append(f"{label}: {', '.join(values) if values else 'missing'}")
        if not values:
            missing.append(base)

    if util is None:
        missing.append("design__instance__utilization")
    if core is None:
        missing.append("design__core__area")
    if stdcell is None:
        missing.append("design__instance__area__stdcell")
    if not any(corner_re.match(k) for k in keys):
        missing.append("timing__setup__ws (any corner)")
    if missing:
        shown = ", ".join(keys[:MAX_KEYS_SHOWN])
        more = "" if len(keys) <= MAX_KEYS_SHOWN else f" (+{len(keys) - MAX_KEYS_SHOWN} more)"
        lines.append("missing keys: " + ", ".join(missing))
        lines.append("keys present: " + shown + more)
        emit("warning", "Hardening metrics", lines)
    else:
        emit("notice", "Hardening metrics", lines)


if __name__ == "__main__":
    try:
        main()
    except Exception as err:  # never fail the job from a reporting step
        print(f"::warning title=Hardening metrics::metrics step failed: {esc(repr(err))}")
    sys.exit(0)
