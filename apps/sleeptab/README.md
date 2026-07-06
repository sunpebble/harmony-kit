# Sleeptab

Generated from `HarmonyKit/templates/tool-app`.

If an iOS version exists, port its first screen and core workflow first. Reuse
the same copy, presets, empty state, and primary controls before adding
Harmony-only extras.

Replace the sample page with the app's single core workflow before adding
secondary settings or monetization.

## Build

```bash
ohpm install
cd entry && ohpm install
cd ..
DEVECO_SDK_HOME=/Users/shikun/Developer/freelance/sunpebble/harmony-kit/.deveco-sdk/default hvigorw assembleApp --no-daemon
```
