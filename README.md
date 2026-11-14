# Steal an Anime Treasure

Roblox game: dig up a treasure outside the SAFE ZONE, carry it home while the
guardian boss chases you and drops telegraphed skills you have to dodge.

Design specs live in the Obsidian vault in [`docs/`](docs/00_Game_Plan/Main_Index.md).

## Phase 1: Core Loop & Boss Telegraph Prototype

- Hold **E** on the dig mound (`ProximityPrompt`, `DigTimeSeconds`) → a placeholder treasure is welded above your head.
- The boss wakes up and chases you (`WalkSpeed`). Every `SkillCooldownSeconds` it drops a red circle on your position; after `TelegraphWarningSeconds` everything inside `SkillRadiusStuds` takes `SkillDamage` and drops the treasure.
- Enter the SAFE ZONE → the boss walks home and goes back to sleep. Stand on any base plot → the treasure is banked (`leaderstats.Treasures`).

## Layout

`src/` mirrors the Studio hierarchy (Rojo-style names) and is the source of truth for scripts:

| File | Studio location |
| --- | --- |
| `src/ReplicatedStorage/Shared/AnimeConfig.lua` | `ReplicatedStorage.Shared.AnimeConfig` (ModuleScript) |
| `src/ServerScriptService/TreasureGame/TreasureServer.server.lua` | `ServerScriptService.TreasureGame.TreasureServer` (Script) |
| `src/ServerScriptService/TreasureGame/*.lua` | ModuleScripts beside it: `BossController`, `SkillPatterns`, `DigService`, `HeldPhysics`, `PlotService`, `PlayerData`, `InventoryService`, `Roll`, `ModelLoader`, `Carry`, `Remotes`, `Zones`, `Sfx` |
| `src/ReplicatedStorage/Shared/TreasureModels.lua` | `ReplicatedStorage.Shared.TreasureModels` (ModuleScript, server + client) |
| `src/ReplicatedStorage/Shared/VfxPlayer.lua` | `ReplicatedStorage.Shared.VfxPlayer` (ModuleScript, client only: plays the VFX packs) |
| `src/ReplicatedStorage/Shared/ChestFxPresets.lua` | `ReplicatedStorage.Shared.ChestFxPresets` (ModuleScript: which pack layers play at each dig/chest moment, and `RarityFx`, every rarity's glow, beam, burst and opening; tune here) |
| `src/ReplicatedStorage/Shared/ChestAura.lua` | `ReplicatedStorage.Shared.ChestAura` (ModuleScript, client only: builds and animates one chest's rarity aura) |
| `assets/VFX/*.rbxm` | The four KitsBlox VFX packs, in Studio as `ReplicatedStorage.VFX.<PBlue\|FistShotVFX_2\|Frost\|SplashPuddle>` |
| `src/StarterPlayer/StarterPlayerScripts/*.client.lua` | LocalScripts: `DigClient` (Pickaxe + dig visuals), `ChestFx` (plot chest effects, opening burst + light beam), `ChestAura` (the rarity aura on every chest tagged `ChestAura`: glow, gem light, sparkles, sky beam, shimmer; distance culling and mobile caps), `Announcements` (server announcements such as a Secret chest, in chat and as a banner), `OwnerOnlyPrompts` |
| `tools/FixPickaxeTool.luau` | Run in the Studio command bar to apply the held-tool physics rules and grip to `StarterPack.Pickaxe` |
| `tools/BuildDirtMound.luau` | Run in the Studio command bar to (re)build `ReplicatedStorage.Models.Treasures.DirtMound`: the 3-layer sand stud-block mound with ice-blue crystals from `docs/References/DirtMound_Ref.png` (never touches the chest) |
| `tools/PrepareChests.luau` | Run in the Studio command bar after dropping chest models into `Models.Treasures.Chests` (`Chest_Common`, `Chest_Epic`, `Chest_Legendary`, `Chest_Secret`) |
| `tools/BuildPhase1World.luau` | Run in the Studio command bar to (re)build `Workspace.TreasureGame` |
| `src/ReplicatedStorage/Assets/Items/CharacterItemDefinitions.lua` | `ReplicatedStorage.Assets.Items.CharacterItemDefinitions`, called by a 2-line hook in the existing `ItemDefinitions` (not in this repo) |

Models are loaded by name from `ReplicatedStorage.Models.Bosses.<BossId>`, `ReplicatedStorage.Models.Characters.<SeriesId>.<CharacterId>`, `ReplicatedStorage.Models.Treasures.Chests.Chest_<Rarity>` and `ReplicatedStorage.Models.Treasures.DirtMound`; missing ones fall back to placeholders (a missing rarity uses `Chest_Common`, then the older `Models.Treasures.Chest`, then the part-built chest in `TreasureModels`). A new chest model: drop it into `Models.Treasures.Chests` as `Chest_<Rarity>`, then run `tools/PrepareChests.luau` (`Base` PrimaryPart plus optional `Trim` welded to it, pivot at the bottom centre, front facing −Z, unanchored, non-colliding, 3.3 studs wide; it adds a `Gem` part over the painted gem if there isn't one). Chests have no lid: opening is a squash, a burst, and the character popping out (ChestFx). Rarity shows in the chest model, its Neon gem and the rarity aura (Common silver-white, Epic purple, Legendary gold, Secret red; see `ChestFxPresets.RarityFx`), never a repaint. A replacement mound needs a `Root` PrimaryPart at ground level, a `DigLayer` attribute on its parts (1 = top layer, knocked off first; the highest layer bursts on the last hit) and `ChestPose0/1/2` CFrame attributes for where the chest sits at each stage; parts named `Crystal` twinkle (see the header of `tools/BuildDirtMound.luau`).

## VFX

The dig and chest effects are particle layers from the four packs in `assets/VFX`, played by `VfxPlayer` from the recipes in `ChestFxPresets` ([VFX plan](docs/00_Game_Plan/VFX_Plan.md)). Studio's insert tools only take Creator Store IDs, so the packs were rebuilt into `ReplicatedStorage.VFX` from the decoded `.rbxm` files with every emitter property and attribute checked. To update a pack, right-click `ReplicatedStorage.VFX` → **Insert from File…**, pick the `.rbxm` and keep its name. Effects tuned in VFX Studio / Effect Designer Suite keep working: `EmitCount`, `EmitDelay` and `EmitDuration` attributes are read.

## Adding Boss_02 / Boss_03

1. Copy the `Boss_01` block in `AnimeConfig.lua`, change the id, and make it harder (higher `WalkSpeed`, lower `TelegraphWarningSeconds` / `SkillCooldownSeconds`, bigger `SkillRadiusStuds`).
2. For a harder skill, add a function to `SkillPatterns.lua` and set `SkillPattern` to its name.
3. Add a dig site under `Workspace.TreasureGame.DigSites` with attribute `BossId` and children `DigMound` + `BossSpawn`.
