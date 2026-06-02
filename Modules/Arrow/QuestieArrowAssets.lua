---@class QuestieArrowAssets
local QuestieArrowAssets = QuestieLoader:CreateModule("QuestieArrowAssets")

---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")

QuestieArrowAssets.styles = {
    ["arrow1"] = {
        label = "Arrow 1",
        texture = "Icons\\Arrows\\Arrow1.tga",
        preview = "Icons\\Arrows\\Arrow1_preview.tga",
        mode = "image",
        displayWidth = 77,
        displayHeight = 96,
        visualBottomInset = 0,
    },
    ["arrow2"] = {
        label = "Arrow 2",
        texture = "Icons\\Arrows\\Arrow2.tga",
        preview = "Icons\\Arrows\\Arrow2_preview.tga",
        mode = "image",
        displayWidth = 75,
        displayHeight = 96,
        visualBottomInset = 0,
    },
    ["arrow3"] = {
        label = "Arrow 3",
        texture = "Icons\\Arrows\\Arrow3.tga",
        preview = "Icons\\Arrows\\Arrow3_preview.tga",
        mode = "image",
        displayWidth = 64,
        displayHeight = 96,
        visualBottomInset = 0,
    },
    ["arrow4"] = {
        label = "Arrow 4",
        texture = "Icons\\Arrows\\Arrow4.tga",
        preview = "Icons\\Arrows\\Arrow4_preview.tga",
        mode = "image",
        displayWidth = 67,
        displayHeight = 96,
        visualBottomInset = 0,
    },
    ["arrowold"] = {
        label = "Arrow Old",
        texture = "Icons\\Arrows\\arrowold.tga",
        preview = "Icons\\Arrows\\arrowold_preview.tga",
        mode = "sheet",
        displayWidth = 56,
        displayHeight = 42,
        visualBottomInset = 0,
    },
}

QuestieArrowAssets.order = {
    "arrow1",
    "arrow2",
    "arrow3",
    "arrow4",
    "arrowold",
}

function QuestieArrowAssets:GetStyleData(key)
    return self.styles[key]
end

function QuestieArrowAssets:GetStyleOptions()
    local values = {}
    local addonPath = (QuestieLib and QuestieLib.AddonPath) or ""
    for _, key in ipairs(self.order) do
        local style = self.styles[key]
        if style then
            values[key] = string.format('|T%s:32:32:0:0|t    %s', addonPath .. style.preview, style.label)
        end
    end
    return values
end

function QuestieArrowAssets:GetStyleOrder()
    return self.order
end

function QuestieArrowAssets:GetStyles()
    return self.styles
end
