-- mod-temucraft-lostlands: the same quest check for the Cataclysm-era quests 14001-28607 (goblin start zone, holidays and
-- test quests from the merged race modpaks): quests that can't be done are hidden with a `disables` row commented
-- 'cata quest check:'. Reasons per quest in `mod_temucraft_cata_quest_check`. Only rows this file made are touched.
-- Remove the file (and run DELETE FROM disables WHERE comment LIKE 'cata quest check:%') to show them again.
-- mod-temucraft-lostlands: hide the quests that can't be done yet. Re-runnable: run it again after you add spawns
-- (for example data/sql/optional/lostlands_spawns_eastern_kingdoms_kalimdor.sql), and the quests that are fine now
-- come back.
--
-- A quest can be done when:
--   - someone gives it: a quest giver creature or object with a spawn, or an item that starts it (startquest) that
--     can be found (loot, vendor, or given by another quest);
--   - someone takes it back: a quest ender creature or object with a spawn;
--   - every creature or object it asks for (RequiredNpcOrGo1-4) has a spawn, is summoned by a SmartAI script or a
--     summon group or a server spell, or gives kill credit through a spawned creature (KillCredit1/2);
--   - every item it asks for (RequiredItemId1-6) can be found: loot of any kind, a vendor, the quest's own start item
--     or source item, another quest's reward, or a server spell that makes it. Only our items (@ITEM_FIRST and up)
--     are checked; stock items are taken as found.
-- The others get a `disables` row (type 1 = quest): they are not shown and can't be picked up. Why each one is
-- hidden is in `mod_temucraft_cata_quest_check` (one row per reason).
-- Not seen by this check: creatures or objects that only a C++ script spawns. If such a quest is hidden, add its ID
-- to @KEEP below.
SET @QUEST := 14001;
SET @QUEST_LAST := 28607;
SET @ITEM_FIRST := 1200000;
SET @KEEP := '';   -- the goblin and worgen start zones come back when phasing is ported: list their quests here then, or drop this file   -- quest IDs never to hide, comma separated, for example '1200012,1200345'

DROP TABLE IF EXISTS `mod_temucraft_cata_quest_check`;
CREATE TABLE `mod_temucraft_cata_quest_check` (
  `ID` int unsigned NOT NULL,
  `Reason` varchar(40) NOT NULL,
  `What` int NOT NULL DEFAULT 0,
  PRIMARY KEY (`ID`, `Reason`, `What`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='mod-temucraft-lostlands: quests hidden because they can not be done yet';

-- creatures that are there: spawned, summoned, or that give kill credit through a spawned creature
DROP TEMPORARY TABLE IF EXISTS `tmp_ll_cre`;
CREATE TEMPORARY TABLE `tmp_ll_cre` (`entry` int unsigned NOT NULL PRIMARY KEY);
INSERT IGNORE INTO `tmp_ll_cre` SELECT `id` FROM `creature` WHERE `id` <> 0;
INSERT IGNORE INTO `tmp_ll_cre` SELECT `action_param1` FROM `smart_scripts` WHERE `action_type` = 12 AND `action_param1` <> 0;
INSERT IGNORE INTO `tmp_ll_cre` SELECT `entry` FROM `creature_summon_groups` WHERE `entry` <> 0;
INSERT IGNORE INTO `tmp_ll_cre` SELECT `EffectMiscValue_1` FROM `spell_dbc` WHERE `Effect_1` IN (28, 41, 42, 56, 112) AND `EffectMiscValue_1` > 0;
INSERT IGNORE INTO `tmp_ll_cre` SELECT `EffectMiscValue_2` FROM `spell_dbc` WHERE `Effect_2` IN (28, 41, 42, 56, 112) AND `EffectMiscValue_2` > 0;
INSERT IGNORE INTO `tmp_ll_cre` SELECT `EffectMiscValue_3` FROM `spell_dbc` WHERE `Effect_3` IN (28, 41, 42, 56, 112) AND `EffectMiscValue_3` > 0;
DROP TEMPORARY TABLE IF EXISTS `tmp_ll_cre2`;
CREATE TEMPORARY TABLE `tmp_ll_cre2` (`entry` int unsigned NOT NULL PRIMARY KEY);
INSERT IGNORE INTO `tmp_ll_cre2` SELECT `entry` FROM `tmp_ll_cre`;
INSERT IGNORE INTO `tmp_ll_cre` SELECT t.`KillCredit1` FROM `creature_template` t JOIN `tmp_ll_cre2` c ON c.`entry` = t.`entry` WHERE t.`KillCredit1` <> 0;
INSERT IGNORE INTO `tmp_ll_cre` SELECT t.`KillCredit2` FROM `creature_template` t JOIN `tmp_ll_cre2` c ON c.`entry` = t.`entry` WHERE t.`KillCredit2` <> 0;
DROP TEMPORARY TABLE `tmp_ll_cre2`;

-- objects that are there: spawned or summoned
DROP TEMPORARY TABLE IF EXISTS `tmp_ll_go`;
CREATE TEMPORARY TABLE `tmp_ll_go` (`entry` int unsigned NOT NULL PRIMARY KEY);
INSERT IGNORE INTO `tmp_ll_go` SELECT `id` FROM `gameobject`;
INSERT IGNORE INTO `tmp_ll_go` SELECT `action_param1` FROM `smart_scripts` WHERE `action_type` = 50 AND `action_param1` <> 0;
INSERT IGNORE INTO `tmp_ll_go` SELECT `EffectMiscValue_1` FROM `spell_dbc` WHERE `Effect_1` IN (50, 76, 104, 105, 106, 107) AND `EffectMiscValue_1` > 0;
INSERT IGNORE INTO `tmp_ll_go` SELECT `EffectMiscValue_2` FROM `spell_dbc` WHERE `Effect_2` IN (50, 76, 104, 105, 106, 107) AND `EffectMiscValue_2` > 0;
INSERT IGNORE INTO `tmp_ll_go` SELECT `EffectMiscValue_3` FROM `spell_dbc` WHERE `Effect_3` IN (50, 76, 104, 105, 106, 107) AND `EffectMiscValue_3` > 0;

-- items that can be found
DROP TEMPORARY TABLE IF EXISTS `tmp_ll_item`;
CREATE TEMPORARY TABLE `tmp_ll_item` (`entry` int unsigned NOT NULL PRIMARY KEY);
INSERT IGNORE INTO `tmp_ll_item` SELECT `Item` FROM `creature_loot_template` WHERE `Reference` = 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `Item` FROM `gameobject_loot_template` WHERE `Reference` = 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `Item` FROM `item_loot_template` WHERE `Reference` = 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `Item` FROM `reference_loot_template` WHERE `Reference` = 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `Item` FROM `pickpocketing_loot_template` WHERE `Reference` = 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `Item` FROM `skinning_loot_template` WHERE `Reference` = 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `Item` FROM `fishing_loot_template` WHERE `Reference` = 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `Item` FROM `disenchant_loot_template` WHERE `Reference` = 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `Item` FROM `prospecting_loot_template` WHERE `Reference` = 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `Item` FROM `milling_loot_template` WHERE `Reference` = 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `Item` FROM `spell_loot_template` WHERE `Reference` = 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `item` FROM `npc_vendor` WHERE `item` > 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `StartItem` FROM `quest_template` WHERE `StartItem` <> 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `ItemDrop1` FROM `quest_template` WHERE `ItemDrop1` <> 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `ItemDrop2` FROM `quest_template` WHERE `ItemDrop2` <> 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `ItemDrop3` FROM `quest_template` WHERE `ItemDrop3` <> 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `ItemDrop4` FROM `quest_template` WHERE `ItemDrop4` <> 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `RewardItem1` FROM `quest_template` WHERE `RewardItem1` <> 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `RewardItem2` FROM `quest_template` WHERE `RewardItem2` <> 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `RewardItem3` FROM `quest_template` WHERE `RewardItem3` <> 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `RewardItem4` FROM `quest_template` WHERE `RewardItem4` <> 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `RewardChoiceItemID1` FROM `quest_template` WHERE `RewardChoiceItemID1` <> 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `RewardChoiceItemID2` FROM `quest_template` WHERE `RewardChoiceItemID2` <> 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `RewardChoiceItemID3` FROM `quest_template` WHERE `RewardChoiceItemID3` <> 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `RewardChoiceItemID4` FROM `quest_template` WHERE `RewardChoiceItemID4` <> 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `RewardChoiceItemID5` FROM `quest_template` WHERE `RewardChoiceItemID5` <> 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `RewardChoiceItemID6` FROM `quest_template` WHERE `RewardChoiceItemID6` <> 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `EffectItemType_1` FROM `spell_dbc` WHERE `Effect_1` IN (24, 59) AND `EffectItemType_1` <> 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `EffectItemType_2` FROM `spell_dbc` WHERE `Effect_2` IN (24, 59) AND `EffectItemType_2` <> 0;
INSERT IGNORE INTO `tmp_ll_item` SELECT `EffectItemType_3` FROM `spell_dbc` WHERE `Effect_3` IN (24, 59) AND `EffectItemType_3` <> 0;
-- stock items are taken as found
INSERT IGNORE INTO `tmp_ll_item` SELECT `entry` FROM `item_template` WHERE `entry` < @ITEM_FIRST;

-- 1. no quest giver
INSERT IGNORE INTO `mod_temucraft_cata_quest_check` (`ID`, `Reason`)
SELECT q.`ID`, 'no quest giver' FROM `quest_template` q
WHERE q.`ID` BETWEEN @QUEST AND @QUEST_LAST
  AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` s JOIN `tmp_ll_cre` c ON c.`entry` = s.`id` WHERE s.`quest` = q.`ID`)
  AND NOT EXISTS (SELECT 1 FROM `gameobject_queststarter` s JOIN `tmp_ll_go` g ON g.`entry` = s.`id` WHERE s.`quest` = q.`ID`)
  AND NOT EXISTS (SELECT 1 FROM `item_template` i JOIN `tmp_ll_item` f ON f.`entry` = i.`entry` WHERE i.`startquest` = q.`ID`);

-- 2. nobody to turn it in to
INSERT IGNORE INTO `mod_temucraft_cata_quest_check` (`ID`, `Reason`)
SELECT q.`ID`, 'no quest ender' FROM `quest_template` q
WHERE q.`ID` BETWEEN @QUEST AND @QUEST_LAST
  AND NOT EXISTS (SELECT 1 FROM `creature_questender` e JOIN `tmp_ll_cre` c ON c.`entry` = e.`id` WHERE e.`quest` = q.`ID`)
  AND NOT EXISTS (SELECT 1 FROM `gameobject_questender` e JOIN `tmp_ll_go` g ON g.`entry` = e.`id` WHERE e.`quest` = q.`ID`);

-- 3. a creature or object it asks for is not there (positive = creature, negative = object)
DROP TEMPORARY TABLE IF EXISTS `tmp_ll_need`;
CREATE TEMPORARY TABLE `tmp_ll_need` (`ID` int unsigned NOT NULL, `What` int NOT NULL);
INSERT INTO `tmp_ll_need` SELECT `ID`, `RequiredNpcOrGo1` FROM `quest_template` WHERE `ID` BETWEEN @QUEST AND @QUEST_LAST AND `RequiredNpcOrGo1` <> 0;
INSERT INTO `tmp_ll_need` SELECT `ID`, `RequiredNpcOrGo2` FROM `quest_template` WHERE `ID` BETWEEN @QUEST AND @QUEST_LAST AND `RequiredNpcOrGo2` <> 0;
INSERT INTO `tmp_ll_need` SELECT `ID`, `RequiredNpcOrGo3` FROM `quest_template` WHERE `ID` BETWEEN @QUEST AND @QUEST_LAST AND `RequiredNpcOrGo3` <> 0;
INSERT INTO `tmp_ll_need` SELECT `ID`, `RequiredNpcOrGo4` FROM `quest_template` WHERE `ID` BETWEEN @QUEST AND @QUEST_LAST AND `RequiredNpcOrGo4` <> 0;
INSERT IGNORE INTO `mod_temucraft_cata_quest_check` (`ID`, `Reason`, `What`)
SELECT n.`ID`, 'target creature not there', n.`What` FROM `tmp_ll_need` n
WHERE n.`What` > 0 AND NOT EXISTS (SELECT 1 FROM `tmp_ll_cre` c WHERE c.`entry` = n.`What`);
INSERT IGNORE INTO `mod_temucraft_cata_quest_check` (`ID`, `Reason`, `What`)
SELECT n.`ID`, 'target object not there', n.`What` FROM `tmp_ll_need` n
WHERE n.`What` < 0 AND NOT EXISTS (SELECT 1 FROM `tmp_ll_go` g WHERE g.`entry` = -n.`What`);
DROP TEMPORARY TABLE `tmp_ll_need`;

-- 4. an item it asks for can't be found
DROP TEMPORARY TABLE IF EXISTS `tmp_ll_need`;
CREATE TEMPORARY TABLE `tmp_ll_need` (`ID` int unsigned NOT NULL, `What` int NOT NULL);
INSERT INTO `tmp_ll_need` SELECT `ID`, `RequiredItemId1` FROM `quest_template` WHERE `ID` BETWEEN @QUEST AND @QUEST_LAST AND `RequiredItemId1` <> 0;
INSERT INTO `tmp_ll_need` SELECT `ID`, `RequiredItemId2` FROM `quest_template` WHERE `ID` BETWEEN @QUEST AND @QUEST_LAST AND `RequiredItemId2` <> 0;
INSERT INTO `tmp_ll_need` SELECT `ID`, `RequiredItemId3` FROM `quest_template` WHERE `ID` BETWEEN @QUEST AND @QUEST_LAST AND `RequiredItemId3` <> 0;
INSERT INTO `tmp_ll_need` SELECT `ID`, `RequiredItemId4` FROM `quest_template` WHERE `ID` BETWEEN @QUEST AND @QUEST_LAST AND `RequiredItemId4` <> 0;
INSERT INTO `tmp_ll_need` SELECT `ID`, `RequiredItemId5` FROM `quest_template` WHERE `ID` BETWEEN @QUEST AND @QUEST_LAST AND `RequiredItemId5` <> 0;
INSERT INTO `tmp_ll_need` SELECT `ID`, `RequiredItemId6` FROM `quest_template` WHERE `ID` BETWEEN @QUEST AND @QUEST_LAST AND `RequiredItemId6` <> 0;
INSERT IGNORE INTO `mod_temucraft_cata_quest_check` (`ID`, `Reason`, `What`)
SELECT n.`ID`, 'item can not be found', n.`What` FROM `tmp_ll_need` n
WHERE NOT EXISTS (SELECT 1 FROM `tmp_ll_item` f WHERE f.`entry` = n.`What`);
DROP TEMPORARY TABLE `tmp_ll_need`;

-- quests kept on purpose
DELETE FROM `mod_temucraft_cata_quest_check` WHERE FIND_IN_SET(`ID`, @KEEP) > 0;

-- hide them (only our own disables rows are touched)
DELETE FROM `disables` WHERE `sourceType` = 1 AND `entry` BETWEEN @QUEST AND @QUEST_LAST AND `comment` LIKE 'cata quest check:%';
INSERT IGNORE INTO `disables` (`sourceType`, `entry`, `flags`, `params_0`, `params_1`, `comment`)
SELECT 1, `ID`, 0, '', '', LEFT(CONCAT('cata quest check: ', GROUP_CONCAT(DISTINCT `Reason` ORDER BY `Reason` SEPARATOR ', ')), 255)
FROM `mod_temucraft_cata_quest_check` GROUP BY `ID`;

DROP TEMPORARY TABLE IF EXISTS `tmp_ll_cre`;
DROP TEMPORARY TABLE IF EXISTS `tmp_ll_go`;
DROP TEMPORARY TABLE IF EXISTS `tmp_ll_item`;

-- See what is hidden and why:
--   SELECT c.`ID`, q.`LogTitle`, c.`Reason`, c.`What` FROM `mod_temucraft_cata_quest_check` c
--   JOIN `quest_template` q ON q.`ID` = c.`ID` ORDER BY c.`ID`;
