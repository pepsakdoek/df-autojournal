--@ module = true
-- Real-time event listener using DFHack eventful hooks.
-- Delegates captured events to the event parser, then routes
-- parsed results to wiki pages via persistent storage.

local logger = reqscript('internal/df-autojournal/logger')
local event_parser = reqscript('internal/df-autojournal/event_parser')

local LISTENER_KEY = 'mfw_auto_journal_enabled'
local SEEN_UNITS_KEY = 'mfw_seen_units'

local EventListener = {}

-- Global state shared with overlay and toggle UI
if not dfhack.mfw_state then
    dfhack.mfw_state = {
        listener_enabled = false,
    }
end

---------------------------------------------------------------------------
-- Persistence helpers — directly read/write dfhack.persistent
-- (independent of WikiContext, so the listener works even when wiki UI is closed)
---------------------------------------------------------------------------

--- Append an entry string to a wiki page under a given section.
--- Works with the span-array content format used by the wiki editor.
local function append_to_page(page_id, section_title, entry_text)
    if not page_id or not section_title or not entry_text then return end
    if entry_text == "" then return end

    local key = 'mfw_p_' .. page_id
    local ok, data = pcall(function()
        return dfhack.persistent.getSiteData(key) or {}
    end)
    if not ok then data = {} end

    local content = data.content or {}

    -- Normalize string content to array format
    if type(content) == 'string' then
        content = {{text=content, pen=COLOR_LIGHTCYAN}}
    end

    local section_header = "## " .. section_title

    -- Search for existing section header
    local section_idx = nil
    for i, item in ipairs(content) do
        local text = type(item) == 'table' and item.text or tostring(item)
        if text == section_header then
            section_idx = i
            break
        end
    end

    if section_idx then
        -- Find where this section ends (next ## or end of content)
        local insert_at = #content + 1
        for i = section_idx + 1, #content do
            local text = type(content[i]) == 'table' and content[i].text or tostring(content[i])
            if text and text:match("^## ") then
                insert_at = i
                break
            end
        end
        -- If section has no content after the header (just \n), append after the newline
        if section_idx + 1 <= #content then
            local next_text = type(content[section_idx + 1]) == 'table' and content[section_idx + 1].text or tostring(content[section_idx + 1])
            if next_text == "\n" then
                insert_at = section_idx + 2
            end
        end
        table.insert(content, insert_at, entry_text)
    else
        -- Section doesn't exist — append at end
        table.insert(content, "\n\n")
        table.insert(content, {text=section_header, pen=COLOR_YELLOW})
        table.insert(content, "\n")
        table.insert(content, entry_text)
    end

    local ok2, err2 = pcall(dfhack.persistent.saveSiteData, key, {content=content, cursor=data.cursor or {1}})
    if not ok2 then
        logger.log_error("Failed to save page '" .. page_id .. "' - " .. tostring(err2))
    else
        logger.log("Appended to " .. page_id .. " [" .. section_title .. "]")
    end
end

--- Route a parsed event result to all its target pages
local function route_parsed(parsed)
    if not parsed or not parsed.targets then return end
    for _, target in ipairs(parsed.targets) do
        if target.page_id and target.section and target.entry then
            append_to_page(target.page_id, target.section, target.entry)
        end
    end
end

--- Load/save seen unit IDs to avoid duplicate events
local function load_seen_units()
    local ok, data = pcall(function()
        return dfhack.persistent.getSiteData(SEEN_UNITS_KEY)
    end)
    if ok and data and data.val then
        local set = {}
        for _, id in ipairs(data.val) do
            set[id] = true
        end
        return set
    end
    return {}
end

local function save_seen_units(set)
    local ids = {}
    for id, _ in pairs(set) do
        table.insert(ids, id)
    end
    pcall(dfhack.persistent.saveSiteData, SEEN_UNITS_KEY, {val=ids})
end

---------------------------------------------------------------------------
-- Core API
---------------------------------------------------------------------------

function EventListener.start()
    if EventListener.is_running() then
        return
    end

    local ok, err = pcall(function()
        -- Register eventful hooks only once per Lua session
        if not dfhack.mfw_state.hooks_registered then
            local eventful = require('plugins.eventful')

            eventful.onReport(EventListener._on_report)
            eventful.onUnitDeath(EventListener._on_unit_death)
            eventful.onItemCreated(EventListener._on_item_created)
            eventful.onUnitNewActive(EventListener._on_unit_new_active)
            eventful.onInvasion(EventListener._on_invasion)
            eventful.onSyndrome(EventListener._on_syndrome)

            dfhack.mfw_state.hooks_registered = true
            logger.log("Eventful hooks registered")
        end

        -- Init seen units from persistent storage
        if not dfhack.mfw_state.seen_units then
            dfhack.mfw_state.seen_units = load_seen_units()
        end

        dfhack.mfw_state.listener_enabled = true
        dfhack.persistent.saveSiteData(LISTENER_KEY, {val={1}})
        logger.log("Event listener started")
    end)

    if not ok then
        logger.log_error("Failed to start event listener: " .. tostring(err))
    end
end

function EventListener.stop()
    -- Persist seen units before stopping
    if dfhack.mfw_state.seen_units then
        save_seen_units(dfhack.mfw_state.seen_units)
    end

    dfhack.mfw_state.listener_enabled = false
    dfhack.persistent.saveSiteData(LISTENER_KEY, {val={0}})
    logger.log("Event listener stopped")
end

function EventListener.is_running()
    return dfhack.mfw_state and dfhack.mfw_state.listener_enabled == true
end

function EventListener.load_state()
    local ok, data = pcall(function()
        return dfhack.persistent.getSiteData(LISTENER_KEY)
    end)
    if ok and data and data.val and data.val[1] == 1 then
        dfhack.mfw_state.listener_enabled = true
        return true
    end
    dfhack.mfw_state.listener_enabled = false
    return false
end

---------------------------------------------------------------------------
-- Event handlers — each calls the parser and routes results
---------------------------------------------------------------------------

function EventListener._on_report(report_id)
    if not EventListener.is_running() then return end

    pcall(function()
        -- Find the report object
        local report = nil
        for i = #df.global.world.status.reports - 1, math.max(0, #df.global.world.status.reports - 20), -1 do
            local r = df.global.world.status.reports[i]
            if r and r.id == report_id then
                report = r
                break
            end
        end
        if not report or not report.text then return end

        local report_type = report.type
        local report_text = report.text
        pcall(function() report_text = dfhack.df2utf(report_text) end)

        local parsed = event_parser.parse_report(report_type, report_text, report)
        if parsed then
            route_parsed(parsed)
            logger.log("Routed report #" .. report_id .. " type=" .. tostring(report_type) .. " -> " .. parsed.category)
        end
    end)
end

function EventListener._on_unit_death(unit_id)
    if not EventListener.is_running() then return end

    pcall(function()
        local unit = df.unit.find(unit_id)
        if not unit then return end

        local parsed = event_parser.parse_death(unit)
        if parsed then
            route_parsed(parsed)
            logger.log("Routed death: unit " .. unit_id)
        end
    end)
end

function EventListener._on_item_created(item_id)
    if not EventListener.is_running() then return end

    pcall(function()
        local item = df.item.find(item_id)
        if not item then return end

        local parsed = event_parser.parse_item_created(item)
        if parsed then
            route_parsed(parsed)
            logger.log("Routed item created: " .. item_id)
        end
    end)
end

function EventListener._on_unit_new_active(unit_id)
    if not EventListener.is_running() then return end

    pcall(function()
        local unit = df.unit.find(unit_id)
        if not unit then return end

        -- Deduplicate: skip units we've already processed
        if not dfhack.mfw_state.seen_units then
            dfhack.mfw_state.seen_units = {}
        end
        if dfhack.mfw_state.seen_units[unit_id] then
            return
        end
        dfhack.mfw_state.seen_units[unit_id] = true

        local parsed = event_parser.parse_new_unit(unit)
        if parsed then
            route_parsed(parsed)
            logger.log("Routed new unit: " .. unit_id)
        end
    end)
end

function EventListener._on_invasion(invasion_id)
    if not EventListener.is_running() then return end

    pcall(function()
        local parsed = event_parser.parse_invasion(invasion_id)
        if parsed then
            route_parsed(parsed)
            logger.log("Routed invasion: " .. invasion_id)
        end
    end)
end

function EventListener._on_syndrome(unit_id, syndrome_id)
    if not EventListener.is_running() then return end

    pcall(function()
        local unit = df.unit.find(unit_id)
        if not unit then return end

        local parsed = event_parser.parse_syndrome(unit, syndrome_id)
        if parsed then
            route_parsed(parsed)
            logger.log("Routed syndrome: unit " .. unit_id .. " syn " .. syndrome_id)
        end
    end)
end

-- Export append_to_page for use by initializer (historical catch-up)
EventListener.append_to_page = append_to_page

return EventListener
