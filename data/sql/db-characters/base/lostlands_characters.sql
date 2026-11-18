-- mod-temucraft-lostlands: collection spells learned by each account (toys, mounts, companions).
CREATE TABLE IF NOT EXISTS `mod_temucraft_lostlands_account_collection` (
  `AccountID` int unsigned NOT NULL,
  `SpellID` int unsigned NOT NULL,
  PRIMARY KEY (`AccountID`,`SpellID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='mod-temucraft-lostlands account-wide collections';
