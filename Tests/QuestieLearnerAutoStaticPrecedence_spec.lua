describe("QuestieLearner auto mode static spawn precedence", function()
    local originalImportModule

    local function loadObjectiveBuilders()
        originalImportModule = QuestieLoader.ImportModule
        _G.QuestieCorrections = {
            questNPCBlacklist = {},
        }
        QuestieLoader.ImportModule = function(self, name)
            if name == "QuestieCorrections" then return _G.QuestieCorrections end
            return originalImportModule(self, name)
        end

        QuestieQuest.private = {
            objectiveSpawnListCallTable = {},
        }
        dofile("Modules/Quest/QuestieQuestPrivates.lua")
        return QuestieQuest.private.objectiveSpawnListCallTable
    end

    before_each(function()
        dofile("Tests/wow_api_mock.lua")
        Questie.IsAscension = true
        Questie.ICON_TYPE_MONSTER = "monster"
        Questie.ICON_TYPE_OBJECT = "object"
        Questie.db.profile.monsterScale = 1
        Questie.db.profile.objectScale = 1
        Questie.dbLearner.global.settings.enabled = true
        Questie.dbLearner.global.settings.dataSourceMode = "auto"
        Questie.dbLearner.global.settings.minConfidencePins = 1
    end)

    after_each(function()
        if originalImportModule then
            QuestieLoader.ImportModule = originalImportModule
            originalImportModule = nil
        end
    end)

    it("keeps static NPC spawns in auto mode even when learner has reliable spawns", function()
        QuestieDB.GetNPC = function(_, npcId)
            if npcId == 15274 then
                return {
                    name = "Mana Wyrm",
                    spawns = {
                        [3430] = {
                            { 37.77, 26.01 },
                            { 37.21, 25.79 },
                            { 36.95, 25.44 },
                        },
                    },
                }
            end
        end
        Questie.dbLearner.global.npcs[15274] = {
            [1] = "Mana Wyrm",
            [7] = {
                [1241] = {
                    { 57.19, 40.49 },
                    { 58.44, 41.31 },
                },
            },
            mc = 166,
        }

        local builders = loadObjectiveBuilders()
        local result = builders.monster(15274, { Description = "Mana Wyrm slain" })

        assert.is_table(result)
        assert.is_table(result[15274])
        assert.is_table(result[15274].Spawns[3430])
        assert.equals(3, table.getn(result[15274].Spawns[3430]))
        assert.is_nil(result[15274].Spawns[1241])
        assert.is_false(result[15274].isLearned)
    end)

    it("keeps static object spawns in auto mode even when learner has reliable spawns", function()
        QuestieDB.GetObject = function(_, objectId)
            if objectId == 9001 then
                return {
                    name = "Static Object",
                    spawns = {
                        [12] = {
                            { 10, 20 },
                            { 11, 21 },
                        },
                    },
                }
            end
        end
        Questie.dbLearner.global.objects[9001] = {
            [1] = "Static Object",
            [4] = {
                [44] = {
                    { 30, 40 },
                    { 31, 41 },
                },
            },
            mc = 5,
        }

        local builders = loadObjectiveBuilders()
        local result = builders.object(9001, { Description = "Static Object" })

        assert.is_table(result)
        assert.is_table(result[9001])
        assert.is_table(result[9001].Spawns[12])
        assert.equals(2, table.getn(result[9001].Spawns[12]))
        assert.is_nil(result[9001].Spawns[44])
        assert.is_false(result[9001].isLearned)
    end)
end)
