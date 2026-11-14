# Audio List (SFX)

Workflow per sound: generate in ElevenLabs → download → Studio **Asset Manager → Bulk Import** → copy Asset ID → paste in the SoundId column → tell Claude Code "update sounds from Audio_List".

In code, every id and volume lives in `ReplicatedStorage.Shared.AudioConfig` (same keys as below). Sounds play in 3D at the chest, mound or boss; only SecretAnnounce is 2D for every player. Priority 3 keys are in AudioConfig with `rbxassetid://0` and play nothing until filled in.

Style for every prompt: *cartoon game sound effect, clean, punchy, no music, no voice*. Keep sounds short; long ones overlap badly when many players dig.

## Priority 1: the core loop (do these first)

| Key              | When it plays              | Length  | SoundId                      | ElevenLabs prompt                                                                                                |
| ---------------- | -------------------------- | ------- | ---------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| DigHit           | Pickaxe hits 1–2           | 0.3s    | rbxassetid://79276780678315  | "short cartoon pickaxe hitting packed sand and stone, crunchy thud with a small crystal tink, game sound effect" |
| EmergeSoundId    | Hit 3, chest bursts out    | 2s      | rbxassetid://125649136159228 | ✅ done (Ice magic spell hit)                                                                                     |
| ChestLand        | Chest lands on the sand    | 0.4s    | rbxassetid://91242421295360  | "heavy wooden treasure chest dropping onto sand, soft thump with a metal clank, cartoon game sound"              |
| PickupHold       | While holding E (loops 1s) | 1s loop | rbxassetid://99639233150105  | "rising magical charge-up whoosh, short, building tension, cartoon game sound effect"                            |
| PickupDone       | Chest picked up            | 0.5s    | rbxassetid://96798069357974  | "satisfying cartoon item pickup, bright sparkle chime with a wooden grab, game sound effect"                     |
| WakeUpSoundId    | Boss_01 wakes              | 1.5s    | rbxassetid://78009492285312  | "deep cartoon monster growl waking up angry, stone grinding, short, game sound effect"                           |
| TelegraphSoundId | Boss skill warning circle  | 1.5s    | rbxassetid://123300737699319 | "rising warning hum charging up, magical energy building, ends abruptly, game sound effect"                      |
| SkillHitSoundId  | Boss shockwave lands       | 0.8s    | rbxassetid://96778894932911  | "heavy ground slam shockwave, deep boom with sand debris, cartoon game sound effect"                             |
| ChestDrop        | Player hit, drops chest    | 0.5s    | rbxassetid://139704439924981 | "treasure chest knocked out of hands, wooden clatter and a sad cartoon bonk, game sound effect"                  |

## Priority 2: opening by rarity (rarer = bigger)

| Key             | When it plays                | Length | SoundId                      | ElevenLabs prompt                                                                                                        |
| --------------- | ---------------------------- | ------ | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Open_Common     | Open Common chest            | 0.8s   | rbxassetid://79338530438715  | "small cartoon chest pop, light magical poof with a tiny chime, game sound effect"                                       |
| Open_Epic       | Open Epic chest              | 1.2s   | rbxassetid://75234031266413  | "magical purple energy burst, shimmering whoosh and bright chime, cartoon game sound effect"                             |
| Open_Legendary  | Open Legendary chest         | 1.8s   | rbxassetid://138288384813574 | "epic golden treasure reveal, coins jingling, choir-like shimmer and triumphant sparkle, cartoon game sound effect"      |
| Open_Secret     | Open Secret chest            | 2.5s   | rbxassetid://113798106466533 | "dramatic dark red power explosion, deep bass boom then rising mystical shimmer, intense rare reveal, game sound effect" |
| CharacterAppear | Character lands on plot      | 0.6s   | rbxassetid://123327428401145 | "cartoon character pop-in, bouncy whoosh and landing thud with sparkle, game sound effect"                               |
| SecretAnnounce  | Server message: Secret found | 1.5s   | rbxassetid://80906199019263  | "rare item alert jingle, dramatic short fanfare, mysterious and exciting, game notification sound"                       |

## Priority 3: ambience and polish

| Key            | When it plays          | Length   | SoundId                      | ElevenLabs prompt                                                                  |
| -------------- | ---------------------- | -------- | ---------------------------- | ---------------------------------------------------------------------------------- |
| BeamHum        | Sky beam loop (Epic+)  | 3s loop  | rbxassetid://109788180216976 | "soft magical energy hum loop, gentle shimmering, seamless loop, game ambience"    |
| MoundRespawn   | New mound grows back   | 0.6s     | rbxassetid://71520234795064  | "sand shifting and rising up, soft rumble with a small sparkle, game sound effect" |
| CashTick       | Income added           | 0.2s     | rbxassetid://121758541053378 | "tiny cartoon coin clink, very short, game UI sound"                               |
| SafeZoneEnter  | Enter safe zone        | 0.5s     | rbxassetid://134919952997653 | "calm soft shield chime, relief, short, game sound effect"                         |
| UIClick        | Buttons                | 0.1s     | rbxassetid://95740396502829  | "soft cartoon UI button click, short pop"                                          |
| DesertAmbience | Background on Track_01 | 30s loop | rbxassetid://131963591216655 | "light desert wind ambience with distant sand blowing, calm, seamless loop"        |

## Carry loops (chest on your head, by rarity)

| Key             | When it plays              | Length    | SoundId                      | File (assets/SFX)       |
| --------------- | -------------------------- | --------- | ---------------------------- | ----------------------- |
| Carry_Common    | Carrying a Common chest    | 1.7s loop | rbxassetid://95132538649866  | SFX_Carry_Common.ogg    |
| Carry_Epic      | Carrying an Epic chest     | 1.7s loop | rbxassetid://109004894928009 | SFX_Carry_Epic.ogg      |
| Carry_Legendary | Carrying a Legendary chest | 1.7s loop | rbxassetid://129565902405958 | SFX_Carry_Legendary.ogg |
| Carry_Secret    | Carrying a Secret chest    | 1.7s loop | rbxassetid://96978809939891  | SFX_Carry_Secret.ogg    |

New DigHit (SFX_DigHit.mp3, "One powerful human b..."): replace the DigHit SoundId in Priority 1 after uploading.

## Volume guide
- Big moments (Emerge, Open_Legendary/Secret, SkillHit): 0.6–0.8
- Frequent sounds (DigHit, CashTick, UIClick): 0.3–0.4
- Loops (BeamHum, DesertAmbience, Carry_*): 0.15–0.25
