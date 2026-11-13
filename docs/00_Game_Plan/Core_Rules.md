# Core Rules (as built in Phase 2)

What the game does today. Edit the **Planned** lines to set the rules for later phases.

## Dig & carry
- Hold **E** on the dig mound for `DigTimeSeconds` → treasure appears above your head.
- One treasure per dig site at a time; it respawns on the mound once the boss is asleep again.

## Boss
- Sleeps by its dig site. Wakes when a dig completes and chases the carrier at `WalkSpeed`.
- Every `SkillCooldownSeconds` it drops a red circle on the carrier; after `TelegraphWarningSeconds` anyone inside `SkillRadiusStuds` takes `SkillDamage`.
- The first hit drops the treasure (`DropTreasureOnHit`); 25 damage means it takes 4 hits to kill. Normal health regen stays on.
- Stops chasing the moment the carrier enters the SAFE ZONE (the lobby) or loses the treasure.
- Walks home and falls asleep `ReturnToSleepSeconds` after the chase ends.
- The server decides all hits, damage and drops.

## Plot assignment
- **Now:** none. All 8 lobby plots are shared; standing on any plot banks the treasure.
- **Planned (Phase 3):** one plot per player; only your own plot banks.

## Income (`IncomePerSecond`)
- **Now:** not paid. Banking only adds +1 to the `Treasures` leaderstat. No currency exists yet.
- **Planned (Phase 3):** banked treasures pay `IncomePerSecond` into Cash.

## Selling (`SellPrice`)
- **Now:** not implemented.
- **Planned (Phase 3):** sell a banked treasure for `SellPrice` Cash.

## Losing the treasure
- Hit by a boss skill, dying, respawning, or leaving the game → treasure is gone and returns to its dig site.
