local function countKeys(tbl)
    local n = 0
    for _ in pairs(tbl or {}) do
        n = n + 1
    end
    return n
end

describe("QuestieLearner reset all learned data", function()
    local QuestieLearner

    before_each(function()
        dofile("Tests/wow_api_mock.lua")

        Questie.dbLearner.global = {
            settings = {
                enabled = false,
                prioritizeMyData = true,
                dataSourceMode = "auto",
                learnNpcs = true,
                learnQuests = true,
                learnItems = true,
                learnObjects = true,
            },
            npcs = {
                [1001] = { [1] = "Boar", mc = 2 },
            },
            quests = {
                [2001] = { [1] = "Quest", mc = 1 },
            },
            items = {
                [3001] = { [1] = "Item", mc = 1 },
            },
            objects = {
                [4001] = { [1] = "Object", mc = 1 },
            },
            Ascension = {
                npcs = { [9001] = { [1] = "Bucket NPC" } },
                quests = { [9002] = { [1] = "Bucket Quest" } },
                items = { [9003] = { [1] = "Bucket Item" } },
                objects = { [9004] = { [1] = "Bucket Object" } },
            },
        }

        dofile("Modules/QuestieLearner.lua")
        QuestieLearner = _G.QuestieLearner
    end)

    it("clears all learned data buckets while preserving settings", function()
        QuestieLearner:ClearAllData()

        assert.is_table(Questie.dbLearner.global.settings)
        assert.equals("auto", Questie.dbLearner.global.settings.dataSourceMode)
        assert.is_true(Questie.dbLearner.global.settings.learnObjects)

        local npcCount, questCount, itemCount, objectCount = QuestieLearner:GetStats()
        assert.equals(0, npcCount)
        assert.equals(0, questCount)
        assert.equals(0, itemCount)
        assert.equals(0, objectCount)
        assert.equals(0, countKeys(Questie.dbLearner.global.npcs))
        assert.equals(0, countKeys(Questie.dbLearner.global.quests))
        assert.equals(0, countKeys(Questie.dbLearner.global.items))
        assert.equals(0, countKeys(Questie.dbLearner.global.objects))
        assert.is_nil(Questie.dbLearner.global.Ascension)
    end)
end)
