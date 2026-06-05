local function read_file(path)
    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local function find_lines(content, needle)
    local lines = {}
    for line in content:gmatch("[^\r\n]+") do
        if line:find(needle, 1, true) then
            lines[#lines + 1] = line
        end
    end
    return lines
end

local function count_occurrences(content, needle)
    local count = 0
    local start = 1
    while true do
        local first, last = content:find(needle, start, true)
        if not first then
            break
        end
        count = count + 1
        start = last + 1
    end
    return count
end

describe("Questie error policy", function()
    it("routes Questie:Error through debug critical and keeps a fatal printer", function()
        local questie = read_file("Questie.lua")

        assert.is.truthy(questie:find("function Questie:Error(...)", 1, true))
        assert.is.truthy(questie:find("Questie:Debug(Questie.DEBUG_CRITICAL", 1, true))
        assert.is.truthy(questie:find("function Questie:Fatal(...)", 1, true))
        assert.is.truthy(questie:find("[FATAL]", 1, true))
    end)

    it("routes missing quest spam through debug critical", function()
        local quest = read_file("Modules/Quest/QuestieQuest.lua")
        local comms = read_file("Modules/Network/QuestieComms.lua")
        assert.are.equal(2, count_occurrences(quest, "Questie:Debug(Questie.DEBUG_CRITICAL, l10n("))
        assert.are.equal(2, count_occurrences(comms, "Questie:Debug(Questie.DEBUG_CRITICAL, l10n("))
    end)

    it("keeps startup-breaking conditions on the fatal path", function()
        local versionCheck = read_file("Modules/VersionCheck.lua")
        local init = read_file("Modules/QuestieInit.lua")
        local eventHandler = read_file("Modules/QuestieEventHandler.lua")
        local versionLines = find_lines(versionCheck, "ERROR inside NewAddon")
        local initLines = find_lines(init, "Module not loaded correctly")
        local eventLines = find_lines(eventHandler, "Config DB from saved variables")

        assert.are.equal(1, #versionLines)
        assert.are.equal(1, #initLines)
        assert.are.equal(1, #eventLines)

        assert.is.truthy(versionLines[1]:find("Questie:Fatal", 1, true))
        assert.is.truthy(initLines[1]:find("Questie:Fatal", 1, true))
        assert.is.truthy(eventLines[1]:find("Questie:Fatal", 1, true))
    end)
end)
