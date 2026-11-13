# Core Rules (as built in Phase 3)

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
- On join you get the first free plot (Place1 → Place8). Its sign shows "<Name>'s Plot x/8".
- Only your own plot banks treasure. Other plots do nothing.
- Leaving frees the plot and removes everything on it. A 9th player gets no plot.

## Banking & slots
- Standing on your plot while carrying puts the treasure in a free slot (`PlotSlots` = 8).
- Plot full → the treasure stays on your head and the sign shows "Plot full! Sell a treasure".
- `Treasures` leaderstat = treasures on your plot right now.

## Income (`IncomePerSecond`)
- Every banked treasure pays `IncomePerSecond` into **Cash** once per second (`IncomeTickSeconds`).

## Selling (`SellPrice`)
- Hold **E** (`SellHoldSeconds` = 0.5) on a treasure on your plot → +`SellPrice` Cash, slot freed.
- Only the owner sees and can use the Sell prompt.

## Saving
- Session only: Cash, plot and banked treasures reset when you leave.

## Losing the treasure
- Hit by a boss skill, dying, respawning, or leaving the game → treasure is gone and returns to its dig site.
