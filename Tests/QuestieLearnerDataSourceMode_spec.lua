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
end)
