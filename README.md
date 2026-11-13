# Steal an Anime Treasure

Roblox game: dig up a treasure outside the SAFE ZONE, carry it home while the
guardian boss chases you and drops telegraphed skills you have to dodge.

Design specs live in the Obsidian vault in [`Test/`](Test/Main_Index.md).

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
| `src/ServerScriptService/TreasureGame/*.lua` | ModuleScripts beside it: `BossController`, `SkillPatterns`, `Carry`, `Zones`, `Sfx` |
| `tools/BuildPhase1World.luau` | Run in the Studio command bar to (re)build `Workspace.TreasureGame` |

## Adding Boss_02 / Boss_03

1. Copy the `Boss_01` block in `AnimeConfig.lua`, change the id, and make it harder (higher `WalkSpeed`, lower `TelegraphWarningSeconds` / `SkillCooldownSeconds`, bigger `SkillRadiusStuds`).
2. For a harder skill, add a function to `SkillPatterns.lua` and set `SkillPattern` to its name.
3. Add a dig site under `Workspace.TreasureGame.DigSites` with attribute `BossId` and children `DigMound` + `BossSpawn`.
