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
| `src/ReplicatedStorage/Shared/ChestFxPresets.lua` | `ReplicatedStorage.Shared.ChestFxPresets` (ModuleScript: which pack layers play at each dig/chest moment; tune here) |
| `assets/VFX/*.rbxm` | The four KitsBlox VFX packs, in Studio as `ReplicatedStorage.VFX.<PBlue\|FistShotVFX_2\|Frost\|SplashPuddle>` |
| `src/StarterPlayer/StarterPlayerScripts/*.client.lua` | LocalScripts: `DigClient` (Pickaxe + dig visuals), `ChestFx` (plot chest effects, opening burst + light beam), `OwnerOnlyPrompts` |
| `tools/FixPickaxeTool.luau` | Run in the Studio command bar to apply the held-tool physics rules and grip to `StarterPack.Pickaxe` |
| `tools/BuildPhase4Models.luau` | Run in the Studio command bar to (re)build `ReplicatedStorage.Models.Treasures.DirtMound`, the pale rock mound with blue crystals (never touches the chest) |
| `tools/PrepareChestModel.luau` | Run in the Studio command bar after dropping in a new `Models.Treasures.Chest` |
| `tools/BuildPhase1World.luau` | Run in the Studio command bar to (re)build `Workspace.TreasureGame` |
| `src/ReplicatedStorage/Assets/Items/CharacterItemDefinitions.lua` | `ReplicatedStorage.Assets.Items.CharacterItemDefinitions`, called by a 2-line hook in the existing `ItemDefinitions` (not in this repo) |

Models are loaded by name from `ReplicatedStorage.Models.Bosses.<BossId>`, `ReplicatedStorage.Models.Characters.<SeriesId>.<CharacterId>` and `ReplicatedStorage.Models.Treasures.<Chest|DirtMound>`; missing ones fall back to placeholders (the part-built chest lives in `TreasureModels`). A new chest model: drop it in, then run `tools/PrepareChestModel.luau` (Root PrimaryPart with the pivot at the bottom centre, front facing −Z, everything welded and non-colliding, 3.3 studs wide). An optional `Lid` model pivoted on its back hinge opens with a lid animation; a single-mesh chest opens with a burst. Rarity is a glow (soft glow sprite, light, sparkle aura: Common white, Epic purple, Legendary gold, Secret rainbow), never a repaint. A replacement mound needs a `Root` PrimaryPart at ground level; parts named `Chunk` or `Crystal` break off on hits.

## VFX

The dig and chest effects are particle layers from the four packs in `assets/VFX`, played by `VfxPlayer` from the recipes in `ChestFxPresets` ([VFX plan](docs/00_Game_Plan/VFX_Plan.md)). Studio's insert tools only take Creator Store IDs, so the packs were rebuilt into `ReplicatedStorage.VFX` from the decoded `.rbxm` files with every emitter property and attribute checked. To update a pack, right-click `ReplicatedStorage.VFX` → **Insert from File…**, pick the `.rbxm` and keep its name. Effects tuned in VFX Studio / Effect Designer Suite keep working: `EmitCount`, `EmitDelay` and `EmitDuration` attributes are read.

## Adding Boss_02 / Boss_03

1. Copy the `Boss_01` block in `AnimeConfig.lua`, change the id, and make it harder (higher `WalkSpeed`, lower `TelegraphWarningSeconds` / `SkillCooldownSeconds`, bigger `SkillRadiusStuds`).
2. For a harder skill, add a function to `SkillPatterns.lua` and set `SkillPattern` to its name.
3. Add a dig site under `Workspace.TreasureGame.DigSites` with attribute `BossId` and children `DigMound` + `BossSpawn`.
