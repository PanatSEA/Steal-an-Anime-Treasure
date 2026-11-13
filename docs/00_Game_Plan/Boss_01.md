# Boss Spec: Boss_01

## 1. General & Treasure Info
- BossId: "Boss_01"
- DisplayName: "Starter Guardian"
- AnimeSeries: "Series_01"
- Rarity: "Common"
- TreasureName: "Tier 1 Anime Treasure"
- DigTimeSeconds: 3
- IncomePerSecond: 10
- SellPrice: 100

## 2. Wake-Up, Chase & Telegraph Skill (Scales by Rarity/Stage)
- DefaultState: "Sleeping"
- TriggerCondition: "OnDigCompleted"
- WalkSpeed: 18
- ChaseStopInSafeZone: true
- ReturnToSleepSeconds: 8.0
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
- TreasureModelName: "TBD"
- TelegraphColor: "Red"
- DigSoundId: "rbxassetid://0"
- WakeUpSoundId: "rbxassetid://0"
- TelegraphSoundId: "rbxassetid://0"
- SkillHitSoundId: "rbxassetid://0"
- SkillVFXName: "TBD"