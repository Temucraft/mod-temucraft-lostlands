/*
 * mod-temucraft-lostlands: the scripted parts of the Lost Lands content. All data lives in world DB tables
 * (see data/sql/db-world/base/lostlands_features.sql), so none of it is hard-coded here.
 *
 *   Illusion toys       casting a spell from mod_temucraft_lostlands_illusion turns you into one of its displays
 *                       (random, by gender); casting it again, mounting or entering combat drops it.
 *   Collections         spells taught by the items in mod_temucraft_lostlands_collection (toys, mounts, companions)
 *                       are saved for the account and taught to every character of it at login
 *                       (Temucraft.LostLands.AccountWideCollections).
 *   Spawn scale         objects listed in mod_temucraft_lostlands_spawn_scale get that size when they appear.
 *   Cast objectives     mod_temucraft_lostlands_quest_cast: hitting another player with the spell (of the right class,
 *                       or a game master) completes the quest objective.
 *   Map aura removal    entering a map in mod_temucraft_lostlands_map_aura_removal removes those auras.
 *
 *   .temucraft lostlands reload   re-reads the tables
 *
 * Written for AzerothCore; the ideas follow features of a 1.12 server, the code is new.
 */

#include "Chat.h"
#include "TemucraftModuleText.h"
#include "ChatCommand.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "GameObject.h"
#include "Log.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "Spell.h"
#include "SpellInfo.h"
#include <unordered_map>
#include <unordered_set>
#include <vector>

using namespace Acore::ChatCommands;

void ReloadTemucraftLostLandsScripts();

namespace
{
    struct Settings
    {
        bool enable = true;
        bool illusions = true;
        bool accountWide = true;
        bool spawnScale = true;
        bool castObjectives = true;
        bool auraRemoval = true;
    } settings;

    struct IllusionDisplays { std::vector<uint32> male, female, any; };
    std::unordered_map<uint32, IllusionDisplays> sIllusions;           // spell -> displays
    std::unordered_set<uint32> sCollectionSpells;                      // spells shared by the account
    std::unordered_map<uint32, float> sSpawnScale;                     // gameobject spawn guid -> scale
    struct CastObjective { uint32 quest; uint8 index; uint8 targetClass; bool targetGM; };
    std::unordered_map<uint32, std::vector<CastObjective>> sCastObjectives; // spell -> objectives
    std::unordered_map<uint32, std::vector<uint32>> sMapAuraRemoval;   // map -> auras
    std::unordered_set<ObjectGuid> sIllusioned;                        // players wearing an illusion

    void LoadTables()
    {
        sIllusions.clear(); sCollectionSpells.clear(); sSpawnScale.clear(); sCastObjectives.clear(); sMapAuraRemoval.clear();

        if (QueryResult r = WorldDatabase.Query("SELECT `SpellID`, `Gender`, `DisplayID` FROM `mod_temucraft_lostlands_illusion`"))
            do
            {
                Field* f = r->Fetch();
                IllusionDisplays& d = sIllusions[f[0].Get<uint32>()];
                switch (f[1].Get<uint8>())
                {
                    case 0: d.male.push_back(f[2].Get<uint32>()); break;
                    case 1: d.female.push_back(f[2].Get<uint32>()); break;
                    default: d.any.push_back(f[2].Get<uint32>()); break;
                }
            } while (r->NextRow());

        if (QueryResult r = WorldDatabase.Query("SELECT `SpellID` FROM `mod_temucraft_lostlands_collection`"))
            do sCollectionSpells.insert(r->Fetch()[0].Get<uint32>()); while (r->NextRow());

        if (QueryResult r = WorldDatabase.Query("SELECT `Guid`, `Scale` FROM `mod_temucraft_lostlands_spawn_scale`"))
            do sSpawnScale[r->Fetch()[0].Get<uint32>()] = r->Fetch()[1].Get<float>(); while (r->NextRow());

        if (QueryResult r = WorldDatabase.Query("SELECT `QuestID`, `ObjectiveIndex`, `SpellID`, `TargetClass`, `TargetGM` FROM `mod_temucraft_lostlands_quest_cast`"))
            do
            {
                Field* f = r->Fetch();
                if (f[1].Get<uint8>() >= QUEST_OBJECTIVES_COUNT)
                    continue;
                sCastObjectives[f[2].Get<uint32>()].push_back({ f[0].Get<uint32>(), f[1].Get<uint8>(), f[3].Get<uint8>(), f[4].Get<bool>() });
            } while (r->NextRow());

        if (QueryResult r = WorldDatabase.Query("SELECT `MapID`, `SpellID` FROM `mod_temucraft_lostlands_map_aura_removal`"))
            do sMapAuraRemoval[r->Fetch()[0].Get<uint32>()].push_back(r->Fetch()[1].Get<uint32>()); while (r->NextRow());

        LOG_INFO("module", "mod-temucraft-lostlands: {} illusion toys, {} collection spells, {} scaled objects, {} cast objectives, {} maps with aura removal",
            sIllusions.size(), sCollectionSpells.size(), sSpawnScale.size(), sCastObjectives.size(), sMapAuraRemoval.size());
    }

    void DropIllusion(Player* player)
    {
        if (sIllusioned.erase(player->GetGUID()))
            player->DeMorph();
    }

    void ApplyIllusion(Player* player, uint32 spellId)
    {
        auto itr = sIllusions.find(spellId);
        if (itr == sIllusions.end())
            return;

        if (sIllusioned.count(player->GetGUID()))   // cast again: take it off
        {
            DropIllusion(player);
            return;
        }

        IllusionDisplays const& d = itr->second;
        std::vector<uint32> const& gendered = player->getGender() == GENDER_MALE ? d.male : d.female;
        std::vector<uint32> const& pool = !gendered.empty() ? gendered : d.any;
        if (pool.empty())
        {
            ChatHandler(player->GetSession()).SendSysMessage(TemucraftModuleText("mod-temucraft-lostlands", player->GetSession(), 1, "This illusion has no form for your character."));
            return;
        }
        player->SetDisplayId(pool[urand(0, pool.size() - 1)]);
        sIllusioned.insert(player->GetGUID());
    }

    void SaveCollectionSpell(Player* player, uint32 spellId)
    {
        CharacterDatabase.Execute("INSERT IGNORE INTO `mod_temucraft_lostlands_account_collection` (`AccountID`, `SpellID`) VALUES ({}, {})",
            player->GetSession()->GetAccountId(), spellId);
    }

    void CreditCastObjective(Player* caster, Spell* spell)
    {
        auto itr = sCastObjectives.find(spell->GetSpellInfo()->Id);
        if (itr == sCastObjectives.end())
            return;
        Unit* target = spell->m_targets.GetUnitTarget();
        Player* victim = target ? target->ToPlayer() : nullptr;
        if (!victim || victim == caster)
            return;

        for (CastObjective const& o : itr->second)
        {
            if (caster->GetQuestStatus(o.quest) != QUEST_STATUS_INCOMPLETE)
                continue;
            if (o.targetGM ? victim->GetSession()->GetSecurity() == SEC_PLAYER : (o.targetClass && victim->getClass() != o.targetClass))
                continue;
            Quest const* quest = sObjectMgr->GetQuestTemplate(o.quest);
            if (!quest)
                continue;
            int32 required = quest->RequiredNpcOrGo[o.index];
            if (required > 0)
                caster->KilledMonsterCredit(uint32(required));
            else if (required < 0)
                caster->KillCreditGO(uint32(-required));
        }
    }
}

class TemucraftLostLands_Player : public PlayerScript
{
public:
    TemucraftLostLands_Player() : PlayerScript("TemucraftLostLands_Player", { PLAYERHOOK_ON_SPELL_CAST, PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_LOGOUT,
        PLAYERHOOK_ON_LEARN_SPELL, PLAYERHOOK_ON_MAP_CHANGED, PLAYERHOOK_ON_PLAYER_ENTER_COMBAT }) { }

    void OnPlayerSpellCast(Player* player, Spell* spell, bool /*skipCheck*/) override
    {
        if (!settings.enable || !spell || !spell->GetSpellInfo())
            return;
        uint32 id = spell->GetSpellInfo()->Id;
        if (settings.illusions)
        {
            if (sIllusions.count(id))
                ApplyIllusion(player, id);
            else if (spell->GetSpellInfo()->HasAura(SPELL_AURA_MOUNTED))
                DropIllusion(player);
        }
        if (settings.castObjectives)
            CreditCastObjective(player, spell);
    }

    void OnPlayerEnterCombat(Player* player, Unit* /*enemy*/) override
    {
        if (settings.illusions)
            DropIllusion(player);
    }

    void OnPlayerLogout(Player* player) override
    {
        sIllusioned.erase(player->GetGUID());
    }

    void OnPlayerLearnSpell(Player* player, uint32 spellId) override
    {
        if (settings.enable && settings.accountWide && sCollectionSpells.count(spellId))
            SaveCollectionSpell(player, spellId);
    }

    void OnPlayerLogin(Player* player) override
    {
        if (!settings.enable || !settings.accountWide)
            return;
        QueryResult r = CharacterDatabase.Query("SELECT `SpellID` FROM `mod_temucraft_lostlands_account_collection` WHERE `AccountID` = {}",
            player->GetSession()->GetAccountId());
        if (!r)
            return;
        do
        {
            uint32 spellId = r->Fetch()[0].Get<uint32>();
            if (sCollectionSpells.count(spellId) && !player->HasSpell(spellId))
                player->learnSpell(spellId);
        } while (r->NextRow());
    }

    void OnPlayerMapChanged(Player* player) override
    {
        if (!settings.enable || !settings.auraRemoval)
            return;
        auto itr = sMapAuraRemoval.find(player->GetMapId());
        if (itr == sMapAuraRemoval.end())
            return;
        for (uint32 aura : itr->second)
            player->RemoveAurasDueToSpell(aura);
    }
};

class TemucraftLostLands_GameObject : public AllGameObjectScript
{
public:
    TemucraftLostLands_GameObject() : AllGameObjectScript("TemucraftLostLands_GameObject") { }

    void OnGameObjectAddWorld(GameObject* go) override
    {
        if (!settings.enable || !settings.spawnScale || !go->GetSpawnId())
            return;
        auto itr = sSpawnScale.find(go->GetSpawnId());
        if (itr != sSpawnScale.end() && itr->second > 0.0f)
            go->SetObjectScale(itr->second);
    }
};

class TemucraftLostLands_Commands : public CommandScript
{
public:
    TemucraftLostLands_Commands() : CommandScript("TemucraftLostLands_Commands") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable lostLands =
        {
            { "reload", HandleReload, 101001 /* SEC_ADMINISTRATOR -> RBAC */, Console::Yes },
        };
        static ChatCommandTable root = { { "temucraft lostlands", lostLands } };
        return root;
    }

    static bool HandleReload(ChatHandler* handler)
    {
        LoadTables();
        ReloadTemucraftLostLandsScripts();
        handler->SendSysMessage(TemucraftModuleText("mod-temucraft-lostlands", handler, 2, "Lost Lands tables reloaded."));
        return true;
    }
};

class TemucraftLostLands_World : public WorldScript
{
public:
    TemucraftLostLands_World() : WorldScript("TemucraftLostLands_World", { WORLDHOOK_ON_AFTER_CONFIG_LOAD, WORLDHOOK_ON_STARTUP }) { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        settings.enable = sConfigMgr->GetOption<bool>("Temucraft.LostLands.Enable", true);
        settings.illusions = sConfigMgr->GetOption<bool>("Temucraft.LostLands.Illusions", true);
        settings.accountWide = sConfigMgr->GetOption<bool>("Temucraft.LostLands.AccountWideCollections", true);
        settings.spawnScale = sConfigMgr->GetOption<bool>("Temucraft.LostLands.SpawnScale", true);
        settings.castObjectives = sConfigMgr->GetOption<bool>("Temucraft.LostLands.CastObjectives", true);
        settings.auraRemoval = sConfigMgr->GetOption<bool>("Temucraft.LostLands.MapAuraRemoval", true);
    }

    void OnStartup() override
    {
        LoadTables();
    }
};

void AddTemucraftLostLandsScripts()
{
    new TemucraftLostLands_Player();
    new TemucraftLostLands_GameObject();
    new TemucraftLostLands_Commands();
    new TemucraftLostLands_World();
}
