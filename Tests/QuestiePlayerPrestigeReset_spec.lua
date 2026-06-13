describe("QuestiePlayer prestige reset", function()
    local resetCalls

    before_each(function()
        dofile("Tests/wow_api_mock.lua")

        resetCalls = 0
        QuestieQuest.SmoothReset = function()
            resetCalls = resetCalls + 1
        end

        dofile("Modules/QuestiePlayer.lua")
        QuestiePlayer.private.playerLevel = 70
    end)

    it("drops the cached level to 1 and refreshes quest state when prestige restarts", function()
        _G.UnitLevel = function()
            return 1
        end

        local resetTriggered = QuestiePlayer:SetPlayerLevel(1)

        assert.is_true(resetTriggered)
        assert.equals(1, QuestiePlayer.private.playerLevel)
        assert.equals(1, resetCalls)
    end)

    it("does not treat an ordinary level 1 login as a prestige reset", function()
        QuestiePlayer.private.playerLevel = 1
        _G.UnitLevel = function()
            return 1
        end

        local resetTriggered = QuestiePlayer:SetPlayerLevel(1)

        assert.is_false(resetTriggered)
        assert.equals(1, QuestiePlayer.private.playerLevel)
        assert.equals(0, resetCalls)
    end)
end)
