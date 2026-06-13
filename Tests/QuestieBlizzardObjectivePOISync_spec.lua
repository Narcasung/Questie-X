local function read(path)
    local f = assert(io.open(path, "r"), "cannot open " .. path)
    local content = f:read("*a")
    f:close()
    return content
end

local function has(content, needle)
    return content:find(needle, 1, true) ~= nil
end

describe("Blizzard objective POI sync", function()
    local compat = read("Compat/Compat.lua")
    local init = read("Modules/QuestieInit.lua")
    local iconOptions = read("Modules/Options/IconsTab/QuestieOptionsIcons.lua")
    local questieMenu = read("Modules/QuestieMenu/QuestieMenu.lua")

    it("disables native quest POIs when Questie objective icons are enabled", function()
        local helperStart = assert(compat:find("function QuestieCompat.SyncBlizzardObjectivePOIs", 1, true))
        local helperEnd = assert(compat:find("-- https://wowpedia.fandom.com/wiki/API_GetQuestLink", helperStart, true))
        local helper = compat:sub(helperStart, helperEnd)

        assert.is_true(has(helper, "SetCVar(\"questPOI\", useQuestieObjectives and \"0\" or \"1\")"))
        assert.is_true(has(helper, "WorldMapQuestShowObjectives:SetChecked(not useQuestieObjectives)"))
    end)

    it("syncs native POIs on startup and objective ownership changes", function()
        assert.is_true(has(init, "QuestieCompat.SyncBlizzardObjectivePOIs(Questie.db.profile.enableObjectives)"))
        assert.is_true(has(iconOptions, "QuestieCompat.SyncBlizzardObjectivePOIs(value)"))
        assert.is_true(has(iconOptions, "QuestieCompat.SyncBlizzardObjectivePOIs(true)"))
        assert.is_true(has(iconOptions, "QuestieCompat.SyncBlizzardObjectivePOIs(false)"))
        assert.is_true(has(questieMenu, "QuestieCompat.SyncBlizzardObjectivePOIs(value)"))
    end)
end)
