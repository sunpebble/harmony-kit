# HarmonyKit

Shared ArkUI foundation for Sunpebble HarmonyOS apps.

This is the batch-app layer: one brand system, one small tool shell, one template,
many apps. The first app should prove the loop; only then add release automation.

## Layout

```text
HarmonyKit/
  packages/sunpebble_ui/   ArkUI tokens, components, and shell
  templates/tool-app/      Copyable app starter
  scripts/new-app.mjs      Template copier
```

## Create an App

```bash
node HarmonyKit/scripts/new-app.mjs Simmer --tagline "Parallel kitchen timers" --accent "#F7B733"
```

The command writes `HarmonyKit/apps/simmer` from `templates/tool-app`.

## First App Order

1. Simmer: timers, presets, card, notification.
2. Sleeptab: sleep record, debt, weekly insight, card.
3. Steady: meds, readings, reminders, export.
4. Dayroll: daily entry, mood, export.
5. Homekeep: household maintenance reminders.

Skipped for now: auth, payments, analytics, CI release, and AppGallery metadata
automation. Add those after one generated app builds in DevEco Studio.
