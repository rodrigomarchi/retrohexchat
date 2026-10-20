#!/usr/bin/env python3
"""Skip a deterministic check whose inputs have not changed since it last passed.

    python3 scripts/ci_cache.py NAME --input PATH [--input PATH ...] \\
        [--python-module PIL ...] -- COMMAND [ARGS ...]

A check that is a pure function of files -- rebuild the outputs from the
sources and compare -- gives the same verdict for the same bytes. So the
verdict is keyed on a digest of everything it reads and everything it
compares against: every file under each --input (sources and committed
outputs alike), the command line, the Python running it and the version of
each --python-module. When the digest matches the one stored the last time
the command passed, the command is not run.

The digest is taken before and after the run, and stored only when the
command passed and nothing changed while it ran: an edit made by someone
else mid-run must not be blessed by a verdict on the files before it.

CI_CACHE=0 runs the command regardless (and still records a pass).
Stamps live in tmp/ci-cache/, one file per NAME.

Stdlib only, like every gate.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib
import os
import subprocess
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
STAMPS = os.path.join(REPO, "tmp", "ci-cache")
# Written by the interpreter or the OS, never read by a check.
IGNORED_NAMES = {"__pycache__", ".DS_Store"}


def digest(inputs, command, python_modules, root=REPO):
    """One hex digest over the files under `inputs`, the command and the toolchain."""
    sha = hashlib.sha256()
    sha.update(b"command\0" + "\0".join(command).encode() + b"\0")
    sha.update(b"python\0" + sys.version.encode() + b"\0")
    for name in sorted(python_modules):
        version = getattr(importlib.import_module(name), "__version__", "unknown")
        sha.update(f"module\0{name}\0{version}\0".encode())
    for path in sorted(input_files(inputs, root)):
        sha.update(b"file\0" + os.path.relpath(path, root).encode() + b"\0")
        with open(path, "rb") as handle:
            sha.update(hashlib.sha256(handle.read()).digest())
    return sha.hexdigest()


def input_files(inputs, root=REPO):
    """Every file under each input path; a missing input counts as no files."""
    files = set()
    for entry in inputs:
        path = os.path.join(root, entry)
        if os.path.isfile(path):
            files.add(path)
            continue
        for folder, dirs, names in os.walk(path):
            dirs[:] = [d for d in dirs if d not in IGNORED_NAMES]
            files.update(os.path.join(folder, n) for n in names if n not in IGNORED_NAMES)
    return files


def stamp_path(name, stamps=STAMPS):
    return os.path.join(stamps, f"{name}.sha256")


def read_stamp(name, stamps=STAMPS):
    try:
        with open(stamp_path(name, stamps)) as handle:
            return handle.read().strip()
    except OSError:
        return None


def write_stamp(name, value, stamps=STAMPS):
    os.makedirs(stamps, exist_ok=True)
    final = stamp_path(name, stamps)
    partial = f"{final}.{os.getpid()}.tmp"
    with open(partial, "w") as handle:
        handle.write(value + "\n")
    os.replace(partial, final)


def run(name, inputs, command, python_modules=(), root=REPO, stamps=STAMPS, runner=subprocess.call,
        force=False):
    """Run `command` unless its inputs match the last pass; return its exit status."""
    before = digest(inputs, command, python_modules, root)
    if not force and read_stamp(name, stamps) == before:
        print(f"OK {name}: inputs unchanged since the last pass (tmp/ci-cache/{name}.sha256)")
        return 0
    status = runner(command, cwd=root)
    if status == 0:
        if digest(inputs, command, python_modules, root) == before:
            write_stamp(name, before, stamps)
        else:
            print(f"{name}: inputs changed while the check ran; not recording the pass")
    return status


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if "--" not in argv:
        print("usage: ci_cache.py NAME --input PATH ... -- COMMAND ...", file=sys.stderr)
        return 2
    split = argv.index("--")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("name")
    parser.add_argument("--input", action="append", default=[], required=True)
    parser.add_argument("--python-module", action="append", default=[])
    args = parser.parse_args(argv[:split])
    command = argv[split + 1:]
    if not command:
        parser.error("no command after --")
    force = os.environ.get("CI_CACHE") == "0"
    return run(args.name, args.input, command, args.python_module, force=force)


if __name__ == "__main__":
    sys.exit(main())
