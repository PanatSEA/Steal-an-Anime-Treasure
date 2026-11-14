# Core Rules (as built in Phase 5)

What the game does today. Values in `code` live in the boss / series notes and AnimeConfig.

## Dig & carry
- Each dig node shows a lumpy 3-layer pile of sand-coloured stud blocks (same stud look as the tracks) with loose blocks around it and 3 glowing ice-blue crystal clusters. The chest's lid pokes out of a gap in the top layer. On an untouched mound a crystal twinkles every few seconds. The pile is solid (you can't walk through it).
- Equip the **Pickaxe** from hotbar slot 1 (press 1) and click near the mound. It takes `DigHitsRequired` hits.
- Each hit: a pink-white starburst and a big yellow star flash where the pickaxe lands, dust puffs out, and the digger's camera shakes. Hit 1 knocks the top layer off, hit 2 the middle layer (with its crystals): the blocks fly outward spinning, land and fade within a second, and the chest rises a step each time.
- Final hit: the bottom layer and loose blocks burst outward and the chest bursts out (white flash, orange-gold rays and a golden glow, sparks, flying crystals and rock chips, the emerge sound), pops up and bounces down with a dust ring, and shows the rarity the **server** rolled from `RarityWeights` as a glow and light in the rarity colour. The boss wakes and the chest lands on your head.
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
- Reaching your plot turns the treasure into a chest of its rarity; it lands with a dust ring. No limit on chests.
- A chest needs `UnlockTimeSeconds` for its rarity before it can open. The timer runs on the server clock, so it keeps counting while you're offline. Meanwhile slow twinkles drift around it; once it can open, twinkles are drawn into it and a ring pulses from its base (both in the rarity colour).
- When it's ready, hold **E** on the **Search** prompt for `OpenTimeSeconds` (only the owner sees the prompt). The chest bursts open in its rarity colour (flash, rays, sparks) with a thin white light beam, cyan cubes and white sparkles before the character appears. A chest model with a `Lid` swings the lid open instead of fading away.

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
