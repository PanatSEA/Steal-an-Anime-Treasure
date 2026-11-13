# Core Rules (as built in Phase 1)

What the game does today. Edit the **Planned** lines to set the rules for later phases.

## Dig & carry
- Hold **E** on the dig mound for `DigTimeSeconds` → treasure appears above your head.
- One treasure per dig site at a time; it respawns on the mound once the boss is asleep again.

## Boss
- Sleeps by its dig site. Wakes when a dig completes and chases the carrier at `WalkSpeed`.
- Every `SkillCooldownSeconds` it drops a red circle on the carrier; after `TelegraphWarningSeconds` anyone inside `SkillRadiusStuds` takes `SkillDamage`.
- A hit drops the treasure (`DropTreasureOnHit`). The boss then walks home and sleeps.
- Stops chasing the moment the carrier enters the SAFE ZONE (the lobby).

## Plot assignment
- **Now:** none. All 8 lobby plots are shared; standing on any plot banks the treasure.
- **Planned:**

## Income (`IncomePerSecond`)
- **Now:** not paid. Banking only adds +1 to the `Treasures` leaderstat. No currency exists yet.
- **Planned:**

## Selling (`SellPrice`)
- **Now:** not implemented.
- **Planned:**

## Losing the treasure
- Hit by a boss skill, dying, respawning, or leaving the game → treasure is gone and returns to its dig site.
