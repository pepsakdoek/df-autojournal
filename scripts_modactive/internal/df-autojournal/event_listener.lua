--@ module = true
-- Real-time event listener using DFHack eventful hooks.
-- Delegates captured events to the event parser, then routes
-- parsed results to wiki pages via persistent storage.

local logger = reqscript('internal/df-autojournal/logger')
local event_parser = reqscript('internal/df-autojournal/event_parser')
local mfw_settings = reqscript('internal/df-autojournal/wiki_settings')
local utils = reqscript('internal/df-autojournal/wiki_utils')

local LISTENER_KEY = 'mfw_auto_journal_enabled'
local SEEN_UNITS_KEY = 'mfw_seen_units'
local TIMELINE_KEY = 'mfw_event_timeline'
local TIMELINE_MAX = 1000

-- Map event categories to their settings keys
local CATEGORY_SETTING_KEY = {
    threat = "threat_events",
    achievement = "achievement_events",
    social = "social_events",
    trade = "trade_events",
    crisis = "crisis_events",
    military = "military_events",
    environment = "environment_events",
    world = "world_events",
    death = "death_events",
    population = "birth_migrant_events",
    syndrome = "syndrome_events",
    combat = "threat_events",
    siege = "siege_events",
}

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
        return dfhack.persistent.getWorldData(key) or {}
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

    local ok2, err2 = pcall(dfhack.persistent.saveWorldData, key, {content=content, cursor=data.cursor or {1}})
    if not ok2 then
        logger.log_error("Failed to save page '" .. page_id .. "' - " .. tostring(err2))
    else
        logger.log("Appended to " .. page_id .. " [" .. section_title .. "]")
    end
end

--- Register an event in the timeline registry.
--- Stores a lightweight entry for timeline table rendering on Events/Fort pages.
local function register_timeline_entry(parsed)
    if not parsed then return end

    -- Build a clean summary (strip wiki markup)
    local raw = parsed.summary or ""
    local clean = raw:gsub("^%* ", ""):gsub("\n", ""):gsub("%[([^%]]+)%]%([^%)]+%)", "%1")
    if #clean > 120 then
        clean = clean:sub(1, 117) .. "..."
    end

    local entry = {
        year = parsed.year or df.global.cur_year,
        season = parsed.season or "",
        category = parsed.category or "general",
        event_type = parsed.event_type or "unknown",
        summary = clean,
    }

    local data = {}
    local ok_load = pcall(function()
        local raw = dfhack.persistent.getWorldData(TIMELINE_KEY)
        if raw and raw.entries then
            data.entries = raw.entries
        end
    end)
    if not ok_load or not data.entries then
        data.entries = {}
    end

    table.insert(data.entries, entry)

    -- Cap at max entries (remove oldest)
    if #data.entries > TIMELINE_MAX then
        local excess = #data.entries - TIMELINE_MAX
        for _ = 1, excess do
            table.remove(data.entries, 1)
        end
    end

    pcall(dfhack.persistent.saveWorldData, TIMELINE_KEY, {entries=data.entries})
end

--- Register an enemy encounter in the enemies registry.
--- Creates or updates an enemy record with name, type, year, defeat status, and kill count.
local ENEMIES_KEY = 'mfw_enemies'

local function register_enemy_encounter(enemy_name, enemy_type, year, was_defeated, kill_count_inc)
    if not enemy_name or enemy_name == "" then return end
    kill_count_inc = kill_count_inc or 0

    local data = {}
    local ok_load = pcall(function()
        local raw = dfhack.persistent.getWorldData(ENEMIES_KEY)
        if raw and raw.enemies then
            data.enemies = raw.enemies
        end
    end)
    if not ok_load or not data.enemies then
        data.enemies = {}
    end

    -- Use normalized name as key
    local key = enemy_name:lower():gsub("[^%w]", "_")
    local record = data.enemies[key]

    if record then
        record.encounters = (record.encounters or 1) + 1
        record.last_year = year
        if was_defeated then
            record.defeated = true
        end
        if kill_count_inc > 0 then
            record.citizens_killed = (record.citizens_killed or 0) + kill_count_inc
        end
    else
        record = {
            name = enemy_name,
            enemy_type = enemy_type or "Unknown",
            first_year = year,
            first_season = "",
            encounters = 1,
            defeated = was_defeated or false,
            last_year = year,
            notes = "",
            citizens_killed = kill_count_inc > 0 and kill_count_inc or 0,
        }
        data.enemies[key] = record
    end

    pcall(dfhack.persistent.saveWorldData, ENEMIES_KEY, {enemies=data.enemies})
end

local VISITORS_KEY = 'mfw_visitors'

local function register_visitor(visitor_name, visitor_type, year, season, has_departed)
    if not visitor_name or visitor_name == "" then return end

    local data = {}
    local ok_load = pcall(function()
        local raw = dfhack.persistent.getWorldData(VISITORS_KEY)
        if raw and raw.visitors then
            data.visitors = raw.visitors
        end
    end)
    if not ok_load or not data.visitors then
        data.visitors = {}
    end

    local key = visitor_name:lower():gsub("[^%w]", "_")
    local record = data.visitors[key]

    if record then
        record.encounters = (record.encounters or 1) + 1
        record.last_year = year
        record.last_season = season or ""
        if has_departed then
            record.departed = true
        elseif record.departed then
            record.departed = false
        end
    else
        record = {
            name = visitor_name,
            visitor_type = visitor_type or "unknown",
            first_year = year,
            first_season = season or "",
            last_year = year,
            last_season = season or "",
            encounters = 1,
            departed = has_departed or false,
            notes = "",
        }
        data.visitors[key] = record
    end

    pcall(dfhack.persistent.saveWorldData, VISITORS_KEY, {visitors=data.visitors})
end

local function load_visitors()
    local data = {}
    local ok = pcall(function()
        local raw = dfhack.persistent.getWorldData(VISITORS_KEY)
        if raw and raw.visitors then
            local list = {}
            for _, rec in pairs(raw.visitors) do
                table.insert(list, rec)
            end
            table.sort(list, function(a, b)
                local ay = a.last_year or a.first_year or 0
                local by = b.last_year or b.first_year or 0
                return ay > by
            end)
            data = list
        end
    end)
    return data
end

--- Check if a visitor type is enabled in settings.
local function is_visitor_type_enabled(visitor_type)
    local settings = mfw_settings.get_settings()
    local vj = settings.visitors and settings.visitors.journal
    if not vj then return false end
    local key = "track_" .. (visitor_type or "unknown")
    return vj[key] == true
end

--- Load enemy kill data aggregated from the registry.
--- Returns a table keyed by normalized enemy name: { count, victims[] }
local function load_enemy_kills()
    local data = {}
    local ok = pcall(function()
        local raw = dfhack.persistent.getWorldData(ENEMIES_KEY)
        if raw and raw.enemies then
            for nkey, rec in pairs(raw.enemies) do
                if rec.citizens_killed and rec.citizens_killed > 0 then
                    data[nkey] = {
                        count = rec.citizens_killed,
                        victims = {},
                    }
                end
            end
        end
    end)
    return data
end

--- Load the enemies registry (array of records sorted by first_year).
local function load_enemies()
    local data = {}
    local ok = pcall(function()
        local raw = dfhack.persistent.getWorldData(ENEMIES_KEY)
        if raw and raw.enemies then
            local list = {}
            for _, rec in pairs(raw.enemies) do
                table.insert(list, rec)
            end
            table.sort(list, function(a, b)
                return (a.first_year or 0) < (b.first_year or 0)
            end)
            data = list
        end
    end)
    return data
end

--- Check if a given event category is enabled in user settings.
local function is_category_enabled(category)
    local settings = mfw_settings.get_settings()
    local setting_key = CATEGORY_SETTING_KEY[category]
    if not setting_key then return true end
    local s = settings.event and settings.event.journal
    return s and s[setting_key] ~= false
end

--- Check if a section on the enemies page is enabled in enemies journal settings.
local function is_enemies_section_enabled(section_title)
    local settings = mfw_settings.get_settings()
    local ej = settings.enemies and settings.enemies.journal
    if not ej then return true end
    if section_title == "Notable Encounters" then
        return ej.encounter_log ~= false
    elseif section_title == "Kill List" then
        return ej.kill_list ~= false
    end
    return true
end

--- Route a parsed event result to all its target pages
local function fortify_page_id(page_id)
    -- Route generic root page_ids to the current fort's section pages
    if page_id == "fort" then
        return "fort:" .. utils.get_site_id()
    elseif page_id == "events" then
        return "fort:" .. utils.get_site_id() .. "/events"
    elseif page_id == "enemies" then
        return "fort:" .. utils.get_site_id() .. "/enemies"
    elseif page_id == "visitors" then
        return "fort:" .. utils.get_site_id() .. "/visitors"
    end
    return page_id
end

local function route_parsed(parsed)
    if not parsed or not parsed.targets then return end

    -- Skip if this event category is disabled in settings
    if not is_category_enabled(parsed.category) then return end

    local site_ok = utils.get_site_id() and utils.get_site_id() ~= -1

    for _, target in ipairs(parsed.targets) do
        if target.page_id and target.section and target.entry then
            local routed_id = site_ok and fortify_page_id(target.page_id) or target.page_id
            -- Check enemies page section-level settings
            if routed_id:match("/enemies$") and not is_enemies_section_enabled(target.section) then
                -- Skip this target if the section is disabled in enemies settings
            else
                append_to_page(routed_id, target.section, target.entry)
            end
        end
    end
    -- Register in the global timeline
    register_timeline_entry(parsed)
    -- Register enemy encounter if this event has an enemy name
    if parsed.enemy_name then
        local kill_inc = (parsed.category == "death" and parsed.enemy_defeated == nil) and 1 or 0
        register_enemy_encounter(
            parsed.enemy_name,
            parsed.enemy_type,
            parsed.year or df.global.cur_year,
            parsed.enemy_defeated or false,
            kill_inc
        )
    end

    -- Register visitor if this event has a visitor name (and type is enabled in settings)
    if parsed.visitor_name and is_visitor_type_enabled(parsed.visitor_type) then
        register_visitor(
            parsed.visitor_name,
            parsed.visitor_type or "unknown",
            parsed.year or df.global.cur_year,
            parsed.season or "",
            false
        )
    end
end

--- Load/save seen unit IDs to avoid duplicate events
local function load_seen_units()
    local ok, data = pcall(function()
        return dfhack.persistent.getWorldData(SEEN_UNITS_KEY)
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
    pcall(dfhack.persistent.saveWorldData, SEEN_UNITS_KEY, {val=ids})
end

---------------------------------------------------------------------------
-- Core API
---------------------------------------------------------------------------

function EventListener.start()
    if dfhack.mfw_state.hooks_registered and EventListener.is_running() then
        return
    end

    -- Set state and persist immediately so the overlay/toggle always reflect
    -- the correct status, even if hook registration fails.
    dfhack.mfw_state.listener_enabled = true
    pcall(dfhack.persistent.saveWorldData, LISTENER_KEY, {val={1}})

    -- Init seen units from persistent storage
    if not dfhack.mfw_state.seen_units then
        dfhack.mfw_state.seen_units = load_seen_units()
    end

    -- Load user settings for category filtering
    dfhack.mfw_state.settings = mfw_settings.get_settings()

    -- Register eventful hooks (may fail if plugin not loaded)
    if not dfhack.mfw_state.hooks_registered then
        local ok, err = pcall(function()
            local eventful = require('plugins.eventful')

            eventful.onReport(EventListener._on_report)
            eventful.onUnitDeath(EventListener._on_unit_death)
            eventful.onItemCreated(EventListener._on_item_created)
            eventful.onUnitNewActive(EventListener._on_unit_new_active)
            eventful.onInvasion(EventListener._on_invasion)
            eventful.onSyndrome(EventListener._on_syndrome)

            dfhack.mfw_state.hooks_registered = true
        end)

        if not ok then
            logger.log_error("Failed to register eventful hooks: " .. tostring(err))
        end
    end
end

function EventListener.stop()
    -- Persist seen units before stopping
    if dfhack.mfw_state.seen_units then
        save_seen_units(dfhack.mfw_state.seen_units)
    end

    dfhack.mfw_state.listener_enabled = false
    pcall(dfhack.persistent.saveWorldData, LISTENER_KEY, {val={0}})
end

function EventListener.is_running()
    return dfhack.mfw_state and dfhack.mfw_state.listener_enabled == true
end

function EventListener.load_state()
    local ok, data = pcall(function()
        return dfhack.persistent.getWorldData(LISTENER_KEY)
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

-- Exports for use by initializer (historical catch-up)
EventListener.append_to_page = append_to_page
EventListener.register_timeline_entry = register_timeline_entry
EventListener.register_enemy_encounter = register_enemy_encounter
EventListener.load_enemies = load_enemies
EventListener.load_enemy_kills = load_enemy_kills
EventListener.register_visitor = register_visitor
EventListener.load_visitors = load_visitors
EventListener.is_visitor_type_enabled = is_visitor_type_enabled

-- Export EventListener functions to the module environment so reqscript callers
-- find them.  DFHack returns _ENV for --@ module = true scripts.
for k, v in pairs(EventListener) do
    _ENV[k] = v
end
return _ENV
