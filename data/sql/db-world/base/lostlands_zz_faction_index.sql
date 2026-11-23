-- The 3.3.5 client keeps reputation in a list of 128 (indices 0 to 127). An index above 127 is written past the end of
-- that list, over the client's reputation headers: the client then crashes when it adds a header (talking to an NPC,
-- gaining reputation, logging in) and when it frees them (logout, exit). These four had 128 to 131. The client data
-- (patch-T Faction.dbc) already has -1 for them, so the server now agrees: no reputation list slot.
UPDATE `faction_dbc` SET `ReputationIndex` = -1 WHERE `ID` IN (2314, 2318, 2319, 2321);
