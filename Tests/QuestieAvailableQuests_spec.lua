local function read(path)
    local f = assert(io.open(path, "r"), "cannot open " .. path)
    local c = f:read("*a")
    f:close()
    return c
end

describe("Questie available quests guard", function()
    it("skips unavailable quests before touching tagInfoWasCached", function()
        local content = read("Modules/Quest/AvailableQuests.lua")
        assert.is_true(content:find("if not quest then", 1, true) ~= nil)
        assert.is_true(content:find("Skipping unavailable quest during draw", 1, true) ~= nil)
        assert.is_true(content:find("quest.tagInfoWasCached = true", 1, true) ~= nil)
    end)
end)
