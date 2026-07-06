# HarmonyKit

Shared ArkUI foundation for Sunpebble HarmonyOS apps.

This is the batch-app layer: one brand system, one small tool shell, one template,
many apps. The first app should prove the loop; only then add release automation.

## Layout

```text
HarmonyKit/
  packages/sunpebble_ui/   ArkUI tokens, components, and shell
  apps/                     Simmer, Sleeptab, Steady, Dayroll, Homekeep
  templates/tool-app/      Copyable app starter
  scripts/new-app.mjs      Template copier
```

## Create an App

```bash
node HarmonyKit/scripts/new-app.mjs Simmer --tagline "Parallel kitchen timers" --accent "#F7B733"
```

The command writes `HarmonyKit/apps/simmer` from `templates/tool-app`.

## Apps

1. Simmer: timers, presets, burner countdown.
2. Sleeptab: sleep debt, night ranges, insights, sleep need.
3. Steady: readings, trends, meds, settings/export preview.
4. Dayroll: daily entry, mood, streak, export preview.
5. Homekeep: household maintenance reminders.

Skipped for now: auth, payments, analytics, CI release, and AppGallery metadata
automation. Add those after one generated app builds in DevEco Studio.
