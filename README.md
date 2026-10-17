# Froschglibber Repair

## Repair your gear before the frog judges you

**Froschglibber Repair** is a humorous World of Warcraft Retail addon for Midnight that warns you when one of your equipped items is running low on durability.

When an equipped item falls below your configured durability threshold, a large frog appears on screen and tells you:

> **Go repair already, you noob!**

The frog can be moved, minimized, and hidden whenever you want.

## Features

- Large frog warning when equipped gear reaches low durability
- Configurable durability threshold from 0% to 80%
- 50% durability threshold by default
- Movable warning window
- Minimize and restore the frog display
- Position and display state are saved automatically
- Automatic equipment repair at merchants
- Automatic repair enabled by default
- Choose the preferred repair payment source:
  - Prefer Guild Bank funds
  - Use personal funds
- Optional automatic selling of poor-quality (gray) items at merchants
- Manual test mode
- Slash command support
- Lightweight and easy to configure

## Slash Commands

```text
/frosch test   Show the frog warning
/frosch hide   Hide the frog warning
/frosch reset  Reset the frog position and display state
/fgr           Short command alias
```

## Configuration

Open the World of Warcraft **Settings** menu and select **AddOns** > **Froschglibber Repair**.

There you can configure the durability threshold, automatic repair, the preferred repair payment source, and automatic selling of gray items.

## Installation

Install the addon through the CurseForge App, or copy the `FroschglibberRepair` folder into:

```text
World of Warcraft/_retail_/Interface/AddOns/
```

After installing or updating the addon, restart the game or use:

```text
/reload
```

## Notes

Automatic repair and automatic selling work when interacting with a merchant that provides the corresponding services. Repair costs follow the normal World of Warcraft merchant rules and available funds.
