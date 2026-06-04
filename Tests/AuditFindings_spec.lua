-- Audit verification suite for workflow/performance-audit-2026-06-03-FULL.md (Pass 8).
--
-- These are STATIC source assertions: each test reads the actual file and checks
-- that the audit's claim still matches the source. They run in desktop Lua (no
-- WoW mock needed) and are re-runnable.
--
-- Tests in "false positives" and "structural facts" should ALWAYS pass.
-- Tests in "confirmed bugs"/"confirmed perf" are a SNAPSHOT at HEAD 581634d:
-- they pass while the finding is unfixed. When you land a fix, invert or remove
-- the matching assertion (each is tagged with its Pass-8 ID, e.g. [B1]).

local function read(path)
    local f = assert(io.open(path, "r"), "cannot open " .. path)
    local c = f:read("*a")
    f:close()
    return c
end

-- plain (non-pattern) substring search
local function has(content, needle)
    return string.find(content, needle, 1, true) ~= nil
end

-- count plain (non-pattern) occurrences
local function count(content, needle)
    local n, pos = 0, 1
    while true do
        local s, e = string.find(content, needle, pos, true)
        if not s then break end
        n = n + 1
        pos = e + 1
    end
    return n
end

local function startsWithBOM(path)
    local f = assert(io.open(path, "rb"), "cannot open " .. path)
    local head = f:read(3)
    f:close()
    return head == "\239\187\191"
end

describe("Audit Pass 8.1 - Lua 5.0 incompatibility surface", function()
    it("[8.1] raw # length operator is used in TOC-loaded files (5.0 parse error)", function()
        -- The dominant 5.0 blocker the pass-6/7 scan missed entirely.
        assert.is_true(has(read("Localization/l10n.lua"), "#args"))
        assert.is_true(has(read("Modules/Map/QuestieMap.lua"), "#mapDrawQueue"))
    end)

    it("[8.1] QuestieLib.tpack uses the ... expression (real 5.0 parse error)", function()
        assert.is_true(has(read("Modules/Libs/QuestieLib.lua"), 'n = select("#", ...), ...'))
    end)

    it("[8.1] % is NOT used as a modulo operator (codebase uses math.mod)", function()
        -- math.mod shim exists; raw % only appears in format strings.
        assert.is_true(has(read("Modules/Libs/QuestieLoader.lua"), "math.mod"))
    end)

    it("[8.1] no goto / bit32 / string.pack / utf8 in core runtime", function()
        local db = read("Database/QuestieDB.lua")
        assert.is_false(has(db, "goto "))
        assert.is_false(has(db, "bit32."))
        assert.is_false(has(db, "string.pack"))
    end)
end)

describe("Audit Pass 8.2 - corrected FALSE POSITIVES (must always pass)", function()
    it("[FP2] UnitFactionGroup('Player') capital-P is an established working pattern", function()
        -- Used across Corrections DB files that gate real entries; proves tokens
        -- are case-insensitive, so QuestieMenu.lua:114 is NOT a bug.
        assert.is_true(has(read("Database/Corrections/classicItemFixes.lua"),
            'UnitFactionGroup("Player")'))
        assert.is_true(has(read("Modules/QuestieMenu/QuestieMenu.lua"),
            'UnitFactionGroup("Player")'))
    end)

    it("[FP1] Ascension_IsScalingEnabled is declared no-arg but called with questId (harmless lint)", function()
        local lib = read("Modules/Libs/QuestieLib.lua")
        assert.is_true(has(lib, "local function Ascension_IsScalingEnabled()"))
        assert.is_true(has(lib, "Ascension_IsScalingEnabled(questId)"))
        -- Lua discards extra args; this changes no behavior. Lint only.
    end)

    it("[FP3] the select() shim exists, proving Lua 5.0 lacks select (pass-3 was wrong)", function()
        local loader = read("Modules/Libs/QuestieLoader.lua")
        assert.is_true(has(loader, "if not select then"))
        assert.is_true(has(loader, "select = function(index, ...)"))
    end)

    it("[FP5] TaskQueue is wired (NOT dead code)", function()
        assert.is_true(has(read("Questie-X.toc"), "TaskQueue.lua"))
        assert.is_nil(io.open("Questie-X-Turtle.toc", "r"))
        local qq = read("Modules/Quest/QuestieQuest.lua")
        assert.is_true(has(qq, 'ImportModule("TaskQueue")'))
        assert.is_true(has(qq, "TaskQueue:Queue("))
    end)
end)

describe("Audit Pass 8.3 - confirmed BUGS (snapshot at HEAD; invert on fix)", function()
    it("[B1] IsComplete calls GetQuest(questId) twice in one expression", function()
        assert.is_true(has(read("Database/QuestieDB.lua"),
            "QuestieDB.GetQuest(questId) and QuestieDB.GetQuest(questId).ObjectiveData"))
    end)

    it("[B2] QuestieOptionsTracker calls :Cancel() on the number fadeTickerValue", function()
        local content = read("Modules/Options/TrackerTab/QuestieOptionsTracker.lua")
        assert.is_true(count(content, "fadeTickerValue:Cancel()") >= 3)
    end)

    it("[B3] alreadySentBandaid is declared once and never wiped (unbounded)", function()
        local content = read("Modules/QuestieAnnounce.lua")
        assert.is_true(has(content, "local alreadySentBandaid = {}"))
        assert.is_false(has(content, "wipe(alreadySentBandaid)"))
        assert.equals(1, count(content, "alreadySentBandaid = {}"))
    end)

    it("[B4] factionReactions reads UnitFactionGroup at module load time", function()
        assert.is_true(has(read("Database/QuestieDB.lua"),
            'local playerFaction = UnitFactionGroup("player")'))
    end)

    it("[B5] Questie-X.toc lists QuestieSlash.lua twice", function()
        assert.equals(2, count(read("Questie-X.toc"), "QuestieSlash.lua"))
    end)

    it("[B6] correction files begin with a UTF-8 BOM", function()
        assert.is_true(startsWithBOM("Database/Corrections/tbcQuestFixes.lua"))
        assert.is_true(startsWithBOM("Database/Corrections/wotlkItemFixes.lua"))
        assert.is_true(startsWithBOM("Database/Corrections/wotlkQuestFixes.lua"))
    end)

    it("[B7] _Qframe.BaseOnUpdate is referenced but never defined (dead glow ticker)", function()
        local frame = read("Modules/FramePool/QuestieFrame.lua")
        local pool = read("Modules/FramePool/QuestieFramePool.lua")
        assert.is_true(has(frame, "_Qframe.BaseOnUpdate"))      -- assigned from
        assert.is_true(has(pool, "returnFrame.BaseOnUpdate"))   -- gated on
        -- never defined anywhere:
        assert.is_false(has(frame, "function _Qframe.BaseOnUpdate"))
        assert.is_false(has(frame, "function _Qframe:BaseOnUpdate"))
        assert.is_false(has(frame, "_Qframe.BaseOnUpdate = function"))
    end)
end)

describe("Audit Pass 8.4 - confirmed PERFORMANCE findings (snapshot)", function()
    it("[P1] QuestieComms no longer re-serializes the accumulating list inside the loop", function()
        local comms = read("Modules/Network/QuestieComms.lua")
        assert.is_false(has(comms, "string.len(QuestieSerializer:Serialize(rawQuestList)) > 200"))
        assert.is_true(has(comms, "GetSerializedPacketSize(quest)"))
    end)

    it("[P3] QuestieComms no longer front-removes its broadcast queues", function()
        local comms = read("Modules/Network/QuestieComms.lua")
        assert.is_false(has(comms, "tremove(blocks, 1)"))
        assert.is_false(has(comms, "tremove(_QuestieComms._nextBroadcastData, 1)"))
        assert.is_false(has(comms, "tremove(_QuestieComms._nextBroadcastDataV2, 1)"))
        assert.is_true(has(comms, "local function QueuePop(queue, queueState)"))
    end)

    it("[P4] QuestieLib.tunpack is recursive (slow vararg unpack)", function()
        local lib = read("Modules/Libs/QuestieLib.lua")
        assert.is_true(has(lib, "local function recursion(i)"))
        assert.is_true(has(lib, "return tbl[i], recursion(i + 1)"))
        assert.is_false(has(lib, "return unpack(tbl, 1, tbl.n)")) -- the proposed fix
    end)

    it("[P6] O(n) front-insert tinsert(t, 1, x) is used in the tooltip path", function()
        assert.is_true(has(read("Modules/Tooltips/Tooltip.lua"),
            "tinsert(tempObjectives, 1, objectiveInfo.text)"))
    end)
end)

describe("Audit Pass 9 - file-by-file findings (snapshot at HEAD)", function()
    it("[N1] bit library is used UNGUARDED in TOC files (1.12 runtime risk)", function()
        assert.is_true(has(read("Questie.lua"), "local band = bit.band"))
        assert.is_true(has(read("Database/QuestieDB.lua"), "local bitband = bit.band"))
        -- no bit shim in the compat layer:
        assert.is_false(has(read("Modules/QuestieCompat.lua"), "bit ="))
        -- ...while the vendored XXH lib DOES guard it (the contrast):
        assert.is_true(has(read("Libs/XXH_Lua_Lib/XXH_Lua_Lib.lua"), "bit and bit.band"))
    end)

    it("[N2] strsplit is used in runtime but only shimmed in a test mock", function()
        assert.is_true(has(read("Modules/Network/QuestieComms.lua"), "strsplit"))
        assert.is_false(has(read("Modules/QuestieCompat.lua"), "strsplit"))
    end)

    it("[N3] Options files use { ... } where {} was intended (5.0 parse error)", function()
        assert.is_true(has(read("Modules/Options/QuestieOptions.lua"), "tabs = { ... }"))
        assert.is_true(has(read("Modules/Options/ArrowTab/QuestieOptionsArrow.lua"), "= { ... }"))
    end)

    it("[N4] QuestieCommsData indexes GetNPC/GetObject result with no nil-check", function()
        local d = read("Modules/Network/QuestieCommsData.lua")
        assert.is_true(has(d, "QuestieDB:GetNPC(objective.id).name"))
        assert.is_true(has(d, "QuestieDB:GetObject(objective.id).name"))
        -- the item branch right below DOES guard, proving the inconsistency:
        assert.is_true(has(d, "if(dbItem and dbItem.name and (not dbItem.Hidden)) then"))
    end)

    it("[N5] select(8, GetInstanceInfo()) left in QuestiePlayer (5.0 rewrite unfinished)", function()
        assert.is_true(has(read("Modules/QuestiePlayer.lua"), "select(8, GetInstanceInfo())"))
        -- QuestieLearner was rewritten away from it:
        assert.is_true(has(read("Modules/QuestieLearner.lua"), "Lua 5.0 compat"))
    end)

    it("[9.1->11.1] CORRECTED: % modulo IS used (the 'avoided' claim was wrong)", function()
        -- Pass 8-10 wrongly said % modulo = 0. Real modulo operators exist in
        -- Turtle-TOC files and are 5.0 parse errors that math.mod cannot rescue.
        assert.is_true(has(read("Modules/QuestieStream.lua"), " % 256"))
        assert.is_true(has(read("Modules/QuestiePlayer.lua"), "% playerRaceFlagX2"))
    end)
end)

describe("Audit Pass 11 - gap-fill findings (snapshot at HEAD)", function()
    it("[11.1] % modulo operator is present in multiple Turtle-TOC files", function()
        assert.is_true(has(read("Database/QuestieDB.lua"), " % "))
        assert.is_true(has(read("Modules/QuestieLearner.lua"), " % "))
    end)

    it("[G1] QuestieNameplate:UpdateNameplate re-splits the GUID and early-returns in-loop", function()
        local np = read("Modules/QuestieNameplate.lua")
        -- re-derives npcId from the guid on every update (cacheable):
        assert.is_true(has(np, 'strsplit("-", guid)'))
        -- the early return aborts the whole loop on a missing unit:
        assert.is_true(has(np, "if (not unitName) or (not npcId) then\n            return"))
    end)

    it("[G2] QuestieValidateGameCache has the unreachable isQuestLogGood guard", function()
        local v = read("Modules/QuestieValidateGameCache.lua")
        assert.is_true(has(v, "local isQuestLogGood = true"))
        assert.is_false(has(v, "isQuestLogGood = false")) -- never set false => guard is dead
    end)

    it("[G3] QuestieCompat shims neither bit nor strsplit (N1/N2 gaps stand)", function()
        local c = read("Modules/QuestieCompat.lua")
        assert.is_false(has(c, "strsplit ="))
        assert.is_false(has(c, "bit ="))
        assert.is_true(has(c, "QuestieCompat.C_Timer")) -- but C_Timer IS polyfilled
    end)
end)

describe("Audit Pass 10 - additional performance findings (snapshot)", function()
    it("[PP1] a batch Query(id, keys) API exists that IsDoable does not use", function()
        local compiler = read("Database/compiler.lua")
        assert.is_true(has(compiler, "handle.Query = function(id, keys)")) -- batch reader exists
        local db = read("Database/QuestieDB.lua")
        -- IsDoable issues many single-key reads instead of one batch read:
        assert.is_true(count(db, "QueryQuestSingle(questId,") >= 8)
    end)

    it("[PP2] hot non-fragile files repeat Questie.db.profile chains", function()
        assert.is_true(count(read("Modules/Tooltips/MapIconTooltip.lua"), "Questie.db.profile.") >= 8)
        assert.is_true(count(read("Modules/Map/QuestieMap.lua"), "Questie.db.profile.") >= 8)
    end)

    it("[PP3] arrow target sort no longer allocates an inline comparator per refresh", function()
        assert.is_true(has(read("Modules/Arrow/QuestieArrow.lua"),
            "local function _SortTargetByDistance(a, b)"))
        assert.is_true(has(read("Modules/Arrow/QuestieArrow.lua"),
            "table.sort(sortedTargets, _SortTargetByDistance)"))
        assert.is_true(count(read("Modules/Network/QuestieComms.lua"), "table.sort(") >= 3)
    end)

    it("[PP4] arrow avoids re-setting unchanged distance text every throttled tick", function()
        assert.is_true(has(read("Modules/Arrow/QuestieArrow.lua"),
            "objectiveFrame._lastDistanceText ~= distanceText"))
    end)

    it("[PP7] arrow performance throttles are profile-backed and exposed in Arrow options", function()
        local arrow = read("Modules/Arrow/QuestieArrow.lua")
        local arrowOptions = read("Modules/Options/ArrowTab/QuestieOptionsArrow.lua")
        local advancedOptions = read("Modules/Options/AdvancedTab/QuestieOptionsAdvanced.lua")
        local defaults = read("Modules/Options/QuestieOptionsDefaults.lua")

        assert.is_true(has(arrow, 'return _GetProfileNumber("arrowUpdateThrottle"'))
        assert.is_true(has(arrow, 'return _GetProfileNumber("arrowRecalcInterval"'))
        assert.is_true(has(arrow, 'return _GetProfileNumber("arrowTrackerRefreshThrottle"'))
        assert.is_false(has(arrowOptions, "arrowPerformanceHeader"))
        assert.is_false(has(arrowOptions, "arrowUpdateThrottle"))
        assert.is_true(has(advancedOptions, "arrowPerformanceHeader"))
        assert.is_true(has(advancedOptions, "arrowUpdateThrottle"))
        assert.is_true(has(advancedOptions, "arrowRecalcInterval"))
        assert.is_true(has(advancedOptions, "arrowTrackerRefreshThrottle"))
        assert.is_true(has(defaults, "arrowUpdateThrottle = 0.05"))
        assert.is_true(has(defaults, "arrowRecalcInterval = 1.0"))
        assert.is_true(has(defaults, "arrowTrackerRefreshThrottle = 0.5"))
    end)

    it("[L9] learner performance presets keep comms UI and broadcast gate synchronized", function()
        local advancedOptions = read("Modules/Options/AdvancedTab/QuestieOptionsAdvanced.lua")
        assert.is_true(has(advancedOptions, 'settings.learnerCommsIntensity = "fast"'))
        assert.is_true(has(advancedOptions, 'settings.learnerCommsIntensity = "normal"'))
        assert.is_true(has(advancedOptions, 'settings.learnerCommsIntensity = "low"'))
        assert.is_true(has(advancedOptions, "Questie.db.profile.learnerBroadcast = true"))
    end)

    it("[C1] QuestieComms full quest-list throttles are profile-backed", function()
        local comms = read("Modules/Network/QuestieComms.lua")
        local defaults = read("Modules/Options/QuestieOptionsDefaults.lua")
        local broadcastQuestUpdatePos = comms:find("function _QuestieComms:BroadcastQuestUpdate", 1, true)
        local isQuestieCommsEnabledPos = comms:find("local IsQuestieCommsEnabled", 1, true)

        assert.is_true(has(comms, 'GetProfileNumber("questieCommsQuestListPacketSize"'))
        assert.is_true(has(comms, 'GetProfileNumber("questieCommsQuestListInitialJitter"'))
        assert.is_true(has(comms, 'GetProfileNumber("questieCommsQuestListBlockInterval"'))
        assert.is_true(has(comms, "IsQuestieCommsEnabled = function()"))
        assert.is_true(isQuestieCommsEnabledPos ~= nil)
        assert.is_true(broadcastQuestUpdatePos ~= nil)
        assert.is_true(isQuestieCommsEnabledPos < broadcastQuestUpdatePos)
        assert.is_true(has(comms, "GetQuestListPacketSizeLimit()"))
        assert.is_true(has(comms, "GetQuestListInitialJitter()"))
        assert.is_true(has(comms, "GetQuestListBlockInterval()"))
        assert.is_true(has(defaults, "questieCommsEnabled = true"))
        assert.is_true(has(defaults, "questieCommsQuestListPacketSize = 200"))
        assert.is_true(has(defaults, "questieCommsQuestListInitialJitter = 3"))
        assert.is_true(has(defaults, "questieCommsQuestListBlockInterval = 3"))
    end)

    it("[C2] QuestieComms performance controls are exposed in Advanced options", function()
        local advancedOptions = read("Modules/Options/AdvancedTab/QuestieOptionsAdvanced.lua")

        assert.is_true(has(advancedOptions, "questieCommsPerformanceHeader"))
        assert.is_true(has(advancedOptions, "questieCommsEnabled"))
        assert.is_true(has(advancedOptions, "questieCommsQuestListPacketSize"))
        assert.is_true(has(advancedOptions, "questieCommsQuestListInitialJitter"))
        assert.is_true(has(advancedOptions, "questieCommsQuestListBlockInterval"))
        assert.is_true(has(advancedOptions, "Questie.db.profile.questieCommsEnabled == false"))
    end)
end)
