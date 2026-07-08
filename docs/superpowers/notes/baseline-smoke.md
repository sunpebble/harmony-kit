# Baseline Smoke Notes — simmer (Task 0)

Date: 2026-07-08
Branch: `harmony-platform-opt-simmer`
Purpose: Confirm unmodified code builds cleanly, install to simulator, capture "before" screenshots.

## Environment

- Simulator: `127.0.0.1:5555` (online, HarmonyOS API 23 / 6.1.0)
- Toolchain: DevEco Studio bundled SDK at
  `/Applications/DevEco-Studio.app/Contents/sdk/default`
- hvigorw: `/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw`
- hdc: `/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc`

## Bundle name

Confirmed from `AppScope/app.json5`:

- `bundleName`: **`com.sunpebble.simmer`**

> NOTE: the task brief referenced `com.sunpebble.simmer.harmony`, but the
> actual bundleName in the source of truth has **no `.harmony` suffix**. All
> install/launch commands used the real value `com.sunpebble.simmer`.

## Build result (CRITICAL GATE): BUILD SUCCESSFUL

Commands (run from `apps/simmer`):

```bash
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
HVIGOR=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
$HVIGOR clean --no-daemon                       # BUILD SUCCESSFUL
$HVIGOR assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
                                                # BUILD SUCCESSFUL in ~5.4s
```

### IMPORTANT environment finding — DEVECO_SDK_HOME

A clean CLI build **fails** unless `DEVECO_SDK_HOME` is set correctly:

- Wrong (task-brief literal / bundled `default` dir):
  `DEVECO_SDK_HOME=.../Contents/sdk/default` → hvigor error
  `00303168 Configuration Error: SDK component missing.`
  Reason: the bundled SDK is a *flattened* layout (`default/openharmony`,
  `default/hms`). The HarmonyOS SDK loader scans for a per-version
  `sdk-pkg.json` sitting inside a **subdirectory** of the SDK home; the
  flattened layout puts the only `sdk-pkg.json` at the root of `default`,
  so the recursive scan finds 0 components.
- Correct: `DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk`
  (the **parent** of `default`). Then the loader discovers
  `Contents/sdk/default/sdk-pkg.json` as the single versioned SDK and build
  succeeds. Verified empirically against the hvigor SDK loader.

This value must be exported for every CLI build in subsequent tasks.

### Warnings (non-fatal, present in baseline — these are PRE-EXISTING)

ArkTS deprecation / "may throw" warnings emitted by the unmodified source:

- `packages/sunpebble_ui/src/main/ets/runtime/SunWindowInsets.ets:17,22,23`
  — `px2vp` deprecated; "Function may throw exceptions".
- `apps/simmer/entry/src/main/ets/entryability/EntryAbility.ets:10`
  — "Function may throw exceptions".
- `apps/simmer/entry/src/main/ets/pages/Index.ets:102,675`
  — `getStringSync` deprecated; "Function may throw exceptions".

JDK warning (toolchain-side, not our code): `sun.misc.Unsafe::arrayBaseOffset`
called by fastjson2 inside `app_packing_tool.jar` (terminally deprecated).

### Signing caveat

`build-profile.json5` has **no `signingConfigs`**, so the SignHap step is
skipped and the build emits only `entry-default-unsigned.hap` (there is no
`entry-default-signed.hap`). The running simulator accepts the **unsigned**
hap for debug install, so this did not block baseline capture. Subsequent
tasks should be aware: any release/signed build will require configuring
`signingConfigs` first.

- Built artifact: `apps/simmer/entry/build/default/outputs/default/entry-default-unsigned.hap`
  (≈ 350 KB)

## Install + launch

```bash
$HDC uninstall com.sunpebble.simmer           # ok (or "not installed")
$HDC install .../entry-default-unsigned.hap   # install bundle successfully
$HDC shell aa start -a EntryAbility -b com.sunpebble.simmer  # start ability successfully
```

On first launch the OS shows a "Allow Simmer to send you notifications?"
dialog — tapped **Allow** so timers/alarms behave normally.

## Smoke behavior (spec §7.3 quick pass)

Manual walk-through on the baseline build:

1. Empty state: "Nothing on the stove" + preset chips (`+ Custom`,
   `🍵 Tea · 3:00`, `🍜 Ramen · 4:00`). ✔ as expected.
2. Tap Tea preset → single running timer card (🍵 TEA, counts down from 3:00;
   controls `+1 minute` / `Restart` / `Cancel`). ✔
3. Tap Ramen preset (with Tea already running) → second running card stacked
   below (🍜 RAMEN 4:00). Multi-timer list scrolls. ✔
4. Let a timer expire → card switches to `DONE` with `OVER +m:ss` counting up
   (overdue indicator), controls still present. ✔ (matches "done" state)
5. `+ Custom` opens a custom-timer sheet: emoji picker, min/sec wheel pickers,
   `SAVE AS PRESET` and `START` buttons. ✔

No crashes, no ANRs observed during the smoke pass. Baseline app behavior is
functional and matches expectations for the "before" state.

## Before screenshots captured

Saved to `.asc-shots/simmer/before/` (outside the repo):

| Scene            | File                 | Notes |
|------------------|----------------------|-------|
| empty            | `empty.jpeg`         | Empty stove, presets visible |
| single_running   | `single_running.jpeg`| 🍵 TEA running (~2:42) |
| multi_running    | `multi_running.jpeg` | 🍵 TEA + 🍜 RAMEN both running |
| done_state       | `done_state.jpeg`    | 🍵 TEA `DONE` / `OVER +0:14`, Ramen still running |

Captured all 4 highest-value before scenes requested for the task. The 4
secondary scenes from the brief (`paused`, `context_menu`,
`saved_presets_block`, `swipe_delete`) were not captured: the baseline UX
does not surface those exact forms (no context menu / swipe-delete in the
current build), so they are N/A for "before" and will be introduced/compared
only on the "after" side.
