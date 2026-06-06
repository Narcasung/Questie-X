describe("Questie debug throttle", function()
    local originalPrint
    local originalGetTime
    local originalImport

    before_each(function()
        dofile("Tests/wow_api_mock.lua")
        Questie.Print = nil
        _G.IsLoggedIn = function()
            return false
        end
        _G.C_Timer = _G.C_Timer or {}
        _G.C_Timer.After = function()
        end
        originalImport = QuestieLoader.ImportModule
        QuestieLoader.ImportModule = function(self, name)
            if name == "QuestieLib" then
                return { AddonPath = "" }
            elseif name == "QuestieValidateGameCache" then
                return { StartCheck = function() end }
            end
            return originalImport(self, name)
        end
        dofile("Questie.lua")

        originalPrint = _G.print
        originalGetTime = _G.GetTime

        _G._questie_debug_lines = {}
        _G.print = function(...)
            local parts = {}
            for i = 1, select("#", ...) do
                parts[#parts + 1] = tostring(select(i, ...))
            end
            table.insert(_G._questie_debug_lines, table.concat(parts, " "))
        end
    end)

    after_each(function()
        _G.print = originalPrint
        _G.GetTime = originalGetTime
        QuestieLoader.ImportModule = originalImport
        _G._questie_debug_lines = nil
    end)

    it("suppresses rapid debug lines until the throttle window reopens", function()
        local now = 0
        _G.GetTime = function()
            return now
        end

        Questie.db.profile.debugEnabled = true
        Questie.db.profile.debugEnabledPrint = true
        Questie.db.profile.debugLevel = Questie.DEBUG_INFO
        Questie.db.profile.debugMessageThrottle = 0.5

        Questie:Debug(Questie.DEBUG_INFO, "alpha")
        now = 0.1
        Questie:Debug(Questie.DEBUG_INFO, "beta")
        now = 0.6
        Questie:Debug(Questie.DEBUG_INFO, "gamma")

        assert.equals(2, table.getn(_G._questie_debug_lines))
        assert.is_true(string.find(_G._questie_debug_lines[1], "alpha", 1, true) ~= nil)
        assert.is_true(string.find(_G._questie_debug_lines[2], "gamma", 1, true) ~= nil)
    end)

    it("throttles critical messages too because fatal output is separate", function()
        local now = 0
        _G.GetTime = function()
            return now
        end

        Questie.db.profile.debugEnabled = true
        Questie.db.profile.debugEnabledPrint = true
        Questie.db.profile.debugLevel = Questie.DEBUG_INFO + Questie.DEBUG_CRITICAL
        Questie.db.profile.debugMessageThrottle = 0.5

        Questie:Debug(Questie.DEBUG_INFO, "alpha")
        now = 0.1
        Questie:Debug(Questie.DEBUG_CRITICAL, "boom")

        assert.equals(1, table.getn(_G._questie_debug_lines))
        assert.is_true(string.find(_G._questie_debug_lines[1], "alpha", 1, true) ~= nil)
    end)
end)
