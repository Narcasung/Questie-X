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
        assert.is_true(has(priv, "dataSourceMode == \"none\" or dataSourceMode == \"learner\""))
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

    it("returns learner object data when static queries are unavailable", function()
        local obj = QuestieDB:GetObject(9002)
        assert.is_table(obj)
        assert.equals("Learner Cache", obj.name)
        assert.is_table(obj.spawns)
        assert.equals(44, obj.zoneID)
    end)
end)
