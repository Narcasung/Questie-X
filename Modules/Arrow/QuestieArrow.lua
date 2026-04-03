---@class QuestieArrow
local QuestieArrow = QuestieLoader:CreateModule("QuestieArrow")

---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
---@type QuestieMap
local QuestieMap = QuestieLoader:ImportModule("QuestieMap")
---@type QuestieTracker
local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")
---@type QuestieQuest
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest")

local HBD = QuestieCompat.HBD or LibStub("HereBeDragonsQuestie-2.0")

local atan2 = math.atan2
local pi = math.pi
local floor = math.floor
local abs = math.abs
local max = math.max
local min = math.min

local ARROW_SHEET_SIZE = 512
local ARROW_CELL_W = 56
local ARROW_CELL_H = 42
local ARROW_SHEET_COLS = 9
local ARROW_SHEET_ROWS = 12
local ARROW_TOTAL_CELLS = ARROW_SHEET_COLS * ARROW_SHEET_ROWS

local UPDATE_THROTTLE_SECONDS = 0.05
local RECALC_NEAREST_SECONDS = 1.0
local TRACKER_REFRESH_THROTTLE_SECONDS = 0.5

---@type Frame?
local arrowFrame = nil
---@type Frame?
local driverFrame = nil

-- Current auto-tracked targets sorted by distance
local sortedTargets = {}
local hasManualTarget = false

-- Shared context written by UpdateNearestTargets, read by hoisted helpers.
-- Avoids closure allocation on every call.
local _arrow_playerX, _arrow_playerY, _arrow_playerInstance
local _arrow_usingAutoLogic, _arrow_playerZoneId, _arrow_playerUiMapId
local _arrow_quest  -- current quest being processed by the hoisted helpers

local lastPopulateByQuestId = {}

local function _IsArrowEnabled()
    if not Questie or not Questie.db or not Questie.db.profile then
        return true
    end
    return Questie.db.profile.arrowEnabled ~= false
end

local function _GetArrowScale()
    if not Questie or not Questie.db or not Questie.db.profile then
        return 1
    end
    return Questie.db.profile.arrowScale or 1
end

local function _GetArrowAlpha()
    if not Questie or not Questie.db or not Questie.db.profile then
        return 1.0
    end
    return Questie.db.profile.arrowAlpha or 1.0
end

local function _SetArrowScale(scale)
    if not Questie or not Questie.db or not Questie.db.profile then
        return
    end
    Questie.db.profile.arrowScale = scale
end

local function _GetProfilePosition()
    if not Questie or not Questie.db or not Questie.db.profile then
        return nil
    end
    return Questie.db.profile.arrowPosition
end

local function _SaveProfilePosition(point, relativePoint, x, y)
    if not Questie or not Questie.db or not Questie.db.profile then
        return
    end
    Questie.db.profile.arrowPosition = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end

local function modulo(val, by)
    return val - floor(val / by) * by
end

local function GetColorGradient(perc)
    if perc <= 0.5 then
        return 1, perc * 2, 0
    else
        return 2 - perc * 2, 1, 0
    end
end

local function ResolveIconTexture(icon)
    if not icon then
        return nil
    end

    if type(icon) == "string" then
        return icon
    end

    if type(icon) == "number" then
        if Questie and Questie.usedIcons then
            return Questie.usedIcons[icon]
        end
        return nil
    end

    return nil
end

local function _ApplyOutline(fontString)
    if not fontString or not fontString.GetFont or not fontString.SetFont then
        return
    end

    local font, size, flags = fontString:GetFont()
    if not font then
        return
    end

    flags = flags or ""
    if not string.find(flags, "OUTLINE", 1, true) then
        if flags ~= "" then
            flags = flags .. ",OUTLINE"
        else
            flags = "OUTLINE"
        end
    end

    fontString:SetFont(font, size, flags)
end

local function EnsureArrowFrame()
    if arrowFrame then
        -- Apply current scale and alpha settings even if frame already exists
        arrowFrame:SetScale(_GetArrowScale())
        arrowFrame:SetAlpha(_GetArrowAlpha())
        return
    end

    arrowFrame = CreateFrame("Frame", "QuestieArrowFrame", UIParent)

    local pos = _GetProfilePosition()
    if pos and pos.point and pos.relativePoint and pos.x and pos.y then
        arrowFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    else
        arrowFrame:SetPoint("CENTER", 0, -100)
    end

    -- Store whether we should use saved position or default
    arrowFrame._useDefaultPosition = not (pos and pos.point)

    -- Make room for the objective icon below the arrow (no overlap)
    arrowFrame:SetWidth(56)
    arrowFrame:SetHeight(64)
    arrowFrame:SetScale(_GetArrowScale())
    arrowFrame:SetClampedToScreen(true)
    arrowFrame:SetMovable(true)
    arrowFrame:EnableMouse(true)
    arrowFrame:EnableMouseWheel(true)
    arrowFrame:RegisterForDrag("LeftButton")
    arrowFrame:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then
            self:StartMoving()
        end
    end)
    arrowFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()

        local point, _, relativePoint, x, y = self:GetPoint(1)
        if point and relativePoint and x and y then
            _SaveProfilePosition(point, relativePoint, x, y)
        end
    end)

    arrowFrame:SetScript("OnMouseWheel", function(self, delta)
        if not IsShiftKeyDown() then
            return
        end

        local scale = _GetArrowScale() or 1
        local step = 0.05
        if delta and delta > 0 then
            scale = scale + step
        else
            scale = scale - step
        end

        if scale < 0.5 then scale = 0.5 end
        if scale > 2.0 then scale = 2.0 end

        _SetArrowScale(scale)
        self:SetScale(scale)
    end)

    -- Arrow sprite sheet texture (108 cells: 9 columns, 12 rows)
    arrowFrame.arrow = arrowFrame:CreateTexture(nil, "MEDIUM")
    arrowFrame.arrow:SetTexture(QuestieLib.AddonPath .. "Icons\\arrow.tga")
    -- Render at native cell size; use frame scaling if you want it larger.
    arrowFrame.arrow:SetWidth(ARROW_CELL_W)
    arrowFrame.arrow:SetHeight(ARROW_CELL_H)
    arrowFrame.arrow:SetPoint("TOP", arrowFrame, "TOP", 0, 0)
    arrowFrame.arrow:SetTexCoord(0, 0.109375, 0, 0.08203125) -- First cell

    -- Quest icon texture at bottom (pfQuest style)
    arrowFrame.icon = arrowFrame:CreateTexture(nil, "OVERLAY")
    arrowFrame.icon:SetWidth(28)
    arrowFrame.icon:SetHeight(28)
    arrowFrame.icon:SetPoint("BOTTOM", arrowFrame.arrow, "BOTTOM", 0, -20)

    arrowFrame.title = arrowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrowFrame.title:SetPoint("TOP", arrowFrame.icon, "BOTTOM", 0, -2)
    arrowFrame.title:SetJustifyH("CENTER")
    _ApplyOutline(arrowFrame.title)

    arrowFrame.distance = arrowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arrowFrame.distance:SetPoint("TOP", arrowFrame.title, "BOTTOM", 0, -2)
    arrowFrame.distance:SetJustifyH("CENTER")
    arrowFrame.distance:SetTextColor(1, 1, 1, 1)
    _ApplyOutline(arrowFrame.distance)

    arrowFrame._lastUpdate = 0
    arrowFrame._lastRecalc = 0
    arrowFrame._lastTarget = nil

    -- Right-click to clear manual target and resume auto-tracking
    arrowFrame:EnableMouse(true)
    arrowFrame:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            hasManualTarget = false
            sortedTargets = {}
            QuestieArrow:Refresh()
        end
    end)

    arrowFrame:SetScript("OnUpdate", function(self)
        local now = GetTime()

        local target = sortedTargets[1]
        if not target then
            self:Hide()
            return
        end

        if not self:IsShown() then
            self:Show()
        end

        if (self._lastUpdate or 0) + UPDATE_THROTTLE_SECONDS > now then
            return
        end
        self._lastUpdate = now

        local playerX, playerY, playerInstance = HBD:GetPlayerWorldPosition()
        if not playerX or not playerY or not playerInstance then
            self.distance:SetText("Distance: --")
            return
        end

        local targetX, targetY, targetInstance = HBD:GetWorldCoordinatesFromZone(target.x / 100.0, target.y / 100.0,
            target.uiMapId)
        if not targetX or not targetY or not targetInstance then
            self.distance:SetText("Distance: --")
            return
        end

        if targetInstance ~= playerInstance then
            self:Hide()
            return
        end

        -- Calculate arrow direction using pfQuest's method, but in world coordinates
        -- (map coordinates break when the target is in a different zone)
        local xDelta = (playerX - targetX) * 1.5
        local yDelta = (playerY - targetY)
        local angle = atan2(xDelta, -(yDelta))
        angle = angle > 0 and (pi * 2) - angle or -angle
        if angle < 0 then angle = angle + (pi * 2) end

        local player = GetPlayerFacing and GetPlayerFacing() or 0
        angle = angle - player

        -- Calculate color gradient based on direction
        local perc = abs(((pi - abs(angle)) / pi))
        local r, g, b = GetColorGradient(perc)

        -- Select sprite sheet cell
        local cell = modulo(floor(angle / (pi * 2) * ARROW_TOTAL_CELLS + 0.5), ARROW_TOTAL_CELLS)
        local column = modulo(cell, ARROW_SHEET_COLS)
        local row = floor(cell / ARROW_SHEET_COLS)
        local xstart = (column * ARROW_CELL_W) / ARROW_SHEET_SIZE
        local ystart = (row * ARROW_CELL_H) / ARROW_SHEET_SIZE
        local xend = ((column + 1) * ARROW_CELL_W) / ARROW_SHEET_SIZE
        local yend = ((row + 1) * ARROW_CELL_H) / ARROW_SHEET_SIZE

        -- Avoid bleeding from neighboring cells when texture filtering is enabled.
        local padX = 0.5 / ARROW_SHEET_SIZE
        local padY = 0.5 / ARROW_SHEET_SIZE
        xstart = xstart + padX
        ystart = ystart + padY
        xend = xend - padX
        yend = yend - padY

        -- Calculate distance and alpha
        local dist = HBD:GetWorldDistance(targetInstance, playerX, playerY, targetX, targetY)
        if dist then
            local area = 1
            local alpha = dist - area
            alpha = alpha > 1 and 1 or alpha
            alpha = alpha < 0.5 and 0.5 or alpha

            local texalpha = (1 - alpha) * 2
            texalpha = texalpha > 1 and 1 or texalpha
            texalpha = texalpha < 0 and 0 or texalpha

            r, g, b = r + texalpha, g + texalpha, b + texalpha

            self.arrow:SetTexCoord(xstart, xend, ystart, yend)
            self.arrow:SetVertexColor(r, g, b)
            self.arrow:SetAlpha(alpha)

            local distText = string.format("%.1f", dist)
            self.distance:SetText("Distance: " .. distText)
        end

        -- Update title and icon when target changes
        if target ~= self._lastTarget then
            self._lastTarget = target

            local title = target.title or ""
            if target.questLevel then
                title = "[" .. target.questLevel .. "] " .. title
            end
            self.title:SetText(Questie:Colorize(title, "gold"))

            if target.iconPath then
                self.icon:SetTexture(target.iconPath)
                self.icon:Show()
            else
                self.icon:Hide()
            end
        end
    end)

    arrowFrame:Hide()
end

local function EnsureDriverFrame()
    if driverFrame then
        return
    end

    driverFrame = CreateFrame("Frame", "QuestieArrowDriverFrame", UIParent)
    driverFrame:Show()
    driverFrame._lastRecalc = 0

    driverFrame:SetScript("OnUpdate", function(self)
        local now = GetTime()
        if (self._lastRecalc or 0) + RECALC_NEAREST_SECONDS < now then
            self._lastRecalc = now
            if not _IsArrowEnabled() then
                if arrowFrame then
                    arrowFrame:Hide()
                end
                return
            end
            QuestieArrow:Refresh()
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Hoisted helpers for UpdateNearestTargets.
-- These were previously closures recreated on every call; now they are
-- module-level functions that read shared upvalue state set each cycle.
-- ---------------------------------------------------------------------------

local function _HasMissingCompletedFlag(list)
    if not list then return false end
    for _, obj in pairs(list) do
        if obj and obj.Completed == nil then
            return true
        end
    end
    return false
end

local function _GetCompleteIconType(quest)
    local iconType = Questie.ICON_TYPE_COMPLETE
    if QuestieDB and QuestieDB.IsActiveEventQuest and QuestieDB.IsActiveEventQuest(quest.Id) then
        iconType = Questie.ICON_TYPE_EVENTQUEST_COMPLETE
    elseif QuestieDB and QuestieDB.IsPvPQuest and QuestieDB.IsPvPQuest(quest.Id) then
        iconType = Questie.ICON_TYPE_PVPQUEST_COMPLETE
    elseif quest.IsRepeatable then
        iconType = Questie.ICON_TYPE_REPEATABLE_COMPLETE
    end
    return iconType
end

local function _CollectFinisherSpawns(finisher, quest)
    if not finisher then return end
    local pX, pY, pInst = _arrow_playerX, _arrow_playerY, _arrow_playerInstance
    local autoLogic, pZone, pMap = _arrow_usingAutoLogic, _arrow_playerZoneId, _arrow_playerUiMapId
    local iconPath = ResolveIconTexture(_GetCompleteIconType(quest))
    if finisher.spawns then
        for finisherZone, spawns in pairs(finisher.spawns) do
            if finisherZone and spawns then
                for _, coords in ipairs(spawns) do
                    if coords and coords[1] and coords[2] then
                        if coords[1] == -1 or coords[2] == -1 then
                            local dungeonLocation = ZoneDB:GetDungeonLocation(finisherZone)
                            if dungeonLocation then
                                for _, value in ipairs(dungeonLocation) do
                                    local zone = value[1]
                                    local x = value[2]
                                    local y = value[3]
                                    -- Zone filtering disabled (zone ID vs area ID mismatch)
                                    if true then
                                        local uiMapId = ZoneDB:GetUiMapIdByAreaId(zone)
                                        if uiMapId and x and y then
                                            local tX, tY, tInst = HBD:GetWorldCoordinatesFromZone(x / 100.0, y / 100.0, uiMapId)
                                            if tX and tY and tInst then
                                                local dist = HBD:GetWorldDistance(tInst, pX, pY, tX, tY)
                                                if dist then
                                                    if tInst ~= pInst then dist = 500000 + dist * 100 end
                                                    table.insert(sortedTargets, {
                                                        x = x, y = y, uiMapId = uiMapId, title = quest.name, questLevel = quest.level, iconPath = iconPath, distance = dist,
                                                    })
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        else
                            -- Zone filtering disabled (same zone ID vs area ID mismatch issue)
                            if true then
                                local x = coords[1]
                                local y = coords[2]
                                local uiMapId = ZoneDB:GetUiMapIdByAreaId(finisherZone)
                                if uiMapId then
                                    local tX, tY, tInst = HBD:GetWorldCoordinatesFromZone(x / 100.0, y / 100.0, uiMapId)
                                    if tX and tY and tInst then
                                        local dist = HBD:GetWorldDistance(tInst, pX, pY, tX, tY)
                                        if dist then
                                            if tInst ~= pInst then dist = 500000 + dist * 100 end
                                            table.insert(sortedTargets, {
                                                x = x, y = y, uiMapId = uiMapId, title = quest.name, questLevel = quest.level, iconPath = iconPath, distance = dist,
                                            })
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if finisher.waypoints then
        for zone, waypoints in pairs(finisher.waypoints) do
            -- Zone filtering disabled (same zone ID vs area ID mismatch issue)
            if true then
                if waypoints and waypoints[1] and waypoints[1][1] and waypoints[1][1][1] then
                    local x = waypoints[1][1][1]
                    local y = waypoints[1][1][2]
                    local uiMapId = ZoneDB:GetUiMapIdByAreaId(zone)
                    if uiMapId and x and y then
                        local tX, tY, tInst = HBD:GetWorldCoordinatesFromZone(x / 100.0, y / 100.0, uiMapId)
                        if tX and tY and tInst then
                            local dist = HBD:GetWorldDistance(tInst, pX, pY, tX, tY)
                            if dist then
                                if tInst ~= pInst then dist = 500000 + dist * 100 end
                                table.insert(sortedTargets, {
                                    x = x, y = y, uiMapId = uiMapId, title = quest.name, questLevel = quest.level, iconPath = iconPath, distance = dist,
                                })
                            end
                        end
                    end
                end
            end
        end
    end
end

local function _CollectObjective(objective, quest)
    if not objective or not objective.spawnList then return end
    if QuestieQuest.ShouldHideObjective(objective) then return end
    if objective.Completed == true or objective.Completed == 1 then return end
    if objective.Needed and objective.Collected
        and type(objective.Needed) == "number" and type(objective.Collected) == "number"
        and objective.Collected >= objective.Needed then
        return
    end
    local pX, pY, pInst = _arrow_playerX, _arrow_playerY, _arrow_playerInstance
    local autoLogic, pZone, pMap = _arrow_usingAutoLogic, _arrow_playerZoneId, _arrow_playerUiMapId
    local debugCollect = Questie and Questie.db and Questie.db.profile and Questie.db.profile.debugArrow
    if debugCollect then
        print(string.format("    _CollectObjective: spawnList=%s", objective.spawnList and "yes" or "nil"))
    end
    if not objective.spawnList then return end
    for _, spawnData in pairs(objective.spawnList) do
        if debugCollect then
            print(string.format("      spawnData=%s Spawns=%s", spawnData and "yes" or "nil", spawnData and spawnData.Spawns and "yes" or "nil"))
        end
        if spawnData and spawnData.Spawns then
            for zone, spawns in pairs(spawnData.Spawns) do
                -- Zone filtering is disabled in auto mode because zone IDs and area IDs
                -- are different systems that don't directly compare. The distance
                -- calculation handles instance mismatches.
                local zoneFiltered = false -- Disabled: autoLogic and zone ~= pZone and zone ~= pMap
                if debugCollect then
                    print(string.format("        zone=%s filtered=%s (pZone=%s pMap=%s)", tostring(zone), tostring(zoneFiltered), tostring(pZone), tostring(pMap)))
                end
                if not zoneFiltered then
                    for _, spawn in pairs(spawns) do
                        local uiMapId = ZoneDB:GetUiMapIdByAreaId(zone)
                        if debugCollect then
                            print(string.format("          spawn=(%.1f,%.1f) uiMapId=%s", spawn[1], spawn[2], tostring(uiMapId)))
                        end
                        if uiMapId then
                            local tX, tY, tInst = HBD:GetWorldCoordinatesFromZone(spawn[1] / 100.0, spawn[2] / 100.0, uiMapId)
                            if tX and tY and tInst then
                                local dist = HBD:GetWorldDistance(tInst, pX, pY, tX, tY)
                                if dist then
                                    if tInst ~= pInst then dist = 500000 + dist * 100 end
                                    if debugCollect then
                                        print(string.format("            ADDED dist=%.0f", dist))
                                    end
                                    table.insert(sortedTargets, {
                                        x = spawn[1], y = spawn[2], uiMapId = uiMapId,
                                        title = quest.name, questLevel = quest.level,
                                        iconPath = ResolveIconTexture(objective.Icon) or ResolveIconTexture(spawnData and spawnData.Icon),
                                        distance = dist,
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Gather all objectives from tracked quests and sort by distance
function QuestieArrow:UpdateNearestTargets()
    -- Don't override manual targets with auto-updates
    if hasManualTarget then
        return
    end

    sortedTargets = {}

    if not Questie.db or not Questie.db.char then
        return
    end

    local playerX, playerY, playerInstance = HBD:GetPlayerWorldPosition()
    if not playerX or not playerY or not playerInstance then
        return
    end

    local tracked = Questie.db.char.TrackedQuests or {}
    local hasTracked = next(tracked) ~= nil

    -- Auto mode logic: If autoTrack is on OR NOTHING is tracked
    local usingAutoLogic = Questie.db.profile.autoTrackQuests or not hasTracked
    local playerZoneId = QuestiePlayer:GetCurrentZoneId()
    local playerUiMapId = QuestiePlayer:GetCurrentUiMapId()

    -- Publish context for hoisted helper functions (avoids closure allocation every call)
    _arrow_playerX, _arrow_playerY, _arrow_playerInstance = playerX, playerY, playerInstance
    _arrow_usingAutoLogic = usingAutoLogic
    _arrow_playerZoneId, _arrow_playerUiMapId = playerZoneId, playerUiMapId

    local function _CollectQuestTargets(quest)
        if not quest then return end

        local debugCollect = Questie and Questie.db and Questie.db.profile and Questie.db.profile.debugArrow

        -- Avoid spamming QuestieQuest:PopulateQuestLogInfo (it can trigger marker rebuilds and flicker).
        -- Only populate when objective completion flags are missing, and throttle per quest id.
        if QuestieQuest and QuestieQuest.PopulateQuestLogInfo and quest.Id then
            local needsPopulate = false
            if not quest.Objectives and not quest.SpecialObjectives then
                needsPopulate = true
            elseif _HasMissingCompletedFlag(quest.Objectives) or _HasMissingCompletedFlag(quest.SpecialObjectives) then
                needsPopulate = true
            end
            if needsPopulate then
                local now = GetTime()
                local last = lastPopulateByQuestId[quest.Id] or 0
                if (last + 2.0) < now then
                    lastPopulateByQuestId[quest.Id] = now
                    QuestieQuest:PopulateQuestLogInfo(quest)
                end
            end
        end

        local isComplete = quest.isComplete or (QuestieDB.IsComplete(quest.Id) == 1)
        if isComplete then quest.isComplete = true end

        if debugCollect then
            print(string.format("  _CollectQuestTargets: %s isComplete=%s hasObjectives=%s hasSpecialObjectives=%s hasFinisher=%s",
                tostring(quest.name), tostring(isComplete),
                tostring(quest.Objectives ~= nil),
                tostring(quest.SpecialObjectives ~= nil),
                tostring(quest.Finisher ~= nil)))
        end

        -- _GetCompleteIconType, _CollectFinisherSpawns, _CollectObjective are hoisted
        -- to module level above; no closures are created here.

        -- Main Logic Route for this quest target
        if isComplete then
            if quest.Finisher and quest.Finisher.Id and quest.Finisher.Type then
                local finisher
                if quest.Finisher.Type == "monster" and QuestieDB and QuestieDB.GetNPC then
                    finisher = QuestieDB:GetNPC(quest.Finisher.Id)
                elseif quest.Finisher.Type == "object" and QuestieDB and QuestieDB.GetObject then
                    finisher = QuestieDB:GetObject(quest.Finisher.Id)
                end
                _CollectFinisherSpawns(finisher, quest)
            end
            -- If the quest is complete, do not add normal objectives to the arrow!
            return
        end

        if quest.Objectives then
            if debugCollect then print(string.format("    Collecting %d objectives", #quest.Objectives)) end
            for _, objective in pairs(quest.Objectives) do
                _CollectObjective(objective, quest)
            end
        else
            if debugCollect then print("    No Objectives") end
        end
        if quest.SpecialObjectives then
            if debugCollect then print(string.format("    Collecting %d special objectives", #quest.SpecialObjectives)) end
            for _, objective in pairs(quest.SpecialObjectives) do
                _CollectObjective(objective, quest)
            end
        end
    end

    if QuestiePlayer and QuestiePlayer.currentQuestlog then
        local debugCollect = Questie and Questie.db and Questie.db.profile and Questie.db.profile.debugArrow
        for questId, quest in pairs(QuestiePlayer.currentQuestlog) do
            if debugCollect then
                print(string.format("Processing questId=%d type=%s", questId, type(quest)))
            end
            if type(quest) == "number" then
                if QuestieDB and QuestieDB.GetQuest then
                    quest = QuestieDB.GetQuest(questId)
                end
            end
            if type(quest) == "table" then
                local shouldTrack = false
                if usingAutoLogic then
                    if not Questie.db.char.AutoUntrackedQuests or not Questie.db.char.AutoUntrackedQuests[questId] then
                        shouldTrack = true
                    end
                else
                    if Questie.db.char.TrackedQuests and Questie.db.char.TrackedQuests[questId] then
                        shouldTrack = true
                    end
                end

                if debugCollect then
                    print(string.format("  questId=%d shouldTrack=%s usingAutoLogic=%s", questId, tostring(shouldTrack), tostring(usingAutoLogic)))
                end

                if shouldTrack then
                    if debugCollect then
                        print(string.format("  Calling _CollectQuestTargets for %s", tostring(quest.name)))
                    end
                    _CollectQuestTargets(quest)
                end
            end
        end
    end

    -- Sort by distance
    table.sort(sortedTargets, function(a, b) return a.distance < b.distance end)
end

function QuestieArrow:Refresh()
    if not _IsArrowEnabled() then
        if arrowFrame then
            arrowFrame:Hide()
        end
        return
    end

    QuestieArrow:UpdateNearestTargets()

    EnsureArrowFrame()

    local alpha = _GetArrowAlpha()
    local scale = _GetArrowScale()
    if arrowFrame then
        arrowFrame:SetAlpha(alpha)
        arrowFrame:SetScale(scale)
    end

    if sortedTargets[1] then
        arrowFrame:Show()
    else
        arrowFrame:Hide()
    end
end

-- Manual target setting (called from tracker TomTom bind)
---@param title string
---@param zoneOrUiMapId number
---@param x number
---@param y number
function QuestieArrow:SetTarget(title, zoneOrUiMapId, x, y)
    if not _IsArrowEnabled() then
        return
    end
    -- For manual targets, insert at front of sorted list
    local uiMapId = ZoneDB:GetUiMapIdByAreaId(zoneOrUiMapId) or zoneOrUiMapId

    hasManualTarget = true
    sortedTargets = { {
        x = x,
        y = y,
        uiMapId = uiMapId,
        title = title,
        distance = 0,     -- Manual targets always go first
    } }

    EnsureArrowFrame()
    arrowFrame:SetAlpha(_GetArrowAlpha())
    arrowFrame:Show()
end

function QuestieArrow:ClearTarget()
    hasManualTarget = false
    sortedTargets = {}

    if arrowFrame then
        arrowFrame:Hide()
    end
end

function QuestieArrow:ResetPosition()
    Questie.db.profile.arrowPosition = nil
    -- Ensure frame exists, then reset to default center position
    EnsureArrowFrame()
    if arrowFrame then
        arrowFrame:ClearAllPoints()
        arrowFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -100)
        arrowFrame._useDefaultPosition = true
    end
end

function QuestieArrow:ApplyScale()
    EnsureArrowFrame()
    if arrowFrame then
        arrowFrame:SetScale(_GetArrowScale())
    end
end

function QuestieArrow:ApplyAlpha()
    EnsureArrowFrame()
    if arrowFrame then
        arrowFrame:SetAlpha(_GetArrowAlpha())
    end
end

function QuestieArrow:UpdateSettings()
    EnsureArrowFrame()
    if arrowFrame then
        arrowFrame:SetScale(_GetArrowScale())
        arrowFrame:SetAlpha(_GetArrowAlpha())
        QuestieArrow:UpdateFont()
    end
end

function QuestieArrow:UpdateFont()
    print("UpdateFont called, arrowFrame=" .. tostring(arrowFrame) .. " title=" .. tostring(arrowFrame and arrowFrame.title))
    if not arrowFrame then return end
    local fontSize = Questie.db.profile.arrowFontSize or 10
    local fontFace = Questie.db.profile.arrowFont or QuestieFont:GetFont()
    if arrowFrame.title then
        print("Setting title font to " .. tostring(fontFace) .. " size " .. fontSize)
        arrowFrame.title:SetFont(fontFace, fontSize, "OUTLINE")
    end
    if arrowFrame.distance then
        print("Setting distance font to " .. tostring(fontFace) .. " size " .. (fontSize - 2))
        arrowFrame.distance:SetFont(fontFace, fontSize - 2, "OUTLINE")
    end
end

function QuestieArrow:Initialize()
    EnsureArrowFrame()

    EnsureDriverFrame()

    -- Refresh immediately on tracker updates (quest progress, objective completion, etc.)
    if QuestieTracker and QuestieTracker.Update and hooksecurefunc then
        local lastTrackerRefresh = 0
        hooksecurefunc(QuestieTracker, "Update", function()
            if hasManualTarget or not _IsArrowEnabled() then
                return
            end

            local now = GetTime()
            if (lastTrackerRefresh + TRACKER_REFRESH_THROTTLE_SECONDS) > now then
                return
            end

            lastTrackerRefresh = now
            QuestieArrow:Refresh()
        end)
    end

    QuestieArrow:Refresh()
end

-- Debug function to show current arrow target coordinates
function QuestieArrow:PrintTargetCoords()
    if not sortedTargets or not sortedTargets[1] then
        print("Questie Arrow: No target currently set!")
        return
    end
    local target = sortedTargets[1]
    print("Questie Arrow Target:")
    print("  Quest: " .. tostring(target.title))
    print("  Level: " .. tostring(target.questLevel))
    print("  Zone Coords: " .. string.format("%.1f, %.1f", target.x, target.y))
    print("  UI Map ID: " .. tostring(target.uiMapId))
    print("  Distance: " .. string.format("%.0f", target.distance))
end

function QuestieArrow:DebugPrint()
    print("=== Questie Arrow Debug ===")
    print("sortedTargets count: " .. tostring(#sortedTargets))
    print("hasManualTarget: " .. tostring(hasManualTarget))
    print("_arrow_usingAutoLogic: " .. tostring(_arrow_usingAutoLogic))
    print("_arrow_playerX: " .. tostring(_arrow_playerX))
    print("_arrow_playerY: " .. tostring(_arrow_playerY))
    print("_arrow_playerZoneId: " .. tostring(_arrow_playerZoneId))
    print("_arrow_playerUiMapId: " .. tostring(_arrow_playerUiMapId))
    if Questie and Questie.db and Questie.db.profile then
        print("autoTrackQuests: " .. tostring(Questie.db.profile.autoTrackQuests))
    end
    if Questie and Questie.db and Questie.db.char then
        local tracked = Questie.db.char.TrackedQuests or {}
        local autoUntracked = Questie.db.char.AutoUntrackedQuests or {}
        local trackedCount = 0
        for _ in pairs(tracked) do trackedCount = trackedCount + 1 end
        local autoUntrackedCount = 0
        for _ in pairs(autoUntracked) do autoUntrackedCount = autoUntrackedCount + 1 end
        print("TrackedQuests count: " .. tostring(trackedCount))
        print("AutoUntrackedQuests count: " .. tostring(autoUntrackedCount))
    end
    if QuestiePlayer and QuestiePlayer.currentQuestlog then
        local count = 0
        for _ in pairs(QuestiePlayer.currentQuestlog) do count = count + 1 end
        print("currentQuestlog count: " .. tostring(count))
    end
    if sortedTargets and #sortedTargets > 0 then
        print("First 3 targets:")
        for i = 1, math.min(3, #sortedTargets) do
            local t = sortedTargets[i]
            print(string.format("  [%d] %s (%.1f, %.1f) dist=%.0f", i, tostring(t.title), t.x, t.y, t.distance))
        end
    end
    print("========================")
end

-- Also expose sortedTargets for external access
function QuestieArrow:GetTargets()
    return sortedTargets
end

-- Hook into Refresh to show debug info when arrow updates
local _OriginalRefresh = QuestieArrow.Refresh
QuestieArrow.Refresh = function(self, ...)
    _OriginalRefresh(self, ...)
    if Questie and Questie.db and Questie.db.profile and Questie.db.profile.debugArrow then
        if sortedTargets and sortedTargets[1] then
            QuestieArrow:PrintTargetCoords()
        end
    end
end
