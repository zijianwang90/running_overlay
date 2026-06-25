#!/usr/bin/env python3
"""
Cursor project hook: remind agents to keep the monthly project log current.

- sessionStart: inject standing policy into conversation context.
- postToolUse (Write | StrReplace): nudge after substantive path edits.
"""
from __future__ import annotations

import json
import os
import sys

SESSION_CONTEXT = (
    "Running Overlay — project log: After substantive changes under "
    "`Sources/`, `Tests/`, `Package.swift`, or `docs/` (except when the only "
    "edit is the project log itself), append a dated `## YYYY-MM-DD` section "
    "to the current monthly file linked from `docs/project-log.md`.\n\n"
    "仓库约定：完成有用户可见影响的改动后，在 `docs/project-log.md` 所链接的当月日志中追加记录；"
    "若本轮只维护了 project-log 可略过。"
)

POST_NUDGE = (
    "Project log: this edit touches tracked paths — if the change is substantive, "
    "append a brief dated entry to the current monthly project log."
)


def _norm(p: str) -> str:
    return p.replace("\\", "/")


def _workspace_roots(data: dict) -> list[str]:
    roots = data.get("workspace_roots")
    if isinstance(roots, list):
        return [str(r) for r in roots if r]
    return []


def _under_workspace(path: str, data: dict) -> bool:
    n = _norm(path)
    for root in _workspace_roots(data):
        r = _norm(os.path.abspath(root))
        if n.startswith(r.rstrip("/") + "/") or n == r:
            return True
    return True


def _should_nudge_for_path(path: str, data: dict) -> bool:
    if not path:
        return False
    path = os.path.abspath(path)
    if not _under_workspace(path, data):
        return False
    n = _norm(path)
    if "/docs/project-log/" in n or n.endswith("/docs/project-log.md"):
        return False
    if "/.cursor/hooks/" in n:
        return False
    markers = ("/Sources/", "/Tests/", "/docs/", "/CLAUDE.md", "/Package.swift")
    return any(m in n for m in markers)


def _extract_write_path(data: dict) -> str:
    ti = data.get("tool_input")
    if isinstance(ti, str):
        try:
            ti = json.loads(ti)
        except json.JSONDecodeError:
            ti = None
    if not isinstance(ti, dict):
        return ""
    for key in ("path", "file_path", "target_file", "file"):
        v = ti.get(key)
        if isinstance(v, str) and v.strip():
            return v.strip()
    return ""


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        print("{}")
        return

    event = data.get("hook_event_name") or ""

    if event == "sessionStart":
        print(json.dumps({"additional_context": SESSION_CONTEXT}))
        return

    is_post = event == "postToolUse" or (
        not event and data.get("tool_name") in ("Write", "StrReplace")
    )
    if is_post:
        raw = _extract_write_path(data)
        if not raw:
            print("{}")
            return
        cwd = data.get("cwd") or os.getcwd()
        path = raw if os.path.isabs(raw) else os.path.normpath(os.path.join(cwd, raw))
        if _should_nudge_for_path(path, data):
            print(json.dumps({"additional_context": POST_NUDGE}))
        else:
            print("{}")
        return

    print("{}")


if __name__ == "__main__":
    main()
