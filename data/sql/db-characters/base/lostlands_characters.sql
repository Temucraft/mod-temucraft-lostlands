-- mod-temucraft-lostlands: collection spells learned by each account (toys, mounts, companions).
-- kind 10 of the shared account collection
CREATE TABLE IF NOT EXISTS `mod_temucraft_account_collection` (
  `account` int unsigned NOT NULL, `kind` tinyint unsigned NOT NULL, `id` int unsigned NOT NULL,
  PRIMARY KEY (`account`, `kind`, `id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Temucraft: account collections (kinds in mod-temucraft-account-wide)';
-- rows from the old `mod_temucraft_lostlands_account_collection` table, if this server still has it, then it goes
SET @old := (SELECT COUNT(*) FROM information_schema.TABLES WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'mod_temucraft_lostlands_account_collection');
SET @sql := IF(@old > 0, 'INSERT IGNORE INTO `mod_temucraft_account_collection` (`account`, `kind`, `id`) SELECT `AccountID`, 10, `SpellID` FROM `mod_temucraft_lostlands_account_collection`', 'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
DROP TABLE IF EXISTS `mod_temucraft_lostlands_account_collection`;
