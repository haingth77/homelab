#!/usr/bin/env python3
"""Documentation freshness checker.

Reads .doc-manifest.yml and uses git history to detect stale documentation.
Reports which docs need updating and how far behind they are.

Usage:
    scripts/doc-freshness.py                  # Full freshness report
    scripts/doc-freshness.py --stale          # Only show stale docs
    scripts/doc-freshness.py --check-pr       # Check files changed on current branch vs main
    scripts/doc-freshness.py --json           # JSON output (for CI pipelines)
    scripts/doc-freshness.py --markdown       # Markdown table (for PR comments)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path


@dataclass
class DocEntry:
    doc: str
    sources: list[str]


@dataclass
class FreshnessResult:
    doc: str
    exists: bool
    stale: bool
    doc_commit: str | None = None
    doc_timestamp: int | None = None
    source_commit: str | None = None
    source_timestamp: int | None = None
    commits_behind: int = 0


# ── Manifest parser (no PyYAML dependency) ──────────────────────────────────

def parse_manifest(path: str) -> list[DocEntry]:
    """Parse the simple YAML manifest structure without external dependencies."""
    entries: list[DocEntry] = []
    current_doc: str | None = None
    current_sources: list[str] = []
    in_sources = False

    with open(path) as f:
        for line in f:
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue

            if stripped.startswith("- doc:"):
                if current_doc is not None:
                    entries.append(DocEntry(doc=current_doc, sources=current_sources))
                current_doc = stripped.split(":", 1)[1].strip()
                current_sources = []
                in_sources = False
            elif stripped == "sources:":
                in_sources = True
            elif in_sources and stripped.startswith("- "):
                current_sources.append(stripped[2:].strip())
            elif stripped == "documents:":
                continue
            else:
                in_sources = False

    if current_doc is not None:
        entries.append(DocEntry(doc=current_doc, sources=current_sources))

    return entries


# ── Git helpers ──────────────────────────────────────────────────────────────

REPO_ROOT: str | None = None


def repo_root() -> str:
    global REPO_ROOT
    if REPO_ROOT is None:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True,
        )
        REPO_ROOT = result.stdout.strip()
    return REPO_ROOT


def git_last_commit(paths: list[str], exclude: str | None = None) -> tuple[str | None, int | None]:
    """Return (short_hash, unix_timestamp) of the most recent commit touching paths."""
    cmd = ["git", "log", "-1", "--format=%H %ct", "--"]
    cmd.extend(paths)
    if exclude:
        cmd.append(f":!{exclude}")

    result = subprocess.run(cmd, capture_output=True, text=True, cwd=repo_root())
    output = result.stdout.strip()
    if not output:
        return None, None
    parts = output.split()
    return parts[0][:8], int(parts[1])


def git_commits_between(
    older_hash: str, newer_hash: str, paths: list[str], exclude: str | None = None,
) -> int:
    """Count commits between two refs, scoped to paths."""
    cmd = ["git", "rev-list", "--count", f"{older_hash}..{newer_hash}", "--"]
    cmd.extend(paths)
    if exclude:
        cmd.append(f":!{exclude}")

    result = subprocess.run(cmd, capture_output=True, text=True, cwd=repo_root())
    return int(result.stdout.strip()) if result.stdout.strip() else 0


def git_changed_files_on_branch(base: str = "origin/main") -> set[str]:
    """Return the set of file paths changed on the current branch vs base."""
    result = subprocess.run(
        ["git", "diff", "--name-only", f"{base}...HEAD"],
        capture_output=True, text=True, cwd=repo_root(),
    )
    if result.returncode != 0 or not result.stdout.strip():
        return set()
    return set(result.stdout.strip().splitlines())


# ── Core logic ───────────────────────────────────────────────────────────────

def check_freshness(entries: list[DocEntry]) -> list[FreshnessResult]:
    results: list[FreshnessResult] = []

    for entry in entries:
        doc_path = Path(repo_root()) / entry.doc

        if not doc_path.exists():
            results.append(FreshnessResult(doc=entry.doc, exists=False, stale=True))
            continue

        doc_hash, doc_ts = git_last_commit([entry.doc])
        src_hash, src_ts = git_last_commit(entry.sources, exclude=entry.doc)

        if not src_hash:
            stale, behind = False, 0
        elif not doc_hash:
            stale, behind = True, -1
        elif src_ts and doc_ts and src_ts > doc_ts:
            stale = True
            behind = git_commits_between(doc_hash, src_hash, entry.sources, exclude=entry.doc)
        else:
            stale, behind = False, 0

        results.append(FreshnessResult(
            doc=entry.doc,
            exists=True,
            stale=stale,
            doc_commit=doc_hash,
            doc_timestamp=doc_ts,
            source_commit=src_hash,
            source_timestamp=src_ts,
            commits_behind=behind,
        ))

    return results


def check_pr(entries: list[DocEntry], base: str = "origin/main") -> list[dict]:
    """Check which docs should have been updated in the current branch."""
    changed = git_changed_files_on_branch(base)
    if not changed:
        return []

    warnings: list[dict] = []
    for entry in entries:
        source_touched = False
        for f in changed:
            if f == entry.doc:
                continue
            for src in entry.sources:
                if f.startswith(src) or f == src:
                    source_touched = True
                    break
            if source_touched:
                break

        if source_touched and entry.doc not in changed:
            warnings.append({
                "doc": entry.doc,
                "sources": entry.sources,
                "message": f"Implementation sources changed but {entry.doc} was not updated",
            })

    return warnings


# ── Formatting ───────────────────────────────────────────────────────────────

def time_ago(ts: int | None) -> str:
    if ts is None:
        return "never"
    delta = datetime.now(tz=timezone.utc) - datetime.fromtimestamp(ts, tz=timezone.utc)
    if delta.days > 30:
        return f"{delta.days // 30}mo ago"
    if delta.days > 0:
        return f"{delta.days}d ago"
    if delta.seconds > 3600:
        return f"{delta.seconds // 3600}h ago"
    return f"{delta.seconds // 60}m ago"


def print_table(results: list[FreshnessResult], stale_only: bool = False) -> None:
    items = [r for r in results if r.stale] if stale_only else results
    if not items:
        print("\n  All documentation is up-to-date.\n")
        return

    col = max(len(r.doc) for r in items)

    print()
    print(f"  {'Document':<{col}}  {'Status':<8}  {'Doc':<10}  {'Source':<10}  {'Behind'}")
    print(f"  {'─' * col}  {'─' * 8}  {'─' * 10}  {'─' * 10}  {'─' * 10}")

    for r in items:
        icon = "✗" if r.stale else "✓"
        status = "MISSING" if not r.exists else ("STALE" if r.stale else "ok")
        doc_ref = r.doc_commit or "—"
        src_ref = r.source_commit or "—"
        behind = f"{r.commits_behind} commits" if r.commits_behind > 0 else "—"
        print(f"  {icon} {r.doc:<{col}}  {status:<8}  {doc_ref:<10}  {src_ref:<10}  {behind}")

    stale_n = sum(1 for r in results if r.stale)
    fresh_n = len(results) - stale_n
    print(f"\n  Summary: {fresh_n}/{len(results)} up-to-date, {stale_n} stale\n")


def print_markdown(results: list[FreshnessResult]) -> None:
    """Markdown table suitable for PR comments."""
    stale = [r for r in results if r.stale]
    if not stale:
        print("All documentation is up-to-date.")
        return

    print("| Status | Document | Doc commit | Source commit | Behind |")
    print("|--------|----------|------------|---------------|--------|")
    for r in stale:
        status = "MISSING" if not r.exists else "STALE"
        doc_ref = f"`{r.doc_commit}`" if r.doc_commit else "—"
        src_ref = f"`{r.source_commit}`" if r.source_commit else "—"
        behind = f"{r.commits_behind}" if r.commits_behind > 0 else "—"
        print(f"| {status} | `{r.doc}` | {doc_ref} | {src_ref} | {behind} |")


def print_pr_warnings(warnings: list[dict]) -> None:
    if not warnings:
        print("\n  All affected docs are updated in this branch.\n")
        return
    print(f"\n  ⚠  {len(warnings)} doc(s) may need updating:\n")
    for w in warnings:
        print(f"  • {w['doc']}")
        print(f"    {w['message']}")
    print()


# ── CLI ──────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Check documentation freshness against implementation sources",
    )
    parser.add_argument("--stale", action="store_true", help="Only show stale docs")
    parser.add_argument("--check-pr", action="store_true", help="Check current branch for missing doc updates")
    parser.add_argument("--base", default="origin/main", help="Base branch for --check-pr (default: origin/main)")
    parser.add_argument("--json", action="store_true", help="JSON output")
    parser.add_argument("--markdown", action="store_true", help="Markdown table output")
    parser.add_argument("--manifest", default=".doc-manifest.yml", help="Path to manifest (default: .doc-manifest.yml)")
    args = parser.parse_args()

    manifest_path = Path(repo_root()) / args.manifest
    if not manifest_path.exists():
        print(f"Error: manifest not found at {manifest_path}", file=sys.stderr)
        sys.exit(2)

    entries = parse_manifest(str(manifest_path))

    # ── PR mode ──────────────────────────────────────────────────────────
    if args.check_pr:
        warnings = check_pr(entries, base=args.base)
        if args.json:
            print(json.dumps(warnings, indent=2))
        elif args.markdown:
            if warnings:
                print("| Document | Issue |")
                print("|----------|-------|")
                for w in warnings:
                    print(f"| `{w['doc']}` | {w['message']} |")
            else:
                print("All affected docs are updated in this branch.")
        else:
            print_pr_warnings(warnings)
        sys.exit(1 if warnings else 0)

    # ── Full freshness report ────────────────────────────────────────────
    results = check_freshness(entries)
    has_stale = any(r.stale for r in results)

    if args.json:
        data = [
            {k: v for k, v in asdict(r).items() if k != "exists" or not r.exists}
            for r in results
        ]
        print(json.dumps(data, indent=2))
    elif args.markdown:
        print_markdown(results)
    else:
        print_table(results, stale_only=args.stale)

    sys.exit(1 if has_stale else 0)


if __name__ == "__main__":
    main()
