local function read(path)
    local f = assert(io.open(path, "r"), "cannot open " .. path)
    local content = f:read("*a")
    f:close()
    return content
end

local function has(content, needle)
    return content:find(needle, 1, true) ~= nil
end

describe("Blizzard objective POI suppression", function()
    local compat = read("Compat/Compat.lua")
    local init = read("Modules/QuestieInit.lua")
    local iconOptions = read("Modules/Options/IconsTab/QuestieOptionsIcons.lua")
    local questieMenu = read("Modules/QuestieMenu/QuestieMenu.lua")

    it("suppresses native POI buttons that duplicate visible or intentionally hidden Questie quest icons", function()
        local helperStart = assert(compat:find("function QuestieCompat.HasVisibleQuestiePOIForQuest", 1, true))
        local helperEnd = assert(compat:find("-- https://wowpedia.fandom.com/wiki/API_GetQuestLink", helperStart, true))
        local helper = compat:sub(helperStart, helperEnd)

        assert.is_true(has(compat, "complete = true"))
        assert.is_true(has(compat, "monster = true"))
        assert.is_true(has(compat, "object = true"))
        assert.is_true(has(compat, "item = true"))
        assert.is_true(has(compat, "event = true"))
        assert.is_true(has(compat, "frame:ShouldBeHidden()"))
        assert.is_true(has(helper, "QuestieMap.questIdFrames and QuestieMap.questIdFrames[questId]"))
        assert.is_true(has(helper, "poiButton:Hide()"))
        assert.is_true(has(helper, "function QuestieCompat.ShouldSuppressHiddenQuestieAvailablePOI"))
        assert.is_true(has(helper, "profile.hideRepeatableBelowMaxLevel"))
        assert.is_true(has(helper, "QuestieDB.IsBoardQuest"))
        assert.is_true(has(helper, "profile.showDungeonQuests"))
        assert.is_true(has(helper, "questTagId == 81"))
        assert.is_true(has(helper, "QuestieCompat.HasVisibleQuestiePOIForQuest(questId) or QuestieCompat.ShouldSuppressHiddenQuestieAvailablePOI(questId, poiButton)"))
    end)

    it("hooks Blizzard POI display without globally disabling native POIs", function()
        local helperStart = assert(compat:find("function QuestieCompat.InitializeBlizzardPOISuppression", 1, true))
        local helperEnd = assert(compat:find("-- https://wowpedia.fandom.com/wiki/API_GetQuestLink", helperStart, true))
        local helper = compat:sub(helperStart, helperEnd)

        assert.is_true(has(helper, "hooksecurefunc(\"QuestPOI_DisplayButton\""))
        assert.is_true(has(helper, "hooksecurefunc(\"QuestPOI_SelectButton\""))
        assert.is_true(has(compat, "\"poi%s%s_%d\""))
        assert.is_false(has(compat, "SetCVar(\"questPOI\", useQuestieObjectives and \"0\" or \"1\")"))
    end)

    it("initializes duplicate suppression but leaves objective toggles in control of Questie icons only", function()
        assert.is_true(has(init, "QuestieCompat.InitializeBlizzardPOISuppression()"))
        assert.is_false(has(iconOptions, "QuestieCompat.SyncBlizzardObjectivePOIs"))
        assert.is_true(has(iconOptions, "QuestieCompat.EnableBlizzardObjectivePOIs()"))
        assert.is_false(has(questieMenu, "QuestieCompat.SyncBlizzardObjectivePOIs"))
    end)
end)
