#!/usr/bin/env python3
"""Regression tests for the PreToolUse bash guard.

Run: python3 scripts/hooks/test_guard_bash.py

Every false positive found in the wild gets a case here. The first one was real:
a commit message that *described* the blocked commands, inside a heredoc, tripped
the guard on its own documentation.
"""

import json
import subprocess
import sys
from pathlib import Path

GUARD = Path(__file__).with_name("guard_bash.py")

BLOCK = [
    "git add -A",
    "git add .",
    "git add --all",
    "cd /tmp && git add -A",
    "mix format; git add .",
    "make deploy-sun",
    "git checkout -- lib/foo.ex",
    "git checkout CLAUDE.md",
]

ALLOW = [
    "git add CLAUDE.md AGENTS.md",
    "git add docs/reference/ci-pipeline.md",
    "git checkout -b feature/x",
    "git switch main",
    "make deploy",
    "make ci",
    "mix format",
    "ls -la",
    # prose that merely mentions a blocked command must not trip the guard
    "git commit -F - <<'EOF'\nDoc: explain why `git add -A` is blocked\nand `make deploy-sun` too.\nEOF",
    'echo "never use git add -A here"',
    'grep -rn "git checkout" docs/',
]


def verdict(cmd):
    result = subprocess.run(
        [sys.executable, str(GUARD)],
        input=json.dumps({"tool_input": {"command": cmd}}),
        capture_output=True,
        text=True,
    )
    return "BLOCK" if result.returncode == 2 else "ALLOW"


def main():
    failures = []
    for expected, commands in (("BLOCK", BLOCK), ("ALLOW", ALLOW)):
        for cmd in commands:
            got = verdict(cmd)
            if got != expected:
                failures.append(f"expected {expected}, got {got}: {cmd.splitlines()[0]}")

    total = len(BLOCK) + len(ALLOW)
    if failures:
        print(f"guard_bash: {len(failures)}/{total} FAILED")
        for f in failures:
            print(f"  {f}")
        return 1
    print(f"guard_bash: {total}/{total} passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
