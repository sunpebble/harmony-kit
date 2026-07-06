# Design

## Design System

Sunpebble HarmonyKit is a restrained product UI system for small HarmonyOS tools.
The base visual language mirrors the existing Sunpebble brand and native app
themes:

- Cream `#FFF6E8` for light surfaces.
- Ink `#232733` for primary text and dark cards.
- Sun `#F7B733` for primary actions and selected state.
- Pebble `#6E6E73` for secondary text.
- Night `#161928` for dark-first apps.

## Typography

Use HarmonyOS system typography. Product labels, buttons, rows, and tool surfaces
use one sans family. App-specific type treatments are allowed only as a profile
choice, such as Dayroll's monospaced receipt feel.

## Layout

The iOS app is the source of truth when a Sunpebble app already exists there.
Match the iOS first screen, core flow, copy, presets, empty state, and control
placement before adding Harmony-only affordances.

The default shell is a task surface: compact all-caps title area, optional
primary action, content list or cards, and a small settings/info area. No
landing page, no hero, no nested cards.

## Components

Initial shared components:

- `SunButton`: primary, secondary, danger, disabled, loading.
- `SunCard`: repeated item or framed tool surface.
- `SunListRow`: settings, navigation, and value rows.
- `SunEmptyState`: empty or first-run state with one action.
- `SunToolShell`: app title, tagline, primary action, and content slot.

## Motion

Use default ArkUI state feedback first. Add explicit motion only for state
changes that need feedback, such as a row being added or a timer changing state.
