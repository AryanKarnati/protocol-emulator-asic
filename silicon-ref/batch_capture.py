# silicon-ref/batch_capture.py
#
# Runs every capture in a manifest, one after another, on the Pico 2 (MicroPython), and writes
# one trace per job plus a summary. Written for MicroPython: plain json, no pathlib, no f-strings.
#
# On the board (after make_batch.py --stage copies this tree to the board root):
#   import capture, batch_capture
#   batch_capture.run_batch(capture, "/manifest.json", "", "/traces")
# The host copies /traces back (see silicon-ref/README.md, "When the Pico 2 arrives").
#
# On a PC, without hardware, the same code runs on the mock in test_capture_mock.py:
#   python3 silicon-ref/batch_capture.py --dry-run
# Dry run exercises the whole path (argument conversion, capture.run, trace writing and
# reading back with trace.py). It checks the register writes capture.py makes, not the silicon.
#
# A job that raises is recorded in the summary and the batch goes on. A job marked
# "runnable": false in the manifest is skipped and recorded with its reason.

import json
import os


def _convert_args(args):
    """JSON to capture.run keyword arguments. Keys of init_levels and init_dirs become ints,
    clkdiv becomes a tuple, host_pins and host_actions become tuples."""
    a = dict(args)
    if "pins" in a:
        a["pins"] = {k: int(v) for k, v in a["pins"].items()}
    if "init_levels" in a:
        a["init_levels"] = {int(k): int(v) for k, v in a["init_levels"].items()}
    if "init_dirs" in a:
        a["init_dirs"] = {int(k): int(v) for k, v in a["init_dirs"].items()}
    if a.get("clkdiv") is not None:
        a["clkdiv"] = tuple(a["clkdiv"])
    if "host_pins" in a:
        a["host_pins"] = [tuple(p) for p in a["host_pins"]]
    if "host_actions" in a:
        a["host_actions"] = [(act[0], tuple(act[1])) for act in a["host_actions"]]
    return a


def _join(root, rel):
    return root.rstrip("/") + "/" + rel.lstrip("/")


def run_batch(capture, manifest_path, root, out_dir):
    """Run every job of the manifest with `capture`.

    capture: the capture module, or a function job -> capture module (the PC dry run uses this
        to install a fresh mock for each job).

    manifest_path: JSON file, {"jobs": [...]}. Each job has "name", "program_json" (relative to
        root), "program_name", "runnable" (default true) and "args" (capture.run keywords, without
        program_json and out_path).
    root: directory the program_json paths are relative to ("" on the board, a directory on a PC).
    out_dir: where <name>.jsonl and summary.json are written.
    Returns the summary dict, which is also written to out_dir/summary.json.
    """
    with open(manifest_path) as f:
        manifest = json.load(f)
    try:
        os.mkdir(out_dir)              # MicroPython and CPython both have os.mkdir
    except OSError:
        pass                           # already there
    summary = {"ok": [], "failed": {}, "skipped": {}}
    for job in manifest["jobs"]:
        name = job["name"]
        if not job.get("runnable", True):
            summary["skipped"][name] = job.get("reason", "not runnable")
            continue
        try:
            cap = capture(job) if callable(capture) else capture
            args = _convert_args(job["args"])
            args["program_json"] = _join(root, job["program_json"])
            args["program_name"] = job["program_name"]
            args["out_path"] = out_dir.rstrip("/") + "/" + name + ".jsonl"
            cap.run(**args)
        except Exception as e:  # noqa: BLE001 - every failure is recorded, none is hidden
            summary["failed"][name] = "%s: %s" % (type(e).__name__, e)
        else:
            summary["ok"].append(name)
    with open(out_dir.rstrip("/") + "/summary.json", "w") as f:
        json.dump(summary, f, indent=1, sort_keys=True)
        f.write("\n")
    return summary


if __name__ == "__main__":
    import argparse
    import os
    import sys
    import tempfile

    here = os.path.dirname(os.path.abspath(__file__))
    sys.path.insert(0, here)
    ap = argparse.ArgumentParser(description="batch capture (PC dry run with the mock)")
    ap.add_argument("--dry-run", action="store_true", required=True)
    ap.add_argument("--manifest", default=os.path.join(here, "board_stage", "manifest.json"))
    ap.add_argument("--root", default=os.path.join(here, "board_stage"))
    ap.add_argument("--out", default=None, help="output directory (default: a temporary one)")
    opts = ap.parse_args()
    import test_capture_mock as mock  # the fakes for machine, rp2, time and uctypes

    out = opts.out or tempfile.mkdtemp(prefix="batch_dry_")
    os.makedirs(out, exist_ok=True)

    def per_job(job):
        # Fresh fakes for each job, so register logs and DMA state do not carry over.
        cap, _ = mock._install_fakes()
        mock.FakeDMA.busy_polls = 200 if job["args"].get("host_actions") else 0
        return cap

    summary = run_batch(per_job, opts.manifest, opts.root, out)
    print("dry run: %d ok, %d failed, %d skipped, output in %s"
          % (len(summary["ok"]), len(summary["failed"]), len(summary["skipped"]), out))
    for name in sorted(summary["failed"]):
        print("  failed %s: %s" % (name, summary["failed"][name]))
    sys.exit(1 if summary["failed"] else 0)
