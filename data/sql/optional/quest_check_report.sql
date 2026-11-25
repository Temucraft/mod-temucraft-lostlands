-- Read-only report: which quests of an ID range can't be done, and why. Changes nothing (temporary tables only).
-- The same tests as data/sql/db-world/base/lostlands_zzz_quest_check.sql (giver, ender, objective creatures and
-- objects), plus what that check does not see: script support. Run it by hand, once per range:
--   14001-28607  Cataclysm goblin start (mod-worgoblin-high-elf F-013, Kezan and the Lost Isles)
--   1200000-1202464  Lost Lands
--   any other range of quests players report
SET @QUEST := 14001;
SET @QUEST_LAST := 28607;

DROP TEMPORARY TABLE IF EXISTS `tmp_qr_cre`;
CREATE TEMPORARY TABLE `tmp_qr_cre` (`entry` int unsigned NOT NULL PRIMARY KEY);
INSERT IGNORE INTO `tmp_qr_cre` SELECT `id` FROM `creature` WHERE `id` <> 0;
INSERT IGNORE INTO `tmp_qr_cre` SELECT `action_param1` FROM `smart_scripts` WHERE `action_type` = 12 AND `action_param1` <> 0;
INSERT IGNORE INTO `tmp_qr_cre` SELECT `entry` FROM `creature_summon_groups` WHERE `entry` <> 0;
INSERT IGNORE INTO `tmp_qr_cre` SELECT `EffectMiscValue_1` FROM `spell_dbc` WHERE `Effect_1` IN (28, 41, 42, 56, 112) AND `EffectMiscValue_1` > 0;
INSERT IGNORE INTO `tmp_qr_cre` SELECT `EffectMiscValue_2` FROM `spell_dbc` WHERE `Effect_2` IN (28, 41, 42, 56, 112) AND `EffectMiscValue_2` > 0;
INSERT IGNORE INTO `tmp_qr_cre` SELECT `EffectMiscValue_3` FROM `spell_dbc` WHERE `Effect_3` IN (28, 41, 42, 56, 112) AND `EffectMiscValue_3` > 0;
DROP TEMPORARY TABLE IF EXISTS `tmp_qr_cre2`;
CREATE TEMPORARY TABLE `tmp_qr_cre2` (`entry` int unsigned NOT NULL PRIMARY KEY);
INSERT IGNORE INTO `tmp_qr_cre2` SELECT `entry` FROM `tmp_qr_cre`;
INSERT IGNORE INTO `tmp_qr_cre` SELECT t.`KillCredit1` FROM `creature_template` t JOIN `tmp_qr_cre2` c ON c.`entry` = t.`entry` WHERE t.`KillCredit1` <> 0;
INSERT IGNORE INTO `tmp_qr_cre` SELECT t.`KillCredit2` FROM `creature_template` t JOIN `tmp_qr_cre2` c ON c.`entry` = t.`entry` WHERE t.`KillCredit2` <> 0;
DROP TEMPORARY TABLE `tmp_qr_cre2`;

DROP TEMPORARY TABLE IF EXISTS `tmp_qr_go`;
CREATE TEMPORARY TABLE `tmp_qr_go` (`entry` int unsigned NOT NULL PRIMARY KEY);
INSERT IGNORE INTO `tmp_qr_go` SELECT `id` FROM `gameobject`;
INSERT IGNORE INTO `tmp_qr_go` SELECT `action_param1` FROM `smart_scripts` WHERE `action_type` = 50 AND `action_param1` <> 0;

DROP TEMPORARY TABLE IF EXISTS `tmp_qr`;
CREATE TEMPORARY TABLE `tmp_qr` (`ID` int unsigned NOT NULL, `Reason` varchar(40) NOT NULL, `What` int NOT NULL DEFAULT 0);

INSERT INTO `tmp_qr` (`ID`, `Reason`)
SELECT q.`ID`, 'no spawned giver' FROM `quest_template` q
WHERE q.`ID` BETWEEN @QUEST AND @QUEST_LAST
  AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` s JOIN `tmp_qr_cre` c ON c.`entry` = s.`id` WHERE s.`quest` = q.`ID`)
  AND NOT EXISTS (SELECT 1 FROM `gameobject_queststarter` s JOIN `tmp_qr_go` g ON g.`entry` = s.`id` WHERE s.`quest` = q.`ID`)
  AND NOT EXISTS (SELECT 1 FROM `item_template` i WHERE i.`startquest` = q.`ID`)
  AND NOT EXISTS (SELECT 1 FROM `quest_template_addon` a WHERE a.`NextQuestID` = q.`ID`)
  AND NOT EXISTS (SELECT 1 FROM `quest_template` p WHERE p.`RewardNextQuest` = q.`ID`);

INSERT INTO `tmp_qr` (`ID`, `Reason`)
SELECT q.`ID`, 'no spawned ender' FROM `quest_template` q
WHERE q.`ID` BETWEEN @QUEST AND @QUEST_LAST
  AND NOT EXISTS (SELECT 1 FROM `creature_questender` e JOIN `tmp_qr_cre` c ON c.`entry` = e.`id` WHERE e.`quest` = q.`ID`)
  AND NOT EXISTS (SELECT 1 FROM `gameobject_questender` e JOIN `tmp_qr_go` g ON g.`entry` = e.`id` WHERE e.`quest` = q.`ID`);

INSERT INTO `tmp_qr` (`ID`, `Reason`, `What`)
SELECT q.`ID`, 'objective not spawned', n.`What`
FROM `quest_template` q
JOIN (SELECT `ID`, `RequiredNpcOrGo1` AS `What` FROM `quest_template` UNION ALL SELECT `ID`, `RequiredNpcOrGo2` FROM `quest_template`
      UNION ALL SELECT `ID`, `RequiredNpcOrGo3` FROM `quest_template` UNION ALL SELECT `ID`, `RequiredNpcOrGo4` FROM `quest_template`) n ON n.`ID` = q.`ID`
WHERE q.`ID` BETWEEN @QUEST AND @QUEST_LAST AND n.`What` <> 0
  AND ((n.`What` > 0 AND NOT EXISTS (SELECT 1 FROM `tmp_qr_cre` c WHERE c.`entry` = n.`What`))
    OR (n.`What` < 0 AND NOT EXISTS (SELECT 1 FROM `tmp_qr_go` g WHERE g.`entry` = -n.`What`)));

-- objectives done by a script (creature/object with a ScriptName and no spawn-side credit): may need C++ the core lacks
INSERT INTO `tmp_qr` (`ID`, `Reason`, `What`)
SELECT q.`ID`, 'objective has ScriptName', t.`entry`
FROM `quest_template` q JOIN `creature_template` t ON t.`entry` IN (q.`RequiredNpcOrGo1`, q.`RequiredNpcOrGo2`, q.`RequiredNpcOrGo3`, q.`RequiredNpcOrGo4`)
WHERE q.`ID` BETWEEN @QUEST AND @QUEST_LAST AND t.`ScriptName` <> '';

-- conditions the stock core ignores (26 = phase, 25 = terrain swap, 27 = graveyard: "don't use on 3.3.5a")
INSERT INTO `tmp_qr` (`ID`, `Reason`, `What`)
SELECT DISTINCT c.`ConditionValue1`, 'phase condition (type 26)', c.`SourceTypeOrReferenceId`
FROM `conditions` c WHERE c.`SourceTypeOrReferenceId` IN (25, 26, 27) AND c.`ConditionTypeOrReference` IN (8, 9, 14, 28, 47)
  AND c.`ConditionValue1` BETWEEN @QUEST AND @QUEST_LAST;

-- 1. counts
SELECT `Reason`, COUNT(DISTINCT `ID`) AS `Quests` FROM `tmp_qr` GROUP BY `Reason`;
SELECT COUNT(*) AS `QuestsInRange`, (SELECT COUNT(DISTINCT `ID`) FROM `tmp_qr` WHERE `Reason` IN ('no spawned giver', 'no spawned ender', 'objective not spawned')) AS `Undoable`
FROM `quest_template` WHERE `ID` BETWEEN @QUEST AND @QUEST_LAST;
-- 2. hidden already (disables type 1)
SELECT COUNT(*) AS `Disabled` FROM `disables` WHERE `sourceType` = 1 AND `entry` BETWEEN @QUEST AND @QUEST_LAST;
-- 3. the list
SELECT r.`ID`, q.`LogTitle`, r.`Reason`, r.`What` FROM `tmp_qr` r JOIN `quest_template` q ON q.`ID` = r.`ID` ORDER BY r.`ID` LIMIT 500;
-- 4. script names on the givers, enders and objectives of the range (compare with "Script named ... does not exist"
--    lines in Server.log / DBErrors.log)
SELECT DISTINCT t.`ScriptName`, t.`AIName` FROM `creature_template` t
WHERE t.`ScriptName` <> '' AND (t.`entry` IN (SELECT `id` FROM `creature_queststarter` WHERE `quest` BETWEEN @QUEST AND @QUEST_LAST)
   OR t.`entry` IN (SELECT `id` FROM `creature_questender` WHERE `quest` BETWEEN @QUEST AND @QUEST_LAST));
-- 5. SmartAI of the range's creatures by event type (the F-013 core patch adds events the stock core rejects)
SELECT s.`event_type`, s.`action_type`, COUNT(*) FROM `smart_scripts` s
WHERE s.`source_type` = 0 AND s.`entryorguid` IN (SELECT `id` FROM `creature_queststarter` WHERE `quest` BETWEEN @QUEST AND @QUEST_LAST)
GROUP BY s.`event_type`, s.`action_type` ORDER BY 3 DESC;
-- 6. are the maps / zones closed by mod-temucraft-zone-access (Temucraft.ZoneAccess.Expansion = 2)?
SELECT * FROM `mod_temucraft_zone_access` WHERE `Expansion` > 2 AND (`OpenDate` IS NULL OR `OpenDate` > NOW());

DROP TEMPORARY TABLE IF EXISTS `tmp_qr`;
DROP TEMPORARY TABLE IF EXISTS `tmp_qr_cre`;
DROP TEMPORARY TABLE IF EXISTS `tmp_qr_go`;
