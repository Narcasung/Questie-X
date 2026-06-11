describe("QuestieDB learner spawn suppression hardening", function()
    before_each(function()
        dofile("Tests/wow_api_mock.lua")
        dofile("Database/QuestieDB.lua")
    end)

    it("ignores malformed numeric NPC spawns while still suppressing valid learned rows", function()
        Questie.dbLearner.global.settings.enabled = true
        Questie.dbLearner.global.settings.prioritizeMyData = true

        Questie.dbLearner.global.npcs = {
            [1001] = {
                mc = 2,
                [7] = 123,
            },
            [1002] = {
                mc = 2,
                [7] = {
                    [3431] = { { 12.5, 34.5 } },
                },
            },
        }

        local suppressed = QuestieDB.GetSuppressedNPCs(3431)

        assert.is_nil(suppressed[1001])
        assert.is_true(suppressed[1002])
    end)

    it("falls back to legacy object spawn tables when the current field is malformed", function()
        Questie.dbLearner.global.settings.enabled = true
        Questie.dbLearner.global.settings.prioritizeMyData = true

        Questie.dbLearner.global.objects = {
            [2001] = {
                mc = 2,
                [4] = 456,
                [7] = {
                    [3431] = { { 55.5, 66.6 } },
                },
            },
            [2002] = {
                mc = 2,
                [4] = 789,
            },
        }

        local suppressed = QuestieDB.GetSuppressedObjects(3431)

        assert.is_true(suppressed[2001])
        assert.is_nil(suppressed[2002])
    end)

    it("normalizes malformed NPC spawn entries during cleanup", function()
        local entry = {
            [1] = "Test NPC",
            [4] = {
                [3431] = { { 10.1, 20.2 } },
            },
            [7] = 999,
        }

        local changed = QuestieDB.private.NormalizeLearnerSpawnEntry(entry, 7, 4)

        assert.is_true(changed)
        assert.is_table(entry[7])
        assert.is_nil(entry[4])
        assert.are.same({ [3431] = { { 10.1, 20.2 } } }, entry[7])
    end)

    it("normalizes malformed object spawn entries during cleanup", function()
        local entry = {
            [1] = "Test Object",
            [4] = 999,
            [7] = {
                [3431] = { { 77.7, 88.8 } },
            },
        }

        local changed = QuestieDB.private.NormalizeLearnerSpawnEntry(entry, 4, 7)

        assert.is_true(changed)
        assert.is_table(entry[4])
        assert.is_nil(entry[7])
        assert.are.same({ [3431] = { { 77.7, 88.8 } } }, entry[4])
    end)

    it("treats dungeon quests with missing quest tags as dungeon quests when zone data proves it", function()
        local oldGetQuestTagInfo = _G.GetQuestTagInfo
        local oldQueryQuestSingle = QuestieDB.QueryQuestSingle
        local oldIsDungeonZone = ZoneDB.IsDungeonZone
        local oldGetAlternativeZoneId = ZoneDB.GetAlternativeZoneId
        local oldGetParentZoneId = ZoneDB.GetParentZoneId

        _G.GetQuestTagInfo = function() return nil end
        QuestieDB.QueryQuestSingle = function(_, key)
            if key == "zoneOrSort" then
                return 4810
            end
            return nil
        end
        ZoneDB.IsDungeonZone = function(_, areaId)
            return areaId == 4810
        end
        ZoneDB.GetAlternativeZoneId = function() return nil end
        ZoneDB.GetParentZoneId = function() return nil end

        local isDungeon = QuestieDB.IsDungeonQuest(12345)

        _G.GetQuestTagInfo = oldGetQuestTagInfo
        QuestieDB.QueryQuestSingle = oldQueryQuestSingle
        ZoneDB.IsDungeonZone = oldIsDungeonZone
        ZoneDB.GetAlternativeZoneId = oldGetAlternativeZoneId
        ZoneDB.GetParentZoneId = oldGetParentZoneId

        assert.is_true(isDungeon)
    end)

    it("treats dungeon quests with missing quest tags as dungeon quests when starter spawns are dungeon-only", function()
        local oldGetQuestTagInfo = _G.GetQuestTagInfo
        local oldQueryQuestSingle = QuestieDB.QueryQuestSingle
        local oldQueryNPCSingle = QuestieDB.QueryNPCSingle
        local oldQueryObjectSingle = QuestieDB.QueryObjectSingle
        local oldIsDungeonZone = ZoneDB.IsDungeonZone
        local oldGetAlternativeZoneId = ZoneDB.GetAlternativeZoneId
        local oldGetParentZoneId = ZoneDB.GetParentZoneId

        _G.GetQuestTagInfo = function() return nil end
        QuestieDB.QueryQuestSingle = function(_, key)
            if key == "startedBy" then
                return {
                    { 101 },
                    { 202 },
                }
            end
            return nil
        end
        QuestieDB.QueryNPCSingle = function(id, key)
            if id == 101 and key == "spawns" then
                return {
                    [4810] = { { 12.5, 34.5 } },
                }
            end
            return nil
        end
        QuestieDB.QueryObjectSingle = function() return nil end
        ZoneDB.IsDungeonZone = function(_, areaId)
            return areaId == 4810
        end
        ZoneDB.GetAlternativeZoneId = function() return nil end
        ZoneDB.GetParentZoneId = function() return nil end

        local isDungeon = QuestieDB.IsDungeonQuest(23456)

        _G.GetQuestTagInfo = oldGetQuestTagInfo
        QuestieDB.QueryQuestSingle = oldQueryQuestSingle
        QuestieDB.QueryNPCSingle = oldQueryNPCSingle
        QuestieDB.QueryObjectSingle = oldQueryObjectSingle
        ZoneDB.IsDungeonZone = oldIsDungeonZone
        ZoneDB.GetAlternativeZoneId = oldGetAlternativeZoneId
        ZoneDB.GetParentZoneId = oldGetParentZoneId

        assert.is_true(isDungeon)
    end)

    it("does not treat ordinary quests as dungeon quests when the tag is missing", function()
        local oldGetQuestTagInfo = _G.GetQuestTagInfo
        local oldQueryQuestSingle = QuestieDB.QueryQuestSingle
        local oldIsDungeonZone = ZoneDB.IsDungeonZone
        local oldGetAlternativeZoneId = ZoneDB.GetAlternativeZoneId
        local oldGetParentZoneId = ZoneDB.GetParentZoneId

        _G.GetQuestTagInfo = function() return nil end
        QuestieDB.QueryQuestSingle = function(_, key)
            if key == "zoneOrSort" then
                return 12
            elseif key == "startedBy" then
                return {
                    { 301 },
                    { 401 },
                }
            end
            return nil
        end
        ZoneDB.IsDungeonZone = function(_, areaId)
            return false
        end
        ZoneDB.GetAlternativeZoneId = function() return nil end
        ZoneDB.GetParentZoneId = function() return nil end

        local isDungeon = QuestieDB.IsDungeonQuest(34567)

        _G.GetQuestTagInfo = oldGetQuestTagInfo
        QuestieDB.QueryQuestSingle = oldQueryQuestSingle
        ZoneDB.IsDungeonZone = oldIsDungeonZone
        ZoneDB.GetAlternativeZoneId = oldGetAlternativeZoneId
        ZoneDB.GetParentZoneId = oldGetParentZoneId

        assert.is_false(isDungeon)
    end)
end)
