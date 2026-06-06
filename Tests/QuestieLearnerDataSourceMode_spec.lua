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
        assert.is_true(has(priv, "local strictLearnerOnly = dataSourceMode == \"learner\""))
        assert.is_true(has(priv, "local name = strictLearnerOnly and nil or QuestieDB.QueryNPCSingle(npcId, \"name\")"))
        assert.is_true(has(priv, "local spawns = strictLearnerOnly and {} or QuestieDB.QueryNPCSingle(npcId, \"spawns\")"))
        assert.is_true(has(priv, "local name = strictLearnerOnly and nil or QuestieDB.QueryObjectSingle(objectId, \"name\")"))
        assert.is_true(has(priv, "local spawns = strictLearnerOnly and {} or QuestieDB.QueryObjectSingle(objectId, \"spawns\")"))
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
