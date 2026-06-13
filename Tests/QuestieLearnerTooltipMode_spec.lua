local function read(path)
    local f = assert(io.open(path, "r"), "cannot open " .. path)
    local c = f:read("*a")
    f:close()
    return c
end

local function has(content, needle)
    return string.find(content, needle, 1, true) ~= nil
end

describe("QuestieLearner tooltip mode and anchoring", function()
    local learner = read("Modules/QuestieLearner.lua")
    local tooltip = read("Modules/Tooltips/Tooltip.lua")

    it("allows learned tooltip data in auto and learner modes", function()
        assert.is_true(has(learner, "function QuestieLearner:CanShowLearnerTooltips()"))
        assert.is_true(has(learner, "return mode == \"auto\" or mode == \"learner\""))
        assert.is_true(has(tooltip, "QuestieLearner:CanShowLearnerTooltips()"))
        assert.is_false(has(tooltip, "QuestieLearner:IsEnabled()"))
    end)

    it("anchors the secondary learner tooltip under the default tooltip", function()
        assert.is_true(has(learner, "tooltip:SetOwner(UIParent, \"ANCHOR_NONE\")"))
        assert.is_true(has(learner, "local anchor = sourceTooltip or GameTooltip"))
        assert.is_true(has(learner, "tooltip:ClearAllPoints()"))
        assert.is_true(has(learner, "tooltip:SetPoint(\"TOPLEFT\", anchor, \"BOTTOMLEFT\", 0, -2)"))
        assert.is_false(has(learner, "tooltip:SetOwner(sourceTooltip or GameTooltip, \"ANCHOR_RIGHT\")"))
    end)
end)
