-- mod-temucraft-lostlands: shop companions and illusion toys on models we already have (sold by the Temucraft Curator,
-- see mod-temucraft-shop). Spell rows: lostlands_shop_dbc.sql (made by tools/build_shop_extras.py, client rows in
-- patch-R). The illusion forms and the collection rows are at the end of lostlands_features.sql (that file clears those
-- tables). Re-runnable.
--   Companions (collection type 2, learned account-wide): items 610200-610204 and 610208, spells 1260000-1260004 and 1260008,
--   creatures 608980-608985
--   Illusion toys (Vanity window, "Costumes"): items 610205-610207, spells 1260005-1260007
SET @ITEM := 610200; SET @SPELL := 1260000; SET @PET := 608980;

DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN @PET AND @PET+5;
DELETE FROM `creature_template` WHERE `entry` BETWEEN @PET AND @PET+5;
INSERT INTO `creature_template` (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `unit_class`, `unit_flags`, `unit_flags2`, `type`, `flags_extra`) VALUES
(@PET+0, 'Corgi Pup', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET+1, 'Cloud Serpent Hatchling', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET+2, 'Kobold Pip', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET+3, 'Wee Nefarian', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET+4, 'Willowisp', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET+5, 'Coco', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2);
-- Corgi: the Lost Lands corgi (creature 1205154, displays 1200529-1200530); serpent: our black cloud serpent, small;
-- kobold: stock Kobold Miner look, small; Nefarian: stock Nefarian, very small; wisp: stock Wisp;
-- Coco: the stock dog look (display 10209, the "Dog" NPC 10582).
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`) VALUES
(@PET+0, 0, 1200529, 1, 1), (@PET+0, 1, 1200530, 1, 1),
(@PET+1, 0, 1200023, 0.3, 1),
(@PET+2, 0, 373, 0.6, 1),
(@PET+3, 0, 11380, 0.08, 1),
(@PET+4, 0, 10045, 0.8, 1),
(@PET+5, 0, 10209, 1, 1);

-- The 34 Lost Lands companions whose creatures were never imported (spells 1201623-1201656 pointed at 37020-37072,
-- Icecrown NPCs in 3.3.5). Made here on stock models of the same kind; tools/fix_companion_spells.py points the
-- spells at them (client patch-R and the UPDATE at the end of lostlands_dbc.sql).
SET @PET2 := 1205189;
DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN @PET2 AND @PET2+33;
DELETE FROM `creature_template` WHERE `entry` BETWEEN @PET2 AND @PET2+33;
INSERT INTO `creature_template` (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `unit_class`, `unit_flags`, `unit_flags2`, `type`, `flags_extra`) VALUES
(@PET2+0, 'Son of Mergothid', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+1, 'Swamp Crocolisk Hatchling', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+2, 'Marsh Crocolisk Hatchling', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+3, 'Dust Crocolisk Hatchling', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+4, 'Baby Moonwhisper Elekk', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+5, 'Baby Ashenvale Elekk', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+6, 'Baby Azshara Elekk', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+7, 'Hawkstrider Hatchling', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+8, 'Tamed Skunk', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+9, 'Wolpertinger', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+10, 'Portable Zeppelin Prototype', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+11, 'Potato Fairy', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+12, 'Berry Squirrel', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+13, 'Pumpkin Marmot', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+14, 'Sand Hare', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+15, 'Verdant Melon Muncher', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+16, 'Wild Autumn Owl', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+17, 'Living Mushroom', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+18, 'Swiftstar', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+19, 'Grumbles', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+20, 'Whitebranch', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+21, 'Rufflebeak', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+22, 'Wood Constrictor', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+23, 'Yellow Wasp', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+24, 'Dung Beetle', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+25, 'Reclusive Spider', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+26, 'Darkfeather Owl', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+27, 'Shadewing Bat', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+28, 'Tropical Monkey', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+29, 'Vibrant Parrot', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+30, 'Sludge Ooze', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+31, 'Starsilk Moth', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+32, 'Toothy', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2),
(@PET2+33, 'Palatinate Pebble', '', 1, 1, 188, 0, 1, 1.14286, 1, 768, 2048, 12, 2);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`) VALUES
(@PET2+0, 0, 19878, 0.35, 1),
(@PET2+1, 0, 814, 0.4, 1),
(@PET2+2, 0, 1039, 0.3, 1),
(@PET2+3, 0, 807, 0.3, 1),
(@PET2+4, 0, 17063, 0.3, 1),
(@PET2+5, 0, 19869, 0.3, 1),
(@PET2+6, 0, 19870, 0.3, 1),
(@PET2+7, 0, 18696, 0.4, 1),
(@PET2+8, 0, 16633, 1, 1),
(@PET2+9, 0, 22349, 1, 1),
(@PET2+10, 0, 17192, 0.04, 1),
(@PET2+11, 0, 901, 1.2, 1),
(@PET2+12, 0, 134, 1, 1),
(@PET2+13, 0, 1072, 1, 1),
(@PET2+14, 0, 1560, 1, 1),
(@PET2+15, 0, 328, 1, 1),
(@PET2+16, 0, 6299, 1, 1),
(@PET2+17, 0, 2022, 0.35, 1),
(@PET2+18, 0, 654, 0.5, 1),
(@PET2+19, 0, 8843, 0.45, 1),
(@PET2+20, 0, 18922, 0.25, 1),
(@PET2+21, 0, 21774, 0.6, 1),
(@PET2+22, 0, 1206, 1, 1),
(@PET2+23, 0, 482, 0.4, 1),
(@PET2+24, 0, 7511, 1, 1),
(@PET2+25, 0, 1160, 1, 1),
(@PET2+26, 0, 6299, 0.9, 1),
(@PET2+27, 0, 4732, 0.5, 1),
(@PET2+28, 0, 21362, 1, 1),
(@PET2+29, 0, 8816, 1, 1),
(@PET2+30, 0, 7763, 1, 1),
(@PET2+31, 0, 17574, 0.5, 1),
(@PET2+32, 0, 814, 0.25, 1),
(@PET2+33, 0, 2410, 0.3, 1);

DELETE FROM `item_template` WHERE `entry` BETWEEN @ITEM AND @ITEM+8;
INSERT INTO `item_template` (`entry`, `class`, `subclass`, `SoundOverrideSubclass`, `name`, `displayid`, `Quality`, `Flags`, `BuyCount`, `BuyPrice`, `SellPrice`, `InventoryType`, `ItemLevel`, `maxcount`, `stackable`, `spellid_1`, `spelltrigger_1`, `spellcharges_1`, `spellcooldown_1`, `spellcategorycooldown_1`, `spellid_2`, `spelltrigger_2`, `spellcooldown_2`, `spellcategorycooldown_2`, `bonding`, `description`, `Material`) VALUES
(@ITEM+0, 15, 2, -1, 'Corgi Pup', 20629, 3, 64, 1, 0, 0, 0, 20, 1, 1, 55884, 0, -1, -1, -1, @SPELL+0, 6, -1, -1, 1, 'Teaches you how to summon this companion.', 4),
(@ITEM+1, 15, 2, -1, 'Cloud Serpent Hatchling', 18050, 3, 64, 1, 0, 0, 0, 20, 1, 1, 55884, 0, -1, -1, -1, @SPELL+1, 6, -1, -1, 1, 'Teaches you how to summon this companion.', 4),
(@ITEM+2, 15, 2, -1, 'Kobold Pip', 1119, 3, 64, 1, 0, 0, 0, 20, 1, 1, 55884, 0, -1, -1, -1, @SPELL+2, 6, -1, -1, 1, 'Teaches you how to summon this companion.', 4),
(@ITEM+3, 15, 2, -1, 'Wee Nefarian', 31434, 3, 64, 1, 0, 0, 0, 20, 1, 1, 55884, 0, -1, -1, -1, @SPELL+3, 6, -1, -1, 1, 'Teaches you how to summon this companion.', 4),
(@ITEM+4, 15, 2, -1, 'Willowisp', 3109, 3, 64, 1, 0, 0, 0, 20, 1, 1, 55884, 0, -1, -1, -1, @SPELL+4, 6, -1, -1, 1, 'Teaches you how to summon this companion.', 4),
(@ITEM+5, 15, 0, -1, 'Tuskarr Fisherman''s Horn', 956, 3, 0, 1, 0, 0, 0, 1, 1, 1, @SPELL+5, 0, 0, 1500, -1, 0, 0, -1, -1, 1, 'Blow it to look like a tuskarr fisher. Use again, mount up or fight to drop it.', 4),
(@ITEM+6, 15, 0, -1, 'Coin of Familiar Faces', 37780, 3, 0, 1, 0, 0, 0, 1, 1, 1, @SPELL+6, 0, 0, 1500, -1, 0, 0, -1, -1, 1, 'Flip it to wear a famous face of Azeroth. Use again, mount up or fight to drop it.', 4),
(@ITEM+7, 15, 0, -1, 'Tome of Disguise: Imp', 918, 3, 0, 1, 0, 0, 0, 1, 1, 1, @SPELL+7, 0, 0, 1500, -1, 0, 0, -1, -1, 1, 'Read it to look like an imp. Use again, mount up or fight to drop it.', 4),
(@ITEM+8, 15, 2, -1, 'Coco', 20629, 3, 64, 1, 0, 0, 0, 20, 1, 1, 55884, 0, -1, -1, -1, @SPELL+8, 6, -1, -1, 1, 'Teaches you how to summon this companion.', 4);

CREATE TABLE IF NOT EXISTS `mod_temucraft_vanity_item` (
  `item` int unsigned NOT NULL COMMENT 'item_template.entry',
  `category` varchar(32) NOT NULL DEFAULT '' COMMENT 'heading in the Vanity window',
  `sort` smallint unsigned NOT NULL DEFAULT 0 COMMENT 'order inside its heading',
  PRIMARY KEY (`item`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Temucraft: vanity items (account collections)';
DELETE FROM `mod_temucraft_vanity_item` WHERE `item` BETWEEN @ITEM+5 AND @ITEM+7;
INSERT INTO `mod_temucraft_vanity_item` (`item`, `category`, `sort`) VALUES
(@ITEM+5, 'Costumes', 20), (@ITEM+6, 'Costumes', 21), (@ITEM+7, 'Costumes', 22);
