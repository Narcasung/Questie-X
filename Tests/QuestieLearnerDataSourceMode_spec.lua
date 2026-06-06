local function read(path)
    local f = assert(io.open(path, "r"), "cannot open " .. path)
    local c = f:read("*a")
    f:close()
    return c
end

local function has(content, needle)
    return string.find(content, needle, 1, true) ~= nil
end

describe("QuestieLearner data source mode", function()
    it("adds a mode selector and explicit fallback options in the database tab", function()
        local dbOptions = read("Modules/Options/DatabaseTab/QuestieOptionsDatabase.lua")
        assert.is_true(has(dbOptions, "Data Source Mode"))
        assert.is_true(has(dbOptions, "auto    = l10n(\"Auto (current behavior)\")"))
        assert.is_true(has(dbOptions, "learner = l10n(\"Learner Only\")"))
        assert.is_true(has(dbOptions, "static  = l10n(\"Static Only\")"))
        assert.is_true(has(dbOptions, "none    = l10n(\"Neither (base DB only)\")"))
        assert.is_true(has(dbOptions, "local function GetLearnerSelectedMode()"))
        assert.is_true(has(dbOptions, "get   = function() return GetLearnerSelectedMode() end"))
        assert.is_true(has(dbOptions, "Runtime mode:"))
    end)

    it("defaults the learner mode to auto and exposes the live refresh hook", function()
        local learner = read("Modules/QuestieLearner.lua")
        local defaults = read("Modules/Options/QuestieOptionsDefaults.lua")
        assert.is_true(has(defaults, "dataSourceMode = \"auto\""))
        assert.is_true(has(learner, "function QuestieLearner:GetDataSourceMode()"))
        assert.is_true(has(learner, "function QuestieLearner:IsLearnerLiveEnabled()"))
        assert.is_true(has(learner, "function QuestieLearner:ApplyDataSourceMode()"))
    end)

    it("gates static suppression and tooltip fallback on the selected mode", function()
        local quest = read("Modules/Quest/QuestieQuest.lua")
        local priv = read("Modules/Quest/QuestieQuestPrivates.lua")
        local tip = read("Modules/Tooltips/Tooltip.lua")
        assert.is_true(has(quest, "dataSourceMode == \"auto\" or dataSourceMode == \"learner\""))
        assert.is_true(has(priv, "dataSourceMode == \"none\""))
        assert.is_true(has(tip, "mode ~= \"static\" and mode ~= \"none\""))
    end)

    it("allows learner mode to draw pins from a single learned spawn when needed", function()
        local priv = read("Modules/Quest/QuestieQuestPrivates.lua")
        assert.is_true(has(priv, "local staticHasSpawns = spawns and next(spawns) ~= nil"))
        assert.is_true(has(priv, "local canUseLearnerSpawns = dataSourceMode == \"learner\""))
        assert.is_true(has(priv, "or not staticHasSpawns"))
    end)

    it("keeps learner-only pin builders off the static DB lookup path", function()
        local priv = read("Modules/Quest/QuestieQuestPrivates.lua")
        assert.is_true(has(priv, "local npcData = QuestieDB:GetNPC(npcId)"))
        assert.is_true(has(priv, "local name = npcData and npcData.name or nil"))
        assert.is_true(has(priv, "local spawns = npcData and npcData.spawns or {}"))
        assert.is_true(has(priv, "local rank = npcData and npcData.rank"))
        assert.is_true(has(priv, "local objectData = QuestieDB:GetObject(objectId)"))
        assert.is_true(has(priv, "local name = objectData and objectData.name or nil"))
        assert.is_true(has(priv, "local spawns = objectData and objectData.spawns or {}"))
    end)

    it("maps object objectives from learner object captures before refresh", function()
        local learner = read("Modules/QuestieLearner.lua")
        assert.is_true(has(learner, "_Learner.recentObjects = _Learner.recentObjects or {}"))
        assert.is_true(has(learner, "function QuestieLearner:LearnQuestObjectiveObject(questId, objectId, objText, objectiveIndex)"))
        assert.is_true(has(learner, "objType == \"object\""))
        assert.is_true(has(learner, "self:LearnQuestObjectiveObject(questId, objectId, objText, j)"))
        assert.is_true(has(learner, "_Learner.recentObjects[objectId]"))
    end)
end)

describe("QuestieLearner missing base DB fallback", function()
    local QuestieLearner

    before_each(function()
        dofile("Tests/wow_api_mock.lua")
        Questie.dbLearner.global.settings.enabled = false
        Questie.dbLearner.global.settings.dataSourceMode = "static"
        QuestieDB.baseDatabaseMissing = true
        QuestieDB.IsBaseDatabaseMissing = function()
            return true
        end
        QuestieLearner = dofile("Modules/QuestieLearner.lua")
    end)

    it("forces learner mode and live recording when the base DB is missing", function()
        assert.equals("learner", QuestieLearner:GetDataSourceMode())
        assert.is_true(QuestieLearner:IsEnabled())
    end)
end)

describe("QuestieLearner learner mode activation", function()
    local QuestieLearner

    before_each(function()
        dofile("Tests/wow_api_mock.lua")
        Questie.dbLearner.global.settings.enabled = false
        Questie.dbLearner.global.settings.dataSourceMode = "learner"
        QuestieDB.baseDatabaseMissing = false
        QuestieDB.IsBaseDatabaseMissing = function()
            return false
        end
        QuestieLearner = dofile("Modules/QuestieLearner.lua")
    end)

    it("re-enables learner recording when learner mode is applied", function()
        QuestieLearner:ApplyDataSourceMode()
        assert.is_true(Questie.dbLearner.global.settings.enabled)
        assert.is_true(QuestieLearner:IsEnabled())
    end)
end)

describe("QuestieLearner quest accept resolution", function()
    local QuestieLearner
    local originalGetNumQuestLogEntries
    local originalGetQuestLogSelection
    local originalGetQuestLogTitle
    local originalGetQuestIDFromLogIndex
    local originalGetQuestLogIndexByID
    local originalLearnQuest
    local originalUnitGUID

    before_each(function()
        dofile("Tests/wow_api_mock.lua")
        Questie.dbLearner.global.settings.enabled = true
        Questie.dbLearner.global.settings.dataSourceMode = "learner"

        originalGetNumQuestLogEntries = _G.GetNumQuestLogEntries
        originalGetQuestLogSelection = QuestieCompat.GetQuestLogSelection
        originalGetQuestLogTitle = QuestieCompat.GetQuestLogTitle
        originalGetQuestIDFromLogIndex = QuestieCompat.GetQuestIDFromLogIndex
        originalGetQuestLogIndexByID = QuestieCompat.GetQuestLogIndexByID
        originalUnitGUID = _G.UnitGUID

        _G.GetNumQuestLogEntries = function()
            return 1
        end
        _G.UnitGUID = function()
            return nil
        end

        QuestieCompat.GetQuestLogSelection = function()
            return 1
        end

        QuestieCompat.GetQuestLogTitle = function(index)
            if index == 1 then
                return "Real Quest", 10, nil, false, nil, nil, nil, 4321
            end
            return nil
        end

        QuestieCompat.GetQuestIDFromLogIndex = function(index)
            if index == 1 then
                return 4321
            end
            return nil
        end

        QuestieCompat.GetQuestLogIndexByID = function(questId)
            if questId == 4321 then
                return 1
            end
            return nil
        end

        QuestieLearner = dofile("Modules/QuestieLearner.lua")
        originalLearnQuest = QuestieLearner.LearnQuest
    end)

    after_each(function()
        QuestieLearner.LearnQuest = originalLearnQuest
        _G.GetNumQuestLogEntries = originalGetNumQuestLogEntries
        _G.UnitGUID = originalUnitGUID
        QuestieCompat.GetQuestLogSelection = originalGetQuestLogSelection
        QuestieCompat.GetQuestLogTitle = originalGetQuestLogTitle
        QuestieCompat.GetQuestIDFromLogIndex = originalGetQuestIDFromLogIndex
        QuestieCompat.GetQuestLogIndexByID = originalGetQuestLogIndexByID
    end)

    it("uses a real quest log entry instead of raw accepted event args", function()
        local capturedQuestId = nil
        QuestieLearner.LearnQuest = function(self, questId, data)
            capturedQuestId = questId
        end

        QuestieLearner:OnQuestAccepted(615514513, nil)

        assert.equals(4321, capturedQuestId)
    end)

    it("refuses impossible quest ids when they do not resolve to the quest log", function()
        local capturedQuestId = nil
        QuestieCompat.GetQuestLogSelection = function()
            return nil
        end
        QuestieCompat.GetQuestLogTitle = function()
            return nil
        end
        QuestieCompat.GetQuestIDFromLogIndex = function()
            return nil
        end
        QuestieCompat.GetQuestLogIndexByID = function()
            return nil
        end
        QuestieLearner.LearnQuest = function(self, questId, data)
            capturedQuestId = questId
        end

        QuestieLearner:OnQuestAccepted(615514513, nil)

        assert.is_nil(capturedQuestId)
    end)
end)

describe("QuestieLearner GUID and loot learning", function()
    local QuestieLearner
    local originalGetNPC
    local originalGetItemInfo
    local originalLearnItem
    local originalLearnItemDrop

    before_each(function()
        dofile("Tests/wow_api_mock.lua")
        Questie.dbLearner.global.settings.enabled = true
        Questie.dbLearner.global.settings.dataSourceMode = "learner"
        Questie.dbLearner.global.settings.learnItems = true
        Questie.dbLearner.global.settings.learnNpcs = true

        QuestieDB.npcData = {
            [15297] = { [1] = "Arcanist Helion" },
        }
        originalGetNPC = QuestieDB.GetNPC
        QuestieDB.GetNPC = function(self, id)
            if id == 168 then
                return { name = "Something Else" }
            end
            return originalGetNPC and originalGetNPC(self, id) or nil
        end

        originalGetItemInfo = _G.GetItemInfo
        _G.GetItemInfo = function(link)
            if link == "item:20470" then
                return "Quest Token", nil, nil, 1, 1, 3, 1, nil, nil, nil, nil, 3, 1
            end
            return nil
        end
        dofile("Modules/QuestieLearner.lua")
        QuestieLearner = _G.QuestieLearner
        originalLearnItem = QuestieLearner.LearnItem
        originalLearnItemDrop = QuestieLearner.LearnItemDrop
    end)

    after_each(function()
        QuestieDB.GetNPC = originalGetNPC
        _G.GetItemInfo = originalGetItemInfo
        if QuestieLearner then
            QuestieLearner.LearnItem = originalLearnItem
            QuestieLearner.LearnItemDrop = originalLearnItemDrop
        end
    end)

    it("prefers the exact NPC name over a mismatched GUID entry id", function()
        local resolvedId, unitType = QuestieLearner:ResolveNpcIdFromGuidAndName("Creature-0-0-0-0-168-0000000000", "Arcanist Helion")
        assert.equals(15297, resolvedId)
        assert.equals("Creature", unitType)
    end)

    it("learns pending loot items once item info arrives even when class metadata is not quest-item shaped", function()
        local learnedItemId = nil
        local dropItemId = nil
        local dropNpcId = nil

        QuestieLearner.LearnItem = function(self, itemId, name, itemLevel, requiredLevel, itemClassId, itemSubClassId)
            learnedItemId = itemId
        end
        QuestieLearner.LearnItemDrop = function(self, itemId, npcId)
            dropItemId = itemId
            dropNpcId = npcId
        end

        _G.GetNumLootItems = function()
            return 1
        end
        _G.GetLootSlotInfo = function(slot)
            return nil, "Quest Token", nil, nil, 1
        end
        _G.GetLootSlotLink = function(slot)
            return "item:20470"
        end
        _G.GetLootSourceInfo = function(slot)
            return "Creature-0-0-0-0-15297-0000000000", 1
        end

        QuestieLearner:OnLootOpened()

        assert.equals(20470, learnedItemId)
        assert.is_nil(dropItemId)
        assert.is_nil(dropNpcId)
    end)
end)

describe("QuestieDB learner source fallback", function()
    before_each(function()
        dofile("Tests/wow_api_mock.lua")
        dofile("Database/QuestieDB.lua")
        dofile("Database/npcDB.lua")
        dofile("Database/objectDB.lua")
        dofile("Database/questDB.lua")
        dofile("Database/itemDB.lua")

        Questie.dbLearner.global.settings.enabled = true
        Questie.dbLearner.global.settings.dataSourceMode = "learner"
        Questie.dbLearner.global.npcs = {
            [9001] = {
                [1] = "Learner Whelp",
                [7] = {
                    [44] = {
                        { 12.3, 45.6 },
                    },
                },
                [8] = {
                    [44] = {
                        { 13.3, 46.6 },
                    },
                },
                [9] = 44,
            },
        }
        Questie.dbLearner.global.objects = {
            [9002] = {
                [1] = "Learner Cache",
                [4] = {
                    [44] = {
                        { 11.1, 22.2 },
                    },
                },
                [5] = 44,
            },
        }

        QuestieDB.QueryNPC = function() return nil end
        QuestieDB.QueryObject = function() return nil end
        QuestieDB.QueryQuest = function() return nil end
        QuestieDB.QueryItem = function() return nil end
        QuestieDB.private.npcCache = {}
        QuestieDB.private.objectCache = {}
        QuestieDB.private.questCache = {}
        QuestieDB.private.itemCache = {}
    end)

    it("returns learner NPC data when static queries are unavailable", function()
        local npc = QuestieDB:GetNPC(9001)
        assert.is_table(npc)
        assert.equals("Learner Whelp", npc.name)
        assert.is_table(npc.spawns)
        assert.is_table(npc.waypoints)
        assert.equals(44, npc.zoneID)
    end)

    it("turns learner kill evidence into NPC spawn coordinates immediately in learner mode", function()
        Questie.dbLearner.global.npcs[9003] = {
            [1] = "Learner Kill",
            [8] = {
                [101] = {
                    zoneId = 44,
                    x = 18.5,
                    y = 27.25,
                },
            },
        }

        local npc = QuestieDB:GetNPC(9003)
        assert.is_table(npc)
        assert.is_table(npc.spawns)
        assert.is_table(npc.spawns[44])
        assert.equals(1, #npc.spawns[44])
        assert.equals(18.5, npc.spawns[44][1][1])
        assert.equals(27.25, npc.spawns[44][1][2])
    end)

    it("collapses many nearby kills (distinct GUIDs) into one spawn pin", function()
        -- Five kills of respawns at the same spot: distinct GUID keys, slightly
        -- drifting player coords. This must render as ONE pin, not five.
        Questie.dbLearner.global.npcs[9005] = {
            [1] = "Respawning Boar",
            [8] = {
                [201] = { zoneId = 44, x = 50.0, y = 50.0 },
                [202] = { zoneId = 44, x = 50.4, y = 50.3 },
                [203] = { zoneId = 44, x = 49.7, y = 50.6 },
                [204] = { zoneId = 44, x = 50.9, y = 49.8 },
                [205] = { zoneId = 44, x = 50.2, y = 50.1 },
            },
        }

        local npc = QuestieDB:GetNPC(9005)
        assert.is_table(npc)
        assert.is_table(npc.spawns[44])
        assert.equals(1, #npc.spawns[44])
    end)

    it("keeps genuinely separate spawn locations as distinct pins", function()
        Questie.dbLearner.global.npcs[9006] = {
            [1] = "Field Boars",
            [8] = {
                [301] = { zoneId = 44, x = 20.0, y = 20.0 },
                [302] = { zoneId = 44, x = 20.3, y = 20.2 }, -- same spot as 301
                [303] = { zoneId = 44, x = 70.0, y = 65.0 }, -- far corner
            },
        }

        local npc = QuestieDB:GetNPC(9006)
        assert.is_table(npc)
        assert.is_table(npc.spawns[44])
        assert.equals(2, #npc.spawns[44])
    end)

    it("honors the spawn dedup radius knob (0 disables proximity merge)", function()
        Questie.dbLearner.global.settings.spawnDedupRadius = 0
        Questie.dbLearner.global.npcs[9007] = {
            [1] = "Drifting Kills",
            [8] = {
                [401] = { zoneId = 44, x = 50.0, y = 50.0 },
                [402] = { zoneId = 44, x = 50.4, y = 50.3 },
                [403] = { zoneId = 44, x = 49.7, y = 50.6 },
                [404] = { zoneId = 44, x = 50.9, y = 49.8 },
                [405] = { zoneId = 44, x = 50.2, y = 50.1 },
            },
        }

        local npc = QuestieDB:GetNPC(9007)
        assert.is_table(npc)
        assert.is_table(npc.spawns[44])
        -- With merging off, each distinct kill coordinate stays its own pin.
        assert.equals(5, #npc.spawns[44])
    end)

    it("widens merging when the dedup radius is increased", function()
        Questie.dbLearner.global.settings.spawnDedupRadius = 12
        Questie.dbLearner.global.npcs[9008] = {
            [1] = "Loose Cluster",
            [8] = {
                [501] = { zoneId = 44, x = 40.0, y = 40.0 },
                [502] = { zoneId = 44, x = 48.0, y = 46.0 }, -- ~10 away: merges at radius 12
            },
        }

        local npc = QuestieDB:GetNPC(9008)
        assert.is_table(npc)
        assert.is_table(npc.spawns[44])
        assert.equals(1, #npc.spawns[44])
    end)

    it("returns learner object data when static queries are unavailable", function()
        local obj = QuestieDB:GetObject(9002)
        assert.is_table(obj)
        assert.equals("Learner Cache", obj.name)
        assert.is_table(obj.spawns)
        assert.equals(44, obj.zoneID)
    end)
end)

describe("QuestieDB partial base DB missing", function()
    before_each(function()
        dofile("Tests/wow_api_mock.lua")
        dofile("Database/QuestieDB.lua")
    end)

    it("does not report the base DB missing when only one store failed", function()
        QuestieDB.baseDatabaseMissing = true
        QuestieDB.baseDatabaseMissingKeys = { itemData = true }
        assert.is_false(QuestieDB:IsBaseDatabaseMissing())
        assert.is_true(QuestieDB:IsStoreMissing("itemData"))
        assert.is_false(QuestieDB:IsStoreMissing("npcData"))
    end)

    it("reports the base DB missing only when every core store failed", function()
        QuestieDB.baseDatabaseMissing = true
        QuestieDB.baseDatabaseMissingKeys = {
            npcData = true, objectData = true, questData = true, itemData = true,
        }
        assert.is_true(QuestieDB:IsBaseDatabaseMissing())
    end)

    it("honors the static selection for a present store even when another is missing", function()
        QuestieDB.baseDatabaseMissing = true
        QuestieDB.baseDatabaseMissingKeys = { itemData = true }
        Questie.dbLearner.global.settings.dataSourceMode = "static"
        Questie.dbLearner.global.npcs = {
            [9100] = { [1] = "Should Not Win", [7] = { [44] = { { 1, 2 } } }, [9] = 44 },
        }
        QuestieDB.private.npcCache = {}
        local queried = false
        QuestieDB.QueryNPC = function() queried = true; return nil end

        pcall(function() QuestieDB:GetNPC(9100) end)
        assert.is_true(queried)
    end)
end)

describe("QuestieDB mode cohesion", function()
    before_each(function()
        dofile("Tests/wow_api_mock.lua")
        dofile("Database/QuestieDB.lua")
        dofile("Database/npcDB.lua")
        Questie.dbLearner.global.settings.enabled = true
        Questie.dbLearner.global.npcs = {
            [9200] = { [1] = "Learner Only NPC", [7] = { [44] = { { 5, 6 } } }, [9] = 44 },
        }
        QuestieDB.QueryNPC = function() return nil end
        QuestieDB.baseDatabaseMissing = false
        QuestieDB.baseDatabaseMissingKeys = {}
        QuestieDB.private.npcCache = {}
    end)

    it("does NOT leak learner data into static mode when the store is present", function()
        Questie.dbLearner.global.settings.dataSourceMode = "static"
        QuestieDB.private.npcCache = {}
        assert.is_nil(QuestieDB:GetNPC(9200))
    end)

    it("does NOT leak learner data into none mode when the store is present", function()
        Questie.dbLearner.global.settings.dataSourceMode = "none"
        QuestieDB.private.npcCache = {}
        assert.is_nil(QuestieDB:GetNPC(9200))
    end)

    it("DOES overlay learner data in auto mode when the static DB lacks it", function()
        Questie.dbLearner.global.settings.dataSourceMode = "auto"
        QuestieDB.private.npcCache = {}
        local npc = QuestieDB:GetNPC(9200)
        assert.is_table(npc)
        assert.equals("Learner Only NPC", npc.name)
    end)

    it("clears every cache including the zone cache on mode switch", function()
        QuestieDB.private.questCache[1] = {}
        QuestieDB.private.zoneCache[1] = {}
        QuestieDB:ClearModeCaches()
        assert.is_nil(QuestieDB.private.questCache[1])
        assert.is_nil(QuestieDB.private.zoneCache[1])
    end)
end)

describe("QuestieLearner mode switch redraw wiring", function()
    it("drives a full real-time refresh via SmoothReset, not the mis-named event handler", function()
        local function read(path)
            local f = assert(io.open(path, "r")); local c = f:read("*a"); f:close(); return c
        end
        local dbOptions = read("Modules/Options/DatabaseTab/QuestieOptionsDatabase.lua")
        assert.is_true(string.find(dbOptions, "QuestieQuest:SmoothReset()", 1, true) ~= nil)
        -- The old import name resolved to nil and silently skipped the redraw.
        assert.is_nil(string.find(dbOptions, "ImportModule(\"QuestieEventHandler\")", 1, true))
    end)
end)
