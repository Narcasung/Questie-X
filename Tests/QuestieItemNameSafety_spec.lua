describe("Questie item name safety", function()
    before_each(function()
        dofile("Tests/wow_api_mock.lua")
        GetItemInfo = function()
            error("GetItemInfo should not be called for invalid item ids")
        end
        dofile("Database/QuestieDB.lua")
    end)

    it("returns a placeholder instead of calling GetItemInfo for invalid item ids", function()
        local item = Item:CreateFromItemID(nil)
        assert.equals("item:nil", item:GetItemName())
    end)

    it("also handles non-numeric item ids safely", function()
        local item = Item:CreateFromItemID("bad-id")
        assert.equals("item:bad-id", item:GetItemName())
    end)
end)
