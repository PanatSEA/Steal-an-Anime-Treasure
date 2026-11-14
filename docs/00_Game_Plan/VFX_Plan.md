# VFX Plan (Chest & Dig)

Source: 4 KitsBlox VFX packs (particles only, no scripts). Files: `assets/VFX/*.rbxm`.
In Studio they live in **ReplicatedStorage/VFX** with their original names.
Code: `ReplicatedStorage/Shared/VfxPlayer` (plays them) + `ChestFxPresets` (which layers, when, how big; `RarityFx` per rarity), plus `Shared/ChestAura` + `StarterPlayerScripts/ChestAura` for the rarity aura on every chest and `StarterPlayerScripts/Announcements` for server announcements.

Look: styled after the reference picture (a cartoon dig). Each hit shows a pink-white starburst and a big yellow star, with tan rock chips and blue crystals flying. Everything about the chest itself scales with its rarity (reference: `docs/References/Chests_AllRarities_Ref.png`): a faint white Common, a pulsing purple Epic with a short beam, a big gold Legendary with sparkles and a tall beam, a flickering red Secret with dark-red sparks, a beam you can see across the track, slow-motion on the burst and a server-wide announcement.

| Moment | Preset | Layers |
|---|---|---|
| Pickaxe hit 1–2 | DigHit | PBlue Impact356 + Impact550 (pink-white starburst), Frost Star (big yellow star), FistShotVFX_2 Stars (small yellow stars), Shards (tan rock chips) and BALLLSLSLSL2 (dust puffs), Frost shards (blue crystal splinters). Played at the impact point, aimed at the digger. |
| Hit 3: chest bursts out | ChestBurstBase + RarityFx[rarity].Burst (+ EmergeSoundId, the rarity's camera shake) | Every rarity: Frost shards (blue crystals), FistShotVFX_2 Shards (rock chips), BALLLSLSLSL2 (dust), Shockwave1 (ground ring). On top, see "Rarity effects" below |
| Chest lands (dig site and plot) | ChestLand | SplashPuddle Ground (tan dust ring), FistShotVFX_2 BALLLSLSLSL2 (puffs) + Shockwave1 |
| Emerged chest waiting, plot chest timer running | IdleSparkle (loop) | Frost Star twinkles around the chest |
| Timer done, ready to open | ReadyToOpen (loop) | Frost Star twinkles drawn in toward the chest + FistShotVFX_2 Shockwave1 ring pulsing from its base |
| Open with E (Search), about 0.6 s | RarityFx[rarity].Open (+ thin white light beam for OpenBeam rarities, Secret's screen-edge flash), then ChestLand under the character | Chests have no lid. The chest squashes about its centre (scale 1 → 1.15 in 0.1 s → 0 in 0.15 s) and the rarity's opening plays as it collapses (see "Rarity effects"). At 0.25 s the server removes the chest and spawns the character, which pops out of the chest's centre (small, growing to full size), arcs 3 studs up and lands on its slot at about 0.6 s with a ChestLand dust ring |
| Every chest from emerging until it's opened (dig site, carried, on a plot) | RarityFx[rarity] Glow, GemLight, SkyBeam + ChestShimmer (ChestAura) | The rarity's halo behind the chest, its one light on the Gem, its sparkles, its sky beam (not while carried) and a Highlight flash in the glow colour every 3–4 s |
| Untouched mound | MoundTwinkle | Frost Star on a crystal tip every 1.5 s |
| Mound grows back (also when an unpicked chest sinks back after 60 s: it slides into the ground first) | MoundPuff | FistShotVFX_2 BALLLSLSLSL2 dust puffs |

## Rarity colours
`ChestFxPresets.RarityTint`, matching the chests' trims:
- Common: silver-white (220, 225, 235)
- Epic: purple (170, 100, 255)
- Legendary: gold (255, 200, 60)
- Secret: red (255, 40, 40). Red, not pink; it no longer cycles through the rainbow.

IdleSparkle, ReadyToOpen and the openings take `RarityTint[rarity]` on every layer that doesn't set its own tint. The pickaxe hits and the rock breaking keep their own colours: yellow star, blue crystals, tan rock. The Gem turns Neon in the rarity colour (`TreasureModels.ApplyRarityGlow`).

## Rarity effects
All in `ChestFxPresets.RarityFx[rarity]`, tunable per rarity (the file header lists every field).

| | Common | Epic | Legendary | Secret |
|---|---|---|---|---|
| Glow (halo behind the chest) | faint white, slow | purple, slow pulse (2.6 s) | big warm gold + gold sparkles drifting up | red, fast pulse with random flicker + dark-red sparks drifting |
| Gem light (Range) | 6 | 9 | 12 | 14 |
| Sky beam | none | purple, 15 studs | gold, 40 studs | red, 80 studs, visible from any distance |
| Burst on hit 3 | small white flash | purple flash + starburst + glow ring | gold flash, orange-gold rays, golden glow, big star, gold sparks + twinkles | red flash + starburst, double glow ring, double ground ring, red sparks; 0.15 s slow-motion |
| Camera shake (digger) | 0.35 | 0.45 | 0.6 | 1.1 (strong) |
| Opening | small white pop | white flash + purple ring, starburst, rays, sparks, twinkles + light beam | gold burst, big star, gold + white confetti + light beam | red explosion: flash, rays, rings, sparks, dark-red smoke + light beam + red screen-edge flash for the owner |

- **Sky beam:** a Beam from the top of the chest straight up, gently pulsing and fading out at the top. It's on while the chest waits at the dig site or sits on a plot, and off while it's carried or once it's opened. LightEmission is kept low, because additive beams wash out to white against the bright sky.
- **Slow-motion (Secret):** for 0.15 s the burst's particles play at 0.2× speed while the chest and the mound blocks hold still. Then the chest pops out and the blocks fly. The game itself never slows down; it's a visual hold.
- **Screen-edge flash (Secret opening):** four red gradients fade in and out from the screen edges over 0.45 s, for the chest's owner only.
- **Announcement (Secret):** when a Secret chest emerges, the server (TreasureServer) sends "[Player] found a SECRET chest!" to everyone. Clients (Announcements) show it in red, as a chat system message and as a banner at the top of the screen. The client never decides it.

## Chest models and opening
- One model per rarity at `ReplicatedStorage/Models/Treasures/Chests/Chest_<Rarity>` (Chest_Common, Chest_Epic, Chest_Legendary, Chest_Secret): `Base` (PrimaryPart) plus optional `Trim`, and a `Gem`; no lid. References: `docs/References/Chest_Common_Ref.png`, `docs/References/Chests_AllRarities_Ref.png`.
- The chest is picked by the rolled rarity. A missing one falls back to Chest_Common, then to the older `Models/Treasures/Chest`, then to the part-built placeholder in TreasureModels. The buried chest in the mound is Chest_Common, because rarity is rolled on the last hit; on that hit it's swapped for the rarity's model as it bursts out.
- After dropping in a chest model, run `tools/PrepareChests.luau`:
  - It welds everything to Base, unanchors it, turns collisions off, puts the pivot at the bottom centre and sizes it to 3.3 studs wide, the size of the old chest.
  - The imported chests are single meshes with the gem painted on, so it also adds a small `Gem` part over the painted gem (half the chest's height, flush with the front). That part glows Neon in the rarity colour and holds the chest's light.
- Opening timing lives in ChestFx (`SQUASH_*`, `CHARACTER_POP_*`). `AnimeConfig.Chest.OpenAnimationSeconds` (0.25) is how long the server waits before removing the chest and spawning the character. It stamps the character with `PopFrom` (the chest's centre) and `PopAt`, and clients only play the pop for characters stamped in the last 2 s, so characters restored on join just stand there.

## Chest aura
Every chest gets its rarity's aura from the moment it emerges until it's opened. `StarterPlayerScripts/ChestAura` adds it to every model tagged `ChestAura`, and `Shared/ChestAura` builds and animates the pieces; it also works in edit mode for previews.
- **Who tags:** the server tags carried and plot chests in `Carry.MakeTreasure`. DigClient tags the emerged dig-site chest and removes the tag when it's picked up.
- **When it stops:** when the server sets `Opening` (the opening effect takes over) or the chest is removed.
- **Halo:** a BillboardGui with the soft round glow image (PBlue "ring"), not always on top and pushed behind the chest (`HaloBehind`), so the chest stays in front. `HaloScale` is the image size times the chest size, and the glow fills about its middle half. The floor hides the part below the chest's base.
- **Gem light:** the chest's one PointLight, on its Gem, pulsing with the halo.
- **Shimmer:** every 3–4 s (`ChestShimmer.Interval`), a Highlight in the glow colour fades in and out over 0.4 s. It only exists during the flash, because clients can show a limited number of Highlights at once.
- **Pulses:** each chest's pulse starts at a random point, so chests side by side don't pulse in step.

## Performance
- **Distance:** past `ChestAura.CullDistance` (150 studs) from the camera, a chest's glow, gem light, sparkles and beam switch off. The Secret beam is the exception (`AlwaysVisible`), so it stays visible across the track.
- **Caps:** only the nearest `MaxLights` (10) chests light their gem, and the nearest `MaxSparkleChests` (10) run their sparkle loop.
- **Phones and tablets** (`VfxPlayer.IsMobile`: touch, no keyboard):
  - 4 lights and 4 sparkle loops at half rate.
  - Bursts at half the particle count.
  - At most 20 particles per burst emitter and 20 per second per loop, instead of 40.

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
- **Limits:** VfxPlayer caps each burst emitter at 40 particles and each looping emitter at 40 per second (20 and 20 on mobile). It skips bursts more than 300 studs from the camera and preloads all pack textures when a client starts.
