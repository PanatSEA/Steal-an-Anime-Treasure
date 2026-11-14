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
- **Phase 4 "Dig feel":** (decided: first hitter claims the dig; Pickaxe lives in hotbar slot 1; rarity shown as trim colour + light beam)
  - Dirt mound at each dig node (rounded cartoon Parts, brown dirt, small rocks/pebbles) at `ReplicatedStorage/Models/Treasures/DirtMound`; idle dust puff or faint sparkle every few seconds
  - The chest starts buried under the mound with only a hint showing (cracked mound or a lid corner)
  - Dig with the existing **Pickaxe** Tool (StarterPack, not renamed): click to hit, `DigHitsRequired` = 3 replaces `DigTimeSeconds`
  - Hits 1–2: pickaxe swing, dirt particle burst, small camera shake; the mound shrinks and loses chunks; the chest rises about ⅓ with a TweenService Back-easing bounce
  - Hit 3: the mound is gone, the chest pops fully out with a bounce and sparkle burst and shows its rarity (trim colour or light beam: Common, Epic, Legendary, Secret); then the boss wakes (`OnDigCompleted`)
  - The lid stays closed until it's opened with E on your plot (lid-opening + coin-pop animation)
  - Chest model: stylized low-poly Parts (wood box, metal trim, a bit of moss) at `ReplicatedStorage/Models/Treasures/Chest`, loaded by name so it can be replaced
  - A new mound appears at the node when the treasure respawns
  - Sounds/animations: `rbxassetid://0` placeholders with `-- TODO(asset):` (hit sound, emerge sound, swing animation); procedural tween motion while the animation ID is 0
  - Exploit safety: the client only plays visuals. The server counts hits, checks the Pickaxe is equipped, checks distance to the node and rate-limits hits. Only the server's 3rd hit spawns the chest, rolls rarity and wakes the boss
- **Phase 5 "VFX" (branch phase-5-vfx):** the dig and chest moments use 4 KitsBlox VFX packs (`ReplicatedStorage/VFX`) through `VfxPlayer` + `ChestFxPresets`, styled after the reference picture. See [[VFX_Plan]]
  - Replaces the Phase 4 neon light beam, neon halo ring, dust/sparkle emitters and the coin pop; rarity is now a soft glow sprite + light + sparkle aura
  - The mound is pale rock with blue crystals; rock chunks and crystals break off on hits
- **Phase 5 "Mound" (branch phase-5-mound):** the dig mound rebuilt after `docs/References/DirtMound_Ref.png` by `tools/BuildDirtMound.luau`
  - 3 layers of sand-coloured "2022 Stud" blocks (40 parts), 7 loose blocks, 3 Neon ice-blue crystal clusters, the chest's lid out of a gap in the top layer
  - Blocks carry a `DigLayer` attribute: hit 1 knocks off the top layer, hit 2 the middle, hit 3 bursts the rest; the chest rises to the mound's `ChestPose0/1/2` and pops out on hit 3
  - Flying blocks are local copies on scripted arcs (land, then fade in 1s); the server still only counts hits. The full mound grows back when the node respawns
  - The plot chest prompt reads **Search**; opening adds a thin white light beam

## Stage 1: Anime Series 1 (3 Bosses)
- [[Boss_01]]
- [[Boss_02]]
- [[Boss_03]]