/*
 * mod-temucraft-lostlands: creature and object scripts. Every number comes from world DB tables
 * (lostlands_features.sql), so moving IDs needs no code change.
 *
 *   npc_temucraft_lostlands_caster        creatures cast the spells in creature_template_spell: heals on hurt allies,
 *                                         buffs on themselves, the rest on their target or someone in range
 *   npc_temucraft_lostlands_rental        rent a mount for a few copper (mod_temucraft_lostlands_rental)
 *   npc_temucraft_lostlands_race_manager  Mirage Raceway: queue, countdown, racecars, checkpoints, speed boosts,
 *                                         exploding sheep, quest credit (mod_temucraft_lostlands_race*)
 *   npc_temucraft_lostlands_race_sheep    the sheep on the track: slows a racer that runs into it
 *   go_temucraft_lostlands_rest           tents and campfires: rested experience builds while you stand close
 *   go_temucraft_lostlands_planter        gardening: plant seeds (mod_temucraft_lostlands_garden_seed)
 *   go_temucraft_lostlands_grow           a growing plant: needs care after a while (mod_temucraft_lostlands_garden_stage)
 *   go_temucraft_lostlands_grow_care      give the plant what it needs to grow to the next stage, then harvest
 *   go_temucraft_lostlands_explore        reaching the object completes a quest objective (mod_temucraft_lostlands_explore)
 *   npc_temucraft_lostlands_teleporter    takes you somewhere (mod_temucraft_lostlands_teleporter)
 *   npc_temucraft_lostlands_token_vendor  sells buffs for tokens, like the arena's Bloody Coins (mod_temucraft_lostlands_token_vendor)
 */

#include "CellImpl.h"
#include "TemucraftModuleText.h"
#include "Chat.h"
#include "CreatureScript.h"
#include "GridNotifiers.h"
#include "GridNotifiersImpl.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "GameObject.h"
#include "GameObjectAI.h"
#include "GameObjectScript.h"
#include "Log.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "ScriptedGossip.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "WorldScript.h"
#include "WorldSession.h"
#include <map>
#include <set>
#include <unordered_map>

namespace LostLands
{
    struct Rental { uint32 spell; uint32 cost; };
    std::unordered_map<uint32, Rental> sRentals;

    struct RaceSpot { float x, y, z; };
    struct RacePoolEntry { uint32 entry; uint8 chance; RaceSpot pos; };
    struct Race
    {
        uint32 id = 0;
        uint32 manager = 0;
        uint8 requiredPlayers = 2;
        uint32 questA = 0, questB = 0;     // racing for team A (goblins) or B (gnomes)
        uint32 prereqA = 0, prereqB = 0;   // quest that must be rewarded before joining (0 = none)
        uint32 winQuest = 0;               // the winner's extra quest
        uint32 mountA = 0, mountB = 0;     // racecar spells
        uint32 checkpointObject = 0;
        uint32 speedSpell = 0, slowSpell = 0, rootSpell = 0, explodeSpell = 0;
        std::vector<RaceSpot> checkpoints;
        std::vector<RacePoolEntry> creatures, objects;
    };
    std::map<uint32, Race> sRaces;                    // race id
    std::unordered_map<uint32, uint32> sRaceByManager; // manager entry -> race id
    std::set<uint32> sRaceObjectEntries;               // speed boost objects

    struct GardenSeed { uint32 planter; uint32 item; uint32 firstStage; std::string text; };
    std::vector<GardenSeed> sSeeds;
    struct GardenStage { uint8 kind; uint32 item; uint32 next; uint32 seconds; bool harvest; std::string missing; };
    std::unordered_map<uint32, GardenStage> sStages;   // object entry (kind 0 grows by itself, 1 needs care)

    struct Explore { uint32 quest; uint32 credit; float radius; };
    std::unordered_map<uint32, std::vector<Explore>> sExplore; // object entry

    struct Teleport { std::string text; uint32 map; float x, y, z, o; uint32 quest; };
    std::unordered_map<uint32, std::vector<Teleport>> sTeleports;
    struct TokenBuff { std::string text; uint32 item; uint32 count; uint32 spell; };
    std::unordered_map<uint32, std::vector<TokenBuff>> sTokenBuffs;

    float sRestRadius = 10.0f;
    float sRestRate = 0.000575f;   // share of the level's experience added per second

    void CreateRaceRuns();

    void Load()
    {

        sTeleports.clear(); sTokenBuffs.clear();
        sRentals.clear(); sRaces.clear(); sRaceByManager.clear(); sRaceObjectEntries.clear(); sSeeds.clear(); sStages.clear(); sExplore.clear();
        if (QueryResult r = WorldDatabase.Query("SELECT `CreatureEntry`, `SpellID`, `Cost` FROM `mod_temucraft_lostlands_rental`"))
            do sRentals[r->Fetch()[0].Get<uint32>()] = { r->Fetch()[1].Get<uint32>(), r->Fetch()[2].Get<uint32>() }; while (r->NextRow());

        if (QueryResult r = WorldDatabase.Query("SELECT `RaceID`, `ManagerEntry`, `RequiredPlayers`, `QuestA`, `QuestB`, `PrereqA`, `PrereqB`, `WinQuest`, `MountA`, `MountB`, "
            "`CheckpointObject`, `SpeedSpell`, `SlowSpell`, `RootSpell`, `ExplodeSpell` FROM `mod_temucraft_lostlands_race`"))
            do
            {
                Field* f = r->Fetch();
                Race& race = sRaces[f[0].Get<uint32>()];
                race.id = f[0].Get<uint32>(); race.manager = f[1].Get<uint32>(); race.requiredPlayers = std::max<uint8>(1, f[2].Get<uint8>());
                race.questA = f[3].Get<uint32>(); race.questB = f[4].Get<uint32>(); race.prereqA = f[5].Get<uint32>(); race.prereqB = f[6].Get<uint32>();
                race.winQuest = f[7].Get<uint32>(); race.mountA = f[8].Get<uint32>(); race.mountB = f[9].Get<uint32>(); race.checkpointObject = f[10].Get<uint32>();
                race.speedSpell = f[11].Get<uint32>(); race.slowSpell = f[12].Get<uint32>(); race.rootSpell = f[13].Get<uint32>(); race.explodeSpell = f[14].Get<uint32>();
                sRaceByManager[race.manager] = race.id;
            } while (r->NextRow());
        if (QueryResult r = WorldDatabase.Query("SELECT `RaceID`, `X`, `Y`, `Z` FROM `mod_temucraft_lostlands_race_checkpoint` ORDER BY `RaceID`, `Point`"))
            do
            {
                auto itr = sRaces.find(r->Fetch()[0].Get<uint32>());
                if (itr != sRaces.end())
                    itr->second.checkpoints.push_back({ r->Fetch()[1].Get<float>(), r->Fetch()[2].Get<float>(), r->Fetch()[3].Get<float>() });
            } while (r->NextRow());
        if (QueryResult r = WorldDatabase.Query("SELECT `RaceID`, `Type`, `Entry`, `Chance`, `X`, `Y`, `Z` FROM `mod_temucraft_lostlands_race_pool`"))
            do
            {
                Field* f = r->Fetch();
                auto itr = sRaces.find(f[0].Get<uint32>());
                if (itr == sRaces.end())
                    continue;
                RacePoolEntry e{ f[2].Get<uint32>(), f[3].Get<uint8>(), { f[4].Get<float>(), f[5].Get<float>(), f[6].Get<float>() } };
                if (f[1].Get<uint8>() == 0)
                    itr->second.creatures.push_back(e);
                else
                {
                    itr->second.objects.push_back(e);
                    sRaceObjectEntries.insert(e.entry);
                }
            } while (r->NextRow());

        if (QueryResult r = WorldDatabase.Query("SELECT `PlanterEntry`, `SeedItem`, `FirstStage`, `Text` FROM `mod_temucraft_lostlands_garden_seed`"))
            do sSeeds.push_back({ r->Fetch()[0].Get<uint32>(), r->Fetch()[1].Get<uint32>(), r->Fetch()[2].Get<uint32>(), r->Fetch()[3].Get<std::string>() }); while (r->NextRow());
        if (QueryResult r = WorldDatabase.Query("SELECT `Entry`, `Kind`, `Item`, `NextEntry`, `Seconds`, `Harvest`, `MissingText` FROM `mod_temucraft_lostlands_garden_stage`"))
            do
            {
                Field* f = r->Fetch();
                sStages[f[0].Get<uint32>()] = { f[1].Get<uint8>(), f[2].Get<uint32>(), f[3].Get<uint32>(), f[4].Get<uint32>(), f[5].Get<bool>(), f[6].Get<std::string>() };
            } while (r->NextRow());

        if (QueryResult r = WorldDatabase.Query("SELECT `ObjectEntry`, `QuestID`, `CreditEntry`, `Radius` FROM `mod_temucraft_lostlands_explore`"))
            do sExplore[r->Fetch()[0].Get<uint32>()].push_back({ r->Fetch()[1].Get<uint32>(), r->Fetch()[2].Get<uint32>(), r->Fetch()[3].Get<float>() }); while (r->NextRow());

        if (QueryResult r = WorldDatabase.Query("SELECT `CreatureEntry`, `Text`, `Map`, `X`, `Y`, `Z`, `O`, `RequiredQuest` FROM `mod_temucraft_lostlands_teleporter` ORDER BY `CreatureEntry`, `Slot`"))
            do
            {
                Field* f = r->Fetch();
                sTeleports[f[0].Get<uint32>()].push_back({ f[1].Get<std::string>(), f[2].Get<uint32>(), f[3].Get<float>(), f[4].Get<float>(), f[5].Get<float>(), f[6].Get<float>(), f[7].Get<uint32>() });
            } while (r->NextRow());
        if (QueryResult r = WorldDatabase.Query("SELECT `CreatureEntry`, `Text`, `ItemID`, `ItemCount`, `SpellID` FROM `mod_temucraft_lostlands_token_vendor` ORDER BY `CreatureEntry`, `Slot`"))
            do
            {
                Field* f = r->Fetch();
                sTokenBuffs[f[0].Get<uint32>()].push_back({ f[1].Get<std::string>(), f[2].Get<uint32>(), f[3].Get<uint32>(), f[4].Get<uint32>() });
            } while (r->NextRow());

        CreateRaceRuns();
        LOG_INFO("module", "mod-temucraft-lostlands scripts: {} rental mounts, {} races, {} seeds, {} garden stages, {} exploration objects",
            sRentals.size(), sRaces.size(), sSeeds.size(), sStages.size(), sExplore.size());
    }

    // ------------------------------------------------------------------ racing state
    struct RaceRun
    {
        std::set<ObjectGuid> queue;
        bool running = false;
        uint32 countdown = 0;
        uint8 countdownStep = 0;
        std::map<ObjectGuid, std::vector<bool>> reached;
        std::vector<ObjectGuid> spawned;   // summoned creatures and objects to clean up
        std::set<std::pair<ObjectGuid, ObjectGuid>> usedBoosts;
    };
    // One entry per race, created by Load() on the world thread (CreateRaceRuns); map threads (race managers' AI, on
    // several Lost Lands maps at once) only find their own entry and never insert into the map.
    std::map<uint32, RaceRun> sRuns;

    void CreateRaceRuns()
    {
        for (auto const& kv : sRaces)
            sRuns[kv.first];   // keeps a run in progress across a reload
    }

    RaceRun* RunOf(uint32 race)
    {
        auto itr = sRuns.find(race);
        return itr == sRuns.end() ? nullptr : &itr->second;
    }

    void PlayersNear(WorldObject* obj, std::list<Player*>& out, float range)
    {
        Acore::AnyPlayerInObjectRangeCheck check(obj, range);
        Acore::PlayerListSearcher<Acore::AnyPlayerInObjectRangeCheck> searcher(obj, out, check);
        Cell::VisitObjects(obj, searcher, range);
    }

    bool Queued(Player* p)
    {
        for (auto const& kv : sRuns)
            if (kv.second.queue.count(p->GetGUID()))
                return true;
        return false;
    }
}

using namespace LostLands;

// ====================================================================== generic caster
struct npc_temucraft_lostlands_casterAI : public ScriptedAI
{
    npc_temucraft_lostlands_casterAI(Creature* c) : ScriptedAI(c) { }

    std::unordered_map<uint32, uint32> cooldowns;
    uint32 thinkTimer = 2000;

    void Reset() override { cooldowns.clear(); thinkTimer = urand(1500, 4000); }

    void JustEngagedWith(Unit* /*who*/) override
    {
        // self buffs right away
        for (uint32 id : me->m_spells)
            if (SpellInfo const* info = sSpellMgr->GetSpellInfo(id))
                if (info->IsPositive() && !info->HasEffect(SPELL_EFFECT_HEAL) && !me->HasAura(id) && TargetsSelf(info))
                {
                    me->CastSpell(me, id, false);
                    cooldowns[id] = Cooldown(info);
                    break;
                }
    }

    static bool TargetsSelf(SpellInfo const* info)
    {
        for (SpellEffectInfo const& e : info->GetEffects())
            if (e.TargetA.GetTarget() == TARGET_UNIT_CASTER)
                return true;
        return false;
    }

    static uint32 Cooldown(SpellInfo const* info)
    {
        uint32 cd = std::max(info->RecoveryTime, info->CategoryRecoveryTime);
        return std::max<uint32>(cd, 8000) + urand(0, 4000);
    }

    Unit* PickTarget(SpellInfo const* info)
    {
        float range = info->GetMaxRange(info->IsPositive(), me);
        if (range <= 0.0f)
            range = 5.0f;
        if (info->HasEffect(SPELL_EFFECT_HEAL) || info->HasAura(SPELL_AURA_PERIODIC_HEAL))
            return DoSelectLowestHpFriendly(range, 1);
        if (info->IsPositive())
            return (TargetsSelf(info) && !me->HasAura(info->Id)) ? me : nullptr;
        Unit* victim = me->GetVictim();
        if (victim && me->IsWithinDistInMap(victim, range))
            return victim;
        return SelectTarget(SelectTargetMethod::Random, 0, range, true);
    }

    void UpdateAI(uint32 diff) override
    {
        if (!UpdateVictim())
            return;
        for (auto& kv : cooldowns)
            kv.second = kv.second > diff ? kv.second - diff : 0;

        if (thinkTimer > diff)
            thinkTimer -= diff;
        else if (!me->HasUnitState(UNIT_STATE_CASTING))
        {
            thinkTimer = urand(2500, 5000);
            std::vector<uint32> ready;
            for (uint32 id : me->m_spells)
                if (id && !cooldowns[id])
                    ready.push_back(id);
            Acore::Containers::RandomShuffle(ready);
            for (uint32 id : ready)
            {
                SpellInfo const* info = sSpellMgr->GetSpellInfo(id);
                if (!info)
                    continue;
                if (Unit* target = PickTarget(info))
                {
                    me->CastSpell(target, id, false);
                    cooldowns[id] = Cooldown(info);
                    break;
                }
            }
        }
        DoMeleeAttackIfReady();
    }
};

class npc_temucraft_lostlands_caster : public CreatureScript
{
public:
    npc_temucraft_lostlands_caster() : CreatureScript("npc_temucraft_lostlands_caster") { }
    CreatureAI* GetAI(Creature* c) const override { return new npc_temucraft_lostlands_casterAI(c); }
};

// ====================================================================== rental mounts
class npc_temucraft_lostlands_rental : public CreatureScript
{
public:
    npc_temucraft_lostlands_rental() : CreatureScript("npc_temucraft_lostlands_rental") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        auto itr = sRentals.find(creature->GetEntry());
        if (itr == sRentals.end() || player->IsMounted())
            return false;
        ClearGossipMenuFor(player);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, Acore::StringFormat(TemucraftModuleText("mod-temucraft-lostlands", player, 3, "Rent this mount ({} copper)."), itr->second.cost), GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        CloseGossipMenuFor(player);
        auto itr = sRentals.find(creature->GetEntry());
        if (action != GOSSIP_ACTION_INFO_DEF + 1 || itr == sRentals.end() || player->IsMounted())
            return true;
        if (!player->HasEnoughMoney(itr->second.cost))
        {
            ChatHandler(player->GetSession()).SendNotification(TemucraftModuleText("mod-temucraft-lostlands", player->GetSession(), 4, "You don't have enough money."));
            return true;
        }
        player->ModifyMoney(-int32(itr->second.cost));
        player->CastSpell(player, itr->second.spell, true);
        return true;
    }
};

// ====================================================================== Mirage Raceway
struct npc_temucraft_lostlands_race_managerAI : public ScriptedAI
{
    npc_temucraft_lostlands_race_managerAI(Creature* c) : ScriptedAI(c) { }

    uint32 checkTimer = 250;

    Race const* GetRace() const
    {
        auto itr = sRaceByManager.find(me->GetEntry());
        if (itr == sRaceByManager.end())
            return nullptr;
        auto r = sRaces.find(itr->second);
        return r == sRaces.end() ? nullptr : &r->second;
    }

    uint32 MountFor(Race const& race, Player* p) const
    {
        return p->GetQuestStatus(race.questA) == QUEST_STATUS_INCOMPLETE ? race.mountA : race.mountB;
    }

    void Start(Race const& race, RaceRun& run)
    {
        if (race.checkpoints.empty())
            return;
        run.running = true;
        run.countdown = 3000;
        run.countdownStep = 0;
        run.reached.clear();
        run.usedBoosts.clear();
        RaceSpot const& start = race.checkpoints.front();
        uint32 n = 0;
        for (ObjectGuid const& guid : run.queue)
        {
            Player* p = ObjectAccessor::GetPlayer(*me, guid);
            if (!p)
                continue;
            run.reached[guid].assign(race.checkpoints.size(), false);
            run.reached[guid][0] = true;
            p->CombatStop(true);
            p->RemoveAurasByType(SPELL_AURA_MOUNTED);
            p->RemoveAurasByType(SPELL_AURA_TRANSFORM);
            p->NearTeleportTo(start.x, start.y + ((n++ % 2) ? 2.0f : -2.0f), start.z, me->GetOrientation());
            p->CastSpell(p, MountFor(race, p), true);
            if (race.rootSpell)
                p->AddAura(race.rootSpell, p);
            p->GetSession()->SendAreaTriggerMessage(TemucraftModuleText("mod-temucraft-lostlands", p->GetSession(), 5, "THREE"));
        }
        for (size_t i = 1; i < race.checkpoints.size(); ++i)
            if (GameObject* go = me->SummonGameObject(race.checkpointObject, race.checkpoints[i].x, race.checkpoints[i].y, race.checkpoints[i].z, 0, 0, 0, 0, 0, 600))
                run.spawned.push_back(go->GetGUID());
        for (RacePoolEntry const& e : race.creatures)
            if (roll_chance_i(e.chance))
                if (Creature* c = me->SummonCreature(e.entry, e.pos.x, e.pos.y, e.pos.z, 0, TEMPSUMMON_TIMED_DESPAWN, 300000))
                    run.spawned.push_back(c->GetGUID());
        for (RacePoolEntry const& e : race.objects)
            if (roll_chance_i(e.chance))
                if (GameObject* go = me->SummonGameObject(e.entry, e.pos.x, e.pos.y, e.pos.z, 0, 0, 0, 0, 0, 300))
                    run.spawned.push_back(go->GetGUID());
    }

    void End(Race const& race, RaceRun& run, bool credit)
    {
        me->Yell("The race has ended!", LANG_UNIVERSAL);
        for (ObjectGuid const& guid : run.queue)
            if (Player* p = ObjectAccessor::GetPlayer(*me, guid))
            {
                if (credit && (p->HasAura(race.mountA) || p->HasAura(race.mountB)))
                {
                    p->AreaExploredOrEventHappens(race.questA);
                    p->AreaExploredOrEventHappens(race.questB);
                }
                p->RemoveAurasDueToSpell(race.mountA);
                p->RemoveAurasDueToSpell(race.mountB);
                if (race.rootSpell)
                    p->RemoveAurasDueToSpell(race.rootSpell);
            }
        for (ObjectGuid const& guid : run.spawned)
        {
            if (guid.IsGameObject())
            {
                if (GameObject* go = ObjectAccessor::GetGameObject(*me, guid))
                    go->DespawnOrUnsummon();
            }
            else if (Creature* c = ObjectAccessor::GetCreature(*me, guid))
                c->DespawnOrUnsummon();
        }
        run = RaceRun();
    }

    void UpdateAI(uint32 diff) override
    {
        if (checkTimer > diff) { checkTimer -= diff; return; }
        uint32 elapsed = 250 + (checkTimer > diff ? 0 : diff - checkTimer);
        checkTimer = 250;
        Race const* race = GetRace();
        RaceRun* runPtr = race ? RunOf(race->id) : nullptr;
        if (!runPtr)
            return;
        RaceRun& run = *runPtr;

        if (!run.running)
        {
            for (auto itr = run.queue.begin(); itr != run.queue.end();)
                if (!ObjectAccessor::GetPlayer(*me, *itr)) itr = run.queue.erase(itr); else ++itr;
            if (run.queue.size() >= race->requiredPlayers)
                Start(*race, run);
            return;
        }

        for (ObjectGuid const& guid : run.queue)
        {
            Player* p = ObjectAccessor::GetPlayer(*me, guid);
            if (!p || !p->IsAlive())
            {
                End(*race, run, false);
                return;
            }
            if (!p->HasAura(race->mountA) && !p->HasAura(race->mountB))
            {
                me->Yell(Acore::StringFormat("{} left the race!", p->GetName()), LANG_UNIVERSAL);
                End(*race, run, false);
                return;
            }
        }

        if (run.countdown)
        {
            run.countdown = run.countdown > elapsed ? run.countdown - elapsed : 0;
            char const* say = nullptr;
            if (run.countdownStep == 0 && run.countdown <= 2000) { say = "TWO"; ++run.countdownStep; }
            else if (run.countdownStep == 1 && run.countdown <= 1000) { say = "ONE"; ++run.countdownStep; }
            else if (run.countdownStep == 2 && run.countdown == 0) { say = "THE RACE HAS BEGUN!"; ++run.countdownStep; }
            if (say)
                for (ObjectGuid const& guid : run.queue)
                    if (Player* p = ObjectAccessor::GetPlayer(*me, guid))
                    {
                        p->GetSession()->SendAreaTriggerMessage(say);
                        if (run.countdownStep == 3 && race->rootSpell)
                            p->RemoveAurasDueToSpell(race->rootSpell);
                    }
            return;
        }

        // checkpoints and speed boosts
        ObjectGuid winner;
        for (auto& kv : run.reached)
        {
            Player* p = ObjectAccessor::GetPlayer(*me, kv.first);
            if (!p)
                continue;
            for (size_t i = 1; i < race->checkpoints.size(); ++i)
                if (!kv.second[i] && p->GetExactDist(race->checkpoints[i].x, race->checkpoints[i].y, race->checkpoints[i].z) < 15.0f)
                {
                    kv.second[i] = true;
                    p->GetSession()->SendAreaTriggerMessage(Acore::StringFormat(TemucraftModuleText("mod-temucraft-lostlands", p->GetSession(), 6, "Checkpoint {} of {}"), i, race->checkpoints.size() - 1));
                }
            for (ObjectGuid const& g : run.spawned)
                if (g.IsGameObject() && !run.usedBoosts.count({ kv.first, g }))
                    if (GameObject* go = ObjectAccessor::GetGameObject(*me, g))
                        if (sRaceObjectEntries.count(go->GetEntry()) && p->IsWithinDist(go, 5.0f))
                        {
                            run.usedBoosts.insert({ kv.first, g });
                            if (race->speedSpell)
                                p->CastSpell(p, race->speedSpell, true);
                        }
            if (winner.IsEmpty() && std::all_of(kv.second.begin(), kv.second.end(), [](bool b) { return b; }))
                winner = kv.first;
        }
        if (!winner.IsEmpty())
        {
            if (Player* p = ObjectAccessor::GetPlayer(*me, winner))
            {
                me->Yell(Acore::StringFormat("{} has won the race!", p->GetName()), LANG_UNIVERSAL);
                if (race->winQuest)
                    p->AreaExploredOrEventHappens(race->winQuest);
            }
            End(*race, run, true);
        }
    }
};

class npc_temucraft_lostlands_race_manager : public CreatureScript
{
public:
    npc_temucraft_lostlands_race_manager() : CreatureScript("npc_temucraft_lostlands_race_manager") { }

    CreatureAI* GetAI(Creature* c) const override { return new npc_temucraft_lostlands_race_managerAI(c); }

    static Race const* RaceOf(Creature* c)
    {
        auto itr = sRaceByManager.find(c->GetEntry());
        if (itr == sRaceByManager.end())
            return nullptr;
        auto r = sRaces.find(itr->second);
        return r == sRaces.end() ? nullptr : &r->second;
    }

    static bool CanRace(Player* p, uint32 quest, uint32 prereq)
    {
        return quest && p->GetQuestStatus(quest) == QUEST_STATUS_INCOMPLETE && (!prereq || p->GetQuestRewardStatus(prereq));
    }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        ClearGossipMenuFor(player);
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());
        if (Race const* race = RaceOf(creature); race && RunOf(race->id))
        {
            RaceRun& run = *RunOf(race->id);
            if (run.queue.count(player->GetGUID()))
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, TemucraftModuleText("mod-temucraft-lostlands", player, 7, "I want to leave the race queue."), GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 3);
            else if (!run.running && !Queued(player))
            {
                if (CanRace(player, race->questA, race->prereqA))
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, TemucraftModuleText("mod-temucraft-lostlands", player, 8, "I'll race for the goblins."), GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);
                if (CanRace(player, race->questB, race->prereqB))
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, TemucraftModuleText("mod-temucraft-lostlands", player, 9, "I'll race for the gnomes."), GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 2);
            }
        }
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        CloseGossipMenuFor(player);
        Race const* race = RaceOf(creature);
        RaceRun* runPtr = race ? RunOf(race->id) : nullptr;
        if (!runPtr)
            return true;
        RaceRun& run = *runPtr;

        if (action == GOSSIP_ACTION_INFO_DEF + 3)
            run.queue.erase(player->GetGUID());
        else if (!run.running)
        {
            run.queue.insert(player->GetGUID());
            uint32 waiting = run.queue.size();
            creature->Whisper(waiting >= race->requiredPlayers ? "Get ready, the race is about to start!" :
                Acore::StringFormat("You're signed up. Waiting for {} more racer(s).", race->requiredPlayers - waiting), LANG_UNIVERSAL, player);
        }
        return true;
    }
};

struct npc_temucraft_lostlands_race_sheepAI : public ScriptedAI
{
    npc_temucraft_lostlands_race_sheepAI(Creature* c) : ScriptedAI(c) { }
    uint32 timer = 250;
    bool done = false;

    void UpdateAI(uint32 diff) override
    {
        if (done)
            return;
        if (timer > diff) { timer -= diff; return; }
        timer = 250;
        for (auto const& kv : sRuns)
        {
            auto race = sRaces.find(kv.first);
            if (!kv.second.running || race == sRaces.end())
                continue;
            for (ObjectGuid const& guid : kv.second.queue)
                if (Player* p = ObjectAccessor::GetPlayer(*me, guid))
                    if (p->IsWithinDist(me, 3.0f))
                    {
                        if (race->second.slowSpell)
                            p->AddAura(race->second.slowSpell, p);
                        if (race->second.explodeSpell)
                            me->CastSpell(me, race->second.explodeSpell, true);
                        done = true;
                        me->DespawnOrUnsummon(1s);
                        return;
                    }
        }
    }
};

class npc_temucraft_lostlands_race_sheep : public CreatureScript
{
public:
    npc_temucraft_lostlands_race_sheep() : CreatureScript("npc_temucraft_lostlands_race_sheep") { }
    CreatureAI* GetAI(Creature* c) const override { return new npc_temucraft_lostlands_race_sheepAI(c); }
};

// ====================================================================== rest objects
struct go_temucraft_lostlands_restAI : public GameObjectAI
{
    go_temucraft_lostlands_restAI(GameObject* go) : GameObjectAI(go) { }
    uint32 timer = 1000;

    void UpdateAI(uint32 diff) override
    {
        if (timer > diff) { timer -= diff; return; }
        timer = 1000;
        std::list<Player*> players;
        PlayersNear(me, players, sRestRadius);
        for (Player* p : players)
            if (p->IsAlive() && p->GetLevel() < sWorld->getIntConfig(CONFIG_MAX_PLAYER_LEVEL))
                p->SetRestBonus(p->GetRestBonus() + p->GetUInt32Value(PLAYER_NEXT_LEVEL_XP) * sRestRate);
    }
};

class go_temucraft_lostlands_rest : public GameObjectScript
{
public:
    go_temucraft_lostlands_rest() : GameObjectScript("go_temucraft_lostlands_rest") { }
    GameObjectAI* GetAI(GameObject* go) const override { return new go_temucraft_lostlands_restAI(go); }
};

// ====================================================================== gardening
class go_temucraft_lostlands_planter : public GameObjectScript
{
public:
    go_temucraft_lostlands_planter() : GameObjectScript("go_temucraft_lostlands_planter") { }

    bool OnGossipHello(Player* player, GameObject* go) override
    {
        ClearGossipMenuFor(player);
        uint32 i = 0;
        for (GardenSeed const& s : sSeeds)
        {
            if (s.planter == go->GetEntry() && player->HasItemCount(s.item, 1))
                AddGossipItemFor(player, GOSSIP_ICON_DOT, s.text, GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + i);
            ++i;
        }
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, GameObject* go, uint32 /*sender*/, uint32 action) override
    {
        CloseGossipMenuFor(player);
        uint32 i = action - GOSSIP_ACTION_INFO_DEF;
        if (i >= sSeeds.size() || !player->HasItemCount(sSeeds[i].item, 1))
            return true;
        GardenSeed const& seed = sSeeds[i];
        auto stage = sStages.find(seed.firstStage);
        player->DestroyItemCount(seed.item, 1, true);
        go->SummonGameObject(seed.firstStage, go->GetPositionX(), go->GetPositionY(), go->GetPositionZ() + 0.4f, 0, 0, 0, 0, 0,
            stage != sStages.end() && stage->second.seconds ? stage->second.seconds + 60 : 3600);
        return true;
    }
};

struct go_temucraft_lostlands_growAI : public GameObjectAI
{
    go_temucraft_lostlands_growAI(GameObject* go) : GameObjectAI(go) { }
    uint32 timer = 0;
    bool grown = false;

    void UpdateAI(uint32 diff) override
    {
        if (grown)
            return;
        auto itr = sStages.find(me->GetEntry());
        if (itr == sStages.end() || itr->second.kind != 0)
            return;
        if (!timer)
            timer = std::max<uint32>(itr->second.seconds, 5) * IN_MILLISECONDS;
        if (timer > diff) { timer -= diff; return; }
        grown = true;
        me->SummonGameObject(itr->second.next, me->GetPositionX(), me->GetPositionY(), me->GetPositionZ(), 0, 0, 0, 0, 0, 300);
        me->DespawnOrUnsummon();
    }
};

class go_temucraft_lostlands_grow : public GameObjectScript
{
public:
    go_temucraft_lostlands_grow() : GameObjectScript("go_temucraft_lostlands_grow") { }
    GameObjectAI* GetAI(GameObject* go) const override { return new go_temucraft_lostlands_growAI(go); }
};

class go_temucraft_lostlands_grow_care : public GameObjectScript
{
public:
    go_temucraft_lostlands_grow_care() : GameObjectScript("go_temucraft_lostlands_grow_care") { }

    bool OnGossipHello(Player* player, GameObject* go) override
    {
        auto itr = sStages.find(go->GetEntry());
        if (itr == sStages.end() || itr->second.kind != 1)
            return false;
        GardenStage const& st = itr->second;
        if (st.item && !player->HasItemCount(st.item, 1))
        {
            ChatHandler(player->GetSession()).SendSysMessage(st.missing.empty() ? TemucraftModuleText("mod-temucraft-lostlands", player->GetSession(), 10, "You don't have what this plant needs." ) : st.missing);
            return true;
        }
        if (st.item)
            player->DestroyItemCount(st.item, 1, true);
        auto next = sStages.find(st.next);
        uint32 life = st.harvest ? 300 : (next != sStages.end() && next->second.seconds ? next->second.seconds + 60 : 900);
        go->SummonGameObject(st.next, go->GetPositionX(), go->GetPositionY(), go->GetPositionZ(), 0, 0, 0, 0, 0, life);
        go->DespawnOrUnsummon();
        return true;
    }
};

// ====================================================================== exploration objectives
struct go_temucraft_lostlands_exploreAI : public GameObjectAI
{
    go_temucraft_lostlands_exploreAI(GameObject* go) : GameObjectAI(go) { }
    uint32 timer = 2500;

    void UpdateAI(uint32 diff) override
    {
        if (timer > diff) { timer -= diff; return; }
        timer = 2500;
        auto itr = sExplore.find(me->GetEntry());
        if (itr == sExplore.end())
            return;
        float radius = 0.0f;
        for (Explore const& e : itr->second)
            radius = std::max(radius, e.radius);
        std::list<Player*> players;
        PlayersNear(me, players, radius);
        for (Player* p : players)
            for (Explore const& e : itr->second)
                if (p->IsAlive() && p->GetQuestStatus(e.quest) == QUEST_STATUS_INCOMPLETE && p->IsWithinDist(me, e.radius))
                    p->KilledMonsterCredit(e.credit);
    }
};

class go_temucraft_lostlands_explore : public GameObjectScript
{
public:
    go_temucraft_lostlands_explore() : GameObjectScript("go_temucraft_lostlands_explore") { }
    GameObjectAI* GetAI(GameObject* go) const override { return new go_temucraft_lostlands_exploreAI(go); }
};

// ====================================================================== teleporters and token vendors
class npc_temucraft_lostlands_teleporter : public CreatureScript
{
public:
    npc_temucraft_lostlands_teleporter() : CreatureScript("npc_temucraft_lostlands_teleporter") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        ClearGossipMenuFor(player);
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());
        auto itr = sTeleports.find(creature->GetEntry());
        if (itr != sTeleports.end())
            for (uint32 i = 0; i < itr->second.size(); ++i)
                if (!itr->second[i].quest || player->GetQuestRewardStatus(itr->second[i].quest))
                    AddGossipItemFor(player, GOSSIP_ICON_TAXI, itr->second[i].text, GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + i);
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        CloseGossipMenuFor(player);
        auto itr = sTeleports.find(creature->GetEntry());
        uint32 i = action - GOSSIP_ACTION_INFO_DEF;
        if (itr != sTeleports.end() && i < itr->second.size())
        {
            Teleport const& t = itr->second[i];
            player->TeleportTo(t.map, t.x, t.y, t.z, t.o);
        }
        return true;
    }
};

class npc_temucraft_lostlands_token_vendor : public CreatureScript
{
public:
    npc_temucraft_lostlands_token_vendor() : CreatureScript("npc_temucraft_lostlands_token_vendor") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        ClearGossipMenuFor(player);
        if (creature->IsVendor())
            AddGossipItemFor(player, GOSSIP_ICON_VENDOR, TemucraftModuleText("mod-temucraft-lostlands", player, 11, "Let me browse your goods."), GOSSIP_SENDER_MAIN, GOSSIP_ACTION_TRADE);
        auto itr = sTokenBuffs.find(creature->GetEntry());
        if (itr != sTokenBuffs.end())
            for (uint32 i = 0; i < itr->second.size(); ++i)
                AddGossipItemFor(player, GOSSIP_ICON_TRAINER, itr->second[i].text, GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + i);
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        if (action == GOSSIP_ACTION_TRADE)
        {
            player->GetSession()->SendListInventory(creature->GetGUID());
            return true;
        }
        CloseGossipMenuFor(player);
        auto itr = sTokenBuffs.find(creature->GetEntry());
        uint32 i = action - GOSSIP_ACTION_INFO_DEF;
        if (itr == sTokenBuffs.end() || i >= itr->second.size())
            return true;
        TokenBuff const& b = itr->second[i];
        if (!player->HasItemCount(b.item, b.count))
        {
            ChatHandler(player->GetSession()).SendNotification(TemucraftModuleText("mod-temucraft-lostlands", player->GetSession(), 12, "You don't have enough tokens."));
            return true;
        }
        player->DestroyItemCount(b.item, b.count, true);
        player->CastSpell(player, b.spell, true);
        return true;
    }
};

class TemucraftLostLandsScripts_World : public WorldScript
{
public:
    TemucraftLostLandsScripts_World() : WorldScript("TemucraftLostLandsScripts_World", { WORLDHOOK_ON_AFTER_CONFIG_LOAD, WORLDHOOK_ON_STARTUP }) { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        sRestRadius = sConfigMgr->GetOption<float>("Temucraft.LostLands.RestRadius", 10.0f);
        sRestRate = sConfigMgr->GetOption<float>("Temucraft.LostLands.RestRate", 0.000575f);
    }

    void OnStartup() override { Load(); }
};

void ReloadTemucraftLostLandsScripts() { Load(); }

void AddTemucraftLostLandsScriptsScripts()
{
    new npc_temucraft_lostlands_caster();
    new npc_temucraft_lostlands_rental();
    new npc_temucraft_lostlands_race_manager();
    new npc_temucraft_lostlands_race_sheep();
    new go_temucraft_lostlands_rest();
    new go_temucraft_lostlands_planter();
    new go_temucraft_lostlands_grow();
    new go_temucraft_lostlands_grow_care();
    new go_temucraft_lostlands_explore();
    new npc_temucraft_lostlands_teleporter();
    new npc_temucraft_lostlands_token_vendor();
    new TemucraftLostLandsScripts_World();
}
