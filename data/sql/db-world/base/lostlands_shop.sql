-- mod-temucraft-lostlands: shop companions and illusion toys on models we already have (sold by the Temucraft Curator,
-- see mod-temucraft-shop). Spell rows: lostlands_shop_dbc.sql (made by tools/build_shop_extras.py, client rows in
-- patch-R). The illusion forms and the collection rows are at the end of lostlands_features.sql (that file clears those
-- tables). Re-runnable.
--   Companions (collection type 2, learned account-wide): items 610200-610204, spells 96700-96704, creatures 608980-608984
--   Illusion toys (Vanity window, "Costumes"): items 610205-610207, spells 96705-96707
SET @ITEM := 610200; SET @SPELL := 96700; SET @PET := 608980;

DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN @PET AND @PET+4;
DELETE FROM `creature_template` WHERE `entry` BETWEEN @PET AND @PET+4;
INSERT INTO `creature_template` (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `unit_class`, `unit_flags`, `unit_flags2`, `type`, `flags_extra`) VALUES
(@PET+0, 'Corgi Pup', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET+1, 'Cloud Serpent Hatchling', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET+2, 'Kobold Pip', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET+3, 'Wee Nefarian', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET+4, 'Willowisp', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2);
-- Corgi: the Lost Lands corgi (creature 1205154, displays 1200529-1200530); serpent: our black cloud serpent, small;
-- kobold: stock Kobold Miner look, small; Nefarian: stock Nefarian, very small; wisp: stock Wisp.
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`) VALUES
(@PET+0, 0, 1200529, 1, 1), (@PET+0, 1, 1200530, 1, 1),
(@PET+1, 0, 1200023, 0.3, 1),
(@PET+2, 0, 373, 0.6, 1),
(@PET+3, 0, 11380, 0.08, 1),
(@PET+4, 0, 10045, 0.8, 1);

DELETE FROM `item_template` WHERE `entry` BETWEEN @ITEM AND @ITEM+7;
INSERT INTO `item_template` (`entry`, `class`, `subclass`, `SoundOverrideSubclass`, `name`, `displayid`, `Quality`, `Flags`, `BuyCount`, `BuyPrice`, `SellPrice`, `InventoryType`, `ItemLevel`, `maxcount`, `stackable`, `spellid_1`, `spelltrigger_1`, `spellcharges_1`, `spellcooldown_1`, `spellcategorycooldown_1`, `spellid_2`, `spelltrigger_2`, `spellcooldown_2`, `spellcategorycooldown_2`, `bonding`, `description`, `Material`) VALUES
(@ITEM+0, 15, 2, -1, 'Corgi Pup', 20629, 3, 64, 1, 0, 0, 0, 20, 1, 1, 55884, 0, -1, -1, -1, @SPELL+0, 6, -1, -1, 1, 'Teaches you how to summon this companion.', 4),
(@ITEM+1, 15, 2, -1, 'Cloud Serpent Hatchling', 18050, 3, 64, 1, 0, 0, 0, 20, 1, 1, 55884, 0, -1, -1, -1, @SPELL+1, 6, -1, -1, 1, 'Teaches you how to summon this companion.', 4),
(@ITEM+2, 15, 2, -1, 'Kobold Pip', 1119, 3, 64, 1, 0, 0, 0, 20, 1, 1, 55884, 0, -1, -1, -1, @SPELL+2, 6, -1, -1, 1, 'Teaches you how to summon this companion.', 4),
(@ITEM+3, 15, 2, -1, 'Wee Nefarian', 31434, 3, 64, 1, 0, 0, 0, 20, 1, 1, 55884, 0, -1, -1, -1, @SPELL+3, 6, -1, -1, 1, 'Teaches you how to summon this companion.', 4),
(@ITEM+4, 15, 2, -1, 'Willowisp', 3109, 3, 64, 1, 0, 0, 0, 20, 1, 1, 55884, 0, -1, -1, -1, @SPELL+4, 6, -1, -1, 1, 'Teaches you how to summon this companion.', 4),
(@ITEM+5, 15, 0, -1, 'Tuskarr Fisherman''s Horn', 956, 3, 0, 1, 0, 0, 0, 1, 1, 1, @SPELL+5, 0, 0, 1500, -1, 0, 0, -1, -1, 1, 'Blow it to look like a tuskarr fisher. Use again, mount up or fight to drop it.', 4),
(@ITEM+6, 15, 0, -1, 'Coin of Familiar Faces', 37780, 3, 0, 1, 0, 0, 0, 1, 1, 1, @SPELL+6, 0, 0, 1500, -1, 0, 0, -1, -1, 1, 'Flip it to wear a famous face of Azeroth. Use again, mount up or fight to drop it.', 4),
(@ITEM+7, 15, 0, -1, 'Tome of Disguise: Imp', 918, 3, 0, 1, 0, 0, 0, 1, 1, 1, @SPELL+7, 0, 0, 1500, -1, 0, 0, -1, -1, 1, 'Read it to look like an imp. Use again, mount up or fight to drop it.', 4);

CREATE TABLE IF NOT EXISTS `mod_temucraft_vanity_item` (
  `item` int unsigned NOT NULL COMMENT 'item_template.entry',
  `category` varchar(32) NOT NULL DEFAULT '' COMMENT 'heading in the Vanity window',
  `sort` smallint unsigned NOT NULL DEFAULT 0 COMMENT 'order inside its heading',
  PRIMARY KEY (`item`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Temucraft: vanity items (account collections)';
DELETE FROM `mod_temucraft_vanity_item` WHERE `item` BETWEEN @ITEM+5 AND @ITEM+7;
INSERT INTO `mod_temucraft_vanity_item` (`item`, `category`, `sort`) VALUES
(@ITEM+5, 'Costumes', 20), (@ITEM+6, 'Costumes', 21), (@ITEM+7, 'Costumes', 22);
