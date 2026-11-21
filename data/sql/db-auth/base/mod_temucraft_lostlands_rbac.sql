-- mod-temucraft-lostlands: its game master commands as RBAC permissions (101001-101001). Each is linked to the
-- stock security role of its old level (194 moderator, 193 game master, 192 administrator) and to the matching
-- Temucraft GM tier (1011 Triager, 1012 Entertainer, 1014 Administrator). Grant or deny them per account with
-- .rbac account grant / deny, or link them to other roles.
DELETE FROM `rbac_linked_permissions` WHERE `linkedId` BETWEEN 101001 AND 101049;
DELETE FROM `rbac_permissions` WHERE `id` BETWEEN 101001 AND 101049;
INSERT INTO `rbac_permissions` (`id`, `name`) VALUES
(101001, 'Command: temucraft lostlands reload');
INSERT INTO `rbac_linked_permissions` (`id`, `linkedId`) VALUES
(192, 101001),
(1014, 101001);
