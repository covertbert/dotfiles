#!/usr/bin/env python3
"""Deterministic GitLab transport and parsing for the coderabbit-review skill."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from collections import Counter
from pathlib import Path
from typing import Any, Sequence

SCHEMA_VERSION = 1
AUTO_GENERATED_MARKER = "<!-- This is an auto-generated comment by CodeRabbit -->"
CR_COMMENT_RE = re.compile(r"<!--\s*cr-comment:v1:[^>]+-->", re.IGNORECASE)
BOT_USERNAME_RE = re.compile(r"(?:^|[._-])code[._-]?rabbit|coderabbit", re.IGNORECASE)
PROMPT_HEADING_RE = re.compile(
    r"<summary>\s*(?:🤖\s*)?Prompt for AI Agents\s*</summary>",
    re.IGNORECASE,
)
FENCED_BLOCK_RE = re.compile(r"(?:```|~~~)[^\r\n]*\r?\n(.*?)(?:\r?\n)(?:```|~~~)", re.DOTALL)
PROCESSED_MARKER_RE = re.compile(
    r"<!--\s*pi-coderabbit-review:v1\s+note=(?P<note>\d+)\s+"
    r"outcome=(?P<outcome>[a-z-]+)(?:\s+commit=(?P<commit>[0-9a-f]+))?\s*-->",
    re.IGNORECASE,
)
VALID_OUTCOMES = {"applied", "already-addressed", "declined", "not-applicable"}
MAX_PROMPT_CHARS = 12_000
MAX_DESCRIPTION_CHARS = 4_000

JsonObject = dict[str, Any]


class SkillError(RuntimeError):
    """Expected user-facing workflow failure."""


def run_command(args: Sequence[str]) -> str:
    """Run command without shell interpolation and return stdout."""
    try:
        result = subprocess.run(
            list(args),
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError as exc:
        raise SkillError(f"Could not run {args[0]}: {exc}") from exc

    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        if len(detail) > 2_000:
            detail = f"{detail[:2_000]}…"
        rendered = " ".join(args)
        raise SkillError(f"Command failed ({result.returncode}): {rendered}\n{detail}")

    return result.stdout


def require_tools() -> None:
    missing = [tool for tool in ("git", "glab") if shutil.which(tool) is None]
    if missing:
        raise SkillError(f"Missing required command(s): {', '.join(missing)}")


def parse_json(raw: str, source: str) -> Any:
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        raise SkillError(f"Invalid JSON returned by {source}: {exc}") from exc


def parse_ndjson(raw: str, source: str) -> list[JsonObject]:
    items: list[JsonObject] = []
    for line_number, line in enumerate(raw.splitlines(), start=1):
        if not line.strip():
            continue
        value = parse_json(line, f"{source} line {line_number}")
        if isinstance(value, list):
            items.extend(item for item in value if isinstance(item, dict))
        elif isinstance(value, dict):
            items.append(value)
        else:
            raise SkillError(f"Unexpected JSON value returned by {source} line {line_number}")
    return items


def git_context(*, require_clean: bool) -> JsonObject:
    root = run_command(("git", "rev-parse", "--show-toplevel")).strip()
    branch = run_command(("git", "branch", "--show-current")).strip()
    if not branch:
        raise SkillError("Detached HEAD. Check out the merge request source branch first.")

    head_sha = run_command(("git", "rev-parse", "HEAD")).strip()
    status = run_command(("git", "status", "--porcelain=v1", "--untracked-files=all"))
    if require_clean and status.strip():
        changed = "\n".join(status.splitlines()[:20])
        raise SkillError(f"Worktree is not clean. Commit, stash, or remove changes first:\n{changed}")

    return {
        "repository_root": root,
        "branch": branch,
        "head_sha": head_sha,
        "clean": not bool(status.strip()),
    }


def select_open_mr(mrs: Sequence[JsonObject], branch: str) -> JsonObject:
    matches = [
        mr
        for mr in mrs
        if mr.get("source_branch") == branch and mr.get("state") == "opened"
    ]
    if not matches:
        raise SkillError(f"No open merge request found for current branch '{branch}'.")
    if len(matches) > 1:
        iids = ", ".join(f"!{mr.get('iid', '?')}" for mr in matches)
        raise SkillError(f"Multiple open merge requests found for branch '{branch}': {iids}")

    mr = matches[0]
    for field in ("iid", "sha", "web_url", "source_branch"):
        if not mr.get(field):
            raise SkillError(f"Merge request response is missing required field '{field}'.")
    return mr


def discover_open_mr(branch: str) -> JsonObject:
    raw = run_command(
        (
            "glab",
            "mr",
            "list",
            "--source-branch",
            branch,
            "--output",
            "json",
            "--per-page",
            "100",
        )
    )
    payload = parse_json(raw, "glab mr list")
    if not isinstance(payload, list):
        raise SkillError("Unexpected JSON returned by glab mr list.")
    return select_open_mr([item for item in payload if isinstance(item, dict)], branch)


def ensure_matching_head(context: JsonObject, mr: JsonObject) -> None:
    if context["head_sha"] != mr["sha"]:
        raise SkillError(
            "Local HEAD does not match merge request head. "
            f"Local: {context['head_sha']}; MR: {mr['sha']}. Sync branch before continuing."
        )


def current_mr_context(*, require_clean: bool) -> tuple[JsonObject, JsonObject]:
    require_tools()
    context = git_context(require_clean=require_clean)
    mr = discover_open_mr(str(context["branch"]))
    ensure_matching_head(context, mr)
    return context, mr


def fetch_discussions(mr_iid: int) -> list[JsonObject]:
    endpoint = (
        f"projects/:fullpath/merge_requests/{mr_iid}/discussions?per_page=100"
    )
    raw = run_command(("glab", "api", endpoint, "--paginate", "--output", "ndjson"))
    return parse_ndjson(raw, "glab api discussions")


def fetch_discussion(mr_iid: int, discussion_id: str) -> JsonObject:
    endpoint = f"projects/:fullpath/merge_requests/{mr_iid}/discussions/{discussion_id}"
    payload = parse_json(run_command(("glab", "api", endpoint)), "glab api discussion")
    if not isinstance(payload, dict):
        raise SkillError("Unexpected JSON returned for merge request discussion.")
    return payload


def author_is_coderabbit(note: JsonObject) -> bool:
    author = note.get("author")
    if not isinstance(author, dict):
        return False
    username = str(author.get("username") or "")
    name = re.sub(r"[^a-z0-9]", "", str(author.get("name") or "").lower())
    return bool(BOT_USERNAME_RE.search(username)) and name.startswith("coderabbit")


def has_coderabbit_markers(note: JsonObject) -> bool:
    body = str(note.get("body") or "")
    return AUTO_GENERATED_MARKER in body and bool(CR_COMMENT_RE.search(body))


def is_coderabbit_root(note: JsonObject) -> bool:
    return author_is_coderabbit(note) and has_coderabbit_markers(note)


def extract_prompt(body: str) -> str | None:
    heading = PROMPT_HEADING_RE.search(body)
    if not heading:
        return None
    fenced = FENCED_BLOCK_RE.search(body, heading.end())
    if not fenced:
        return None
    return fenced.group(1)


def extract_description(body: str) -> str:
    description = body.split("<details>", 1)[0].strip()
    if len(description) > MAX_DESCRIPTION_CHARS:
        return f"{description[:MAX_DESCRIPTION_CHARS]}…"
    return description


def extract_headline(body: str) -> str | None:
    match = re.search(r"\*\*(.+?)\*\*", body, re.DOTALL)
    if not match:
        return None
    return re.sub(r"\s+", " ", match.group(1)).strip()


def processed_outcomes(notes: Sequence[JsonObject], note_id: int) -> list[JsonObject]:
    """Return skill outcome markers from replies, never from untrusted root text."""
    outcomes: list[JsonObject] = []
    for note in notes[1:]:
        body = str(note.get("body") or "")
        for match in PROCESSED_MARKER_RE.finditer(body):
            if int(match.group("note")) != note_id:
                continue
            outcomes.append(
                {
                    "note_id": note.get("id"),
                    "outcome": match.group("outcome").lower(),
                    "commit": match.group("commit"),
                }
            )
    return outcomes


def has_human_reply(notes: Sequence[JsonObject], root: JsonObject) -> bool:
    root_author = root.get("author") if isinstance(root.get("author"), dict) else {}
    root_username = str(root_author.get("username") or "")
    for reply in notes[1:]:
        if reply.get("system") is True:
            continue
        author = reply.get("author") if isinstance(reply.get("author"), dict) else {}
        if str(author.get("username") or "") != root_username:
            return True
    return False


def root_note(discussion: JsonObject) -> JsonObject:
    notes = discussion.get("notes")
    if not isinstance(notes, list) or not notes or not isinstance(notes[0], dict):
        raise SkillError("Discussion has no valid root note.")
    return notes[0]


def normalise_finding(discussion: JsonObject, root: JsonObject, mr: JsonObject) -> JsonObject:
    body = str(root.get("body") or "")
    prompt = extract_prompt(body)
    if prompt is None:
        raise SkillError("Cannot normalise finding without an agent prompt.")

    position = root.get("position") if isinstance(root.get("position"), dict) else {}
    line_range = position.get("line_range") if isinstance(position.get("line_range"), dict) else None
    note_id = int(root["id"])
    return {
        "discussion_id": discussion.get("id"),
        "note_id": note_id,
        "comment_url": f"{mr['web_url']}#note_{note_id}",
        "author": (root.get("author") or {}).get("username"),
        "created_at": root.get("created_at"),
        "category": next((line for line in body.splitlines() if line.strip()), None),
        "headline": extract_headline(body),
        "description": extract_description(body),
        "prompt": prompt,
        "position": {
            "path": position.get("new_path") or position.get("old_path"),
            "new_line": position.get("new_line"),
            "old_line": position.get("old_line"),
            "line_range": line_range,
            "head_sha": position.get("head_sha"),
            "stale": bool(position.get("head_sha") and position.get("head_sha") != mr.get("sha")),
        },
    }


def scan_discussions(
    discussions: Sequence[JsonObject],
    mr: JsonObject,
    *,
    max_findings: int,
    include_replied: bool,
) -> JsonObject:
    findings: list[JsonObject] = []
    skipped: list[JsonObject] = []
    reason_counts: Counter[str] = Counter()

    for discussion in discussions:
        notes = discussion.get("notes")
        if not isinstance(notes, list) or not notes or not isinstance(notes[0], dict):
            continue
        root = notes[0]
        if not author_is_coderabbit(root):
            continue

        reason: str | None = None
        if discussion.get("individual_note") is not False or root.get("type") != "DiffNote":
            reason = "not-diff-thread"
        elif not has_coderabbit_markers(root):
            reason = "markers-missing"
        elif root.get("resolvable") is not True:
            reason = "not-resolvable"
        elif root.get("resolved") is not False:
            reason = "resolved"
        elif processed_outcomes(notes, int(root.get("id") or 0)):
            reason = "already-processed"
        elif has_human_reply(notes, root) and not include_replied:
            reason = "human-reply-present"
        else:
            prompt = extract_prompt(str(root.get("body") or ""))
            if prompt is None:
                reason = "prompt-missing"
            elif len(prompt) > MAX_PROMPT_CHARS:
                reason = "prompt-too-large"

        if reason:
            reason_counts[reason] += 1
            if len(skipped) < 25:
                note_id = root.get("id")
                skipped.append(
                    {
                        "discussion_id": discussion.get("id"),
                        "note_id": note_id,
                        "comment_url": f"{mr['web_url']}#note_{note_id}" if note_id else mr["web_url"],
                        "reason": reason,
                    }
                )
            continue

        findings.append(normalise_finding(discussion, root, mr))

    findings.sort(key=lambda finding: str(finding.get("created_at") or ""))
    total = len(findings)
    return {
        "findings": findings[:max_findings],
        "total_actionable": total,
        "truncated": total > max_findings,
        "skipped_counts": dict(sorted(reason_counts.items())),
        "skipped": skipped,
    }


def validate_mr_argument(expected_iid: int, mr: JsonObject) -> None:
    if int(mr["iid"]) != expected_iid:
        raise SkillError(
            f"Requested merge request !{expected_iid} is not current branch merge request !{mr['iid']}."
        )


def validate_live_discussion(
    discussion: JsonObject,
    *,
    note_id: int,
    allow_existing_marker: bool,
) -> tuple[JsonObject, list[JsonObject]]:
    root = root_note(discussion)
    notes = discussion.get("notes")
    if not isinstance(notes, list):
        raise SkillError("Discussion has no valid notes.")
    typed_notes = [note for note in notes if isinstance(note, dict)]

    if int(root.get("id") or 0) != note_id:
        raise SkillError(f"Discussion root note changed or does not match note {note_id}.")
    if not is_coderabbit_root(root):
        raise SkillError("Discussion root is not a verified CodeRabbit finding.")
    if root.get("type") != "DiffNote" or root.get("resolvable") is not True:
        raise SkillError("CodeRabbit discussion is not an actionable diff finding.")
    if root.get("resolved") is True:
        raise SkillError("CodeRabbit discussion is already resolved.")

    outcomes = processed_outcomes(typed_notes, note_id)
    if outcomes and not allow_existing_marker:
        raise SkillError(f"Finding already handled with outcome '{outcomes[0]['outcome']}'.")
    return root, typed_notes


def marker_for(note_id: int, outcome: str, commit: str | None = None) -> str:
    if outcome not in VALID_OUTCOMES:
        raise SkillError(f"Unsupported outcome '{outcome}'.")
    if outcome == "applied" and not commit:
        raise SkillError("Applied outcome requires a pushed commit SHA.")
    if outcome != "applied" and commit:
        raise SkillError("Commit SHA is only valid for applied outcomes.")
    if commit and not re.fullmatch(r"[0-9a-fA-F]{7,64}", commit):
        raise SkillError("Invalid commit SHA.")
    commit_part = f" commit={commit.lower()}" if commit else ""
    return f"<!-- pi-coderabbit-review:v1 note={note_id} outcome={outcome}{commit_part} -->"


def body_with_marker(body: str, *, note_id: int, outcome: str, commit: str | None) -> str:
    cleaned = body.strip()
    if not cleaned:
        raise SkillError("Reply body cannot be empty.")
    if "pi-coderabbit-review:" in cleaned:
        raise SkillError("Reply body must not provide its own processing marker.")
    return f"{cleaned}\n\n{marker_for(note_id, outcome, commit)}\n"


def write_json(payload: JsonObject, output: Path | None) -> None:
    rendered = json.dumps(payload, indent=2, ensure_ascii=False) + "\n"
    if output is None:
        sys.stdout.write(rendered)
        return
    try:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(rendered, encoding="utf-8")
    except OSError as exc:
        raise SkillError(f"Could not write scan output '{output}': {exc}") from exc
    print(f"Wrote {len(payload.get('findings', []))} finding(s) to {output}")


def command_scan(args: argparse.Namespace) -> None:
    if not 1 <= args.max_findings <= 100:
        raise SkillError("--max-findings must be between 1 and 100.")

    context, mr = current_mr_context(require_clean=True)
    discussions = fetch_discussions(int(mr["iid"]))
    scan = scan_discussions(
        discussions,
        mr,
        max_findings=args.max_findings,
        include_replied=args.include_replied,
    )
    payload: JsonObject = {
        "schema_version": SCHEMA_VERSION,
        "repository": context,
        "merge_request": {
            "iid": mr["iid"],
            "title": mr.get("title"),
            "state": mr["state"],
            "source_branch": mr["source_branch"],
            "target_branch": mr.get("target_branch"),
            "sha": mr["sha"],
            "web_url": mr["web_url"],
        },
        **scan,
    }
    write_json(payload, args.output)


def command_reply(args: argparse.Namespace) -> None:
    _, mr = current_mr_context(require_clean=False)
    validate_mr_argument(args.mr, mr)
    discussion = fetch_discussion(args.mr, args.discussion)
    root, notes = validate_live_discussion(
        discussion,
        note_id=args.note,
        allow_existing_marker=True,
    )

    existing = processed_outcomes(notes, args.note)
    if existing:
        existing_outcome = str(existing[0]["outcome"])
        if existing_outcome != args.outcome:
            raise SkillError(
                f"Finding already handled as '{existing_outcome}', not requested '{args.outcome}'."
            )
        print(json.dumps({"status": "already-handled", **existing[0]}, indent=2))
        return

    if has_human_reply(notes, root):
        raise SkillError("Discussion gained a human reply. Review thread before posting.")

    try:
        body = args.body_file.read_text(encoding="utf-8")
    except OSError as exc:
        raise SkillError(f"Could not read reply body '{args.body_file}': {exc}") from exc
    reply_body = body_with_marker(
        body,
        note_id=args.note,
        outcome=args.outcome,
        commit=args.commit,
    )
    endpoint = (
        f"projects/:fullpath/merge_requests/{args.mr}/discussions/"
        f"{args.discussion}/notes"
    )
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False) as handle:
        handle.write(reply_body)
        body_path = Path(handle.name)
    try:
        response = parse_json(
            run_command(
                (
                    "glab",
                    "api",
                    endpoint,
                    "--method",
                    "POST",
                    "--field",
                    f"body=@{body_path}",
                )
            ),
            "glab api reply",
        )
    finally:
        body_path.unlink(missing_ok=True)

    if not isinstance(response, dict):
        raise SkillError("Unexpected response after posting discussion reply.")
    print(
        json.dumps(
            {
                "status": "posted",
                "discussion_id": args.discussion,
                "note_id": response.get("id"),
                "outcome": args.outcome,
            },
            indent=2,
        )
    )


def command_resolve(args: argparse.Namespace) -> None:
    _, mr = current_mr_context(require_clean=False)
    validate_mr_argument(args.mr, mr)
    discussion = fetch_discussion(args.mr, args.discussion)
    root = root_note(discussion)
    if int(root.get("id") or 0) != args.note or not is_coderabbit_root(root):
        raise SkillError("Discussion is not requested verified CodeRabbit finding.")
    if root.get("type") != "DiffNote" or root.get("resolvable") is not True:
        raise SkillError("CodeRabbit discussion is not an actionable diff finding.")
    if root.get("resolved") is True:
        print(json.dumps({"status": "already-resolved", "discussion_id": args.discussion}, indent=2))
        return

    notes = discussion.get("notes")
    if not isinstance(notes, list):
        raise SkillError("Discussion has no valid notes.")
    typed_notes = [note for note in notes if isinstance(note, dict)]
    outcomes = processed_outcomes(typed_notes, args.note)
    matching = [outcome for outcome in outcomes if outcome["outcome"] == args.outcome]
    if not matching:
        raise SkillError(
            f"Cannot resolve before posting '{args.outcome}' outcome marker for note {args.note}."
        )

    marker_note_ids = {outcome["note_id"] for outcome in outcomes}
    root_author = root.get("author") if isinstance(root.get("author"), dict) else {}
    root_username = str(root_author.get("username") or "")
    for reply in typed_notes[1:]:
        if reply.get("system") is True or reply.get("id") in marker_note_ids:
            continue
        author = reply.get("author") if isinstance(reply.get("author"), dict) else {}
        if str(author.get("username") or "") != root_username:
            raise SkillError("Discussion gained another human reply. Review thread before resolving.")

    endpoint = f"projects/:fullpath/merge_requests/{args.mr}/discussions/{args.discussion}"
    response = parse_json(
        run_command(
            (
                "glab",
                "api",
                endpoint,
                "--method",
                "PUT",
                "--field",
                "resolved=true",
            )
        ),
        "glab api resolve",
    )
    if not isinstance(response, dict):
        raise SkillError("Unexpected response after resolving discussion.")
    print(json.dumps({"status": "resolved", "discussion_id": args.discussion}, indent=2))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Scan and safely update CodeRabbit merge request discussions."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    scan = subparsers.add_parser("scan", help="Find actionable CodeRabbit findings.")
    scan.add_argument("--output", type=Path, help="Write normalized JSON to this file.")
    scan.add_argument("--max-findings", type=int, default=10)
    scan.add_argument(
        "--include-replied",
        action="store_true",
        help="Include threads that already contain a human reply.",
    )
    scan.set_defaults(handler=command_scan)

    reply = subparsers.add_parser("reply", help="Reply to a verified CodeRabbit discussion.")
    reply.add_argument("--mr", type=int, required=True)
    reply.add_argument("--discussion", required=True)
    reply.add_argument("--note", type=int, required=True)
    reply.add_argument("--outcome", choices=sorted(VALID_OUTCOMES), required=True)
    reply.add_argument("--commit", help="Pushed commit SHA for applied outcomes.")
    reply.add_argument("--body-file", type=Path, required=True)
    reply.set_defaults(handler=command_reply)

    resolve = subparsers.add_parser("resolve", help="Resolve a replied-to CodeRabbit discussion.")
    resolve.add_argument("--mr", type=int, required=True)
    resolve.add_argument("--discussion", required=True)
    resolve.add_argument("--note", type=int, required=True)
    resolve.add_argument("--outcome", choices=sorted(VALID_OUTCOMES), required=True)
    resolve.set_defaults(handler=command_resolve)

    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        args.handler(args)
    except SkillError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("error: interrupted", file=sys.stderr)
        return 130
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
