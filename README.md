# mod-temucraft-lostlands

The **Lost Lands**: built from the open 1.18.1 world database (all its merged fixes, plus a few data fixes from open pull requests), a large set of extra creatures, objects, items and quests for 3.3.5a, with their models, spells
and loot, plus a few scripted features. It fills the new maps (Karazhan Crypt, Crescent Grove, Hateforge Quarry, Gilneas City, Dragonmaw Retreat, Stormwrought Ruins, Timbermaw Hold,
Windhorn Canyon, Frostmane Hollow, the Emerald Sanctum and the rest of the extra maps) and adds content across
Eastern Kingdoms and Kalimdor.

Independent: it needs no other Temucraft module. The extra maps themselves (terrain) are a client patch of their own,
see "Maps" below.

## What it adds

| Database | Table | Rows | IDs |
|---|---|---|---|
| world | `creature_template` (+ `_model`, `_resistance`, `_spell`, `_addon`, `_movement`), `creature_equip_template` | 5187 creatures | `@CRE` = 1200000 and up |
| world | `trainer`, `trainer_spell`, `creature_default_trainer` | 137 trainers | trainer ID = creature ID |
| world | `gameobject_template` (+ `_addon`) | 12125 objects | `@GO` = 1200000 and up |
| world | `item_template`, `item_loot_template` | 8814 items | **1200000-1208813, fixed** (the client's Item.dbc has the same IDs) |
| world | `quest_template` (+ `_addon`, `quest_offer_reward`, `quest_request_items`), quest starters/enders | 2465 quests | `@QUEST` = 1200000 and up |
| world | `creature`, `creature_addon`, `waypoint_data`, `gameobject` | 4973 creatures, 1666 objects | `@GUID_CRE`, `@GUID_GO` = 5000000 and up |
| world | `creature_loot_template`, `gameobject_loot_template`, `pickpocketing_`, `skinning_`, `disenchant_`, `reference_loot_template` | 202216 rows | `@LOOT...` = 1200000 and up |
| world | `npc_vendor` | 7102 items for sale | on the Lost Lands creatures |
| world | `gossip_menu`, `gossip_menu_option`, `npc_text`, `page_text` | | `@GOSSIP`, `@TEXT`, `@PAGE` = 1200000 and up |
| world | `spell_dbc` | 2189 spells | **1200000-1202189, fixed** |
| world | `creaturedisplayinfo_dbc`, `creaturedisplayinfoextra_dbc`, `creaturemodeldata_dbc`, `itemdisplayinfo_dbc`, `gameobjectdisplayinfo_dbc`, `item_dbc` | models | displays 1200000 and up, model data 45000-45004, **fixed** |
| world | `faction_dbc`, `factiontemplate_dbc` | 23 factions, 51 templates | factions 2300-2322, templates 3000-3050, **fixed** |
| world | `mod_temucraft_lostlands_*` | feature data | see below |
| characters | `mod_temucraft_account_collection` (kind 10) | per account | |
| world | `creature_template` (stock) | 301 stock creatures get the quest giver flag | they give or take a Lost Lands quest |

Client DBC rows (same IDs): `Spell`, `SpellIcon` (3300000-3300069), `Item`, `ItemDisplayInfo`, `CreatureDisplayInfo`,
`CreatureDisplayInfoExtra`, `CreatureModelData`, `GameObjectDisplayInfo`, `Faction`, `FactionTemplate`.

**Fixed IDs** are in the DBCs too, so the server SQL and the client patch must agree: don't move them in one only.
Everything marked with an `@` variable is server-only: change the `SET` at the top of each SQL file to move it (keep
the same value in every file). Spells that summon or transform into Lost Lands creatures or objects use the default
IDs, so keep `@CRE` and `@GO` at 1200000 if you want those spells to keep working.

## Scripted features

| Feature | Table (world) | Rows | Config |
|---|---|---|---|
| Illusion toys: cast to turn into a random form for your gender; cast again, mount or fight to drop it | `mod_temucraft_lostlands_illusion` | 132 forms for 36 toys | `Temucraft.LostLands.Illusions` |
| Account-wide collections: toys, mounts and companions taught by these items are learned by every character of the account | `mod_temucraft_lostlands_collection` | 721 items | `Temucraft.LostLands.AccountWideCollections` |
| Per-spawn object size | `mod_temucraft_lostlands_spawn_scale` | 13 | `Temucraft.LostLands.SpawnScale` |
| Quest objectives done by hitting a player of a class (or a game master) with a spell | `mod_temucraft_lostlands_quest_cast` | 9 | `Temucraft.LostLands.CastObjectives` |
| Auras removed when entering a map (world buffs in raids) | `mod_temucraft_lostlands_map_aura_removal` | 178 | `Temucraft.LostLands.MapAuraRemoval` |

`.temucraft lostlands reload` (administrator) re-reads these tables.

## Scripted creatures and objects

Script names are set in the SQL; the data each script uses is in its own table (world DB), so IDs can move freely.

| Script | On | What it does | Table |
|---|---|---|---|
| `npc_temucraft_lostlands_caster` | 958 creatures with spells | Casts its `creature_template_spell` spells in combat: heals hurt allies, buffs itself, the rest on its target or someone in range | |
| `npc_temucraft_lostlands_race_manager` | Daisy (stock 4507), Dolores | **Mirage Raceway**: sign up for your quest's team, countdown, racecars, 28 checkpoints, speed boosts and exploding sheep on the track, quest credit for finishing and an extra quest for the winner | `mod_temucraft_lostlands_race`, `_race_checkpoint`, `_race_pool` |
| `npc_temucraft_lostlands_race_sheep` | the track's sheep | Slows the racer that runs into it, then explodes | |
| `npc_temucraft_lostlands_rental` | 11 mounts (some stock: rams 4710/4779, kodos 12354/12355) | Rent the mount for 50 copper | `mod_temucraft_lostlands_rental` |
| `npc_temucraft_lostlands_teleporter` | the arena ambassadors | Takes you to the Gurubashi Arena | `mod_temucraft_lostlands_teleporter` |
| `npc_temucraft_lostlands_token_vendor` | the arena's coin vendor | Buffs for Bloody Coins | `mod_temucraft_lostlands_token_vendor` |
| `npc_training_dummy` (AzerothCore's) | 4 training dummies | Never dies, never fights back | |
| `go_temucraft_lostlands_rest` | survival tents, the Bright Campfire (stock 31511) | Rested experience builds while you stand close (`Temucraft.LostLands.RestRadius`, `RestRate`) | |
| `go_temucraft_lostlands_planter`, `_grow`, `_grow_care` | the planter and plants | **Gardening**: plant pumpkin, berry, watermelon or mushroom seeds; the plant needs Un'Goro Soil, then Refreshing Spring Water twice, growing in between; the last stage is the harvest | `mod_temucraft_lostlands_garden_seed`, `_garden_stage` |
| `go_temucraft_lostlands_explore` | 6 quest markers | Reaching them completes a quest objective | `mod_temucraft_lostlands_explore` |

Not carried over: scripts for places that only exist on the reference server's own version of Eastern Kingdoms and
Kalimdor (its portals, guild houses and most of its zone scripts), boss and event scripts, and anything tied to its
shop or anticheat.

## Install

1. Put this folder in `modules/` of your AzerothCore source, re-run CMake and build.
2. The SQL in `data/sql/db-world/base/` and `data/sql/db-characters/base/` is applied by the worldserver on its next
   start. Every file deletes its own rows before inserting them, so running one again is safe.
   Copy `conf/mod-temucraft-lostlands.conf.dist` to `configs/modules/mod-temucraft-lostlands.conf` to change settings.
3. **Client.** `client/patch-R.MPQ/` is a patch folder, not a packed MPQ: pack it yourself (keep the paths) and put the
   `.MPQ` in the game's `Data/` folder. It holds the DBCs above (stock 3.3.5a + this module) and the textures and
   buildings the new displays need. Using other Temucraft modules or DBC changes? Two patches with the same DBC
   overwrite each other: use the all-in-one patch from the Temucraft configuration repo, or merge the rows.
4. Re-extract **vmaps** if you want the new objects to have collision (the vmap extractor reads GameObjectDisplayInfo).

`data/sql/optional/` is **not** run automatically:
- `lostlands_spawns_eastern_kingdoms_kalimdor.sql`: 16825 creatures and 19149 objects on Eastern Kingdoms and Kalimdor.
  They were placed on a different version of those continents than Open Azeroth's, so in the new zones many will
  float or sit underground. Run it if you want them, then check them in game.

## Maps

The spawns in `lostlands_spawns.sql` are on the extra maps (800-817, 26, 27 and Azshara Crater as 803). Those maps are
the `extra-maps` client patch and need map, vmap and mmap extraction; without them the spawns simply never load.

## Known gaps

- 231 creature displays use retail models that are not in the client. Each points at the closest stock model
  (a mount uses a similar mount, a boss a similar creature), scaled up where the stand-in is a small critter, so
  nothing is invisible. Listed in `data/lostlands_standin_models.txt`; swap in a real downported model when you have one.
- About 1,540 objects have no model in the source data either (invisible markers and triggers); roughly 70 others are
  real gaps and stay invisible. Some items show no model when worn.
- Creature AI scripts are not converted one by one: creatures with spells use the generic caster above.
- Three objectives of "The Icy Menace" needed specific players of the original server: that quest can't be finished.
- Stats were converted from flat values to AzerothCore's modifiers (health, mana, armor, damage), so numbers are close
  but not exact.

## Texts and translations

The 12 player-facing texts (chat messages, gossip options) are in the `module_string` table under the module name
`mod-temucraft-lostlands`, so they can be changed without rebuilding. Translations go in `module_string_locale` with the same
module and id plus the locale (`deDE`, `esES`, `frFR`, ...). If a row is missing the English text in the code is used.

## Entering the dungeons and raids

`lostlands_map_difficulty.sql` adds `mapdifficulty_dbc` rows for the 15 instance maps (normal and heroic for the
dungeons; 10/25 normal and heroic, or a single 20- or 40-player mode, for the raids). Without a MapDifficulty row the
core refuses to let anyone in.
