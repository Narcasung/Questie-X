-------------------------
--Import modules.
-------------------------
---@type QuestieOptions
local QuestieOptions = QuestieLoader:ImportModule("QuestieOptions")
---@type QuestieOptionsUtils
local QuestieOptionsUtils = QuestieLoader:ImportModule("QuestieOptionsUtils")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

QuestieOptions.tabs.keybinds = { ... }

local keybindOptions = {}

function QuestieOptions.tabs.keybinds:Initialize()
    keybindOptions = {
        name = function() return l10n('Keybinds') end,
        type = "group",
        order = 15,
        args = {
            header = {
                type = "header",
                order = 1,
                name = function() return l10n('Keybind Options') end,
            },
            description = {
                type = "description",
                order = 2,
                name = function() return l10n('Here you can configure various keybinds for Questie UI elements and features.') end,
            },
            spacer_general = QuestieOptionsUtils:Spacer(3),
            generalKeybinds = {
                type = "group",
                name = function() return l10n('General Keybinds') end,
                inline = true,
                order = 4,
                args = {
                    useQuestItemKeybind = {
                        type = "keybinding",
                        order = 1,
                        name = function() return l10n('Use Nearest Quest Item') end,
                        desc = function() return l10n('Press this keybind to automatically use a quest item for the nearest incomplete quest objective. The item must be in your bags and be a usable quest item (trigger a spell when used).') end,
                        get = function() return Questie.db.profile.useQuestItemKeybind end,
                        set = function(_, key)
                            Questie.db.profile.useQuestItemKeybind = key
                            if QuestieTracker_UpdateQuestItemKeybind then
                                QuestieTracker_UpdateQuestItemKeybind()
                            end
                        end
                    },
                    toggleOptionsKeybind = {
                        type = "keybinding",
                        order = 2,
                        name = function() return l10n('Toggle Options') end,
                        desc = function() return l10n('Press this keybind to toggle the Questie Options window.') end,
                        get = function() return Questie.db.profile.toggleOptionsKeybind end,
                        set = function(_, key)
                            Questie.db.profile.toggleOptionsKeybind = key
                            if QuestieTracker_UpdateQuestItemKeybind then
                                QuestieTracker_UpdateQuestItemKeybind()
                            end
                        end
                    },
                    toggleTrackerKeybind = {
                        type = "keybinding",
                        order = 3,
                        name = function() return l10n('Toggle Tracker') end,
                        desc = function() return l10n('Press this keybind to toggle the Questie Tracker.') end,
                        get = function() return Questie.db.profile.toggleTrackerKeybind end,
                        set = function(_, key)
                            Questie.db.profile.toggleTrackerKeybind = key
                            if QuestieTracker_UpdateQuestItemKeybind then
                                QuestieTracker_UpdateQuestItemKeybind()
                            end
                        end
                    },
                    toggleMyJourneyKeybind = {
                        type = "keybinding",
                        order = 4,
                        name = function() return l10n('Toggle My Journey') end,
                        desc = function() return l10n('Press this keybind to toggle the Questie Journey window.') end,
                        get = function() return Questie.db.profile.toggleMyJourneyKeybind end,
                        set = function(_, key)
                            Questie.db.profile.toggleMyJourneyKeybind = key
                            if QuestieTracker_UpdateQuestItemKeybind then
                                QuestieTracker_UpdateQuestItemKeybind()
                            end
                        end
                    },
                }
            }
        }
    }
    return keybindOptions
end
