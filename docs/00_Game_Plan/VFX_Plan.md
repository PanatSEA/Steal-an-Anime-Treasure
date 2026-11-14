# VFX Plan (Chest & Dig)

Source: 4 KitsBlox VFX packs (particles only, no scripts). Files: `assets/VFX/*.rbxm`.
In Studio they live in **ReplicatedStorage/VFX** with their original names.
Code: `ReplicatedStorage/Shared/VfxPlayer` (plays them) + `ChestFxPresets` (which layers, when, how big), plus `StarterPlayerScripts/ChestGoldAura` for the gold aura on every chest.

Look: styled after the reference picture (a cartoon dig). Each hit shows a pink-white starburst and a big yellow star, with tan rock chips and blue crystals flying. On hit 3 the chest bursts out with golden rays and glow. Opening shows a thin white light beam, cyan cubes and sparkles.

| Moment | Preset | Layers |
|---|---|---|
| Pickaxe hit 1–2 | DigHit | PBlue Impact356 + Impact550 (pink-white starburst), Frost Star (big yellow star), FistShotVFX_2 Stars (small yellow stars), Shards (tan rock chips) and BALLLSLSLSL2 (dust puffs), Frost shards (blue crystal splinters). Played at the impact point, aimed at the digger. |
| Hit 3: chest bursts out | ChestBurst (+ EmergeSoundId) | FistShotVFX_2 GlowImpact (white flash), PBlue Impact356 (pink-white starburst), Impact550 (orange-gold rays), ring (golden glow), RedFire2 (gold sparks), Frost Star (big yellow star) and shards, FistShotVFX_2 Shards (rock chips), BALLLSLSLSL2 (dust), Shockwave1 (ground ring) |
| Chest lands (dig site and plot) | ChestLand | SplashPuddle Ground (tan dust ring), FistShotVFX_2 BALLLSLSLSL2 (puffs) + Shockwave1 |
| Emerged chest waiting, plot chest timer running | IdleSparkle (loop) | Frost Star twinkles around the chest |
| Timer done, ready to open | ReadyToOpen (loop) | Frost Star twinkles drawn in toward the chest + FistShotVFX_2 Shockwave1 ring pulsing from its base |
| Open with E (Search) | ChestOpen (+ thin white light beam in ChestFx) | GlowImpact (white flash), PBlue ring, Impact356, Impact550, RedFire2 + Frost Star (rarity colour), FistShotVFX_2 Shards (cyan cubes), Frost Star (white twinkles) |
| Every chest from emerging until it's opened (dig site, carried, on a plot) | GoldAura + GoldShimmer (ChestGoldAura) | Soft golden halo behind the chest (BillboardGui, PBlue "ring" image, pulsing in size and transparency every 1.5 s), one warm gold PointLight pulsing with it, Frost Star sparkles drifting up (gold, low rate), and a gold Highlight flash over the chest every 3–4 s |
| Untouched mound | MoundTwinkle | Frost Star on a crystal tip every 1.5 s |
| Mound grows back | MoundPuff | FistShotVFX_2 BALLLSLSLSL2 dust puffs |

## Rarity tint
- Common: ice white-blue
- Epic: purple
- Legendary: gold
- Secret: hot pink

ChestOpen and the two loops take `RarityTint[rarity]` on every layer that doesn't set its own tint. The hit and burst effects keep their own colours: yellow star, gold rays, blue crystals. The chest's rarity aura (TreasureModels, a slow sparkle aura) uses the game's rarity colours, and Secret cycles through the rainbow. The gold aura's halo, light and shimmer are always gold, whatever the rarity.

## Gold aura
Every chest sits in a warm golden glow from the moment it emerges until it's opened. `ChestGoldAura` (a LocalScript) adds it to every model tagged `GoldAura`: the server tags carried and plot chests in `Carry.MakeTreasure`, DigClient tags the emerged dig-site chest and removes the tag when it's picked up. The aura stops when the server sets `Opening` (ChestOpen takes over) or the chest is removed.
- **Halo:** a BillboardGui with the soft round glow image, not always on top and pushed behind the chest (`HaloBehind`), so the chest stays in front. The image is `HaloScale` (3.4) times the chest's size because the glow only fills about its middle half; the visible glow is about 1.8x the chest. The floor hides the part of the halo below the chest's base.
- **Light:** one PointLight per chest (Color 255,200,80, Range 12), pulsing between `LightBrightness.Low` and `.Peak` with the halo. The rarity glow no longer adds its own light or glow sprite.
- **Sparkles:** Frost Star, tinted gold, about 2.5 a second, drifting up around the chest.
- **Shimmer:** every 3–4 s (`GoldShimmer.Interval`), a gold Highlight fades in and out over 0.4 s. It only exists during the flash, because clients can show a limited number of Highlights at once.
- **Cost:** chests further than `CullDistance` (120 studs) from the camera switch the halo, light and sparkles off, and they come back when you're near again. Each chest's pulse starts at a random point, so chests side by side don't pulse in step.
- Tune `ChestFxPresets.GoldAura` and `ChestFxPresets.GoldShimmer`: colours, sizes, pulse speed, rates and the cull distance.

## What the pack emitters look like
Use this list when picking layers.
- **PBlue:**
  - Impact550 and Impact21: radial spike rings (starbursts).
  - Impact356: starburst on a black background.
  - Flash: 4-point star on a black background.
  - RedFire2: 4-point star sparks.
  - ring: soft round glow.
  - Firework: small sparkle flipbook.
- **FistShotVFX_2:**
  - GlowImpact: soft round glow.
  - Stars: 4-point star.
  - Shards: rounded chunks.
  - BALLLSLSLSL, BALLLSLSLSL2 and BALLLSLSLSL3: cartoon smoke puffs.
  - Shockwave1 and Shockwave2: glowing rings.
  - Wind, Wind2 and Wind3: crescent swirls.
  - WaterImpact and WaterImpactR: splash bits.
- **Frost:**
  - Star: crisp 4-point star.
  - Snow: big snowflake.
  - BrightBlueSharpShard and BrightBlueDiolveShard: blue crystal shards.
  - Debree and DebreeOut: tiny specks.
  - Air* layers: air puffs.
  - *Fire layers: blue wisps.
- **SplashPuddle (blue water):**
  - Ground: splash ring.
  - Splash: a thin ring and a blotch.
  - Smoke: soft smoke.
  - Drops: dots.

Flash and Impact356 have black backgrounds. Keep their LightEmission at 1 (additive), or they show as black squares.

## Tuning
Change `scale`, `countMul`, `delay` and `props` in ChestFxPresets.
- **Scale:** `scale` multiplies size, speed, acceleration, ZOffset and attachment offsets. The packs differ a lot in size. PBlue layers sit at about 0.1–0.27, while FistShotVFX_2 and Frost sit at about 0.2–1.
- **Aim:** bursts play at a CFrame whose LookVector is the main direction: toward the digger for hits, up for the chest. Each pack fires toward its own face, so each layer has a `rotation`; the TOP, BACK and LEFT constants are in the file.
- **On bright sand:**
  - Keep Brightness around 1.5 on coloured layers. The packs' values (5–25) wash colours out to white.
  - Use ZOffset to draw flashes in front of the rock and chest.
  - Use `size = POINT` so FistShotVFX_2 and Frost emit from a point, not their whole holder box.
- **Loops** follow the chest's own axes (Y = up). `anchor = "part"` puts a layer at the chest's base.
- **Limits:** VfxPlayer caps each burst emitter at 40 particles and each looping emitter at 40 per second. It skips bursts more than 300 studs from the camera and preloads all pack textures when a client starts.
