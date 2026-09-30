# The Martyr for Baldur's Gate 3

The Martyr class from *Valda's Spire of Secrets*, playable in Baldur's Gate 3, levels 1 to 12, with all eight Mortal Burdens.

A martyr is a divine champion who pays for magic in blood. Martyrs don't have spell slots: every spell costs hit points, and the gods keep them standing long enough to finish what they were chosen for.

## Requirements

- **A script extender:** [BG3 Script Extender](https://github.com/Norbyte/bg3se) on Windows, or [bg3le](https://github.com/lenonk/bg3le) on native Linux. Much of the class runs in its Lua, including the HP cost of casting. Without an extender the mod loads, but spells cost no HP and many features do nothing.
- **5e Spells** by Celes/DiZ, **loaded before the Martyr**. Some Martyr spells are built on its spells: Gentle Repose, Zone of Truth, Create Food and Water, Dispel Magic, Magic Circle and Intellect Fortress. It isn't declared as a dependency in the mod's metadata, because declaring it made the game disable every mod in the load order, so set the order yourself.

## Installation

1. Install the script extender and 5e Spells.
2. Put `MartyrValdas.pak` in your BG3 `Mods` folder, or install it with your mod manager.
3. Enable it in the load order, after 5e Spells.

## The class

- **Hit points:** d12, 12 + Constitution at 1st level, 7 + Constitution per level after.
- **Proficiencies:** light and medium armour, shields, simple and martial weapons; Strength and Wisdom saving throws; two skills from Athletics, History, Insight, Intimidation, Medicine, Persuasion and Religion.
- **Casting in blood:** from 2nd level the Martyr prepares Wisdom spells from her own list and casts them with Martyr Spell Uses, 2 at 2nd level rising to 10. Each cast also costs hit points: 5 for a 1st-level spell, 10 for 2nd, 20 for 3rd. A spell she can't afford is greyed out, and paying her last hit points downs her. Spells with higher-level versions offer a menu of levels, which unlock at Martyr levels 5 and 9.
- **Healing Magic:** her power comes from suffering, so her healing spells and Balm can't heal herself; only Divine Healing, spending her Hit Dice, does.
- **Features:** Ordained Death (1st); Sainted Reprisal and Mark of the Herald (2nd); Divine Healing and Torment (3rd); Extra Attack (5th); Respite (7th); Undying Conviction (10th); feats at 4th, 8th and 12th.

### Mortal Burdens

Chosen at 1st level. Each brings its own spells at 3rd, 5th and 9th level, a 1st-level feature and a 6th-level feature; some also grant cantrips.

| Burden | Theme | 1st-level feature | 6th-level feature |
|---|---|---|---|
| Atonement | Undo the evils of your past | Heavy armour; Self-Sacrifice | Blooded Reprieve |
| Discord | Spread havoc | Havoc! | Blooded Reprieve |
| The End | Prevent the end of the world | Herald of the End | Sacrosanct Spell |
| Mercy | Heal the sick | Balm | Sacrosanct Spell |
| Rebirth | Protect the wild places | Friend of the Forest | Sacrosanct Spell |
| Revolution | Crush despots | Heavy armour; Bulwark of Rebellion | Blooded Reprieve |
| Truth | Reveal a hidden truth | Moral Erudition; Maxim of Truth | Sacrosanct Spell |
| Tyranny | Rule with an iron fist | Heavy armour; Diabolic Ultimatum | Blooded Reprieve |

### Valda's spells

The Martyr's list includes the book's own spells, each with its own icon: Blood Print, Boomering, Burnt Offering, Curse Ward, Halo of Flame, Indemnify, Instant Replay, Pillar of Salt, Polybrachia, Protection from Ballistics, Snakestaff, Stone Bones and Transient Bulwark.

Snakestaff summons a giant constrictor snake with its own animations, which bites and crushes its prey.

## Differences from the book

BG3 isn't tabletop, so some rules are adapted:

- **Level cap:** BG3 stops at 12, so the 14th- and 18th-level features never arrive, and Martyr spells top out at 3rd level.
- **Missing burden spells:** some don't exist in BG3, so these replace them:
  - Truth gets Faerie Fire, Calm Emotions and Intellect Fortress in place of Identify, Augury and Sending.
  - Tyranny gets Crown of Madness in place of Find Steed.
  - Rebirth gets Blight in place of Speak with Plants, cast as a 3rd-level spell.
  - The End gets its own version of Counterspell, paid for in HP like any Martyr spell.
- **Choices the game can't ask for** are made for you:
  - Sainted Reprisal picks radiant or necrotic damage by the attacker's resistances.
  - Diabolic Ultimatum charms or frightens at random.
  - Undying Conviction always triggers.
- **Herald of the End** becomes: damage dice from your spells never come up 1.
- **Maxim of Truth** becomes an aura that strips invisibility, hiding and illusions from nearby enemies, since Zone of Truth is already on the Martyr's spell list.
- **Balm** heals 1d4 + Wisdom instead of 1 HP, and cleanses Blinded or Poisoned; BG3 has no Deafened.
- **Protection from Ballistics** replaces the book's Protection from Firearms, and covers bows, crossbows, slings, firearms and thrown objects.
- **Snakestaff** doesn't need concentration, like BG3's own creature summons.
- **Moral Erudition** can't make others sense your honesty; there's no mechanic for it.
- **Martyr Spell Uses** refill on a short rest as well as a long one.

## Known issues

- Indemnify's link between caster and target lasts only until you load a save; cast it again after loading.
- Divine Healing counts only Martyr Hit Dice; a multiclassed character's other Hit Dice aren't pooled.
- Martyrs who already passed a level before an update don't receive burden spells added to that level since; respec or level a new Martyr.
- Tested under bg3le on Linux. It uses the standard script extender API, but hasn't been tested under BG3SE on Windows yet.

## Building from source

`Mods/` and `Public/` are the mod. `./build.sh` packs them into `dist/MartyrValdas.pak`, a release-format (v18) package. It needs `dotnet` and a checkout of [LSLib](https://github.com/Norbyte/lslib); `tools/bg3tool` builds against it. [NOTES.md](NOTES.md) explains how each piece is put together.

## Credits

- The Martyr and its spells are from *Valda's Spire of Secrets* by [Mage Hand Press](https://www.magehandpress.com/). This is an unofficial fan adaptation, not affiliated with or endorsed by Mage Hand Press or Larian Studios.
- 5e Spells by Celes/DiZ, which several Martyr spells build on.
- [LSLib](https://github.com/Norbyte/lslib) and the [BG3 Script Extender](https://github.com/Norbyte/bg3se) by Norbyte.
- Baldur's Gate 3 by Larian Studios.
