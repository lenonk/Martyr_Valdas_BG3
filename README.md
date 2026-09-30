# Martyr — Valda's Spire of Secrets (BG3 / BG3LE)

**Alpha 0.1** — generated specifically for Lenon's native Linux BG3 + BG3LE setup.

This source implements the Martyr as a level 1–12 BG3 class with all eight Mortal Burdens from the supplied copy of *Valda's Spire of Secrets*.

## Implemented now
- d12 / 12+CON start and 7+CON per level, STR/WIS saves, light/medium armour, shields, simple/martial weapons.
- Mortal Burden selection at level 1: Atonement, Discord, End, Mercy, Rebirth, Revolution, Truth, Tyranny.
- Martyr Spell Uses progression: 2 / 3 / 6 / 7 / 9 / 10 at the book's levels; refreshes on a short or long rest, like Warlock slots. It is a plain pool: BG3's upcast picker only reads real spell slots, so spells with levels to choose from use a menu (like Wild Shape or Command) whose entries unlock with Martyr level.
- Martyr spell clones consume one Martyr Spell Use and BG3LE Lua charges HP: 5 / 10 / 20 for spell levels 1 / 2 / 3.
- A spell can't be cast without its HP price: each has `RequirementConditions` `not HasHPLessThan(cost, context.Source)` (Sacrosanct Spell exempts spells whose sole effect is restoring hit points: Cure Wounds at any level and Healing Word). Paying the last HP downs her: the Lua holds her at 1 HP until the cast ends (`CastedSpell`), then sets 0 with `Osi.SetHitpoints`, since the engine downs no one mid-cast and a written `Health.Hp` doesn't down at all. The hotbar re-checks those requirements only when an action resource changes, so on every `HitpointsChanged` the Lua flips a hidden resource, `MartyrHotbarTick` (granted by Ordained Death), and unaffordable spells grey out.
- Upcasting: Bless, Cure Wounds, Guiding Bolt, Heroism and Inflict Wounds (1st) and Aid and Halo of Flame (2nd) are linked menus (`IsLinkedSpellContainer`, as vanilla's) with one entry per slot level, `<spell>_<level>`, built on vanilla's upcast entries (Halo of Flame: 5d6 at 3rd). 2nd- and 3rd-level entries need Martyr 5 and 9. Generated once by `tools/martyr_upcast.py` from a `tools/martyr_dump.lua` run.
- Wisdom spellcasting and prepared-caster class wiring.
- Extra Attack at level 5; feats at 4/8/12.
- Torment at level 3: the level-up screen shows one *Torment* feature; the Lua adds its two toggles (on level-up and load, since a passive can't grant passives), in one toggle group like Great Weapon Master's, *Torment: Radiant* and *Torment: Necrotic*. Once per turn a melee weapon hit deals +10 of that type; the Lua takes the 5 HP when the hidden MARTYR_TORMENTED status lands, and Blooded Reprieve refunds it if the hit killed a hostile creature. From 11th level it's 10 HP for +20, automatically. The HP comes off Health directly, so it never prompts a concentration save.
- Undying Conviction, built as vanilla's Relentless Endurance: the passive keeps `MARTYR_UNDYING` on her (applied on creation and each long rest, and by the Lua for older saves), whose `DownedStatus(MARTYR_UNDYING_DOWNED,5)` outranks Ordained Death's; that status spends it and `RegainHitPoints(1,Guaranteed)` stands her up at 1 HP.
- Burden actives/passives: Heavy Armour, Balm, Bulwark of Rebellion, Maxim of Truth, Diabolic Ultimatum, Friend of the Forest, Sacrosanct Spell / Blooded Reprieve flags.
- Class spell list added to the spellbook for preparing, one spell level at a time: 1st at level 2, 2nd at 5, 3rd at 9.
- Burden spells at 3/5/9 wherever BG3 has the spell, and the "one more cleric (or druid) cantrip" choice at level 1.
- Starting equipment (`EQP_CC_Martyr`): longsword, shield, scale mail, light crossbow, plus the usual potions, scroll and camp kit.
- Class and burden icons for character creation (`Public/Game/GUI/Assets/ClassIcons`).
- Character-creation defaults like vanilla classes have: the +2/+1 ability bonus selector, recommended scores (Str 14, Dex 12, Con 15, Int 8, Wis 14, Cha 8, bonus to Con and Wis), default skills and burden cantrips, and a multiclass level-1 entry (light/medium armour, shields, simple/martial weapons).
- Spell icons from `art/spell_icons` (all 13 of the book's spells; the unused two are kept for later), with their painted backgrounds.
- Class feature icons from `art/feature_icons`, in their own atlas (`Martyr_Features_Icons`): round for passives. The squares for Divine Healing and Final Martyrdom and the round March Unto Destiny wait there for when those become actions or are implemented.
- `Progressions/ProgressionDescriptions.lsx` describes the class's own boosts against its table: without it character creation lists none of the class proficiencies (a mod class doesn't get the base game's generic descriptions).
- Burden spells and cantrips are granted as `AddSpells(list,MartyrBurdenSpells,,,AlwaysPrepared)`, as vanilla subclasses do; `UnlockSpell` grants were invisible in character creation. The `MartyrBurdenSpells` selector has a ProgressionDescription (like Paladin's `OathSpells`), which gives them a "Burden Spells" heading on the level-up screen instead of "Spells".
- Martyr Spell Uses has its own resource icon (a blood drop, from `art/resource_icons`), found by the resource's name under `Mods/MartyrValdas/GUI/Assets` (CC, panel states and controller copies). Textures there need `GUI/metadata.lsx` (path as .png, w, h, mipcount), which the build converts to `.lsf`; without it the game reports missing texture metadata at start.
- The build converts `Public/MartyrValdas/Content/**/*.lsx` to `.lsf`: the game only reads content banks (the icon atlases' textures) as LSF, and without them every Martyr icon was blank.
- Custom 16-icon gothic red/gold icon atlas plus 144px and 380px UI assets.

## Valda's spells
Ten of the book's thirteen original spells, on the class list at their book levels, with icons recoloured from BG3's own:

| Spell | Level | In BG3 |
|---|---|---|
| Boomering | 1–3 | Radiant ranged spell attack, as a menu: 1st (3d6), 2nd (4d6, Martyr 5), 3rd (5d6 against two different targets, Martyr 9). The retry on a miss is played as advantage, which at 3rd only the first target gets (`MARTYR_BOOMERING_FIRST` marks it done). The ricochet's 30 ft from the first target isn't enforced |
| Burnt Offering | 1 | Out of combat; until long rest, +max(0, Wis − Dex) AC, added by the Lua (ignores medium armour's Dex cap) |
| Indemnify | 1 | Bonus action, Con save, concentration; 1d8 radiant to the target whenever you lose HP (Lua) |
| Instant Replay | 1 | Bonus action; advantage on your next attack within 10 turns |
| Blood Print | 1–5 | 9 m, Wis save (a Bleeding target fails); until long rest the target can't turn invisible, heavily obscured doesn't give you Disadvantage against it, and once per turn you deal +Nd4 Radiant to it. A menu of levels; 2nd–5th unlock at Martyr 5/9/13/17 (progression `UnlockSpell` boosts, which the level-up screen doesn't list); 5 HP per spell level |
| Transient Bulwark | 1 | +10 AC against the next 3 attacks (three statuses, chained by the Lua, but not while a long rest ends them); Shield's bubble, recoloured red and gold |
| Curse Ward | 2 | Touch; necrotic resistance, immune to curses and possession, until long rest |
| Halo of Flame | 2 | 3m around you, Dex save, 4d6 fire (half on a save), enemies only |
| Stone Bones | 2 | Bonus action; resistance to non-magical B/P/S until the end of the target's next turn |
| Protection from Ballistics | 2 | Touch, concentration; ranged weapon attacks (bows, crossbows, slings, firearms) and thrown objects have disadvantage against the target and deal it half damage. Replaces the book's *Protection from Firearms*; the bubble is Transient Bulwark's, recoloured green |
| Pillar of Salt | 3 | 3m burst, Con save, 7d6 necrotic (half on a save); also Revolution's 9th-level burden spell |
| Polybrachia | 3 | Touch, concentration; advantage on Athletics and a bonus-action melee attack |

**Requires 5e Spells.** The 2nd-level list includes *Gentle Repose* and *Zone of Truth*, and the 3rd-level list *Create Food and Water*, *Dispel Magic* and *Magic Circle*, and Truth's 9th-level *Intellect Fortress*, from that mod (Martyr copies inheriting its spells), so load 5e Spells before the Martyr. It isn't declared in `meta.lsx`: declaring it there made the game drop every mod from the load order. They can't be optional: the level-up reads the spell lists before any mod script runs, and a list entry whose spell doesn't exist yet is dropped.

*Snakestaff* summons a giant constrictor snake: the vanilla viper's model on our own template (`RootTemplates`), scaled up by a status, with the 5e snake's numbers (AC 12, 60 HP, Str 19), a bite and a constrict. Constrict grapples and restrains one creature at a time and crushes it again (2d8+4) at the start of each of its turns; the victim escapes with an action and a DC 16 Athletics or Acrobatics check, and the grapple ends if the snake moves away. Up to an hour, without concentration: BG3 dropped it from its creature summons, so the snake follows suit.

The viper is scenery in the base game and has almost no animations, so the snake has its own, made in Blender (`Assets/Characters/_Anims/Snakestaff`, banked in `Content/Assets/Characters/[PAK]_Snakestaff`): combat stance, bite, hit reaction, slither transitions and a coil round its constrict victim. The viper's head is a separate model on its own skeleton, which the game didn't keep in step with the body, so the snake wears our copy of the head mesh re-skinned onto the body skeleton (`Assets/Characters/Snakestaff_Head`), through our copies of the head visual and the character visual. The jaw no longer moves.

Not implemented: *Tongues* (3rd; not in BG3 or 5e Spells).

## Alpha caveats / things to test in BG3LE
1. Undying Conviction is automatic; the book lets the Martyr choose whether to drop to 1 HP.
2. Divine Healing counts only Martyr Hit Dice (one d12 per Martyr level); a multiclass character's other classes' dice aren't pooled yet.
3. Sainted Reprisal (`Interrupt_Martyr_SaintedReprisal`, like Hellish Rebuke) picks the damage type itself, since BG3 reactions can only ask yes or no. It uses Radiant unless the attacker is immune to it, reflects it (Radiant Retort, Raphael's Blessing), or resists it but not Necrotic; then it uses Necrotic. It isn't offered at all when neither type would land.
4. Burden spells BG3 doesn't have are left out: identify, augury, sending, speak with plants, find steed. Truth gets *faerie fire* (3rd), *calm emotions* (5th) and *intellect fortress* (9th) in place of identify, augury and sending. Tyranny gets *crown of madness* (5th) in place of find steed. Rebirth gets *blight* at 9th in place of speak with plants, cast as a 3rd-level spell (20 HP) though it's 4th-level in the book, since BG3's level cap stops Martyr spells at 3rd. Counterspell (End, 9th) is a reaction, and a reaction's cost lives on its interrupt, so the Martyr has her own: `Martyr_Counterspell` → `Interrupt_Martyr_Counterspell`, costing a reaction and a Martyr Spell Use, offered only with 20 HP to pay, which the Lua takes (via `MARTYR_COUNTERSPELL_PAID`) whether or not the counter lands.
5. Divine Healing's healing range lives in `TooltipDamageList`, like Cure Wounds': a bonus in DescriptionParams is printed after the range instead of added (2~246), and `2*ConstitutionModifier` evaluates as 2 + the modifier, so each entry adds `ConstitutionModifier` once per die.
6. Moral Erudition (Truth) adds `Skill(Persuasion, WisdomModifier-CharismaModifier)` under `IF(AbilityGreaterThan('Wisdom', context.Source.Charisma, context.Source))`, so Persuasion uses whichever modifier is higher; sensing truthfulness has no BG3 mechanic.
   - Herald of the End (End) is replaced for BG3: `Martyr_HeraldOfTheEnd` rerolls a spell damage die that comes up 1, and a second 1 counts as 2 (`Reroll(Damage,1,true)` then `MinimumRollResult(Damage,2)`, as Great Weapon Fighting and Elemental Adept do).
   - Havoc! (Discord) is done: the hidden `Martyr_HavocTrigger` marks an enemy hit with a melee weapon and readies the `Shout_Martyr_Havoc` button for that turn (free, once per short rest). The Lua then rolls a d10 on the book's table, with 1 changed to Shield on the target, 3 to Indemnify on it and 9 to a Fireball explosion at a random spot 6–15 m away.
7. Self-Sacrifice (Atonement) keeps the original attack roll and makes no second attack. One reaction (`Interrupt_Martyr_SelfSacrifice`), offered only when an enemy's attack hits an ally within 2 m; its two outcomes are `IF()`s that test the same roll against the Martyr's AC (`IsFlatValueInterruptInteresting(k)`, k = Martyr AC - ally AC, which the Lua keeps on nearby allies as `MARTYR_SS_D<k>`). Would hit: the ally's 999 temporary-HP ward soaks the hit and the Lua deals each amount and type to the Martyr. Would miss: the roll is forced to miss. Once per short or long rest (`MartyrSelfSacrifice`).
8. Indemnify's links live in Lua memory, so after loading a save it only triggers for casts made since.
9. Balm (Mercy) heals 1d4 + Wisdom instead of the book's 1 HP, and not the Martyr herself (Healing Magic covers the class's healing features too), and its cleanse ends Blinded or Poisoned (BG3 has no Deafened). The two are children of one linked container (`Target_Martyr_Balm`), sharing its once-per-short-rest cooldown.
10. Burnt Offering switches the worn armour's AC ability (`Armor.ArmorClassAbility`) from Dexterity to Wisdom while the status lasts, so the armour's cap (+2 for medium) still applies and the tooltip reads "from Wisdom"; with no body armour it's `ACOverrideFormula(10,true,Wisdom)`, and heavy armour adds no ability to swap. The Lua redoes the swap when armour changes and after a load, and undoes it when the status ends.
11. Maxim of Truth (Truth) is redesigned, since Truth already has zone of truth: for 10 turns a 3 m aura (`MARTYR_MAXIM_TRUTH`) gives enemies `MARTYR_MAXIM_EXPOSED`, which removes and blocks invisibility (SG_Invisible, and any other INVISIBLE-type status via the Lua), hiding (SNEAKING), Blur, Mirror Image and the Cloak of Displacement. Once per short rest.
12. Diabolic Ultimatum (Tyranny) is one spell (`Target_Martyr_Ultimatum`): on a failed Wisdom save the Lua flips a coin between `MARTYR_ULTIMATUM_CHARMED` and `MARTYR_ULTIMATUM_FRIGHTENED` (10 turns, a Wisdom save at the end of each of the target's turns), since the book's "target's choice" is one the AI can't make.
13. Bulwark of Rebellion (Revolution): the Lua rolls 1d10 + level and applies `MARTYR_BULWARK_<n>` (`TemporaryHP(n)`, one per amount up to 22), keeping the higher of the new roll and what Bulwark has left, so a recast always refreshes the duration and never lowers the temporary HP. They share vanilla's `TEMPORARY_HP` stack, so another source's larger temporary HP is left alone.

## Build / install
`Mods/` and `Public/` are the mod; only those two go into the package, a release-format (v18) pak written by `tools/bg3tool pack`:

```bash
./build.sh      # writes dist/MartyrValdas.pak
./deploy.sh     # builds, then copies it into the BG3 Mods folder
```

Enable it in the load order after the mod is deployed.

Edit only `MartyrValdas.xml` for text: the build regenerates `MartyrValdas.loca` from it with `tools/bg3tool`, which builds against the LSLib checkout in `~/Projects/bg3mm` (override with `-p:LSLibProject=...`) and needs `dotnet`.

## BG3LE smoke tests (one-line console commands)
After loading a Martyr save:

```lua
print(Ext.Stats.Get("Martyr_Boomering") and "Martyr stats loaded" or "NO MARTYR STATS")
```

```lua
for _,s in ipairs({'Martyr_OrdainedDeath', 'Martyr_Torment', 'Martyr_Undying'}) do print(s,Osi.HasPassive(Osi.GetHostCharacter(),s)) end
```

```lua
print("Martyr Spell Uses resource defined:",Ext.StaticData.Get("3148272e-c001-52f9-9017-db78ce5a9f91","ActionResource")~=nil)
```

## Design note
The tabletop class prepares `Wisdom modifier + floor(Martyr level / 2)` spells. This source sets up a prepared-caster spell list, but BG3's spellbook/resource coupling is something we need to validate in the native extender. If BG3 insists on slot resources for the preparation UI, the fallback is a custom prepared-spell selector while retaining MartyrSpellUses as the actual cast resource.
