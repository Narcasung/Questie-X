describe("QuestieQuest tooltip fallback", function()
    local function read(path)
        local f = assert(io.open(path, "r"), "cannot open " .. path)
        local c = f:read("*a")
        f:close()
        return c
    end

    local function has(content, needle)
        return string.find(content, needle, 1, true) ~= nil
    end

    it("registers direct objective tooltips when special objectives have ids but no spawnList", function()
        local questieQuest = read("Modules/Quest/QuestieQuest.lua")

        assert.is_true(has(questieQuest, 'tooltipKey = "m_" .. objective.Id'))
        assert.is_true(has(questieQuest, 'tooltipKey = "o_" .. objective.Id'))
        assert.is_true(has(questieQuest, 'tooltipKey = "i_" .. objective.Id'))
        assert.is_true(has(questieQuest, 'elseif objective.Type == "killcredit" then'))
        assert.is_true(has(questieQuest, 'QuestieTooltips:RegisterObjectiveTooltip(questId, "m_" .. id, objective)'))
        assert.is_true(has(questieQuest, "objective.registeredItemTooltips = true"))
    end)
end)
