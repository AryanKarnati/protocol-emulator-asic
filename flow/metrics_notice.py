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
