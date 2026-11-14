# Boss Spec: Boss_01

## 1. General & Treasure Info
- BossId: "Boss_01"
- DisplayName: "Starter Guardian"
- AnimeSeries: "Series_01"
- Rarity: "Common"
- TreasureName: "Tier 1 Anime Treasure"
- DigHitsRequired: 3 (Pickaxe hits; replaces DigTimeSeconds)

## 2. Wake-Up, Chase & Telegraph Skill (Scales by Rarity/Stage)
- DefaultState: "Sleeping"
- TriggerCondition: "OnChestPickedUp" (after hit 3 the chest lands by the mound and the boss stays asleep; it wakes when someone picks the chest up)
- PickupKey: "E"
- PickupHoldSeconds: 1.0 (anyone within about 8 studs can pick it up, not only the digger; untouched for 60s, it sinks back and the mound respawns)
- WalkSpeed: 18
- ChaseStopInSafeZone: true
- ReturnToSleepSeconds: 5.0
- SkillPattern: "CircleTelegraph"
- SkillCooldownSeconds: 3.5
- TelegraphWarningSeconds: 1.5
- SkillRadiusStuds: 18
- SkillDamage: 25
- DropTreasureOnHit: true

## 3. Scaling Rule for Higher Bosses (Boss_02, Boss_03+)
- Higher Rarity = Higher WalkSpeed + Shorter TelegraphWarningSeconds + Larger/Multi-hit SkillPattern

## 4. Assets, VFX & SFX (ElevenLabs / Studio)
- BossModelName: "TBD"
- TreasureModelName: "TBD" (loads ReplicatedStorage/Models/Treasures/Chest)
- TelegraphColor: "Red"
- Sounds: see [[Audio_List]] (keys DigHit, EmergeSoundId, WakeUpSoundId, TelegraphSoundId, SkillHitSoundId, ...). The ids live in code in `ReplicatedStorage.Shared.AudioConfig`.
- SkillVFXName: "TBD"

## 5. Chest Opening
- OpensInto: "[[Series_01_Characters]]"
- OpenKey: "E"
- OpenTimeSeconds: 2
- RarityWeights: Common 700, Epic 250, Legendary 45, Secret 5 (rolled when the dig completes)