# Core Rules (as built in Phase 4)

What the game does today. Values in `code` live in the boss / series notes and AnimeConfig.

## Dig & carry
- Each dig node shows a dirt mound with a chest buried under it (a lid corner pokes out). Untouched mounds puff dust and sparkle every few seconds.
- Equip the **Pickaxe** from hotbar slot 1 (press 1) and click near the mound. It takes `DigHitsRequired` hits.
- Each hit: the mound shrinks and loses chunks, dirt bursts out, the chest rises about a third, and the digger's camera shakes.
- Final hit: the mound is gone, the chest pops out with a bounce and sparkles, and shows the rarity the **server** rolled from `RarityWeights` (trim colour + light beam). The boss wakes and the chest lands on your head.
- **First hitter claims the dig.** Other players' hits are ignored. The claim lapses after 10s without a hit, if the digger walks 25 studs away, dies or leaves, and the mound grows back.
- The server checks every hit: Pickaxe equipped, within 12 studs, not faster than one hit per 0.35s. The client only plays visuals.
- One treasure per dig site at a time; a new mound appears once the boss is asleep again.

## Boss
- Sleeps by its dig site. Wakes when a dig completes and chases the carrier at `WalkSpeed`.
- Every `SkillCooldownSeconds` it drops a red circle on the carrier; after `TelegraphWarningSeconds` anyone inside `SkillRadiusStuds` takes `SkillDamage`.
- The first hit drops the treasure (`DropTreasureOnHit`); 25 damage means it takes 4 hits to kill. Normal health regen stays on.
- Stops chasing the moment the carrier enters the SAFE ZONE (the lobby) or loses the treasure.
- Walks home and falls asleep `ReturnToSleepSeconds` after the chase ends.
- The server decides all hits, damage and drops.

## Plot
- On join you get the first free plot (Place1 → Place8). Sign: "<Name>'s Plot x/8 | n chests".
- Only your own plot accepts treasure. Leaving frees the plot. A 9th player gets no plot.

## Chests
- Reaching your plot turns the treasure into a chest of its rarity. No limit on chests.
- A chest needs `UnlockTimeSeconds` for its rarity before it can open. The timer runs on the server clock, so it keeps counting while you're offline.
- When it's ready, hold **E** for `OpenTimeSeconds` to open it (only the owner sees the prompt). The lid swings open and coins pop out before the character appears.

## Characters
- Opening picks one character of the chest's rarity at random (equal chance) from the boss's series. Server only.
- Up to 8 characters stand on your plot. Each earns its own `IncomePerSecond` into **Cash** every second.
- If the plot is full, the character goes to your **inventory**: storage only, no income.
- Treasures and characters are never sold.

## Saving
- Cash, characters (plot + inventory) and unopened chests (rarity + unlock time) are saved.
- If saving can't load (for example Studio API access is off), you play that session without saving.

## Losing the treasure
- Hit by a boss skill, dying, respawning, or leaving the game → treasure is gone and returns to its dig site.
