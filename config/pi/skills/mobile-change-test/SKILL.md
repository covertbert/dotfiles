---
name: mobile-change-test
description: Run the current mobile app on an iOS Simulator or Android Emulator and verify uncommitted or recently changed user-visible behavior with agent-device. Use when asked to "test these changes on the iOS simulator", "run this on the simulator", "verify this UI change on iOS/Android", "check the app on the emulator", or to smoke-test a flow on a device. Requires the `agent-device` CLI plus repository-local launch, selector, and test-data knowledge.
compatibility: Requires the user-global `agent-device` CLI (installed by this dotfiles repo's `dotfiles npm`), Xcode for iOS, and a mobile app repository with its own documented run commands.
---

# Mobile change test

Run the current app on a device and check the behavior this change is supposed to produce. This skill coordinates existing repository facts and the official `agent-device`, `ios-simulator`, `android-emulator`, and `dogfood` skills. It does not own device control, launch commands, selectors, or credentials.

Typical requests name the device and the platform: `test these changes on the iOS simulator`, `run this on the emulator`, `verify this UI change on Android`. A request that does not name a device or platform is not enough to choose a target; ask which one, or default to iOS when the repository only supports one.

## Non-negotiable rules

- Findings must come from the running app, not from reading source alone.
- Reuse values already defined in the repository. Never invent a bundle identifier, test account, selector, launch script, or cleanup flow.
- Do not add dependencies, install packages, or change application manifests for this task.
- Use one session and one device at a time. Do not run state-changing commands in parallel.
- Clear app data only on a simulator or emulator. Never do it on a physical device without explicit approval.
- Treat screenshots, logs, and network captures as potentially sensitive. Write them to an ignored or temporary directory, and do not commit them.
- Stop and report when the app, device, or expected behavior cannot be determined. Do not guess a target.

## 1. Confirm prerequisites

Check the CLI is available and is the pinned user-global install:

```bash
command -v agent-device
agent-device --version
```

If the command is missing, stop and tell the user to run `dotfiles npm` from the dotfiles repository. Do not install or upgrade it from this skill.

Confirm the working directory is a mobile app repository before touching a device. Look for `package.json`, `app.json`, `android/`, `ios/`, or equivalent Flutter/native project markers, plus a run script or documented run command. If the repository is not a runnable app, say so and stop.

Do not probe with `--help`, `devices`, `appstate`, `snapshot`, or `screenshot` before there is a target. The official skills tell you to start from `open` once the target is known.

## 2. Gather repository facts

Read, in this order, only what exists:

1. Agent instructions: `AGENTS.md`, `CLAUDE.md`, and any nested instructions that cover the files under test.
2. Run and test documentation: `README.md`, `docs/`, and the `scripts` section of `package.json`.
3. App identity: `app.json`, `android/app/build.gradle`, `ios/*/Info.plist`, or the project's equivalent.
4. Existing end-to-end tooling: Detox, Maestro, or project test folders, including page objects, fixtures, generated data, test accounts, and cleanup helpers.
5. Environment files that are already committed. Never read or print secrets from local-only environment files.

Record the following from those sources only:

- Launch command and environment, for example `npm run ios:staging`.
- Bundle identifier or package name.
- Whether a development build with Metro is expected, and how to reload JavaScript changes.
- Test account credentials or fixtures, and where the repository defines them.
- Existing selectors or accessibility identifiers for the screens involved.
- Cleanup rules for any flow that mutates shared state.

This skill holds no credentials. A login is only possible when the repository names a test identity and its code path; a seeded phone number without a working verification step is not a credential. If the login cannot be completed from repository sources, say the session needs credentials and ask for them before driving the app, rather than guessing a number, PIN or bypass.

If a value is missing, report the gap instead of substituting a default.

## 3. Determine what to verify

Build the target list from the change, not from a fixed script:

```bash
git status --short 2>&1 | head -c 4000
git diff --stat 2>&1 | head -c 4000
git diff 2>&1 | head -c 20000
git diff --cached 2>&1 | head -c 20000
```

When the working tree is clean, use the current branch's commits against its merge base instead.

Map changed files to user-visible behavior through the code itself: screens, navigation entries, forms, flags, and copy. Then write a short checklist with one line per runtime check: where to go, what to do, and what must be observed. Keep it small enough to run now.

If the diff has no user-visible effect, say so and stop rather than driving the app for nothing.

## 4. Establish a clean, current runtime

Use the `ios-simulator` skill (or `android-emulator` when Android is requested). Read version-matched guidance only when needed:

```bash
agent-device help validate
agent-device help react-native
```

Choose the smallest step that makes the running app represent the current code:

1. Metro-backed JavaScript-only change: reuse the running development build and reload JavaScript.
2. Native, dependency, or environment-config change: run the repository's documented build and launch command.
3. Stale or unknown state: rebuild using that same documented command.

Over-the-air update code needs a non-debug build. When the diff touches an OTA or self-update path, a debug build reports updates as disabled and the feature is inert, so a Metro session proves nothing. Build the repository's release configuration or install the build its documentation names for update testing, and say which you used.

Clear simulator app data before login when a clean session matters, and state that you did it. Prefer the repository's own reset script when one exists.

Before acting on the app, check for React Native error or warning overlays, permission prompts, and interrupted previous sessions. Dismiss an unrelated overlay, capture it as a finding when it is related, and note it in the report.

## 5. Verify

Drive the app with `agent-device`, following the official `agent-device` workflow:

1. Open the app with `--platform ios` (or the requested platform) and continue from the returned interactive snapshot.
2. Work from current `@refs`, then `id`, `label`, or `role` selectors. Use coordinates only when the accessibility tree is unusable.
3. After each state change, continue from the printed diff and re-snapshot only when the diff lacks the next target.
4. Verify the named expectation with `wait`, `is`, `get`, or `find`. Do not treat a successful tap as a passing check.
5. Capture one screenshot per checklist item, in a single artifact directory, only when it adds evidence. Skip video, recordings, and logs unless the user asks or a failure needs them.

### Baseline checks

Run a login smoke check on every verification when the repository provides non-production test credentials. Reuse the repository's existing fixture and any automatic code handling; do not type real customer credentials.

Run a mutating baseline flow, such as adding a payment card, only when the diff can affect it or the user asked for full smoke coverage. Such flows change shared test-account state, so reuse the repository's generated data, assertions, and cleanup path. Clean up in the same run, and report anything left behind.

## 6. Close and report

Close the session when finished:

```bash
agent-device close
```

Report:

- The platform, device, and launch command used, and whether the app was rebuilt or only reloaded.
- The checklist items and their observed results, marked pass, fail, or not checked.
- Screenshot paths for the items that needed them.
- Any overlay, warning, permission prompt, or unrelated defect seen on the way.
- Any mutation made to a shared test account and its cleanup outcome.
- Gaps: missing credentials, selectors, launch scripts, or ambiguous expected behavior.

Do not paste full command transcripts, snapshots, or diffs. Quote only the evidence needed to justify a result.

## Deferred by design

Do not add replay scripts, CI wiring, or an MCP server to this workflow. The CLI already exposes the same runtime, and a `.ad` replay is worth recording only after the same exploratory flow has proved stable and worth repeating. Raise that need separately.
