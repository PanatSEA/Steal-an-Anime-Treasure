# Steal an Anime Treasure - Master Plan

## Completed in Roblox Studio
- Player Base Plot (Anime character storage) + SAFE ZONE
- Treasure Spawner / Digging Node model

## Rules
- [[Core_Rules]]

## Phases
- **Phase 1 (v0.1-phase1):** dig, carry, boss chase + circle telegraph prototype
- **Phase 2 (Boss_01 only):** boss sleeps by its dig node, wakes on dig there, chases the carrier at WalkSpeed 18, stops at the SAFE ZONE, telegraphed skill; first hit (25 dmg) drops the treasure, normal health regen; back to sleep after ReturnToSleepSeconds; server decides hits/damage/drops; grey-box model, placeholder assets
- **Phase 3:**
  - Plot ownership: auto-assigned on join (first free of 8); only your own plot banks treasure
  - Income + Cash: up to 8 banked treasures per plot, each pays `IncomePerSecond` into Cash every second
  - Selling: hold E on a banked treasure to sell it for `SellPrice` Cash (owner only)
  - Session only, no saving yet

## Stage 1: Anime Series 1 (3 Bosses)
- [[Boss_01]]
- [[Boss_02]]
- [[Boss_03]]