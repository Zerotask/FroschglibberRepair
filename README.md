# Froschglibber Repair

## Repair your gear before the frog judges you

**Froschglibber Repair** is a humorous World of Warcraft Retail addon for Midnight that warns you when one of your equipped items is running low on durability.

When an equipped item falls below your configured durability threshold, a large frog appears on screen and tells you:

> **Go repair already, you noob!**

The frog can be moved, minimized, and hidden whenever you want.

## Features

- Large frog warning when equipped gear reaches low durability
- Small frog popup on ready checks showing the durability of your most worn item for 10 seconds
- Small frog popup taunting "Haha du Noob" for 3 seconds whenever you die
- Small frog popups are positioned automatically so they never cover the big repair frog
- Configurable durability threshold from 0% to 80%
- 50% durability threshold by default
- Movable warning window
- Minimize and restore the frog display
- Position and display state are saved automatically
- Automatic equipment repair at merchants
- Automatic repair enabled by default
- Green chat message telling you how much the repair cost
- Choose the preferred repair payment source:
  - Prefer Guild Bank funds
  - Use personal funds
- Optional automatic selling of poor-quality (gray) items at merchants
- Green chat message after auto-selling: "Froschglibber hat deinen Schrott für X Gold abgekauft."
- Manual test mode
- Slash command support
- Lightweight and easy to configure

## Slash Commands

```text
/frosch test   Show the frog warning
/frosch hide   Hide the frog warning
/frosch rc     Preview the ready-check durability popup
/frosch tod    Preview the death popup ("Haha du Noob")
/frosch reset  Reset the frog position and display state
/fgr           Short command alias
```

## Configuration

Open the World of Warcraft **Settings** menu and select **AddOns** > **Froschglibber Repair**.

There you can configure the durability threshold, automatic repair, the preferred repair payment source, and automatic selling of gray items. You can also toggle the ready-check durability popup and the death taunt popup there.

## Installation

Install the addon through the CurseForge App, or copy the `FroschglibberRepair` folder into:

```text
World of Warcraft/_retail_/Interface/AddOns/
```

After installing or updating the addon, restart the game or use:

```text
/reload
```

## Development

The addon's behaviour is covered by a small test suite that loads the addon
against a stub of the WoW API. It needs a Lua interpreter (e.g. `brew install lua`):

```text
make test          # syntax check + behaviour tests
make zip           # build dist/FroschglibberRepair-<version>.zip
```

Pushing to `main` runs these steps in GitHub Actions and uploads the built zip
as a build artifact (see `.github/workflows/ci.yml`).

## Notes

Automatic repair and automatic selling work when interacting with a merchant that provides the corresponding services. Repair costs follow the normal World of Warcraft merchant rules and available funds.
