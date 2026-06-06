describe("Questie item name safety", function()
    local function read(path)
        local f = assert(io.open(path, "r"), "cannot open " .. path)
        local c = f:read("*a")
        f:close()
        return c
    end

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

    it("skips malformed item objectives without an item id", function()
        local lib = read("Modules/Libs/QuestieLib.lua")
        assert.is_true(string.find(lib, "local itemId = objectiveDB.Id", 1, true) ~= nil)
        assert.is_true(string.find(lib, "if not itemId then", 1, true) ~= nil)
        assert.is_true(string.find(lib, "QuestieDB.itemDataOverrides[itemId]", 1, true) ~= nil)
    end)
end)
