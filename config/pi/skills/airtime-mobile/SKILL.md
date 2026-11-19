---
name: airtime-mobile
description: Drive the Airtime Rewards mobile app (React Native, `airtime-app`) on an iOS Simulator or Android Emulator with agent-device. Use for launching, logging in, navigating, debugging, reproducing a bug, smoke testing, validating a change, or exploratory QA in that app. Defaults to iOS and supplies the login MSISDN.
compatibility: Requires the user-global `agent-device` CLI (installed by the dotfiles repo's `dotfiles npm`), Xcode for iOS, and the `airtime-app` repository.
---

# Airtime mobile

App-specific defaults for the Airtime Rewards mobile app. Device mechanics stay with the upstream skills: `ios-simulator` by default, `android-emulator` only when Android is requested, `agent-device` for interaction and selectors, and `dogfood` for exploratory QA. Read those instead of duplicating their commands here.

## Login

When the task needs a signed-in user, the login MSISDN is `7425676899`. Use it even though the repository defines other test users in `detox/helpers/user.ts`. Request a login code and enter the value the app receives; staging returns it directly, so no SMS step is needed.

## Repository facts

Read these from the repository on every task, because they change: launch command (`package.json` scripts, such as `npm run ios:staging`), bundle identifier (`app.json`), selected scheme, verification-code handling, selectors, and cleanup helpers. Do not invent values, and do not copy them into this skill.

## Work

1. Platform: iOS unless the request names Android.
2. Target: what the user asked for. Inspect a bounded diff only when asked to verify changes and the expected behaviour is otherwise unclear; a clean working tree is not a reason to stop.
3. Build, reload, or reuse the running app by the smallest step that makes it represent the current code. Match the app's CI Xcode version rather than the newest one.
4. Base findings on the running app, not on source reads alone.

## Safety

- Clearing app data is allowed on a simulator or emulator. Never reset a physical device without approval.
- Run flows that mutate shared test-account state only when the task needs them, and clean up in the same run.
- Keep screenshots, logs, and recordings in an ignored or temporary directory.
