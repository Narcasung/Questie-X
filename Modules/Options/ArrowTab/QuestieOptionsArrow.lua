-------------------------
--Import modules.
-------------------------
---@type QuestieOptions
local QuestieOptions = QuestieLoader:ImportModule("QuestieOptions")
---@type QuestieOptionsUtils
local QuestieOptionsUtils = QuestieLoader:ImportModule("QuestieOptionsUtils")
---@type QuestieArrow
local QuestieArrow = QuestieLoader:ImportModule("QuestieArrow")
---@type QuestieTracker
local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")

---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

QuestieOptions.tabs.arrow = { ... }

function QuestieOptions.tabs.arrow:Initialize()
    return {
        name = function() return l10n('Arrow') end,
        type = "group",
        order = 2.5,
        args = {
            arrow_header = {
                type = "header",
                order = 1,
                name = function() return l10n('Arrow Options') end,
            },
            arrowEnabled = {
                type = "toggle",
                order = 2,
                width = 1.5,
                name = function() return l10n("Enable Arrow") end,
                desc = function() return l10n("Show the Questie arrow and auto-track the nearest objective or turn-in location.") end,
                get = function() return Questie.db.profile.arrowEnabled ~= false end,
                set = function(_, value)
                    Questie.db.profile.arrowEnabled = value
                    if QuestieArrow and QuestieArrow.Refresh then
                        if not value and QuestieArrow.ClearTarget then
                            QuestieArrow:ClearTarget()
                        end
                        QuestieArrow:Refresh()
                    end
                end,
            },
            arrow_spacer_1 = QuestieOptionsUtils:Spacer(3),
            arrow_scale = {
                type = "range",
                order = 4,
                width = 1.5,
                name = function() return l10n("Arrow Scale") end,
                desc = function() return l10n("Change the size of the arrow") end,
                min = 0.5,
                max = 2.0,
                step = 0.05,
                get = function() return Questie.db.profile.arrowScale or 1 end,
                set = function(_, value)
                    Questie.db.profile.arrowScale = value
                    if QuestieArrow and QuestieArrow.Refresh then
                        QuestieArrow:Refresh()
                    end
                end,
            },
            arrow_alpha = {
                type = "range",
                order = 5,
                width = 1.5,
                name = function() return l10n("Arrow Transparency") end,
                desc = function() return l10n("Change the transparency of the arrow") end,
                min = 0.1,
                max = 1.0,
                step = 0.05,
                get = function() return Questie.db.profile.arrowAlpha or 1.0 end,
                set = function(_, value)
                    Questie.db.profile.arrowAlpha = value
                    if QuestieArrow and QuestieArrow.Refresh then
                        QuestieArrow:Refresh()
                    end
                end,
            },
            arrow_spacer_2 = QuestieOptionsUtils:Spacer(6),
            autoTrackQuests = {
                type = "toggle",
                order = 7,
                width = 1.5,
                name = function() return l10n("Auto-track Quests") end,
                desc = function() return l10n("Automatically track all quests in your quest log. If disabled, only manually tracked quests will show on the arrow.") end,
                get = function() return Questie.db.profile.autoTrackQuests end,
                set = function(_, value)
                    Questie.db.profile.autoTrackQuests = value
                    if QuestieTracker and QuestieTracker.Update then
                        QuestieTracker:Update()
                    end
                    if QuestieArrow and QuestieArrow.Refresh then
                        QuestieArrow:Refresh()
                    end
                end,
            },
            arrow_spacer_3 = QuestieOptionsUtils:Spacer(8),
            resetArrowPosition = {
                type = "execute",
                order = 9,
                width = 1.0,
                name = function() return l10n("Reset Arrow Position") end,
                desc = function() return l10n("Reset the arrow position to the center of the screen") end,
                func = function()
                    Questie.db.profile.arrowPosition = nil
                    if QuestieArrow and QuestieArrow.Refresh then
                        QuestieArrow:Refresh()
                    end
                end,
            },
            arrow_spacer_4 = QuestieOptionsUtils:Spacer(10),
            debugArrow = {
                type = "toggle",
                order = 11,
                width = 1.5,
                name = function() return l10n("Debug Arrow") end,
                desc = function() return l10n("Show debug information about the arrow target in chat") end,
                get = function() return Questie.db.profile.debugArrow end,
                set = function(_, value)
                    Questie.db.profile.debugArrow = value
                end,
            },
            printArrowTarget = {
                type = "execute",
                order = 12,
                width = 1.0,
                name = function() return l10n("Print Current Target") end,
                desc = function() return l10n("Print the current arrow target coordinates to chat") end,
                func = function()
                    if QuestieArrow and QuestieArrow.PrintTargetCoords then
                        QuestieArrow:PrintTargetCoords()
                    end
                end,
            },
            debugPrintArrow = {
                type = "execute",
                order = 12.5,
                width = 1.0,
                name = function() return l10n("Debug Print Arrow State") end,
                desc = function() return l10n("Print detailed debug info about arrow state to chat") end,
                func = function()
                    if QuestieArrow and QuestieArrow.DebugPrint then
                        QuestieArrow:DebugPrint()
                    end
                end,
            },
            clearArrowTarget = {
                type = "execute",
                order = 13,
                width = 1.0,
                name = function() return l10n("Clear Target") end,
                desc = function() return l10n("Clear the current arrow target and resume auto-tracking") end,
                func = function()
                    if QuestieArrow and QuestieArrow.ClearTarget then
                        QuestieArrow:ClearTarget()
                        QuestieArrow:Refresh()
                    end
                end,
            },
        },
    }
end
