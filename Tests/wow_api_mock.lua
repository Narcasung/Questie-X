-- Tests/wow_api_mock.lua
-- Minimal mock of World of Warcraft API for Busted unit tests

_G = _G or {}

local function _bit_fallback(op, a, b)
    local ok, bit32lib = pcall(function() return bit32 end)
    if ok and bit32lib then
        return bit32lib[op](a, b)
    end

    -- Minimal fallback for the few bitwise operations Questie touches in tests.
    local result, bitval = 0, 1
    while a > 0 or (b and b > 0) do
        local abit = a % 2
        local bbit = b and (b % 2) or 0
        local out = 0
        if op == "band" then
            out = (abit == 1 and bbit == 1) and 1 or 0
        elseif op == "bor" then
            out = (abit == 1 or bbit == 1) and 1 or 0
        elseif op == "bxor" then
            out = ((abit == 1) ~= (bbit == 1)) and 1 or 0
        end
        if out == 1 then
            result = result + bitval
        end
        a = math.floor(a / 2)
        if b then
            b = math.floor(b / 2)
        end
        bitval = bitval * 2
    end
    return result
end

_G.bit = _G.bit or {
    band = function(a, b) return _bit_fallback("band", a, b) end,
    bor = function(a, b) return _bit_fallback("bor", a, b) end,
    bxor = function(a, b) return _bit_fallback("bxor", a, b) end,
    lshift = function(a, b) return a * (2 ^ b) end,
    rshift = function(a, b) return math.floor(a / (2 ^ b)) end,
    arshift = function(a, b) return math.floor(a / (2 ^ b)) end,
}

-- Mock Globals
_G.Questie = {
    DEBUG_LEARNER = "LEARNER",
    DEBUG_DEVELOP = "DEVELOP",
    db = {
        global = {
            learnedData = {
                npcs = {},
                quests = {},
                items = {},
                objects = {},
                settings = {
                    learnQuests = true,
                    learnNPCs = true,
                    learnItems = true,
                    learnObjects = true,
                }
            }
        },
        profile = {
            learnedData = {
                settings = {
                    learnQuests = true,
                    learnNPCs = true,
                }
            }
        }
    },
    dbLearner = {
        global = {
            npcs = {},
            quests = {},
            items = {},
            objects = {},
            settings = {
                enabled = true,
                prioritizeMyData = true,
                minConfidencePins = 2,
            },
        }
    },
    Debug = function(self, level, ...)
        -- print("[" .. tostring(level) .. "]", ...)
    end,
    Print = function(self, ...)
        -- print(...)
    end,
    Error = function(self, ...)
        -- print("[ERROR]", ...)
    end
}

_G.QuestieLoader = {
    ImportModule = function(self, name)
        if name == "QuestieDB" then return _G.QuestieDB end
        if name == "QuestieQuest" then return _G.QuestieQuest end
        if name == "QuestiePlayer" then return _G.QuestiePlayer end
        if name == "QuestLogCache" then return _G.QuestLogCache end
        if name == "QuestieLib" then return {} end
        if name == "QuestieCompat" then return _G.QuestieCompat end
        if name == "ZoneDB" then return _G.ZoneDB end
        if name == "l10n" then return _G.l10n end
        if name == "QuestieTooltips" then return _G.QuestieTooltips end
        return {}
    end,
    CreateModule = function(self, name)
        _G[name] = name == "QuestiePlayer" and { private = {} } or {}
        return _G[name]
    end
}

_G.QuestieDB = {
    npcDataOverrides = {},
    objectDataOverrides = {},
    questDataOverrides = {},
    itemDataOverrides = {},
    QueryNPCSingle = function() return nil end,
    GetQuest = function() return nil end,
}

_G.QuestieQuest = {}

_G.QuestieCompat = {
    GetCurrentPlayerPosition = function() return 1, 0.5, 0.5 end,
    C_QuestLog = {
        IsQuestFlaggedCompleted = function() return false end,
    },
    GetQuestLogTitle = function(index)
        return "Test Quest", 1, nil, false, nil, nil, nil, 123
    end,
    GetQuestTagInfo = function() return nil end,
    IsPlayerSpell = function() return false end,
    IsSpellKnownOrOverridesKnown = function() return false end,
    IsQuestFlaggedCompleted = function() return false end,
    C_Timer = {
        After = function(delay, fn) fn() end,
        NewTicker = function(delay, fn) return { Cancel = function() end } end,
    },
}

_G.QuestiePlayer = {
    GetPlayerLevel = function() return 70 end,
}

_G.QuestLogCache = {
    GetQuestID = function() return 123 end,
    GetQuest = function(_, questId)
        return nil
    end,
    GetQuestObjectives = function(self, questId)
        return _G._mock_questObjectives or {
            { text = "Slay 10 felboars", Icon = 136006, objectiveType = "slay" },
            { text = "Collect 5 herbs", Icon = 134217, objectiveType = "loot" },
        }
    end,
}

_G.ZoneDB = {
    zoneIDs = setmetatable({
        ICECROWN = 1,
    }, {
        __index = function()
            return 1
        end,
    }),
    GetAreaIdByUiMapId = function(self, uiMapId)
        -- Sunstrider Isle (1241) → Eversong Woods (3430)
        if uiMapId == 1241 then return 3430 end
        return nil
    end,
}

_G.l10n = {
    GetAreaId = function(self)
        return 3430
    end,
}

_G.QuestieTooltips = {
    RegisterObjectiveTooltip = function(self, questId, identifier, data)
        _G._lastRegisteredTooltip = { questId = questId, identifier = identifier, data = data }
    end,
}

_G.C_Map = {
    GetBestMapForUnit = function(unit)
        return _G._mock_uiMapId or 530
    end,
    GetPlayerMapPosition = function(uiMapId, unit)
        return 0.5, 0.5
    end,
}

-- string.trim is a WoW API extension
_G.string.trim = function(s)
    if s then return s:match("^%s*(.-)%s*$") or "" end
    return ""
end

_G.GetNumQuestLogEntries = function() return 1 end

_G.GetTime = function() return os.time() end
_G.time = os.time
_G.floor = math.floor
_G.UnitName = function(unit) return "TestUnit" end
_G.UnitLevel = function(unit) return 70 end
_G.UnitGUID = function(unit) return "Creature-0-1234-567-89-1000-0000000000" end
_G.UnitFactionGroup = function(unit) return "Alliance" end
_G.GetRealZoneText = function() return "Shadowmoon Valley" end
_G.GetInstanceInfo = function() return "Shadowmoon Valley", nil, nil, nil, nil, nil, nil, 530 end
_G.CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
_G.GetPlayerMapPosition = function(unit)
    return 0.5, 0.5
end

return _G
