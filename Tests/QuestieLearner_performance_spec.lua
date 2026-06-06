describe("QuestieLearner kill-path batching", function()
    local queuedTimers
    local broadcasts
    local QuestieLearner
    local simulatedTime

    local function read(path)
        local f = assert(io.open(path, "r"))
        local content = f:read("*a")
        f:close()
        return content
    end

    local function has(text, needle)
        return text and text:find(needle, 1, true) ~= nil
    end

    local function drainQueuedTimers()
        while next(queuedTimers) do
            local currentQueue = queuedTimers
            queuedTimers = {}
            for i = 1, table.getn(currentQueue) do
                local fn = currentQueue[i]
                if fn then
                    simulatedTime = simulatedTime + 1
                    fn()
                end
            end
        end
    end

    before_each(function()
        dofile("Tests/wow_api_mock.lua")

        queuedTimers = {}
        broadcasts = {}
        simulatedTime = 1000
        _G.GetTime = function()
            return simulatedTime
        end
        QuestieCompat.C_Timer.After = function(_, fn)
            queuedTimers[table.getn(queuedTimers) + 1] = fn
        end

        local originalImportModule = QuestieLoader.ImportModule
        QuestieLoader.ImportModule = function(self, name)
            if name == "QuestieLearnerComms" then
                return {
                    BroadcastLearnedData = function(_, op, typ, id, data)
                        broadcasts[table.getn(broadcasts) + 1] = {
                            op = op,
                            typ = typ,
                            id = id,
                            data = data,
                        }
                    end,
                }
            end
            return originalImportModule(self, name)
        end

        Questie.dbLearner.global.settings.enabled = true
        Questie.dbLearner.global.settings.learnNpcs = true
        Questie.dbLearner.global.settings.learnQuests = true
        Questie.dbLearner.global.settings.learnItems = true
        Questie.dbLearner.global.settings.learnObjects = true
        Questie.dbLearner.global.settings.minConfidencePins = 1
        Questie.dbLearner.global.npcs = {}
        Questie.dbLearner.global.quests = {}
        Questie.dbLearner.global.items = {}
        Questie.dbLearner.global.objects = {}
        QuestieDB.npcDataOverrides = {}
        QuestieDB.questDataOverrides = {}
        QuestieDB.itemDataOverrides = {}
        QuestieDB.objectDataOverrides = {}
        QuestieDB.private = {
            npcCache = {
                [1001] = { name = "Cached Boar" },
            },
        }
        QuestiePlayer.currentQuestlog = {}

        QuestieLearner = dofile("Modules/QuestieLearner.lua")
    end)

    it("coalesces repeated NPC live updates instead of invalidating DB cache per kill", function()
        QuestieLearner:LearnNPC(1001, "Laggy Boar", nil, nil, nil, nil, 41.25, 52.5, 44)
        QuestieLearner:LearnNPC(1001, "Laggy Boar", nil, nil, nil, nil, 41.35, 52.6, 44)

        assert.is_nil(QuestieDB.npcDataOverrides[1001])
        assert.is_table(QuestieDB.private.npcCache[1001])
        assert.equals(2, table.getn(queuedTimers))

        drainQueuedTimers()

        assert.is_table(QuestieDB.npcDataOverrides[1001])
        assert.is_nil(QuestieDB.private.npcCache[1001])
        assert.is_table(QuestieDB.npcDataOverrides[1001][7])

        local flushedSpawnCount = table.getn(QuestieDB.npcDataOverrides[1001][7][44])

        QuestieLearner:LearnNPC(1001, "Laggy Boar", nil, nil, nil, nil, 80.0, 80.0, 44)

        assert.equals(flushedSpawnCount, table.getn(QuestieDB.npcDataOverrides[1001][7][44]))
        assert.is_true(table.getn(queuedTimers) >= 2)
    end)

    it("force-flushes active quest pins within the NPC live-update flush (no second debounce)", function()
        local updateCount = 0
        local originalUpdateQuest = QuestieQuest.UpdateQuest
        QuestieQuest.UpdateQuest = function(_, questId)
            updateCount = updateCount + 1
        end

        QuestiePlayer.currentQuestlog = { [5500] = true }
        local originalGetQuest = QuestieDB.GetQuest
        QuestieDB.GetQuest = function(questId)
            if questId == 5500 then
                return { Objectives = { [1] = { Id = 7500, spawnList = { [7500] = {} } } } }
            end
            return nil
        end

        QuestieLearner:LearnNPC(7500, "Quest Boar", nil, nil, nil, nil, 41.0, 52.0, 44)

        -- Drain exactly ONE timer round (the NPC live-update flush). The pin refresh
        -- must happen inside that same flush, not in a later pinRefreshDelay cycle.
        local firstRound = queuedTimers
        queuedTimers = {}
        for i = 1, table.getn(firstRound) do
            simulatedTime = simulatedTime + 1
            firstRound[i]()
        end

        assert.is_true(updateCount >= 1)

        -- And draining the rest must terminate (no infinite self-re-arming timer).
        drainQueuedTimers()

        QuestieDB.GetQuest = originalGetQuest
        QuestieQuest.UpdateQuest = originalUpdateQuest
    end)

    it("coalesces repeated quest-pin refreshes into one flush", function()
        local updateCount = 0
        local originalUpdateQuest = QuestieQuest.UpdateQuest
        QuestieQuest.UpdateQuest = function(_, questId)
            updateCount = updateCount + 1
        end

        QuestiePlayer.currentQuestlog = { [5001] = true }
        Questie.dbLearner.global.quests = {}
        QuestieDB.questDataOverrides = {}

        QuestieLearner:LearnQuestObjectiveNPC(5001, 7001, "Pin Boar slain", 1)
        QuestieLearner:LearnQuestObjectiveNPC(5001, 7001, "Pin Boar slain", 1)

        assert.is_true(table.getn(queuedTimers) >= 1)

        for i = 1, table.getn(queuedTimers) do
            queuedTimers[i]()
        end

        assert.is_table(Questie.dbLearner.global.quests[5001])
        assert.is_table(QuestieDB.questDataOverrides[5001])

        QuestieQuest.UpdateQuest = originalUpdateQuest
    end)

    it("suppresses an already queued pin refresh after switching to manual mode", function()
        local updateCount = 0
        local originalUpdateQuest = QuestieQuest.UpdateQuest
        QuestieQuest.UpdateQuest = function(_, questId)
            updateCount = updateCount + 1
        end

        QuestiePlayer.currentQuestlog = { [5003] = true }
        Questie.dbLearner.global.quests = {}
        QuestieDB.questDataOverrides = {}

        QuestieLearner:LearnQuestObjectiveNPC(5003, 7003, "Manual Boar slain", 1)

        assert.is_true(table.getn(queuedTimers) >= 1)

        Questie.dbLearner.global.settings.pinRefreshMode = "manual"
        drainQueuedTimers()

        assert.equals(0, updateCount)

        QuestieQuest.UpdateQuest = originalUpdateQuest
    end)

    it("keeps bystander UNIT_DIED eligible for learning in the source path", function()
        local learner = read("Modules/QuestieLearner.lua")

        assert.is_true(has(learner, "Unconditionally map the spawn position for Ascension DB building"))
        assert.is_true(has(learner, "self:LearnNPC(npcId, name, nil, nil, nil, nil, px, py, zoneId)"))
        assert.is_false(has(learner, 'if eventType ~= "PARTY_KILL" and not credited then'))
    end)

    it("still learns and batches local PARTY_KILL combat-log events", function()
        QuestieLearner:OnCombatLogEvent(
            1234,
            "PARTY_KILL",
            UnitGUID("player"),
            UnitName("player"),
            nil,
            "Creature-0-0-0-0-7003-0000000001",
            "Tagged Boar",
            nil
        )

        assert.is_table(Questie.dbLearner.global.npcs[7003])
        assert.equals("Tagged Boar", Questie.dbLearner.global.npcs[7003][1])
        assert.equals(2, table.getn(queuedTimers))
    end)

    it("only announces combat-log learning once per unique NPC id", function()
        local debugMessages = {}
        local originalDebug = Questie.Debug
        Questie.Debug = function(self, level, ...)
            local parts = { ... }
            for i = 1, table.getn(parts) do
                if parts[i] == "[QuestieLearner] Combat-log learned NPC:" then
                    debugMessages[table.getn(debugMessages) + 1] = level
                    break
                end
            end
        end

        QuestieLearner:OnCombatLogEvent(
            1234,
            "PARTY_KILL",
            UnitGUID("player"),
            UnitName("player"),
            nil,
            "Creature-0-0-0-0-7010-0000000001",
            "Unique Boar",
            nil
        )

        QuestieLearner:OnCombatLogEvent(
            1235,
            "PARTY_KILL",
            UnitGUID("player"),
            UnitName("player"),
            nil,
            "Creature-0-0-0-0-7010-0000000002",
            "Unique Boar",
            nil
        )

        assert.is_table(Questie.dbLearner.global.npcs[7010])
        assert.equals(1, table.getn(debugMessages))

        Questie.Debug = originalDebug
    end)

    it("still learns credited UNIT_DIED combat-log events when PARTY_KILL is absent", function()
        QuestieLearner:OnCombatLogEvent(
            1234,
            "UNIT_DIED",
            UnitGUID("player"),
            UnitName("player"),
            nil,
            "Creature-0-0-0-0-7004-0000000001",
            "Credited Boar",
            nil
        )

        assert.is_table(Questie.dbLearner.global.npcs[7004])
        assert.equals("Credited Boar", Questie.dbLearner.global.npcs[7004][1])
        assert.equals(2, table.getn(queuedTimers))
    end)

    it("cross-links quest giver NPCs and objects learned after the quest without duplicate pin flushes", function()
        local updateCount = 0
        local originalUpdateQuest = QuestieQuest.UpdateQuest
        QuestieQuest.UpdateQuest = function(_, questId)
            updateCount = updateCount + 1
        end
        Questie.db.profile.learnerBroadcast = false
        QuestiePlayer.currentQuestlog = { [6001] = true }

        QuestieLearner:LearnQuest(6001, {
            [1] = "Cross Link Givers",
            [2] = { [1] = { 7101 }, [2] = { 8101 } },
            [3] = { [1] = { 7102 }, [2] = { 8102 } },
        })

        queuedTimers = {}

        QuestieLearner:LearnNPC(7101, "Starter Guard", nil, nil, nil, nil, 10, 20, 44)
        QuestieLearner:LearnNPC(7102, "Finisher Guard", nil, nil, nil, nil, 30, 40, 44)
        QuestieLearner:LearnObject(8101, "Starter Chest")
        QuestieLearner:LearnObject(8102, "Finisher Chest")

        assert.same({ 6001 }, Questie.dbLearner.global.npcs[7101][10])
        assert.same({ 6001 }, Questie.dbLearner.global.npcs[7102][11])
        assert.same({ 6001 }, Questie.dbLearner.global.objects[8101][2])
        assert.same({ 6001 }, Questie.dbLearner.global.objects[8102][3])
        assert.same({ 6001 }, QuestieDB.npcDataOverrides[7101][10])
        assert.same({ 6001 }, QuestieDB.npcDataOverrides[7102][11])
        assert.same({ 6001 }, QuestieDB.objectDataOverrides[8101][2])
        assert.same({ 6001 }, QuestieDB.objectDataOverrides[8102][3])

        drainQueuedTimers()

        assert.is_table(Questie.dbLearner.global.quests[6001])
        assert.is_table(QuestieDB.questDataOverrides[6001])

        QuestieQuest.UpdateQuest = originalUpdateQuest
    end)

    it("cross-links item objective drop NPCs into quest creature objectives", function()
        Questie.db.profile.learnerBroadcast = false
        QuestiePlayer.currentQuestlog = { [6002] = true }

        QuestieLearner:LearnQuest(6002, {
            [1] = "Cross Link Drops",
            [10] = {
                [3] = {
                    { 2201, 0, 1, "Collect one tusk" },
                },
            },
        })
        QuestieLearner:LearnItem(2201, "Quest Tusk", 1, 1, 12, 0)
        QuestieLearner:LearnItemDrop(2201, 7201)

        assert.equals(7201, Questie.dbLearner.global.quests[6002][10][1][1][1])
        assert.equals(7201, QuestieDB.questDataOverrides[6002][10][1][1][1])

        QuestieLearner:LearnItemDrop(2201, 7201)

        assert.equals(1, table.getn(Questie.dbLearner.global.quests[6002][10][1]))
        assert.equals(1, table.getn(QuestieDB.questDataOverrides[6002][10][1]))
    end)

    it("defers learner objective tooltip registration to protected AscensionDB quest data", function()
        Questie.db.profile.learnerBroadcast = false
        QuestiePlayer.currentQuestlog = {}
        QuestieDB.ascensionOverrideKeys = {
            QUEST = {
                [8334] = {
                    [10] = true,
                },
            },
        }
        _G._lastRegisteredTooltip = nil

        QuestieLearner:LearnQuestObjectiveNPC(8334, 15271, "Tender slain", 1)

        assert.is_table(Questie.dbLearner.global.quests[8334])
        assert.is_nil(_G._lastRegisteredTooltip)
    end)

    it("coalesces repeated learner broadcasts into one latest update", function()
        QuestieLearner:LearnItem(2001, "Quest Tusk", 1, 1, 12, 0)
        QuestieLearner:LearnItem(2001, "Quest Tusk", 1, 1, 12, 0)

        assert.equals(0, table.getn(broadcasts))
        assert.equals(1, table.getn(queuedTimers))

        drainQueuedTimers()

        assert.equals(1, table.getn(broadcasts))
        assert.equals("NEW", broadcasts[1].op)
        assert.equals("ITEM", broadcasts[1].typ)
        assert.equals(2001, broadcasts[1].id)
    end)

    it("coalesces repeated inbound network merges into one inject pass", function()
        local injectCount = 0
        local originalInject = QuestieLearner.InjectLearnedData
        QuestieLearner.InjectLearnedData = function(self)
            injectCount = injectCount + 1
            QuestieLearner.data = Questie.dbLearner.global
        end

        QuestieLearner:HandleNetworkData("NPC", 3001, { [1] = "Net Boar", [7] = { [44] = { { 11, 22 } } } }, "NEW")
        QuestieLearner:HandleNetworkData("NPC", 3001, { [1] = "Net Boar", [7] = { [44] = { { 11, 22 }, { 33, 44 } } } }, "UPDATE")

        assert.equals(0, injectCount)
        assert.equals(1, table.getn(queuedTimers))

        drainQueuedTimers()

        assert.equals(1, injectCount)
        assert.equals("Net Boar", Questie.dbLearner.global.npcs[3001][1])
        assert.equals(2, table.getn(Questie.dbLearner.global.npcs[3001][7][44]))

        QuestieLearner.InjectLearnedData = originalInject
    end)

    it("forwards OnEvent payload arguments to learner handlers", function()
        local originalCreateFrame = _G.CreateFrame
        local originalStrsplit = _G.strsplit
        local createdFrame = nil
        local captured = {
            questTurnedIn = nil,
            questAccepted = nil,
            combatLog = nil,
            itemInfoReceived = nil,
            questTrackingCleared = nil,
        }

        _G.CreateFrame = function()
            createdFrame = {
                RegisterEvent = function() end,
                SetScript = function(self, scriptName, fn)
                    if scriptName == "OnEvent" then
                        self._onEvent = fn
                    end
                end,
            }
            return createdFrame
        end
        _G.strsplit = function(sep, str)
            local parts = {}
            local pattern = string.format("([^%s]+)", sep)
            for part in string.gmatch(str, pattern) do
                parts[#parts + 1] = part
            end
            return unpack(parts)
        end

        QuestieLearner = dofile("Modules/QuestieLearner.lua")
        local originalOnQuestTurnedIn = QuestieLearner.OnQuestTurnedIn
        local originalOnQuestAccepted = QuestieLearner.OnQuestAccepted
        local originalOnCombatLogEvent = QuestieLearner.OnCombatLogEvent
        local originalOnGetItemInfoReceived = QuestieLearner.OnGetItemInfoReceived
        local originalClearQuestObjectiveTracking = QuestieLearner.ClearQuestObjectiveTracking

        QuestieLearner.OnQuestTurnedIn = function(self, questId, npcId, questFlags)
            captured.questTurnedIn = { questId, npcId, questFlags }
        end
        QuestieLearner.OnQuestAccepted = function(self, questId, questGiver)
            captured.questAccepted = { questId, questGiver }
        end
        QuestieLearner.OnCombatLogEvent = function(self, timestamp, eventType, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName)
            captured.combatLog = { timestamp, eventType, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName }
        end
        QuestieLearner.OnGetItemInfoReceived = function(self, itemId)
            captured.itemInfoReceived = { itemId }
        end
        QuestieLearner.ClearQuestObjectiveTracking = function(self, questId)
            captured.questTrackingCleared = { questId }
        end

        QuestieLearner:RegisterEvents()

        local frame = createdFrame
        frame._onEvent(frame, "QUEST_TURNED_IN", 101, 202, 303)
        frame._onEvent(frame, "QUEST_ACCEPTED", 404, 505)
        frame._onEvent(frame, "COMBAT_LOG_EVENT_UNFILTERED", 1, "SPELL_DAMAGE", "src-guid", "Src", 2, "dst-guid", "Dst", 4, 777, "Fireball")
        frame._onEvent(frame, "GET_ITEM_INFO_RECEIVED", 888)
        frame._onEvent(frame, "QUEST_REMOVED", 999)

        assert.same({ 101, 202, 303 }, captured.questTurnedIn)
        assert.same({ 404, 505 }, captured.questAccepted)
        assert.same({ 1, "SPELL_DAMAGE", "src-guid", "Src", 2, "dst-guid", "Dst", 4, 777, "Fireball" }, captured.combatLog)
        assert.same({ 888 }, captured.itemInfoReceived)
        assert.same({ 999 }, captured.questTrackingCleared)

        QuestieLearner.OnQuestTurnedIn = originalOnQuestTurnedIn
        QuestieLearner.OnQuestAccepted = originalOnQuestAccepted
        QuestieLearner.OnCombatLogEvent = originalOnCombatLogEvent
        QuestieLearner.OnGetItemInfoReceived = originalOnGetItemInfoReceived
        QuestieLearner.ClearQuestObjectiveTracking = originalClearQuestObjectiveTracking
        _G.CreateFrame = originalCreateFrame
        _G.strsplit = originalStrsplit
    end)
end)

describe("QuestieLearnerComms queue draining", function()
    local sentMessages
    local processedMessages
    local QuestieLearnerComms
    local currentTime

    before_each(function()
        dofile("Tests/wow_api_mock.lua")

        sentMessages = {}
        processedMessages = {}
        currentTime = 1000

        local originalImportModule = QuestieLoader.ImportModule
        QuestieLoader.ImportModule = function(self, name)
            if name == "QuestieLearner" then
                return _G.QuestieLearner
            end
            return originalImportModule(self, name)
        end
        QuestieLoader.CreateModule = function(self, name)
            _G[name] = { private = {} }
            return _G[name]
        end

        _G.LibStub = function(name, silent)
            if name == "AceComm-3.0" then
                return { RegisterComm = function() end }
            elseif name == "LibDeflate" then
                return {
                    CompressDeflate = function(_, s) return s end,
                    EncodeForPrint = function(_, s) return s end,
                    DecodeForPrint = function(_, s) return s end,
                    DecompressDeflate = function(_, s) return s end,
                }
            elseif name == "AceSerializer-3.0" then
                return {
                    Serialize = function(_, payload)
                        return payload.op .. ":" .. tostring(payload.id)
                    end,
                    Deserialize = function(_, serialized)
                        local op, id = string.match(serialized, "([^:]+):(.+)")
                        return true, {
                            _ver = 2,
                            op = op,
                            typ = "NPC",
                            id = tonumber(id) or id,
                            d = { [1] = "net" },
                        }
                    end,
                }
            elseif name == "XXH_Lua_Lib" then
                return nil
            elseif name == "HereBeDragonsQuestie-2.0" then
                return {}
            end
            return {}
        end

        _G.QuestieLearner = {
            HandleNetworkData = function(_, typ, id, d, op)
                processedMessages[table.getn(processedMessages) + 1] = {
                    typ = typ,
                    id = id,
                    op = op,
                }
            end,
        }

        _G.GetChannelName = function() return 1 end
        _G.JoinPermanentChannel = function() end
        _G.ChatFrame_RemoveChannel = function() end
        _G.DEFAULT_CHAT_FRAME = { GetID = function() return 1 end }
        _G.SendChatMessage = function(msg, mode, nilarg, channel)
            sentMessages[table.getn(sentMessages) + 1] = msg
        end
        _G.InCombatLockdown = function() return false end
        _G.random = function() return 0 end
        _G.GetTime = function()
            return currentTime
        end
        QuestieCompat.C_Timer.NewTicker = function(delay, fn)
            return { Cancel = function() end }
        end

        dofile("Modules/Network/QuestieLearnerComms.lua")
        QuestieLearnerComms = _G.QuestieLearnerComms
        QuestieLearnerComms:Initialize()
    end)

    it("drains outgoing and incoming queues in FIFO order without front-removal", function()
        QuestieLearnerComms:BroadcastLearnedData("NEW", "NPC", 101, { foo = "a" })
        QuestieLearnerComms:BroadcastLearnedData("UPDATE", "NPC", 102, { foo = "b" })

        QuestieLearnerComms:OnCommReceived("QuestieLearner", "NEW:201", "CHANNEL", "Alice")
        QuestieLearnerComms:OnCommReceived("QuestieLearner", "UPDATE:202", "CHANNEL", "Bob")

        QuestieLearnerComms.private:ProcessQueues()
        currentTime = currentTime + 4
        QuestieLearnerComms.private:ProcessQueues()
        currentTime = currentTime + 4
        QuestieLearnerComms.private:ProcessQueues()

        assert.equals(2, table.getn(sentMessages))
        assert.equals("NEW:101", sentMessages[1])
        assert.equals("UPDATE:102", sentMessages[2])
        assert.equals(2, table.getn(processedMessages))
        assert.equals(201, processedMessages[1].id)
        assert.equals(202, processedMessages[2].id)
    end)
end)

describe("QuestieComms packet sizing", function()
    local serializeCount
    local sendCount
    local QuestieComms

    before_each(function()
        dofile("Tests/wow_api_mock.lua")

        serializeCount = 0
        sendCount = 0

        local originalCreateModule = QuestieLoader.CreateModule
        local originalImportModule = QuestieLoader.ImportModule
        QuestieLoader.CreateModule = function(self, name)
            _G[name] = { private = {} }
            return _G[name]
        end
        QuestieLoader.ImportModule = function(self, name)
            if name == "QuestieSerializer" then
                return {
                    Serialize = function(_, payload)
                        serializeCount = serializeCount + 1
                        return "packet:" .. tostring(payload.id or payload[1] or "x")
                    end,
                    Deserialize = function() return true, {} end,
                }
            end
            return originalImportModule(self, name)
        end

        _G.LibStub = function(name, silent)
            if name == "AceComm-3.0" then
                return { RegisterComm = function() end }
            elseif name == "LibDeflate" then
                return {
                    CompressDeflate = function(_, s) return s end,
                    EncodeForPrint = function(_, s) return s end,
                    DecodeForPrint = function(_, s) return s end,
                    DecompressDeflate = function(_, s) return s end,
                }
            elseif name == "AceSerializer-3.0" then
                return {
                    Serialize = function(_, payload) return "packet:" .. tostring(payload.id or payload[1] or "x") end,
                    Deserialize = function() return true, {} end,
                }
            elseif name == "XXH_Lua_Lib" then
                return nil
            elseif name == "HereBeDragonsQuestie-2.0" then
                return {}
            end
            return {}
        end

        _G.QuestiePlayer.GetGroupType = function() return "party" end
        _G.QuestiePlayer.numberOfGroupMembers = 5
        _G.QuestieDB.QuestPointers = {
            [101] = true,
            [102] = true,
            [103] = true,
        }
        _G.QuestieDB.QueryQuestSingle = function()
            return 0
        end
        _G.QuestieDB.GetQuest = function(questId)
            return {
                Objectives = {
                    [1] = { Id = questId * 10 },
                },
            }
        end
        _G.QuestLogCache.questLog_DO_NOT_MODIFY = {
            [101] = { questTag = "Normal" },
            [102] = { questTag = "Normal" },
            [103] = { questTag = "Normal" },
        }
        _G.QuestLogCache.GetQuestObjectives = function()
            return {
                { type = "monster", numFulfilled = 0, numRequired = 1 },
            }
        end
        _G.ZoneDB.GetUiMapIdByAreaId = function()
            return 1
        end
        _G.HBD = {
            GetZoneDistance = function() return 1 end,
            GetPlayerZone = function() return 1 end,
        }
        _G.GetChannelName = function() return 1 end
        _G.SendChatMessage = function() end
        _G.Questie.SendCommMessage = function()
            sendCount = sendCount + 1
        end
        _G.UnitInBattleground = function() return false end
        _G.random = function() return 0 end
        _G.GetTime = function() return 0 end
        _G.tinsert = table.insert
        QuestieCompat.C_Timer.After = function(_, fn) end
        QuestieCompat.C_Timer.NewTicker = function(_, fn)
            return { Cancel = function() end }
        end

        QuestieComms = dofile("Modules/Network/QuestieComms.lua")
        QuestieComms.private.CreatePacket = function()
            return {
                data = {},
                write = function() end,
            }
        end

        serializeCount = 0
    end)

    it("serializes each quest once while packing broadcast blocks", function()
        QuestieComms.private:BroadcastQuestLog("QC_ID_BROADCAST_FULL_QUESTLIST", "WHISPER", "Tester")
        assert.equals(3, serializeCount)

        serializeCount = 0
        QuestieComms.private:BroadcastQuestLogV2("QC_ID_BROADCAST_FULL_QUESTLIST", "WHISPER", "Tester")
        assert.equals(3, serializeCount)
    end)

    it("suppresses outgoing QuestieComms immediately when disabled", function()
        Questie.db.profile.questieCommsEnabled = false

        local packet = QuestieComms.private:CreatePacket(QuestieComms.private.QC_ID_BROADCAST_QUEST_REMOVE)
        packet.data.writeMode = QuestieComms.private.QC_WRITE_ALLGROUP
        packet.data.priority = "NORMAL"
        packet.data.id = 101
        packet:write()

        assert.equals(0, sendCount)
    end)
end)
