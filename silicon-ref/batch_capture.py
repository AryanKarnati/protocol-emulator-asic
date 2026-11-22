# silicon-ref/batch_capture.py
#
# Runs the captures of a manifest one after another, on the Pico 2 (MicroPython), and writes one
# trace per job plus summary.json. Written for MicroPython: only json.dumps(obj) and json.loads,
# os.mkdir, os.remove, os.statvfs, gc.collect and plain string formatting. No json.dump with
# keyword arguments, no f-strings, no pathlib, no argparse, no tempfile (PC-only code is below
# the __main__ guard, and the board never runs it).
#
# On the board (after make_batch.py has staged the tree, see silicon-ref/README.md):
#   import capture, batch_capture
#   batch_capture.run_batch(capture, "/manifest.json", "", "/traces", groups=["v1"])
#   batch_capture.run_batch(capture, "/manifest.json", "", "/traces", groups=["corpus"])
#
# On a PC, the same code runs on the mock in test_capture_mock.py, and:
#   python3 silicon-ref/batch_capture.py --dry-run [--groups v1]
# It checks the register writes capture.py makes and the trace format. It does not check silicon.
#
# Limits that protect the board's flash and RAM:
#   * before each job, free space is checked; below min_free_bytes the batch stops and says so;
#   * summary.json is rewritten after every job, so a stop or a reset keeps the record so far;
#   * a job that raises has its partial .jsonl removed and is recorded as failed; the batch goes on;
#   * gc.collect() runs between jobs (each job allocates a sample buffer of 1 byte per sample);
#   * a manifest job with "runnable": false is skipped, with its reason.

import gc
import json
import os

DEFAULT_MIN_FREE = 300000        # a 40000-sample trace is about 140 KB of text


def _convert_args(args):
    """JSON to capture.run keyword arguments. Keys of init_levels and init_dirs become ints,
    clkdiv becomes a tuple, host_pins and host_actions become tuples."""
    a = dict(args)
    if "pins" in a:
        a["pins"] = dict([(k, int(v)) for k, v in a["pins"].items()])
    if "init_levels" in a:
        a["init_levels"] = dict([(int(k), int(v)) for k, v in a["init_levels"].items()])
    if "init_dirs" in a:
        a["init_dirs"] = dict([(int(k), int(v)) for k, v in a["init_dirs"].items()])
    if a.get("clkdiv") is not None:
        a["clkdiv"] = tuple(a["clkdiv"])
    if "host_pins" in a:
        a["host_pins"] = [tuple(p) for p in a["host_pins"]]
    if "host_actions" in a:
        a["host_actions"] = [(act[0], tuple(act[1])) for act in a["host_actions"]]
    return a


def _join(root, rel):
    return root.rstrip("/") + "/" + rel.lstrip("/")


def _free_bytes(path):
    st = os.statvfs(path)
    return st[1] * st[4]         # f_frsize * f_bavail


def _write_summary(out_dir, summary):
    with open(out_dir.rstrip("/") + "/summary.json", "w") as f:
        f.write(json.dumps(summary))
        f.write("\n")


def _remove(path):
    try:
        os.remove(path)
    except OSError:
        pass


def run_batch(capture, manifest_path, root, out_dir, groups=None,
              min_free_bytes=DEFAULT_MIN_FREE):
    """Run the jobs of the manifest with `capture`.

    capture: the capture module, or a function job -> capture module (the PC dry run uses this
        to install a fresh mock for each job).
    manifest_path: JSON file, {"jobs": [...]}. Each job: "name", "group", "program_json" (relative
        to root), "program_name", "runnable" (default true), "args" (capture.run keywords, without
        program_json and out_path).
    root: directory the program_json paths are relative to ("" on the board, a directory on a PC).
    out_dir: where <name>.jsonl and summary.json go. Created if missing.
    groups: only jobs whose "group" is in this list (None = all, in manifest order).
    min_free_bytes: stop before a job when less space than this is free.
    Returns the summary: {"ok": [...], "failed": {name: reason}, "skipped": {name: reason},
    "stopped": reason or None, "done": [...]}, which is also written to out_dir/summary.json.
    """
    with open(manifest_path) as f:
        manifest = json.loads(f.read())
    try:
        os.mkdir(out_dir)
    except OSError:
        pass                                   # already there
    summary = {"ok": [], "failed": {}, "skipped": {}, "stopped": None, "done": []}
    _write_summary(out_dir, summary)
    for job in manifest["jobs"]:
        name = job["name"]
        if groups is not None and job.get("group") not in groups:
            continue
        if not job.get("runnable", True):
            summary["skipped"][name] = job.get("reason", "not runnable")
            summary["done"].append(name)
            _write_summary(out_dir, summary)
            continue
        free = _free_bytes(out_dir)
        if free < min_free_bytes:
            summary["stopped"] = "low space before %s: %d bytes free, need %d" % (
                name, free, min_free_bytes)
            _write_summary(out_dir, summary)
            break
        out_path = out_dir.rstrip("/") + "/" + name + ".jsonl"
        try:
            cap = capture(job) if callable(capture) else capture
            args = _convert_args(job["args"])
            args["program_json"] = _join(root, job["program_json"])
            args["program_name"] = job["program_name"]
            args["out_path"] = out_path
            cap.run(**args)
        except Exception as e:  # noqa: BLE001 - every failure is recorded, none is hidden
            _remove(out_path)                  # no partial trace is left behind
            summary["failed"][name] = "%s: %s" % (type(e).__name__, e)
        else:
            summary["ok"].append(name)
        summary["done"].append(name)
        _write_summary(out_dir, summary)
        gc.collect()
    return summary


if __name__ == "__main__":
    # PC only: the dry run. The board never gets here.
    import sys
    import tempfile
    here = os.path.dirname(os.path.abspath(__file__))
    sys.path.insert(0, here)
    args = sys.argv[1:]
    if "--dry-run" not in args:
        print("usage: batch_capture.py --dry-run [--groups g1,g2] [--out DIR]")
        sys.exit(2)
    groups = None
    out = None
    for i, a in enumerate(args):
        if a == "--groups":
            groups = args[i + 1].split(",")
        if a == "--out":
            out = args[i + 1]
    import test_capture_mock as mock  # the fakes for machine, rp2, time and uctypes
    stage = os.path.join(here, "board_stage")
    out = out or tempfile.mkdtemp(prefix="batch_dry_")

    def per_job(job):
        cap, _ = mock._install_fakes()
        mock.FakeDMA.busy_polls = 200 if job["args"].get("host_actions") else 0
        return cap

    summary = run_batch(per_job, os.path.join(stage, "manifest.json"), stage, out,
                        groups=groups, min_free_bytes=0)
    print("dry run: %d ok, %d failed, %d skipped, output in %s"
          % (len(summary["ok"]), len(summary["failed"]), len(summary["skipped"]), out))
    for name in sorted(summary["failed"]):
        print("  failed %s: %s" % (name, summary["failed"][name]))
    sys.exit(1 if summary["failed"] or summary["stopped"] else 0)
