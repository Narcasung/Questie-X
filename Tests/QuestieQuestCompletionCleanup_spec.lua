local function read(path)
    local f = assert(io.open(path, "r"), "cannot open " .. path)
    local content = f:read("*a")
    f:close()
    return content
end

local function has(content, needle)
    return content:find(needle, 1, true) ~= nil
end

describe("QuestieQuest completion objective pin cleanup", function()
    local questieQuest = read("Modules/Quest/QuestieQuest.lua")
    local questieMap = read("Modules/Map/QuestieMap.lua")
    local questEventHandler = read("Modules/Quest/QuestEventHandler.lua")

    it("unloads objective-owned spawned pins before clearing cached objectives", function()
        local completeStart = assert(questieQuest:find("function QuestieQuest:CompleteQuest(questId)", 1, true))
        local completeEnd = assert(questieQuest:find("---@param questId number\nfunction QuestieQuest:AbandonedQuest", completeStart, true))
        local completeQuest = questieQuest:sub(completeStart, completeEnd)
        local cleanupCall = assert(completeQuest:find("_CleanupCompletedQuestObjectivePins(quest)", 1, true))
        local clearObjectives = assert(completeQuest:find("quest.Objectives = {}", 1, true))

        assert.is_true(cleanupCall < clearObjectives)
    end)

    it("cleans standard objectives, special objectives, and registry frames", function()
        local helperStart = assert(questieQuest:find("local function _CleanupCompletedQuestObjectivePins(quest)", 1, true))
        local helperEnd = assert(questieQuest:find("---@param questId number\nfunction QuestieQuest:CompleteQuest", helperStart, true))
        local helper = questieQuest:sub(helperStart, helperEnd)

        assert.is_true(has(helper, "for objectiveIndex, objective in pairs(quest.Objectives) do"))
        assert.is_true(has(helper, "_UnloadAlreadySpawnedIcons(objective)"))
        assert.is_true(has(helper, "QuestieMap:UnloadQuestFramesForObjective(quest.Id, objectiveIndex)"))
        assert.is_true(has(helper, "for _, objective in pairs(quest.SpecialObjectives) do"))
        assert.is_true(has(helper, "QuestieMap:PurgeQuestFrames(quest.Id)"))
    end)

    it("purges quest-owned frames from HBD registries and pending draw queues", function()
        assert.is_true(has(questieMap, "function QuestieMap:PurgeQuestFrames(questId)"))
        assert.is_true(has(questieMap, "if not iconType then\n        QuestieMap:PurgeQuestFrames(questId)"))
        assert.is_true(has(questieMap, "QuestieMap._mapDrawQueue"))
        assert.is_true(has(questieMap, "QuestieMap._minimapDrawQueue"))
        assert.is_true(has(questieMap, "HBDPins.activeMinimapPins"))
        assert.is_true(has(questieMap, "HBDPins.worldmapPins"))
        assert.is_true(has(questieMap, "frame.data.Id == questId"))
    end)

    it("uses the last known complete state when fallback detects a removed quest", function()
        local fallbackStart = assert(questEventHandler:find("function _QuestEventHandler:CleanupRemovedQuestsFallback()", 1, true))
        local fallback = questEventHandler:sub(fallbackStart)

        assert.is_true(has(fallback, "local completeAtRemoval = QuestieDB.IsComplete(questId)"))
        assert.is_true(has(fallback, "local shouldComplete = wasTurnedIn or wasAlreadyComplete or completeAtRemoval == 1"))
        assert.is_true(has(fallback, "if shouldComplete then"))
    end)
end)
