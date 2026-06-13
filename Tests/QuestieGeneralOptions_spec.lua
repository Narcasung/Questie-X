local function read(path)
    local f = assert(io.open(path, "r"), "cannot open " .. path)
    local c = f:read("*a")
    f:close()
    return c
end

local function has(content, needle)
    return string.find(content, needle, 1, true) ~= nil
end

describe("Questie general options", function()
    it("allows Instant Quest Text to be toggled even when the CVar is unset", function()
        local general = read("Modules/Options/GeneralTab/QuestieOptionsGeneral.lua")

        assert.is_true(has(general, "local function GetInstantQuestTextEnabled()"))
        assert.is_true(has(general, "local function SetInstantQuestTextEnabled(value)"))
        assert.is_true(has(general, "if not SetCVar then return end"))
        assert.is_true(has(general, "SetCVar(\"instantQuestText\", value and \"1\" or \"0\")"))
        assert.is_false(has(general, "if GetCVar(\"instantQuestText\") ~= nil then"))
    end)
end)
