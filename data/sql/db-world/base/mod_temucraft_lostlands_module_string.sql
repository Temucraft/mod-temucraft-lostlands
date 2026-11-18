-- mod-temucraft-lostlands: player-facing texts. Translations go in module_string_locale (same module and id, plus the locale).
DELETE FROM `module_string` WHERE `module` = 'mod-temucraft-lostlands';
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-temucraft-lostlands', 1, 'This illusion has no form for your character.'),
('mod-temucraft-lostlands', 2, 'Lost Lands tables reloaded.'),
('mod-temucraft-lostlands', 3, 'Rent this mount ({} copper).'),
('mod-temucraft-lostlands', 4, 'You don''t have enough money.'),
('mod-temucraft-lostlands', 5, 'THREE'),
('mod-temucraft-lostlands', 6, 'Checkpoint {} of {}'),
('mod-temucraft-lostlands', 7, 'I want to leave the race queue.'),
('mod-temucraft-lostlands', 8, 'I''ll race for the goblins.'),
('mod-temucraft-lostlands', 9, 'I''ll race for the gnomes.'),
('mod-temucraft-lostlands', 10, 'You don''t have what this plant needs.'),
('mod-temucraft-lostlands', 11, 'Let me browse your goods.'),
('mod-temucraft-lostlands', 12, 'You don''t have enough tokens.');
