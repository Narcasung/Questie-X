describe("Questie tooltip precedence", function()
    local function contains(lines, needle)
        for _, line in ipairs(lines or {}) do
            if string.find(line, needle, 1, true) then
                return true
            end
        end
        return false
    end

    before_each(function()
        dofile("Tests/wow_api_mock.lua")

        local originalImportModule = QuestieLoader.ImportModule
        QuestieLoader.ImportModule = function(self, name)
            if name == "QuestieLib" then
                return {
                    GetColoredQuestName = function(_, questId)
                        return "Quest " .. tostring(questId)
                    end,
                    Colorize = function(_, text)
                        return text
                    end,
                }
            end
            return originalImportModule(self, name)
        end

        Questie.db.profile.showQuestsInNpcTooltip = true
        Questie.db.profile.enableTooltipsQuestLevel = false
        Questie.db.profile.enableTooltipsNPCID = false
        QuestiePlayer.numberOfGroupMembers = 0
        QuestieCompat.IsInGroup = function() return false end
        QuestieCompat.UnitInParty = function() return false end

        QuestieDB.GetQuest = function(_, questId)
            if questId ~= 8334 then
                return nil
            end

            return {
                ObjectiveData = {
                    [1] = { Type = "monster", Id = 15271, Text = "Tender slain" },
                    [2] = { Type = "monster", Id = 15294, Text = "Feral Tender slain" },
                },
            }
        end

        dofile("Modules/Tooltips/Tooltip.lua")
        QuestieTooltips.lookupByKey["m_15271"] = {
            ["8334 Tender 15271"] = {
                questId = 8334,
                name = "Tender",
                starterId = 15271,
            },
        }
    end)

    it("adds AscensionDB objective text under quest titles when no objective tooltip is registered", function()
        local lines = QuestieTooltips:GetTooltip("m_15271")

        assert.is_true(contains(lines, "Quest 8334"))
        assert.is_true(contains(lines, "Tender slain"))
        assert.is_true(contains(lines, "Feral Tender slain"))
    end)
end)
