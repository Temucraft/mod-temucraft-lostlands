"""Lost Lands shop extras: the spell rows of the new companions (copies of the stock Bombay Cat 10673 that summon our
creatures) and of the new illusion toys (a self cast with no effect of its own: the module's illusion code gives the
look). Writes the rows into client/patch-R.MPQ Spell.dbc and data/sql/db-world/base/lostlands_shop_dbc.sql (server
spell_dbc). Re-runnable.
usage: python3 tools/build_shop_extras.py   (from the module folder)"""
import re, struct

# spell id, name, description, icon (SpellIcon id), creature entry (companions) or 0 (illusion toys)
COMPANIONS = [
    (96700, 'Corgi Pup', 'Right Click to summon and dismiss your corgi.', 1573, 608980),
    (96701, 'Cloud Serpent Hatchling', 'Right Click to summon and dismiss your cloud serpent.', 1589, 608981),
    (96702, 'Kobold Pip', 'Right Click to summon and dismiss your kobold. You no take candle!', 1522, 608982),
    (96703, 'Wee Nefarian', 'Right Click to summon and dismiss your wee Nefarian.', 1699, 608983),
    (96704, 'Willowisp', 'Right Click to summon and dismiss your wisp.', 117, 608984),
]
ILLUSIONS = [
    (96705, "Tuskarr Fisherman's Horn", 'Turns you into a tuskarr. Use again to drop it.', 3702),
    (96706, 'Coin of Familiar Faces', 'Gives you a famous face of Azeroth. Use again to drop it.', 2801),
    (96707, 'Tome of Disguise: Imp', 'Turns you into an imp. Use again to drop it.', 215),
]
F_ID, F_EFFECT, F_TARGET, F_AURA, F_MISC, F_VISUAL, F_ICON, F_NAME, F_SUB, F_DESC, F_AURADESC = 0, 71, 86, 95, 110, 131, 133, 136, 153, 170, 187
STRING_FIELDS = set(range(136, 204))
SIGNED = set('''ID unk_320_2 unk_320_3 PowerType Reagent_1 Reagent_2 Reagent_3 Reagent_4 Reagent_5 Reagent_6 Reagent_7 Reagent_8
ReagentCount_1 ReagentCount_2 ReagentCount_3 ReagentCount_4 ReagentCount_5 ReagentCount_6 ReagentCount_7 ReagentCount_8
EquippedItemClass EquippedItemSubclass EquippedItemInvTypes EffectDieSides_1 EffectDieSides_2 EffectDieSides_3
EffectBasePoints_1 EffectBasePoints_2 EffectBasePoints_3 EffectMiscValue_1 EffectMiscValue_2 EffectMiscValue_3
EffectMiscValueB_1 EffectMiscValueB_2 EffectMiscValueB_3 RequiredAreasID PowerDisplayID'''.split())   # signed int columns of spell_dbc
FIRST, LAST = 96700, 96709

DBC = 'client/patch-R.MPQ/DBFilesClient/Spell.dbc'
d = bytearray(open(DBC, 'rb').read())
n, fc, rs, ss = struct.unpack('<4I', d[4:20])
rows = [bytearray(d[20 + i * rs:20 + (i + 1) * rs]) for i in range(n)]
strings = bytearray(d[20 + n * rs:])
def u(r, i): return struct.unpack('<I', r[i * 4:i * 4 + 4])[0]
def setu(r, i, v): r[i * 4:i * 4 + 4] = struct.pack('<I', v)
def s_at(o): return strings[o:strings.index(b'\0', o)].decode('latin1')
def add_str(t):
    o = len(strings); strings.extend(t.encode('latin1') + b'\0'); return o
rows = [r for r in rows if not FIRST <= u(r, 0) <= LAST]
by_id = {u(r, 0): k for k, r in enumerate(rows)}
companion_base = rows[by_id[10673]]   # Bombay Cat: summon (28), SummonProperties 41
illusion_base = rows[by_id[1200911]]  # Illusion: Ghoul (our toy look)
out_rows = []
def texts(r, name, desc, sub=''):
    for f in range(136, 204): setu(r, f, 0)
    setu(r, F_NAME, add_str(name)); setu(r, F_DESC, add_str(desc))
    if sub: setu(r, F_SUB, add_str(sub))
    for f in (152, 169, 186, 203): setu(r, f, 0xFFFFFE)   # locale masks
for sid, name, desc, icon, creature in COMPANIONS:
    r = bytearray(companion_base)
    setu(r, F_ID, sid); setu(r, F_MISC, creature); setu(r, F_ICON, icon)
    texts(r, name, desc)
    rows.append(r); out_rows.append(r)
for sid, name, desc, icon in ILLUSIONS:
    r = bytearray(illusion_base)
    setu(r, F_ID, sid); setu(r, F_EFFECT, 3); setu(r, F_AURA, 0); setu(r, F_MISC, 0); setu(r, F_ICON, icon)
    texts(r, name, desc, 'Toy')
    rows.append(r); out_rows.append(r)
rows.sort(key=lambda r: u(r, 0))
hdr = struct.pack('<4s4I', b'WDBC', len(rows), fc, rs, len(strings))
open(DBC, 'wb').write(hdr + b''.join(rows) + bytes(strings))

# server rows: column names and number types from the Lost Lands spell rows in lostlands_dbc.sql
src = open('data/sql/db-world/base/lostlands_dbc.sql').read()
i = src.index('INSERT INTO `spell_dbc` (')
cols = re.findall(r'`(\w+)`', src[i + 25:src.index(') VALUES', i)])
j = src.index('\n(1200911,', i)
vals = re.findall(r"'(?:[^'\\]|\\.|'')*'|[^,()\n]+", src[j + 2:src.index('\n', j + 1)].rstrip(',;)'))
assert len(cols) == fc == len(vals), (len(cols), len(vals))
def sqlval(r, f):
    if f in STRING_FIELDS and vals[f].startswith("'"):
        v = u(r, f)
        return "'" + (s_at(v) if v else '').replace("'", "''") + "'"
    if '.' in vals[f]:
        x = round(struct.unpack('<f', r[f * 4:f * 4 + 4])[0], 6)
        return repr(x)
    v = u(r, f)
    return str(v - (1 << 32) if v >= 1 << 31 and cols[f] in SIGNED else v)
lines = ['-- mod-temucraft-lostlands: spell rows of the shop companions (96700-96704) and illusion toys (96705-96707).',
         '-- Made by tools/build_shop_extras.py; the client rows are in client/patch-R.MPQ Spell.dbc.',
         'DELETE FROM `spell_dbc` WHERE `ID` BETWEEN %d AND %d;' % (FIRST, LAST),
         'INSERT INTO `spell_dbc` (' + ', '.join('`%s`' % c for c in cols) + ') VALUES']
lines.append(',\n'.join('(' + ','.join(sqlval(r, f) for f in range(fc)) + ')' for r in out_rows) + ';')
open('data/sql/db-world/base/lostlands_shop_dbc.sql', 'w').write('\n'.join(lines) + '\n')
print('ok', len(out_rows))
