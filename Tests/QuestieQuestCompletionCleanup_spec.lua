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
        assert.is_true(has(helper, "QuestieMap:UnloadQuestFrames(quest.Id)"))
    end)
end)
