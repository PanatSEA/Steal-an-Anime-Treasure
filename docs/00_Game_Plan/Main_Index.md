# Steal an Anime Treasure - Master Plan

## Completed in Roblox Studio
- Player Base Plot (Anime character storage) + SAFE ZONE
- Treasure Spawner / Digging Node model

## Rules
- [[Core_Rules]]

## Phases
- **Phase 1 (v0.1-phase1):** dig, carry, boss chase + circle telegraph prototype
- **Phase 2 (Boss_01 only):** boss sleeps by its dig node, wakes on dig there, chases the carrier at WalkSpeed 18, stops at the SAFE ZONE, telegraphed skill; first hit (25 dmg) drops the treasure, normal health regen; back to sleep after ReturnToSleepSeconds; server decides hits/damage/drops; grey-box model, placeholder assets
- **Phase 3 (planned, not built):**
  - Plot ownership: each player gets one of the 8 lobby plots; only your own plot banks treasure
  - Income + Cash: banked treasures sit on your plot and pay `IncomePerSecond` into Cash
  - Selling: sell a banked treasure for `SellPrice` Cash

## Stage 1: Anime Series 1 (3 Bosses)
- [[Boss_01]]
- [[Boss_02]]
- [[Boss_03]]