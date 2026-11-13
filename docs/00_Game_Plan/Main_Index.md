# Steal an Anime Treasure - Master Plan

## Completed in Roblox Studio
- Player Base Plot (Anime character storage) + SAFE ZONE
- Treasure Spawner / Digging Node model

## Rules
- [[Core_Rules]]

## Phases
- **Phase 1 (v0.1-phase1):** dig, carry, boss chase + circle telegraph prototype
- **Phase 2 (Boss_01 only):** boss sleeps by its dig node, wakes on dig there, chases the carrier at WalkSpeed 18, stops at the SAFE ZONE, telegraphed skill; first hit (25 dmg) drops the treasure, normal health regen; back to sleep after ReturnToSleepSeconds; server decides hits/damage/drops; grey-box model, placeholder assets
- **Phase 3 (v0.3-phase3, being replaced):** plots, banked treasures paying income, selling. Selling is dropped by the redesign below.
- **Phase 3b (v0.3.1-phase3, redesign):**
  - Plot ownership: auto-assigned on join (first free of 8); only your own plot accepts treasure
  - Rarity roll at dig (server only): the boss's `RarityWeights` decide the chest's rarity, shown on the chest
  - Chests on plot: no limit; each needs `UnlockTimeSeconds` for its rarity (keeps counting offline), then hold **E** for `OpenTimeSeconds`
  - Opening picks one character of the chest's rarity at random (equal chance) from the boss's series ([[Series_01_Characters]])
  - Placing characters: up to 8 on your plot; more go to the inventory (storage only, no income)
  - Income into Cash: each plot character earns its own `IncomePerSecond`
  - Saving: characters, Cash and unopened chests (rarity + timer) between sessions
  - Models load by name: `ReplicatedStorage/Models/Bosses/<BossId>`, `ReplicatedStorage/Models/Characters/<Series>/<CharacterId>`; missing → grey dummy with a name label

## Stage 1: Anime Series 1 (3 Bosses)
- [[Boss_01]]
- [[Boss_02]]
- [[Boss_03]]