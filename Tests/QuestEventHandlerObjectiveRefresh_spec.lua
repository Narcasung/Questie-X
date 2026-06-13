local function read(path)
    local f = assert(io.open(path, "r"), "cannot open " .. path)
    local content = f:read("*a")
    f:close()
    return content
end

local function has(content, needle)
    return content:find(needle, 1, true) ~= nil
end

describe("Quest objective refresh events", function()
    local handler = read("Modules/Quest/QuestEventHandler.lua")

    it("does not depend on a later QUEST_LOG_UPDATE after QUEST_WATCH_UPDATE", function()
        local start = assert(handler:find("function _QuestEventHandler:QuestWatchUpdate", 1, true))
        local finish = assert(handler:find("local _UnitQuestLogChangedCallback", start, true))
        local body = handler:sub(start, finish)

        assert.is_true(has(handler, "_questWatchUpdateDebounceTimer"))
        assert.is_true(has(handler, "_questWatchUpdateFollowUpTimer"))
        assert.is_true(has(body, "QuestieQuest:SetObjectivesDirty(questId)"))
        assert.is_true(has(body, "state = QUEST_LOG_STATES.QUEST_ACCEPTED"))
        assert.is_true(has(body, "C_Timer.NewTimer(0.2"))
        assert.is_true(has(body, "C_Timer.NewTimer(1.0"))
        assert.is_true(has(body, "_QuestEventHandler:QuestLogUpdate()"))
    end)
end)
