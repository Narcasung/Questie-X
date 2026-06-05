---@class l10n
---@field continentLookup table
---@field zoneLookup table
---@field zoneCategoryLookup table
---@field questCategoryLookup table
local l10n = QuestieLoader:CreateModule("l10n")
local _l10n = {}
l10n.translations = {}

l10n.itemLookup = {}
l10n.npcNameLookup = {}
l10n.objectNameLookup = {}
l10n.objectLookup = {}
l10n.questLookup = {}
l10n.translationCache = {}

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")

local locale = 'enUS'
local supportedLocals = {
    ['enUS'] = true,
    ['esES'] = true,
    ['esMX'] = true,
    ['ptBR'] = true,
    ['frFR'] = true,
    ['deDE'] = true,
    ['ruRU'] = true,
    ['zhCN'] = true,
    ['zhTW'] = true,
    ['koKR'] = true,
}

local function ResetTranslationCache()
    l10n.translationCache = {}
end

local format, unpack, tostring, select = string.format, unpack, tostring, select

local function FormatLocalizedString(template, argCount, ...)
    if argCount == 1 then
        return format(template, tostring(select(1, ...)))
    elseif argCount == 2 then
        return format(template, tostring(select(1, ...)), tostring(select(2, ...)))
    elseif argCount == 3 then
        return format(template, tostring(select(1, ...)), tostring(select(2, ...)), tostring(select(3, ...)))
    elseif argCount == 4 then
        return format(template, tostring(select(1, ...)), tostring(select(2, ...)), tostring(select(3, ...)), tostring(select(4, ...)))
    elseif argCount == 5 then
        return format(template, tostring(select(1, ...)), tostring(select(2, ...)), tostring(select(3, ...)), tostring(select(4, ...)), tostring(select(5, ...)))
    elseif argCount == 6 then
        return format(template, tostring(select(1, ...)), tostring(select(2, ...)), tostring(select(3, ...)), tostring(select(4, ...)), tostring(select(5, ...)), tostring(select(6, ...)))
    elseif argCount == 7 then
        return format(template, tostring(select(1, ...)), tostring(select(2, ...)), tostring(select(3, ...)), tostring(select(4, ...)), tostring(select(5, ...)), tostring(select(6, ...)), tostring(select(7, ...)))
    elseif argCount == 8 then
        return format(template, tostring(select(1, ...)), tostring(select(2, ...)), tostring(select(3, ...)), tostring(select(4, ...)), tostring(select(5, ...)), tostring(select(6, ...)), tostring(select(7, ...)), tostring(select(8, ...)))
    end

    local args = {}
    for i = 1, argCount do
        args[i] = tostring(select(i, ...))
    end
    return format(template, unpack(args))
end

function l10n:InitializeLocaleOverride()
    local overridingLocale = QUESTIE_LOCALES_OVERRIDE.locale
    supportedLocals[overridingLocale] = true
    l10n.itemLookup[overridingLocale] = QUESTIE_LOCALES_OVERRIDE.itemLookup
    l10n.questLookup[overridingLocale] = QUESTIE_LOCALES_OVERRIDE.questLookup
    l10n.npcNameLookup[overridingLocale] = QUESTIE_LOCALES_OVERRIDE.npcNameLookup
    l10n.objectLookup[overridingLocale] = QUESTIE_LOCALES_OVERRIDE.objectLookup

    for id, _ in pairs(l10n.translations) do
        if QUESTIE_LOCALES_OVERRIDE.translations[id] ~= nil then
            l10n.translations[id][overridingLocale] = QUESTIE_LOCALES_OVERRIDE.translations[id]
        else
            l10n.translations[id][overridingLocale] = false
        end
    end

    ResetTranslationCache()
end

---@param zoneName string
---@return number
function l10n:GetAreaIdByLocalName(zoneName)
    if not zoneName or zoneName == "" then return 0 end
    for _, zoneTable in pairs(l10n.zoneLookup) do
        for areaId, name in pairs(zoneTable) do
            if name == zoneName then return areaId end
        end
    end
    return 0
end

---@param areaId number
---@return string
function l10n:GetLocalNameByAreaId(areaId)
    if not areaId or areaId <= 0 then return l10n("Unknown Zone") end
    for _, zoneTable in pairs(l10n.zoneLookup) do
        if zoneTable[areaId] then
            return zoneTable[areaId]
        end
    end
    return l10n("Unknown Zone")
end

---@param areaId number
---@return number
function l10n:GetContinentIdByAreaId(areaId)
    if not areaId or areaId <= 0 then return 0 end
    for continentId, zoneTable in pairs(l10n.zoneLookup) do
        if zoneTable[areaId] then
            return continentId
        end
    end
    return 0
end

function l10n:Initialize()
    -- Load item locales
    if l10n.itemLookup and l10n.itemLookup[locale] then
        for id, name in pairs(l10n.itemLookup[locale]) do
            if QuestieDB.itemData[id] and name then
                QuestieDB.itemData[id][QuestieDB.itemKeys.name] = name
            end
        end
    end

    -- data is {<questName>, {<questDescription>,...}, {<questObjective>,...}}
    -- Load quest locales
    if l10n.questLookup and l10n.questLookup[locale] then
        for id, data in pairs(l10n.questLookup[locale]) do
            if QuestieDB.questData[id] then
                if data[1] then
                    QuestieDB.questData[id][QuestieDB.questKeys.name] = data[1]
                end
                -- TODO add details text to questDB.lua (data[2])
                if data[3] then
                    -- needs to be saved as a table for tooltips to have lines
                    if type(data[3]) == "string" then
                        QuestieDB.questData[id][QuestieDB.questKeys.objectivesText] = {data[3]}
                    else
                        QuestieDB.questData[id][QuestieDB.questKeys.objectivesText] = data[3]
                    end
                end
            end
        end
    end

    -- Load NPC locales
    if l10n.npcNameLookup and l10n.npcNameLookup[locale] then
        for id, data in pairs(l10n.npcNameLookup[locale]) do
            if QuestieDB.npcData[id] and data then
                if type(data) == "string" then
                    QuestieDB.npcData[id][QuestieDB.npcKeys.name] = data
                else
                    QuestieDB.npcData[id][QuestieDB.npcKeys.name] = data[1]
                    QuestieDB.npcData[id][QuestieDB.npcKeys.subName] = data[2]
                end
            end
        end
    end

    -- Load object locales
    if l10n.objectLookup and l10n.objectLookup[locale] then
        for id, name in pairs(l10n.objectLookup[locale]) do
            if QuestieDB.objectData[id] and name then
                QuestieDB.objectData[id][QuestieDB.objectKeys.name] = name
            end
        end
    end
end

--Must be run in a coroutine as it yields
function l10n:PostBoot()

    local count = 0
    -- Create {['name'] = {ID, },} table for lookup of possible object IDs by name
    if not QuestieDB.ObjectPointers then return end
    for id in pairs(QuestieDB.ObjectPointers) do
        local name = QuestieDB.QueryObjectSingle(id, "name")
        if name then -- We (meaning me, BreakBB) introduced Fake IDs for objects to show additional locations, so we need to check this
            local entry = l10n.objectNameLookup[name]
            if not entry then
                l10n.objectNameLookup[name] = { id }
            else
                table.insert(entry, id)
            end
        end

        if count > 300 then
            count = 0
            coroutine.yield()
        end
        count = count + 1
    end
end

function _l10n:translate(key, ...)
    if key == nil then
        return ""
    end
    key = tostring(key)
    local argCount = select("#", ...)
    if argCount == 0 then
        local localeCache = l10n.translationCache[locale]
        if localeCache and localeCache[key] ~= nil then
            return localeCache[key]
        end

        local translationEntry = l10n.translations[key]
        if not translationEntry then
            if (Questie.db.profile.debugEnabled) then Questie:Debug(Questie.DEBUG_ELEVATED, "ERROR: Translations for '" .. tostring(key) .. "' are missing completely!") end
            if not localeCache then
                localeCache = {}
                l10n.translationCache[locale] = localeCache
            end
            localeCache[key] = key
            return key
        end

        local translationValue = translationEntry[locale]
        if (not translationValue) then
            if (Questie.db.profile.debugEnabled) then Questie:Debug(Questie.DEBUG_ELEVATED, "ERROR: Translations for '" .. tostring(key) .. "' are missing the entry for language" , locale, "!") end
            if not localeCache then
                localeCache = {}
                l10n.translationCache[locale] = localeCache
            end
            localeCache[key] = key
            return key
        end

        if translationValue == true then
            -- Fallback to enUS which is the key
            if not localeCache then
                localeCache = {}
                l10n.translationCache[locale] = localeCache
            end
            localeCache[key] = key
            return key
        end

        if type(translationValue) ~= "string" then
            if (Questie.db.profile.debugEnabled) then Questie:Debug(Questie.DEBUG_ELEVATED, "ERROR: Translation for '" .. tostring(key) .. "' is not a string!") end
            if not localeCache then
                localeCache = {}
                l10n.translationCache[locale] = localeCache
            end
            localeCache[key] = key
            return key
        end

        if not localeCache then
            localeCache = {}
            l10n.translationCache[locale] = localeCache
        end
        localeCache[key] = translationValue
        return translationValue
    end

    local translationEntry = l10n.translations[key]
    if not translationEntry then
        if (Questie.db.profile.debugEnabled) then Questie:Debug(Questie.DEBUG_ELEVATED, "ERROR: Translations for '" .. tostring(key) .. "' are missing completely!") end
        return FormatLocalizedString(key, argCount, ...)
    end

    local translationValue = translationEntry[locale]
    if (not translationValue) then
        if (Questie.db.profile.debugEnabled) then Questie:Debug(Questie.DEBUG_ELEVATED, "ERROR: Translations for '" .. tostring(key) .. "' are missing the entry for language" , locale, "!") end
        return FormatLocalizedString(key, argCount, ...)
    end

    if translationValue == true then
        -- Fallback to enUS which is the key
        return FormatLocalizedString(key, argCount, ...)
    end

    if type(translationValue) ~= "string" then
        if (Questie.db.profile.debugEnabled) then Questie:Debug(Questie.DEBUG_ELEVATED, "ERROR: Translation for '" .. tostring(key) .. "' is not a string!") end
        return FormatLocalizedString(key, argCount, ...)
    end

    return FormatLocalizedString(translationValue, argCount, ...)
end

setmetatable(l10n, { __call = function(_, ...) return _l10n:translate(...) end})

function _l10n:GetFallbackLocale(lang)
    if (not lang) then
        return 'enUS'
    end

    if supportedLocals[lang] then
        return lang
    elseif lang == 'enGB' then
        return 'enUS'
    elseif lang == 'enCN' then
        return 'zhCN'
    elseif lang == 'enTW' then
        return 'zhTW'
    elseif lang == 'esMX' then
        return 'esES'
    elseif lang == 'ptPT' then
        return 'ptBR'
    else
        return 'enUS'
    end
end

function l10n:SetUILocale(lang)
    if lang then
        locale = _l10n:GetFallbackLocale(lang)
    else
        locale = _l10n:GetFallbackLocale(GetLocale())
    end

    ResetTranslationCache()
end

function l10n:GetUILocale()
    return locale
end
