"""Martyr: upcast menus for seven spells, and an HP gate on every spell that costs Martyr HP.

Reads the effective levels and inherited RequirementConditions from a runtime dump (martyr_dump.lua, lines "MDS").
"""
import re
import sys
import uuid

MOD = "/home/lenon/bg3mods/Martyr_Valdas_BG3"
SPELLS = MOD + "/Public/MartyrValdas/Stats/Generated/Data/Spell_Martyr.txt"
LOCA = MOD + "/Mods/MartyrValdas/Localization/English/MartyrValdas.xml"
DUMP = sys.argv[1]

COST = {1: 5, 2: 10, 3: 20, 4: 30, 5: 45}          # book p. 117; the Lua charges the same
UNLOCK = {2: 5, 3: 9, 4: 13, 5: 17}                   # Martyr level that can create the slot
HEALING = {"Martyr_CureWounds", "Martyr_HealingWord"}  # free with Sacrosanct Spell
ORD = {1: "1st", 2: "2nd", 3: "3rd"}

# base spell, its level, display name, vanilla entry per higher slot (None: derived from the base here)
UPCAST = [
    ("Martyr_Bless", 1, "Bless", {2: "Target_Bless_2", 3: "Target_Bless_3"}),
    ("Martyr_CureWounds", 1, "Cure Wounds", {2: "Target_CureWounds_2", 3: "Target_CureWounds_3"}),
    ("Martyr_GuidingBolt", 1, "Guiding Bolt", {2: "Projectile_GuildingBolt_2", 3: "Projectile_GuildingBolt_3"}),
    ("Martyr_Heroism", 1, "Heroism", {2: "Target_Heroism_2", 3: "Target_Heroism_3"}),
    ("Martyr_InflictWounds", 1, "Inflict Wounds", {2: "Target_InflictWounds_2", 3: "Target_InflictWounds_3"}),
    ("Martyr_Aid", 2, "Aid", {3: "Shout_Aid_3"}),
    ("Martyr_HaloOfFlame", 2, "Halo of Flame", {3: None}),
]
# The parents' SpellFlags, from Shared.pak (no later pak redefines them).
VANILLA_FLAGS = {
    "Target_Bless": "HasVerbalComponent;HasSomaticComponent;IsConcentration;IsSpell;IgnorePreviouslyPickedEntities",
    "Target_CureWounds": "HasVerbalComponent;IsSpell;HasHighGroundRangeExtension;IsMelee",
    "Projectile_GuidingBolt": "HasSomaticComponent;HasVerbalComponent;IsSpell;HasHighGroundRangeExtension;RangeIgnoreVerticalThreshold;IsHarmful",
    "Target_Heroism": "HasVerbalComponent;HasSomaticComponent;IsConcentration;IsSpell;IsMelee;IgnorePreviouslyPickedEntities",
    "Target_InflictWounds": "HasVerbalComponent;HasSomaticComponent;IsMelee;IsSpell;IsHarmful",
    "Shout_Aid": "HasVerbalComponent;HasSomaticComponent;IsSpell",
    "Shout_ArmsOfHadar": "HasVerbalComponent;HasSomaticComponent;IsSpell;IsHarmful",
}
# Halo of Flame: +1d6 per slot level above 2nd (book p. 342).
HALO_3 = [
    ('SpellSuccess', 'DealDamage(5d6,Fire,Magical)'),
    ('SpellFail', 'DealDamage((5d6)/2,Fire,Magical)'),
    ('TooltipDamageList', 'DealDamage(5d6,Fire)'),
]


def cost(name, level):
    return 5 * level if name.startswith("Martyr_BloodPrint") else COST[level]


def root(name):
    return re.sub(r"_\d$", "", name)


def hp_gate(name, level):
    g = "not HasHPLessThan(%d, context.Source)" % cost(name, level)
    # Sacrosanct Spell: free only at the spell's lowest level (all of these are 1st-level spells).
    if root(name) in HEALING and level == 1:
        g = "(%s or HasPassive('Martyr_SacrosanctSpell', context.Source))" % g
    return g


def conditions(name, level, inherited="", slot_level=None):
    parts = [p for p in (inherited, hp_gate(name, level)) if p]
    if slot_level in UNLOCK:
        parts.append("ClassLevelHigherOrEqualThan(%d,'Martyr')" % UNLOCK[slot_level])
    if len(parts) == 1:
        return parts[0]
    return " and ".join("(%s)" % p if " or " in p or " and " in p else p for p in parts)


def handle(key):
    h = uuid.uuid5(uuid.NAMESPACE_URL, "martyr-upcast/" + key).hex
    return "h%sg%sg%sg%sg%s" % (h[:8], h[8:12], h[12:16], h[16:20], h[20:])


# runtime dump: name -> (level, inherited RequirementConditions)
dump = {}
for line in open(DUMP, encoding="utf-8", errors="replace"):
    m = re.search(r"MDS\t(\S+)\t(\d+)\t\d+\tRC=\[(.*)\]\tparent=", line)
    if m:
        dump[m.group(1)] = (int(m.group(2)), m.group(3))
assert len(dump) > 80, len(dump)

text = open(SPELLS, encoding="utf-8").read()
if "martyr-upcast" in text or "_CureWounds_2\"" in text:
    sys.exit("already applied")

# Split into entry blocks, keeping everything between them.
blocks = re.split(r'(?m)^(?=new entry ")', text)
head, blocks = blocks[0], blocks[1:]
by_name = {}
for i, b in enumerate(blocks):
    by_name[re.match(r'new entry "([^"]+)"', b).group(1)] = i


def set_data(block, key, value):
    body = block.rstrip("\n")
    tail = block[len(body):]
    pat = re.compile(r'(?m)^data "%s" ".*"$' % re.escape(key))
    line = 'data "%s" "%s"' % (key, value)
    if pat.search(body):
        body = pat.sub(lambda _m: line, body)
    else:
        body += "\n" + line
    return body + (tail if tail else "\n")


def data_lines(block):
    return re.findall(r'(?m)^data "([^"]+)" "(.*)"$', block)


loca = []
new_blocks = {}
for base, level, title, variants in UPCAST:
    i = by_name[base]
    b = blocks[i]
    use_costs = dict(data_lines(b))["UseCosts"]
    # Mod-specific overrides the base carries, reapplied on top of vanilla's upcast entries.
    carried = [(k, v) for k, v in data_lines(b) if k not in ("Level", "UseCosts", "ContainerSpells", "RequirementConditions",
                                                              "SpellContainerID", "DisplayName")]
    base_using = re.search(r'(?m)^using "([^"]+)"', b).group(1)
    slots = [level] + sorted(variants)
    children = ["%s_%d" % (base, s) for s in slots]
    b = set_data(b, "ContainerSpells", ";".join(children))
    # Linked, as vanilla's containers are: the base stays in the spellbook and its prepared entries stay in its menu.
    b = set_data(b, "SpellFlags", VANILLA_FLAGS[base_using] + ";IsLinkedSpellContainer")
    blocks[i] = b
    out = []
    for s, child in zip(slots, children):
        name_key = handle(child)
        loca.append((name_key, "%s (%s level)" % (title, ORD[s])))
        # Entries inherit from vanilla, not from the (linked) base, so they keep its flags untouched.
        parent = variants.get(s) or base_using
        lines = ['new entry "%s"' % child, 'type "SpellData"', 'using "%s"' % parent]
        fields = [("Level", str(s)), ("UseCosts", use_costs), ("ContainerSpells", ""), ("SpellContainerID", base),
                  ("DisplayName", name_key + ";1")]
        fields += carried + [("RootSpellID", ""), ("CombatAIOverrideSpell", "")]
        if base == "Martyr_HaloOfFlame" and s == 3:
            fields += HALO_3
        fields.append(("RequirementConditions", conditions(child, s, slot_level=s)))
        merged = {}
        for k, v in fields:  # one line per key, the last value winning
            merged.pop(k, None)
            merged[k] = v
        lines += ['data "%s" "%s"' % kv for kv in merged.items()]
        out.append("\n".join(lines) + "\n")
    new_blocks[i] = out

# The HP gate on every other spell that costs Martyr HP, after what it inherits.
gated = 0
for name, i in by_name.items():
    if name not in dump:
        continue
    lv, inherited = dump[name]
    blocks[i] = set_data(blocks[i], "RequirementConditions", conditions(name, lv, inherited))
    gated += 1

out = head
for i, b in enumerate(blocks):
    out += b
    for nb in new_blocks.get(i, []):
        if not out.endswith("\n\n"):
            out += "\n"
        out += nb
open(SPELLS, "w", encoding="utf-8").write(out)

xml = open(LOCA, encoding="utf-8").read()
add = "".join('  <content contentuid="%s" version="1">%s</content>\n' % (h, t) for h, t in loca)
xml = xml.replace("</contentList>", add + "</contentList>", 1)
open(LOCA, "w", encoding="utf-8").write(xml)
print("gated", gated, "spells; added", len(loca), "menu entries")
