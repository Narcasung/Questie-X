local function read(path)
    local f = assert(io.open(path, "r"), "cannot open " .. path)
    local content = f:read("*a")
    f:close()
    return content
end

describe("QuestieCompat completed quest refresh", function()
    local compat = read("Compat/Compat.lua")

    it("clears the completed-quest table before repopulating it", function()
        local getQuestsStart = assert(compat:find("function QuestieCompat.GetQuestsCompleted()", 1, true))
        local getQuestsEnd = assert(compat:find("-- Fires when the data requested by QueryQuestsCompleted() is available.", getQuestsStart, true))
        local getQuests = compat:sub(getQuestsStart, getQuestsEnd)

        local clearPos = assert(getQuests:find("ClearQuestCompleteTable(Questie.db.char.complete)", 1, true))
        local queryPos = assert(getQuests:find("QueryQuestsCompleted()", 1, true))
        assert.is_true(clearPos < queryPos)
    end)

    it("clears stale completions again when the server response arrives", function()
        local eventStart = assert(compat:find("function QuestieCompat:QUEST_QUERY_COMPLETE(event)", 1, true))
        local eventEnd = assert(compat:find("-- https://wowpedia.fandom.com/wiki/API_IsQuestFlaggedCompleted", eventStart, true))
        local eventBlock = compat:sub(eventStart, eventEnd)

        local clearPos = assert(eventBlock:find("ClearQuestCompleteTable(Questie.db.char.complete)", 1, true))
        local fillPos = assert(eventBlock:find("GetQuestsCompleted(Questie.db.char.complete)", 1, true))

        assert.is_true(clearPos < fillPos)
    end)
end)
