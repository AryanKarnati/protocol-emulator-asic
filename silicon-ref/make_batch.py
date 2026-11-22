#!/usr/bin/env python3
"""Build the batch manifest and stage the board files (PC side, plain Python 3).

    python3 silicon-ref/make_batch.py [--stage silicon-ref/board_stage]

Writes, under the stage directory (the board root once copied):
    capture.py, batch_capture.py          the code
    manifest.json                         one job per corpus program and per V1 config
    prog/corpus/<file>.json               pioasm JSON of every corpus file (flat names)
    prog/v1/v1_items.pioasm.json          pioasm JSON of the V1 programs

Jobs:
  * corpus: every program of sw/pgasm/test/corpus/pico-examples (36 programs). The configuration
    is a generic smoke setting (out pin 0, set count 0, clock divider 1.0). Corpus traces are
    therefore only a first capture, not a checked reference (see silicon-ref/README.md).
  * v1: every silicon-ref/v1/*.config.json. A config marked "runnable": false is kept in the
    manifest and skipped on the board, with its reason.

Nothing here touches the board. The host copies the stage directory with mpremote (README).
"""

import glob
import json
import os
import shutil

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
CORPUS = os.path.join(REPO, "sw", "pgasm", "test", "corpus", "pico-examples")
V1_DIR = os.path.join(HERE, "v1")
V1_JSON = os.path.join(V1_DIR, "v1_items.pioasm.json")

CORPUS_ARGS = dict(
    pins=dict(out_base=0, out_count=1, set_base=0, sideset_base=0, in_base=0, jmp_pin=0),
    capture_base=0,
    samples=4000,      # about 14 KB of trace text per job; 40000 would be about 140 KB
    set_count=0,
)
V1_DROP = ("program_json", "program_name", "runnable", "reason")


def flat(rel):
    return rel.replace(os.sep, "__").replace("/", "__")


def corpus_jobs(stage):
    jobs = []
    files = sorted(glob.glob(os.path.join(CORPUS, "**", "*.pio.json"), recursive=True))
    os.makedirs(os.path.join(stage, "prog", "corpus"), exist_ok=True)
    for path in files:
        rel = os.path.relpath(path, CORPUS)            # pio/uart_tx/uart_tx.pio.json
        dest_rel = os.path.join("prog", "corpus", flat(rel))
        shutil.copyfile(path, os.path.join(stage, dest_rel))
        with open(path) as f:
            doc = json.load(f)
        stem = flat(rel)[: -len(".pio.json")]
        for p in doc["programs"]:
            jobs.append(dict(name="corpus__%s__%s" % (stem, p["name"]), group="corpus",
                             program_json=dest_rel.replace(os.sep, "/"),
                             program_name=p["name"], runnable=True, args=dict(CORPUS_ARGS)))
    return jobs


def v1_jobs(stage):
    os.makedirs(os.path.join(stage, "prog", "v1"), exist_ok=True)
    shutil.copyfile(V1_JSON, os.path.join(stage, "prog", "v1", "v1_items.pioasm.json"))
    jobs = []
    for path in sorted(glob.glob(os.path.join(V1_DIR, "*.config.json"))):
        name = os.path.basename(path)[: -len(".config.json")]
        with open(path) as f:
            cfg = json.load(f)
        args = {k: v for k, v in cfg.items() if k not in V1_DROP}
        jobs.append(dict(name="v1__" + name, group="v1", program_json="prog/v1/v1_items.pioasm.json",
                         program_name=cfg["program_name"],
                         runnable=cfg.get("runnable", True),
                         reason=cfg.get("reason", ""), args=args))
    return jobs


def main():
    import argparse
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--stage", default=os.path.join(HERE, "board_stage"))
    opts = ap.parse_args()
    stage = opts.stage
    os.makedirs(stage, exist_ok=True)
    for name in ("capture.py", "batch_capture.py"):
        shutil.copyfile(os.path.join(HERE, name), os.path.join(stage, name))
    # V1 first: it is small, so it can be fetched and deleted before the corpus run.
    jobs = v1_jobs(stage) + corpus_jobs(stage)
    with open(os.path.join(stage, "manifest.json"), "w") as f:
        json.dump({"jobs": jobs}, f, indent=1, sort_keys=True)
        f.write("\n")
    n_run = sum(1 for j in jobs if j["runnable"])
    print("groups: v1 (run first), corpus (run second); run each with groups=[...]")
    print("staged %d jobs (%d runnable) in %s" % (len(jobs), n_run, stage))


if __name__ == "__main__":
    main()
