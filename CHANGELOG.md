# Changelog

All notable changes to FroschglibberRepair will be documented in this file.

## [1.0.0] - 2026-10-18

### Added

- Large frog warning when equipped gear falls below the configured durability threshold
- Configurable durability threshold from 0% to 80% (default: 50%)
- Movable, minimizable warning window with saved position and state
- Automatic repair at merchants (enabled by default)
- Green chat message after an automatic repair: "Froschglibber hat deine Ausrüstung für X Gold repariert."
- Repair payment source preference: guild bank (preferred) or personal funds
- Optional automatic selling of poor-quality (gray) items at merchants
- Green chat message after an automatic sale: "Froschglibber hat deinen Schrott für X Gold abgekauft."
- Options panel under Settings > AddOns > FroschglibberRepair
- Slash commands: `/frosch test`, `/frosch hide`, `/frosch reset` (alias: `/fgr`)

### Fixed

- Guild bank repair now falls back to personal funds when the player has no
  guild, lacks guild repair permission, or the guild bank does not hold enough
  money (no more "no permission" error)
- The guild bank option is hidden in the settings when the player is not in a
  guild, and the saved repair source resets to personal funds in that case
