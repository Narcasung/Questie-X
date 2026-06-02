local lfs = require("lfs")

local function read_file(path)
    local handle = assert(io.open(path, "rb"))
    local content = assert(handle:read("*a"))
    handle:close()
    return content
end

local function list_arrows()
    local names = {}
    for entry in lfs.dir("Icons/Arrows") do
        if entry ~= "." and entry ~= ".." then
            names[#names + 1] = entry
        end
    end
    table.sort(names)
    return names
end

local function extract_block(content, key)
    local needle = '    ["' .. key .. '"] = {'
    local startPos = assert(content:find(needle, 1, true), "missing style block for " .. key)
    local tail = content:sub(startPos)
    local endPos = assert(tail:find("\n    },", 1, true), "missing terminator for style block " .. key)
    return tail:sub(1, endPos)
end

local function extract_mode(content, key)
    local block = extract_block(content, key)
    return assert(block:match('mode%s*=%s*"([^"]+)"'), "missing mode for " .. key)
end

local function extract_texture(content, key)
    local block = extract_block(content, key)
    return assert(block:match('texture%s*=%s*"([^"]+)"'), "missing texture for " .. key)
end

describe("QuestieArrowAssets manifest", function()
    local content = read_file("Modules/Arrow/QuestieArrowAssets.lua")
    local arrowLua = read_file("Modules/Arrow/QuestieArrow.lua")

    it("keeps the default arrow as a regular image", function()
        assert.are.equal("image", extract_mode(content, "arrow1"))
        assert.are.equal("Icons\\\\Arrows\\\\Arrow1.tga", extract_texture(content, "arrow1"))
    end)

    it("keeps the old arrow as a sprite sheet", function()
        assert.are.equal("sheet", extract_mode(content, "arrowold"))
    end)

    it("keeps the other bundled arrows as regular images", function()
        assert.are.equal("image", extract_mode(content, "arrow2"))
        assert.are.equal("image", extract_mode(content, "arrow3"))
        assert.are.equal("image", extract_mode(content, "arrow4"))
        assert.are.equal("image", extract_mode(content, "arcanearrow"))
        assert.are.equal("image", extract_mode(content, "hordearrow"))
        assert.are.equal("image", extract_mode(content, "alliancearrow"))
        assert.are.equal("image", extract_mode(content, "minimal1"))
        assert.are.equal("image", extract_mode(content, "minimal2"))
        assert.are.equal("image", extract_mode(content, "minimal3"))
    end)

    it("only treats arrowold as a bundled sprite sheet", function()
        assert.are.equal("sheet", extract_mode(content, "arrowold"))
        assert.are.equal("image", extract_mode(content, "arrow1"))
        assert.are.equal("image", extract_mode(content, "arrow2"))
        assert.are.equal("image", extract_mode(content, "arrow3"))
        assert.are.equal("image", extract_mode(content, "arrow4"))
        assert.are.equal("image", extract_mode(content, "arcanearrow"))
        assert.are.equal("image", extract_mode(content, "hordearrow"))
        assert.are.equal("image", extract_mode(content, "alliancearrow"))
        assert.are.equal("image", extract_mode(content, "minimal1"))
        assert.are.equal("image", extract_mode(content, "minimal2"))
        assert.are.equal("image", extract_mode(content, "minimal3"))
    end)

    it("keeps the runtime default pointed at arrow1 and the sheet guard locked to arrowold", function()
        assert.is_truthy(arrowLua:find('local ARROW_DEFAULT_STYLE = "arrow1"', 1, true))
        assert.is_truthy(arrowLua:find('return styleKey == "arrowold"', 1, true))
        assert.is_truthy(arrowLua:find('if styleKey == "arrow" then', 1, true))
        assert.is_truthy(arrowLua:find('self.arrow:SetTexCoord(0, 1, 0, 1)', 1, true))
        assert.is_truthy(arrowLua:find('local runtimeTexture = style.preview', 1, true))
        assert.is_truthy(arrowLua:find('sourceTexturePath = QuestieLib.AddonPath .. style.texture', 1, true))
    end)

    it("keeps the bundled arrow folder clean and named consistently", function()
        assert.are.same({
            "AllianceArrow.tga",
            "AllianceArrow_preview.tga",
            "ArcaneArrow.tga",
            "ArcaneArrow_preview.tga",
            "Arrow1.tga",
            "Arrow1_preview.tga",
            "Arrow2.tga",
            "Arrow2_preview.tga",
            "Arrow3.tga",
            "Arrow3_preview.tga",
            "Arrow4.tga",
            "Arrow4_preview.tga",
            "HordeArrow.tga",
            "HordeArrow_preview.tga",
            "Minimal1.tga",
            "Minimal1_preview.tga",
            "Minimal2.tga",
            "Minimal2_preview.tga",
            "Minimal3.tga",
            "Minimal3_preview.tga",
            "arrowold.tga",
            "arrowold_preview.tga",
        }, list_arrows())
    end)
end)
