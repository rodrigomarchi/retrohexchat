#!/usr/bin/env python3
"""PreToolUse guard for Bash commands.

Turns the repository's destructive-command rules into enforcement instead of
prose. Exit 2 blocks the call and shows stderr to the agent; exit 0 allows it.

Anything unexpected allows the command through — a guard that breaks normal work
would be worse than the mistakes it prevents.
"""

import json
import re
import subprocess
import sys
import time
from pathlib import Path

STALE_FETCH_SECONDS = 15 * 60

# A command boundary: start of string, or after a shell separator. Without this,
# prose that merely mentions a command (a commit message, an echo, a doc string)
# would trip the guard.
BOUNDARY = r"(?:^|[\n;&|(]|&&|\|\|)\s*"


def strip_heredocs(cmd):
    """Drop heredoc bodies — they are data, not commands.

    `git commit -F - <<'EOF' ... EOF` legitimately contains prose about the very
    commands this guard blocks.
    """
    out, skip_to = [], None
    for line in cmd.splitlines():
        if skip_to is not None:
            if line.strip() == skip_to:
                skip_to = None
            continue
        m = re.search(r"<<-?\s*['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?", line)
        if m:
            skip_to = m.group(1)
            line = line[: m.start()]
        out.append(line)
    return "\n".join(out)


def block(message):
    print(message, file=sys.stderr)
    sys.exit(2)


def git(*args):
    try:
        out = subprocess.run(
            ["git", *args], capture_output=True, text=True, timeout=5, check=False
        )
        return out.stdout.strip() if out.returncode == 0 else None
    except Exception:
        return None


def check_git_add(cmd):
    if re.search(BOUNDARY + r"git\s+add\s+(-A\b|--all\b|\.(?:\s|$))", cmd):
        block(
            "Blocked: `git add -A` / `git add .` is not allowed in this repository.\n"
            "The working tree may carry unrelated uncommitted work from parallel "
            "sessions.\nStage the exact paths you changed instead: "
            "`git add path/one path/two`."
        )


def check_deploy(cmd):
    if re.search(BOUNDARY + r"make\s+deploy-sun\b", cmd):
        block(
            "Blocked: `make deploy-sun` skips CI validation.\n"
            "Use `make deploy` (runs the full CI pipeline first), or "
            "`make deploy.skip-ci` only if `make ci` just passed on this exact "
            "revision."
        )


def check_destructive_checkout(cmd):
    # `git checkout -- <path>` or `git checkout <existing-file>` discards work.
    # `git checkout -b`, `git checkout <branch>`, `git switch` are fine.
    m = re.search(BOUNDARY + r"git\s+checkout\s+(.+)", cmd)
    if not m:
        return
    rest = m.group(1).strip()
    if rest.startswith("-b") or rest.startswith("-B"):
        return
    targets = [t for t in rest.split() if not t.startswith("-")]
    if "--" in rest or any(Path(t).is_file() for t in targets):
        block(
            "Blocked: `git checkout <file>` reverts to HEAD and destroys *other* "
            "uncommitted work too.\n"
            "Undo the edit with the Edit tool, or use a recoverable "
            "`git stash push -- <file>`."
        )


def check_behind_main(cmd):
    if not re.search(BOUNDARY + r"git\s+(commit|push)\b", cmd):
        return
    branch = git("rev-parse", "--abbrev-ref", "HEAD")
    if branch != "main":
        return

    fetch_head = Path(git("rev-parse", "--git-dir") or ".git") / "FETCH_HEAD"
    if not fetch_head.exists() or time.time() - fetch_head.stat().st_mtime > STALE_FETCH_SECONDS:
        block(
            "Blocked: the remote has not been fetched recently, so we cannot tell "
            "whether local `main` is current.\n"
            "Several people push to this repository in parallel. Run:\n"
            "  git fetch origin && git status --short --branch"
        )

    behind = git("rev-list", "--count", "HEAD..origin/main")
    if behind and behind.isdigit() and int(behind) > 0:
        block(
            f"Blocked: local `main` is {behind} commit(s) behind `origin/main`.\n"
            "Pull before committing or pushing:\n"
            "  git pull --ff-only origin main"
            "   (add --autostash if you have uncommitted edits)"
        )


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    cmd = strip_heredocs((payload.get("tool_input") or {}).get("command") or "")
    if not cmd:
        sys.exit(0)

    for check in (check_git_add, check_deploy, check_destructive_checkout, check_behind_main):
        try:
            check(cmd)
        except SystemExit:
            raise
        except Exception:
            continue  # a broken check must never block real work

    sys.exit(0)


if __name__ == "__main__":
    main()
