"""Lost Lands companion spells: the imported rows use effect 97, which summoned a critter in 1.12 but is CAST_BUTTON in
3.3.5, so they summoned nothing and never showed in the companion tab. A 3.3.5 companion (for example the stock
Bombay Cat 10673) uses effect 28 (summon) with SummonProperties 41 in EffectMiscValueB_1; the target (32) and the
creature in EffectMiscValue_1 were already right. Only rows that summon a Lost Lands creature are changed: 34 rows
(1201623-1201656) point at creatures 37020-37072 that were never imported (in 3.3.5 those ids are Icecrown NPCs), so
they stay as they are until their creatures exist. This sets those two fields in the client rows (patch-R Spell.dbc)
and writes the same change for the server at the end of data/sql/db-world/base/lostlands_dbc.sql. Re-runnable.
usage: python3 tools/fix_companion_spells.py   (from the module folder)"""
import struct

FIRST, LAST = 1200000, 1202189          # Lost Lands spell ids (fixed, same in the client)
F_EFFECT1, F_TARGET1, F_MISC1, F_MISCB1 = 71, 86, 110, 113
CRE_FIRST, CRE_LAST = 1200000, 1205188  # Lost Lands creatures
OLD_EFFECT, NEW_EFFECT, SUMMON_PROPERTIES, TARGET = 97, 28, 41, 32

DBC = 'client/patch-R.MPQ/DBFilesClient/Spell.dbc'
d = bytearray(open(DBC, 'rb').read())
n, fc, rs, ss = struct.unpack('<4I', d[4:20])
def u(o, k): return struct.unpack('<I', d[o + k * 4:o + k * 4 + 4])[0]
def setu(o, k, v): d[o + k * 4:o + k * 4 + 4] = struct.pack('<I', v)
fixed = []
for i in range(n):
    o = 20 + i * rs
    sid = u(o, 0)
    if FIRST <= sid <= LAST and u(o, F_EFFECT1) == OLD_EFFECT and u(o, F_TARGET1) == TARGET and CRE_FIRST <= u(o, F_MISC1) <= CRE_LAST:
        setu(o, F_EFFECT1, NEW_EFFECT); setu(o, F_MISCB1, SUMMON_PROPERTIES); fixed.append(sid)
open(DBC, 'wb').write(bytes(d))

SQL = 'data/sql/db-world/base/lostlands_dbc.sql'
MARK = '-- Companion spells for 3.3.5 (tools/fix_companion_spells.py)'
s = open(SQL, encoding='utf8').read()
if MARK in s:
    s = s[:s.index(MARK)]
s = s.rstrip('\n') + '\n' + MARK + ': effect 97 (critter summon in 1.12, CAST_BUTTON in 3.3.5) becomes\n' + \
    '-- 28 (summon) with SummonProperties 41, like the stock companions, for the ones that summon a Lost Lands creature.\n' + \
    '-- The client rows in patch-R are changed the same way.\n' + \
    'UPDATE `spell_dbc` SET `Effect_1` = %d, `EffectMiscValueB_1` = %d WHERE `ID` BETWEEN %d AND %d AND `Effect_1` = %d AND `ImplicitTargetA_1` = %d\n' % (
        NEW_EFFECT, SUMMON_PROPERTIES, FIRST, LAST, OLD_EFFECT, TARGET) + \
    '  AND `EffectMiscValue_1` BETWEEN %d AND %d;\n' % (CRE_FIRST, CRE_LAST)
open(SQL, 'w', encoding='utf8').write(s)
print('client rows fixed:', len(fixed), '(already fixed rows are not counted)')
if fixed:
    print('ids:', ' '.join(map(str, fixed)))
