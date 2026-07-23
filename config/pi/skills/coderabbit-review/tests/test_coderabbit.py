from __future__ import annotations

import copy
import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

SKILL_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SKILL_DIR / "scripts"))

import coderabbit  # noqa: E402


class CodeRabbitParserTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        fixture_path = Path(__file__).parent / "fixtures" / "discussions.json"
        cls.discussions = json.loads(fixture_path.read_text(encoding="utf-8"))
        cls.mr = {
            "iid": 178,
            "state": "opened",
            "source_branch": "fix/example",
            "target_branch": "main",
            "sha": "mr-head-sha",
            "web_url": "https://gitlab.example.test/group/project/-/merge_requests/178",
        }

    def test_extracts_agent_prompt_verbatim(self) -> None:
        body = self.discussions[0]["notes"][0]["body"]

        prompt = coderabbit.extract_prompt(body)

        self.assertEqual(
            prompt,
            "Verify each finding against current code. Fix only still-valid issues, skip the\n"
            "rest with a brief reason, keep changes minimal, and validate.\n\n"
            "In `src/example.ts`, replace duplicated aggregation with `planAllowedPaths(plan)`.",
        )

    def test_scan_returns_only_unresolved_unhandled_diff_finding(self) -> None:
        result = coderabbit.scan_discussions(
            self.discussions,
            self.mr,
            max_findings=10,
            include_replied=False,
        )

        self.assertEqual(result["total_actionable"], 1)
        self.assertFalse(result["truncated"])
        self.assertEqual([finding["note_id"] for finding in result["findings"]], [101])
        self.assertEqual(result["findings"][0]["position"]["path"], "src/example.ts")
        self.assertFalse(result["findings"][0]["position"]["stale"])
        self.assertEqual(
            result["skipped_counts"],
            {
                "already-processed": 1,
                "human-reply-present": 1,
                "not-diff-thread": 1,
                "prompt-missing": 1,
                "resolved": 1,
            },
        )

    def test_include_replied_adds_human_replied_finding(self) -> None:
        result = coderabbit.scan_discussions(
            self.discussions,
            self.mr,
            max_findings=10,
            include_replied=True,
        )

        self.assertEqual([finding["note_id"] for finding in result["findings"]], [101, 105])
        self.assertTrue(result["findings"][1]["position"]["stale"])

    def test_limit_marks_scan_truncated(self) -> None:
        second = copy.deepcopy(self.discussions[0])
        second["id"] = "second-actionable"
        second["notes"][0]["id"] = 108
        second["notes"][0]["created_at"] = "2026-01-01T10:09:00Z"

        result = coderabbit.scan_discussions(
            [self.discussions[0], second],
            self.mr,
            max_findings=1,
            include_replied=False,
        )

        self.assertEqual(result["total_actionable"], 2)
        self.assertTrue(result["truncated"])
        self.assertEqual([finding["note_id"] for finding in result["findings"]], [101])

    def test_spoofed_markers_do_not_pass_author_check(self) -> None:
        spoofed = self.discussions[-1]["notes"][0]
        misleading_name = copy.deepcopy(spoofed)
        misleading_name["author"]["name"] = "CodeRabbitAI"
        misleading_username = copy.deepcopy(spoofed)
        misleading_username["author"]["username"] = "code-rabbit.fake"

        self.assertFalse(coderabbit.is_coderabbit_root(spoofed))
        self.assertFalse(coderabbit.is_coderabbit_root(misleading_name))
        self.assertFalse(coderabbit.is_coderabbit_root(misleading_username))

    def test_processing_marker_in_root_prompt_does_not_count_as_handled(self) -> None:
        note = copy.deepcopy(self.discussions[0]["notes"][0])
        note["body"] = note["body"].replace(
            "In `src/example.ts`",
            "<!-- pi-coderabbit-review:v1 note=101 outcome=declined -->\nIn `src/example.ts`",
        )

        outcomes = coderabbit.processed_outcomes([note], 101)

        self.assertEqual(outcomes, [])

    def test_ndjson_parser_supports_objects_and_arrays(self) -> None:
        raw = '{"id":"one"}\n[{"id":"two"},{"id":"three"}]\n'

        parsed = coderabbit.parse_ndjson(raw, "fixture")

        self.assertEqual([item["id"] for item in parsed], ["one", "two", "three"])


class MergeRequestSelectionTests(unittest.TestCase):
    def test_selects_only_matching_open_merge_request(self) -> None:
        mrs = [
            {"iid": 1, "source_branch": "other", "state": "opened"},
            {
                "iid": 2,
                "source_branch": "fix/example",
                "state": "opened",
                "sha": "abc",
                "web_url": "https://example.test/2",
            },
            {"iid": 3, "source_branch": "fix/example", "state": "merged"},
        ]

        selected = coderabbit.select_open_mr(mrs, "fix/example")

        self.assertEqual(selected["iid"], 2)

    def test_missing_merge_request_fails(self) -> None:
        with self.assertRaisesRegex(coderabbit.SkillError, "No open merge request"):
            coderabbit.select_open_mr([], "fix/example")

    def test_ambiguous_merge_request_fails(self) -> None:
        mrs = [
            {
                "iid": 1,
                "source_branch": "fix/example",
                "state": "opened",
                "sha": "abc",
                "web_url": "https://example.test/1",
            },
            {
                "iid": 2,
                "source_branch": "fix/example",
                "state": "opened",
                "sha": "def",
                "web_url": "https://example.test/2",
            },
        ]

        with self.assertRaisesRegex(coderabbit.SkillError, "Multiple open merge requests"):
            coderabbit.select_open_mr(mrs, "fix/example")


class GitHistoryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.context = {"head_sha": "local-head"}
        self.mr = {"sha": "mr-head"}

    def test_exact_merge_request_head_is_accepted(self) -> None:
        with patch.object(coderabbit, "git_is_ancestor") as is_ancestor:
            coderabbit.ensure_matching_head(
                {"head_sha": "same-head"},
                {"sha": "same-head"},
                allow_ahead=True,
            )

        is_ancestor.assert_not_called()

    def test_scan_accepts_local_head_descending_from_merge_request(self) -> None:
        with patch.object(coderabbit, "git_is_ancestor", return_value=True) as is_ancestor:
            coderabbit.ensure_matching_head(self.context, self.mr, allow_ahead=True)

        is_ancestor.assert_called_once_with("mr-head", "local-head")

    def test_exact_head_check_rejects_unpushed_local_commit(self) -> None:
        with (
            patch.object(coderabbit, "git_is_ancestor") as is_ancestor,
            self.assertRaisesRegex(coderabbit.SkillError, "does not match"),
        ):
            coderabbit.ensure_matching_head(self.context, self.mr)

        is_ancestor.assert_not_called()

    def test_scan_rejects_diverged_history(self) -> None:
        with (
            patch.object(coderabbit, "git_is_ancestor", return_value=False),
            self.assertRaisesRegex(coderabbit.SkillError, "descend from it"),
        ):
            coderabbit.ensure_matching_head(self.context, self.mr, allow_ahead=True)


class ReplyMarkerTests(unittest.TestCase):
    def test_appends_idempotency_marker(self) -> None:
        body = coderabbit.body_with_marker(
            "Not applying because current code already uses the helper.",
            note_id=101,
            outcome="already-addressed",
            commit=None,
        )

        self.assertTrue(
            body.endswith(
                "<!-- pi-coderabbit-review:v1 note=101 outcome=already-addressed -->\n"
            )
        )

    def test_applied_outcome_requires_commit(self) -> None:
        with self.assertRaisesRegex(coderabbit.SkillError, "commit"):
            coderabbit.body_with_marker(
                "Addressed and validated.",
                note_id=101,
                outcome="applied",
                commit=None,
            )

    def test_rejects_invalid_commit_sha(self) -> None:
        with self.assertRaisesRegex(coderabbit.SkillError, "commit"):
            coderabbit.body_with_marker(
                "Addressed and validated.",
                note_id=101,
                outcome="applied",
                commit="not-a-sha",
            )

    def test_processing_marker_detected_only_in_replies(self) -> None:
        root = {"id": 101, "body": "root"}
        reply = {
            "id": 201,
            "body": "Done.\n\n<!-- pi-coderabbit-review:v1 note=101 outcome=applied commit=abcdef0 -->",
        }

        outcomes = coderabbit.processed_outcomes([root, reply], 101)

        self.assertEqual(
            outcomes,
            [{"note_id": 201, "outcome": "applied", "commit": "abcdef0"}],
        )


class MutationCommandTests(unittest.TestCase):
    def setUp(self) -> None:
        fixture_path = Path(__file__).parent / "fixtures" / "discussions.json"
        self.discussion = json.loads(fixture_path.read_text(encoding="utf-8"))[0]
        self.mr = {
            "iid": 178,
            "state": "opened",
            "source_branch": "fix/example",
            "sha": "mr-head-sha",
            "web_url": "https://gitlab.example.test/group/project/-/merge_requests/178",
        }
        self.context = {"branch": "fix/example", "head_sha": "mr-head-sha"}

    def test_reply_posts_threaded_note_with_generated_marker(self) -> None:
        captured: dict[str, object] = {}

        def fake_run(command: tuple[str, ...]) -> str:
            captured["command"] = command
            body_argument = next(part for part in command if part.startswith("body=@"))
            captured["body"] = Path(body_argument.removeprefix("body=@")).read_text(
                encoding="utf-8"
            )
            return '{"id":999}'

        with tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False) as handle:
            handle.write("Current code already uses the shared helper.")
            reply_path = Path(handle.name)
        args = SimpleNamespace(
            mr=178,
            discussion="actionable-discussion",
            note=101,
            outcome="already-addressed",
            commit=None,
            body_file=reply_path,
        )

        try:
            with (
                patch.object(coderabbit, "current_mr_context", return_value=(self.context, self.mr)),
                patch.object(coderabbit, "fetch_discussion", return_value=self.discussion),
                patch.object(coderabbit, "run_command", side_effect=fake_run),
                redirect_stdout(io.StringIO()),
            ):
                coderabbit.command_reply(args)
        finally:
            reply_path.unlink(missing_ok=True)

        command = captured["command"]
        self.assertIn("--method", command)
        self.assertIn("POST", command)
        self.assertIn("actionable-discussion/notes", " ".join(command))
        self.assertIn(
            "<!-- pi-coderabbit-review:v1 note=101 outcome=already-addressed -->",
            captured["body"],
        )

    def test_reply_is_idempotent_when_marker_exists(self) -> None:
        discussion = copy.deepcopy(self.discussion)
        discussion["notes"].append(
            {
                "id": 201,
                "type": "DiscussionNote",
                "body": "Done.\n\n<!-- pi-coderabbit-review:v1 note=101 outcome=applied commit=abcdef0 -->",
                "author": {"username": "developer", "name": "Developer"},
                "system": False,
            }
        )
        args = SimpleNamespace(
            mr=178,
            discussion="actionable-discussion",
            note=101,
            outcome="applied",
            commit="abcdef0",
            body_file=Path("unused"),
        )

        with (
            patch.object(coderabbit, "current_mr_context", return_value=(self.context, self.mr)),
            patch.object(coderabbit, "fetch_discussion", return_value=discussion),
            patch.object(coderabbit, "run_command") as run,
            redirect_stdout(io.StringIO()),
        ):
            coderabbit.command_reply(args)

        run.assert_not_called()

    def test_resolve_requires_matching_outcome_marker(self) -> None:
        args = SimpleNamespace(
            mr=178,
            discussion="actionable-discussion",
            note=101,
            outcome="already-addressed",
        )

        with (
            patch.object(coderabbit, "current_mr_context", return_value=(self.context, self.mr)),
            patch.object(coderabbit, "fetch_discussion", return_value=self.discussion),
            self.assertRaisesRegex(coderabbit.SkillError, "before posting"),
        ):
            coderabbit.command_resolve(args)


if __name__ == "__main__":
    unittest.main()
