--@ module = true
-- Comprehensive event parser for all fort-relevant DF events.
-- Handles report type classification, death parsing, artifact creation,
-- invasion tracking, syndrome effects, and new unit detection.
-- Returns structured data routed to the appropriate wiki pages.

local utils = reqscript('internal/df-autojournal/wiki_utils')
local logger = reqscript('internal/df-autojournal/logger')

local EventParser = {}

-- Season names by year-tick offset
local function get_season(tick)
    local t = tick % 403200
    if t < 100800 then return "spring"
    elseif t < 201600 then return "summer"
    elseif t < 302400 then return "autumn"
    else return "winter" end
end

local function get_season_detail(tick)
    local t = tick % 403200
    if t < 33600 then return "early spring"
    elseif t < 67200 then return "mid-spring"
    elseif t < 100800 then return "late spring"
    elseif t < 134400 then return "early summer"
    elseif t < 168000 then return "mid-summer"
    elseif t < 201600 then return "late summer"
    elseif t < 235200 then return "early autumn"
    elseif t < 268800 then return "mid-autumn"
    elseif t < 302400 then return "late autumn"
    elseif t < 336000 then return "early winter"
    elseif t < 369600 then return "mid-winter"
    else return "late winter" end
end

local function formatted_date(year, tick)
    local season = get_season_detail(tick)
    return "Year " .. year .. ", " .. season
end

---------------------------------------------------------------------------
-- Report type map: DFHack report_type → { category, type, importance, is_major }
---------------------------------------------------------------------------

local REPORT_MAP = {
    -- World / Era
    [1] = { category = "world", type = "era_change", importance = 3, is_major = true },
    [2] = { category = "world", type = "feature_discovery", importance = 2 },
    [3] = { category = "world", type = "struck_deep_metal", importance = 3 },
    [4] = { category = "world", type = "struck_mineral", importance = 2 },
    [5] = { category = "world", type = "struck_economic_mineral", importance = 2 },

    -- Combat (range 6–48, 111–134, 166–167, 171, 239)
    -- Mapped via helper below; placeholder entries for direct lookup
    [6] = { category = "combat", type = "combat", importance = 1 },
    [239] = { category = "combat", type = "combat", importance = 1 },

    -- Dig cancellations
    [51] = { category = "environment", type = "dig_cancel_warm", importance = 1 },
    [52] = { category = "environment", type = "dig_cancel_damp", importance = 1 },

    -- Ambush (53–66)
    [53] = { category = "military", type = "ambush", importance = 3, is_major = true },

    -- Caravan / Trade
    [67] = { category = "trade", type = "caravan_arrival", importance = 2 },
    [68] = { category = "trade", type = "noble_arrival", importance = 1 },
    [242] = { category = "trade", type = "merchants_unloading", importance = 1 },
    [245] = { category = "trade", type = "merchants_leaving_soon", importance = 1 },
    [246] = { category = "trade", type = "merchants_embarked", importance = 1 },
    [343] = { category = "trade", type = "first_caravan_arrival", importance = 3, is_major = true },

    -- Diplomats
    [79] = { category = "trade", type = "diplomat_arrival", importance = 2 },
    [80] = { category = "trade", type = "liaison_arrival", importance = 1 },
    [81] = { category = "trade", type = "trade_diplomat_arrival", importance = 1 },
    [341] = { category = "trade", type = "diplomat_left_unhappy", importance = 2 },

    -- Environment
    [82] = { category = "environment", type = "cave_collapse", importance = 3 },
    [97] = { category = "environment", type = "magma_defaces_engraving", importance = 1 },
    [98] = { category = "environment", type = "engraving_melts", importance = 1 },
    [100] = { category = "environment", type = "master_architecture_lost", importance = 2 },
    [101] = { category = "environment", type = "master_construction_lost", importance = 2 },
    [154] = { category = "environment", type = "strange_rain", importance = 2 },
    [155] = { category = "environment", type = "strange_cloud", importance = 2 },

    -- Artifacts / Moods
    [86] = { category = "achievement", type = "artifact_created", importance = 3, is_major = true },
    [87] = { category = "achievement", type = "artifact_named", importance = 2 },
    [91] = { category = "achievement", type = "mood_building_claimed", importance = 2 },
    [92] = { category = "achievement", type = "artifact_begun", importance = 2 },
    [99] = { category = "achievement", type = "masterpiece_construction", importance = 2 },
    [238] = { category = "achievement", type = "soldier_becomes_master", importance = 2 },
    [256] = { category = "achievement", type = "masterpiece_crafted", importance = 2 },
    [258] = { category = "achievement", type = "power_learned", importance = 2 },
    [261] = { category = "achievement", type = "dyed_masterpiece", importance = 2 },
    [262] = { category = "achievement", type = "cooked_masterpiece", importance = 2 },
    [287] = { category = "achievement", type = "masterful_improvement", importance = 2 },
    [288] = { category = "achievement", type = "masterpiece_engraving", importance = 2 },
    [303] = { category = "achievement", type = "research_breakthrough", importance = 3 },
    [315] = { category = "achievement", type = "composition_complete", importance = 2 },

    -- Threats
    [93] = { category = "threat", type = "megabeast_arrival", importance = 4, is_major = true },
    [94] = { category = "threat", type = "werebeast_arrival", importance = 4, is_major = true },
    [136] = { category = "threat", type = "night_attack_start", importance = 3, is_major = true },
    [137] = { category = "threat", type = "night_attack_end", importance = 3 },
    [145] = { category = "threat", type = "creature_steals_object", importance = 3 },
    [147] = { category = "threat", type = "body_transformation", importance = 2 },
    [150] = { category = "threat", type = "undead_attack", importance = 4, is_major = true },

    -- Crises
    [96] = { category = "crisis", type = "berserk_citizen", importance = 3 },
    [151] = { category = "crisis", type = "citizen_missing", importance = 3, is_major = true },
    [152] = { category = "crisis", type = "pet_missing", importance = 1 },
    [181] = { category = "crisis", type = "stressed_citizen", importance = 1 },
    [182] = { category = "crisis", type = "citizen_lost_to_stress", importance = 3 },
    [183] = { category = "crisis", type = "citizen_tantrum", importance = 2 },
    [252] = { category = "crisis", type = "citizen_snatched", importance = 4, is_major = true },
    [257] = { category = "crisis", type = "artwork_defaced", importance = 2 },
    [285] = { category = "crisis", type = "possessed_tantrum", importance = 3 },
    [286] = { category = "crisis", type = "building_toppled_by_ghost", importance = 2 },
    [313] = { category = "crisis", type = "building_destroyed", importance = 3 },
    [314] = { category = "crisis", type = "deity_curse", importance = 4, is_major = true },
    [348] = { category = "crisis", type = "food_warning", importance = 2 },

    -- Social
    [153] = { category = "social", type = "embrace", importance = 1 },
    [176] = { category = "social", type = "gain_site_control", importance = 3, is_major = true },
    [178] = { category = "social", type = "position_succession", importance = 2 },
    [254] = { category = "social", type = "land_gains_status", importance = 2 },
    [255] = { category = "social", type = "land_elevated_status", importance = 2 },
    [266] = { category = "social", type = "election_results", importance = 2 },
    [284] = { category = "social", type = "party_organized", importance = 1 },
    [289] = { category = "social", type = "marriage", importance = 2 },
    [301] = { category = "social", type = "guest_arrival", importance = 1 },
    [321] = { category = "social", type = "rumor_spread", importance = 1 },
    [331] = { category = "social", type = "new_guild", importance = 2 },
    [332] = { category = "crisis", type = "crime_witness", importance = 2 },
    [333] = { category = "crisis", type = "crime_witness", importance = 2 },
    [334] = { category = "crisis", type = "crime_witness", importance = 2 },
    [335] = { category = "crisis", type = "crime_witness", importance = 2 },
    [344] = { category = "social", type = "monarch_arrival", importance = 4, is_major = true },
    [345] = { category = "social", type = "hasty_monarch", importance = 2 },
    [346] = { category = "social", type = "satisfied_monarch", importance = 2 },
    [351] = { category = "social", type = "deity_pronouncement", importance = 3 },

    -- Military
    [236] = { category = "military", type = "profession_changed", importance = 1 },
    [237] = { category = "military", type = "recruit_promoted", importance = 1 },
    [278] = { category = "military", type = "somebody_grows_up", importance = 1 },
    [282] = { category = "military", type = "citizen_becomes_soldier", importance = 1 },
    [283] = { category = "military", type = "citizen_becomes_nonsoldier", importance = 1 },

    -- Seasons (handled by polling, skipped in real-time)
    [297] = { category = "world", type = "season_spring", importance = 1 },
    [298] = { category = "world", type = "season_summer", importance = 1 },
    [299] = { category = "world", type = "season_autumn", importance = 1 },
    [300] = { category = "world", type = "season_winter", importance = 1 },
    [342] = { category = "world", type = "embark_message", importance = 1 },

    -- Endgame
    [108] = { category = "world", type = "endgame_event", importance = 5, is_major = true },
    [109] = { category = "world", type = "endgame_event", importance = 5, is_major = true },
    [110] = { category = "world", type = "endgame_event", importance = 5, is_major = true },
}

-- Combat types share a single handler via range detection
local function is_combat_type(report_type)
    return (report_type >= 6 and report_type <= 48)
        or (report_type >= 111 and report_type <= 134)
        or report_type == 166 or report_type == 167
        or report_type == 171 or report_type == 239
end

local function is_ambush_type(report_type)
    return report_type >= 53 and report_type <= 66
end

---------------------------------------------------------------------------
-- Link helpers — all return markdown-style [text](page_id) strings
---------------------------------------------------------------------------

function EventParser.get_unit_link(unit_id)
    local unit = df.unit.find(unit_id)
    if unit then
        local name = utils.sanitize(dfhack.units.getReadableName(unit))
        return "[" .. name .. "](citizen:" .. tostring(unit_id) .. ")"
    end
    return "Unknown Dwarf"
end

function EventParser.get_hf_link(hf_id)
    local hf = df.historical_figure.find(hf_id)
    if hf then
        local name = utils.get_readable_name(hf.name)
        local unit_id = hf.unit_id
        if unit_id ~= -1 then
            return "[" .. name .. "](citizen:" .. tostring(unit_id) .. ")"
        end
        return name
    end
    return "Unknown Figure"
end

function EventParser.is_citizen(hf_id)
    if hf_id == -1 then return false end
    local hf = df.historical_figure.find(hf_id)
    if not hf then return false end
    local unit = df.unit.find(hf.unit_id)
    if not unit then return false end
    return dfhack.units.isCitizen(unit)
end

--- Check if an HF belongs to our civilization (works even if unit is not currently loaded)
function EventParser.is_our_hf(hf_id)
    if hf_id == -1 then return false end
    local hf = df.historical_figure.find(hf_id)
    if not hf then return false end
    -- Fast path: if unit is loaded and is a citizen
    if hf.unit_id ~= -1 then
        local unit = df.unit.find(hf.unit_id)
        if unit and dfhack.units.isCitizen(unit) then
            return true
        end
    end
    -- Fallback: check entity links for our civ
    for _, link in ipairs(hf.entity_links) do
        if link.entity_id == df.global.plotinfo.civ_id then
            return true
        end
    end
    return false
end

--- Get a readable HF name from a historical figure ID
local function get_hf_name(hf_id)
    if hf_id == -1 then return "Unknown" end
    local hf = df.historical_figure.find(hf_id)
    if not hf then return "Unknown" end
    return utils.get_readable_name(hf.name)
end

--- Get a citizen link for an HF (returns name as plain text if not a citizen)
local function hf_link(hf_id)
    if EventParser.is_our_hf(hf_id) then
        return EventParser.get_hf_link(hf_id)
    end
    return get_hf_name(hf_id)
end

local function is_our_unit(unit)
    if not unit then return false end
    local player_race = df.global.plotinfo.race_id
    return unit.race == player_race and dfhack.units.isFortControlled(unit)
end

--- Find a speaking unit from a report text by matching the leading name
local function extract_speaker_from_report(report)
    if report.speaker_id and report.speaker_id ~= -1 then
        local unit = df.unit.find(report.speaker_id)
        if unit then return unit end
    end
    return nil
end

--- Sanitize report text for wiki display
local function sanitize_report_text(text)
    if not text then return "" end
    local safe = text
    pcall(function() safe = dfhack.df2utf(safe) end)
    pcall(function() safe = utils.sanitize(safe) end)
    return safe
end

---------------------------------------------------------------------------
--- Formatting helpers per category
---------------------------------------------------------------------------

local function entry_line(text)
    return "* " .. text .. "\n"
end

function EventParser._format_threat_entry(report_text, report_obj, event_type)
    local date = formatted_date(df.global.cur_year, df.global.cur_year_tick)
    local text = sanitize_report_text(report_text) or event_type
    return entry_line(date .. ": " .. text)
end

function EventParser._format_achievement_entry(report_text, report_obj, event_type)
    local date = formatted_date(df.global.cur_year, df.global.cur_year_tick)
    local unit = extract_speaker_from_report(report_obj)
    local name_part = ""
    if unit and is_our_unit(unit) then
        name_part = EventParser.get_unit_link(unit.id) .. " "
    end
    local text = sanitize_report_text(report_text) or event_type
    return entry_line(date .. ": " .. name_part .. text)
end

function EventParser._format_social_entry(report_text, report_obj, event_type)
    local date = formatted_date(df.global.cur_year, df.global.cur_year_tick)
    local text = sanitize_report_text(report_text) or event_type
    return entry_line(date .. ": " .. text)
end

function EventParser._format_trade_entry(report_text, report_obj, event_type)
    local date = formatted_date(df.global.cur_year, df.global.cur_year_tick)
    local text = sanitize_report_text(report_text) or event_type
    return entry_line(date .. ": " .. text)
end

function EventParser._format_crisis_entry(report_text, report_obj, event_type)
    local date = formatted_date(df.global.cur_year, df.global.cur_year_tick)
    local unit = extract_speaker_from_report(report_obj)
    local name_part = ""
    if unit and is_our_unit(unit) then
        name_part = EventParser.get_unit_link(unit.id) .. " "
    end
    local text = sanitize_report_text(report_text) or event_type
    return entry_line(date .. ": " .. name_part .. text)
end

function EventParser._format_military_entry(report_text, report_obj, event_type)
    local date = formatted_date(df.global.cur_year, df.global.cur_year_tick)
    local text = sanitize_report_text(report_text) or event_type
    return entry_line(date .. ": " .. text)
end

function EventParser._format_environment_entry(report_text, report_obj, event_type)
    local date = formatted_date(df.global.cur_year, df.global.cur_year_tick)
    local text = sanitize_report_text(report_text) or event_type
    return entry_line(date .. ": " .. text)
end

function EventParser._format_world_entry(report_text, report_obj, event_type)
    local date = formatted_date(df.global.cur_year, df.global.cur_year_tick)
    local text = sanitize_report_text(report_text) or event_type
    return entry_line(date .. ": " .. text)
end

function EventParser._format_combat_entry(report_text, report_obj)
    -- Combat entries are aggregated; for now just log the report
    return nil
end

---------------------------------------------------------------------------
--- Build a parsed result structure from category info + entry text
---------------------------------------------------------------------------

local function make_result(info, entry, extra_targets)
    local year = df.global.cur_year
    local tick = df.global.cur_year_tick
    local season = get_season(tick)

    local targets = {}
    local default_section = "Fort Timeline"

    if info.category == "threat" then
        table.insert(targets, { page_id = "enemies", section = "Notable Encounters", entry = entry })
        table.insert(targets, { page_id = "events", section = "Notable Events", entry = entry })
    elseif info.category == "achievement" then
        table.insert(targets, { page_id = "events", section = "Achievements", entry = entry })
    elseif info.category == "social" then
        table.insert(targets, { page_id = "events", section = "Social Events", entry = entry })
    elseif info.category == "trade" then
        table.insert(targets, { page_id = "fort", section = "Trade & Diplomacy", entry = entry })
        table.insert(targets, { page_id = "events", section = "Fort Timeline", entry = entry })
    elseif info.category == "crisis" then
        table.insert(targets, { page_id = "events", section = "Incidents & Crises", entry = entry })
    elseif info.category == "military" then
        table.insert(targets, { page_id = "fort", section = "Military", entry = entry })
        table.insert(targets, { page_id = "events", section = "Fort Timeline", entry = entry })
    elseif info.category == "environment" then
        table.insert(targets, { page_id = "events", section = "Environment", entry = entry })
    elseif info.category == "world" then
        table.insert(targets, { page_id = "events", section = "World Events", entry = entry })
    elseif info.category == "combat" then
        table.insert(targets, { page_id = "events", section = "Combat Log", entry = entry })
    else
        table.insert(targets, { page_id = "events", section = default_section, entry = entry })
    end

    -- Add extra targets from caller (e.g. citizen page)
    if extra_targets then
        for _, t in ipairs(extra_targets) do
            table.insert(targets, t)
        end
    end

    return {
        targets = targets,
        year = year,
        season = season,
        category = info.category,
        event_type = info.type,
        is_major = info.is_major or false,
        importance = info.importance or 1,
        summary = sanitize_report_text(entry),
    }
end

---------------------------------------------------------------------------
--- Public API: parse_report(report_type, report_text, report_obj)
--- Called from eventful onReport hook
---------------------------------------------------------------------------

function EventParser.parse_report(report_type, report_text, report_obj)
    local info = nil

    if is_combat_type(report_type) then
        info = { category = "combat", type = "combat", importance = 1, is_major = false }
    elseif is_ambush_type(report_type) then
        info = { category = "military", type = "ambush", importance = 3, is_major = true }
    else
        info = REPORT_MAP[report_type]
    end

    if not info then
        -- Unknown report type — skip
        return nil
    end

    if info.category == "combat" then
        -- Combat reports are too noisy for per-report entries
        return nil
    end

    if info.type and info.type:match("^season_") then
        -- Season changes are handled by the seasonal poll, not individual hooks
        return nil
    end

    -- Build the entry text
    local entry = nil
    if info.category == "threat" then
        entry = EventParser._format_threat_entry(report_text, report_obj, info.type)
    elseif info.category == "achievement" then
        entry = EventParser._format_achievement_entry(report_text, report_obj, info.type)
    elseif info.category == "social" then
        entry = EventParser._format_social_entry(report_text, report_obj, info.type)
    elseif info.category == "trade" then
        entry = EventParser._format_trade_entry(report_text, report_obj, info.type)
    elseif info.category == "crisis" then
        entry = EventParser._format_crisis_entry(report_text, report_obj, info.type)
    elseif info.category == "military" then
        entry = EventParser._format_military_entry(report_text, report_obj, info.type)
    elseif info.category == "environment" then
        entry = EventParser._format_environment_entry(report_text, report_obj, info.type)
    elseif info.category == "world" then
        entry = EventParser._format_world_entry(report_text, report_obj, info.type)
    else
        entry = EventParser._format_world_entry(report_text, report_obj, info.type)
    end

    if not entry then return nil end

    return make_result(info, entry)
end

---------------------------------------------------------------------------
--- Public API: parse_death(unit)
--- Called from eventful onUnitDeath hook
---------------------------------------------------------------------------

function EventParser.parse_death(unit)
    if not unit then return nil end
    local year = df.global.cur_year
    local tick = df.global.cur_year_tick
    local date_str = formatted_date(year, tick)

    local unit_name = EventParser.get_unit_link(unit.id)
    local cause = "unknown"
    local killer_name = nil

    if unit.death_info then
        pcall(function()
            if unit.death_info.death_cause and unit.death_info.death_cause ~= -1 then
                local raw = tostring(df.death_type[unit.death_info.death_cause])
                cause = raw:lower():gsub("_", " ")
            end
            if unit.death_info.killer and unit.death_info.killer ~= -1 then
                local killer = df.unit.find(unit.death_info.killer)
                if killer then
                    killer_name = EventParser.get_unit_link(killer.id)
                end
            end
        end)
    end

    local citizen_entry = nil
    local events_entry = nil
    local is_fort_dwarf = is_our_unit(unit)

    if is_fort_dwarf then
        if killer_name then
            citizen_entry = entry_line(date_str .. ": Died, cause: " .. cause .. ", slain by " .. killer_name)
        else
            citizen_entry = entry_line(date_str .. ": Died, cause: " .. cause)
        end
        events_entry = entry_line(date_str .. ": " .. unit_name .. " died (" .. cause .. ")")
    else
        -- Enemy/animal death — only noteworthy for enemies page
        local name = utils.sanitize(dfhack.units.getReadableName(unit))
        return {
            targets = {
                { page_id = "enemies", section = "Kill List", entry = entry_line(date_str .. ": " .. name .. " slain") },
            },
            year = year,
            season = get_season(tick),
            category = "threat",
            event_type = "enemy_killed",
            is_major = false,
            importance = 1,
            summary = name .. " slain",
        }
    end

    local targets = {}
    if is_fort_dwarf then
        table.insert(targets, {
            page_id = "citizen:" .. tostring(unit.id),
            section = "History & Timeline",
            entry = citizen_entry,
        })
    end
    table.insert(targets, {
        page_id = "events",
        section = "Deaths",
        entry = events_entry or citizen_entry,
    })

    return {
        targets = targets,
        year = year,
        season = get_season(tick),
        category = "death",
        event_type = "unit_died",
        is_major = is_fort_dwarf,
        importance = is_fort_dwarf and 2 or 1,
        summary = unit_name .. " died (" .. cause .. ")",
    }
end

---------------------------------------------------------------------------
--- Public API: parse_item_created(item)
--- Called from eventful onItemCreated hook
---------------------------------------------------------------------------

function EventParser.parse_item_created(item)
    if not item then return nil end
    local year = df.global.cur_year
    local tick = df.global.cur_year_tick
    local date_str = formatted_date(year, tick)

    local item_name = ""
    pcall(function() item_name = dfhack.items.getDescription(item, 0, true) end)
    local safe_name = utils.sanitize(item_name)

    -- Check if this item is an artifact
    local creator_unit = nil
    for _, art in ipairs(df.global.world.artifacts.all) do
        if art.item and art.item.id == item.id then
            pcall(function()
                if art.name and art.name.has_name then
                    local art_name = dfhack.translation.translateName(art.name, true)
                    if art_name and art_name ~= "" then
                        safe_name = utils.sanitize(art_name)
                    end
                end
            end)
            pcall(function()
                if item.maker and item.maker.unit_id >= 0 then
                    creator_unit = df.unit.find(item.maker.unit_id)
                end
            end)
            break
        end
    end

    local creator_link = ""
    if creator_unit and is_our_unit(creator_unit) then
        creator_link = " created by " .. EventParser.get_unit_link(creator_unit.id)
    end

    local entry = entry_line(date_str .. ": " .. safe_name .. creator_link .. " completed")

    return {
        targets = {
            { page_id = "events", section = "Artifacts & Crafts", entry = entry },
            { page_id = "artifacts", section = "Recent Events", entry = entry },
        },
        year = year,
        season = get_season(tick),
        category = "achievement",
        event_type = "item_created",
        is_major = true,
        importance = 2,
        summary = safe_name .. " completed",
    }
end

---------------------------------------------------------------------------
--- Public API: parse_new_unit(unit)
--- Called from eventful onUnitNewActive hook
---------------------------------------------------------------------------

function EventParser.parse_new_unit(unit)
    if not unit or not dfhack.units.isAlive(unit) then return nil end
    local year = df.global.cur_year
    local tick = df.global.cur_year_tick
    local date_str = formatted_date(year, tick)

    local unit_name = EventParser.get_unit_link(unit.id)
    local is_dwarf = is_our_unit(unit)

    if not is_dwarf then
        -- Check for invader
        local is_invader = false
        pcall(function() is_invader = dfhack.units.isInvader(unit) end)
        if is_invader then
            -- Invasions are handled by onInvasion — skip to avoid double-count
            return nil
        end
        -- Non-citizen, non-invader (animals, visitors) — skip
        return nil
    end

    -- Check age to determine if migrant or birth
    local age = 0
    pcall(function() age = dfhack.units.getAge(unit) or 0 end)

    local entry = nil
    local event_type = ""
    if age <= 1 then
        entry = entry_line(date_str .. ": " .. unit_name .. " was born")
        event_type = "birth"
    else
        entry = entry_line(date_str .. ": " .. unit_name .. " arrived at the fortress")
        event_type = "migrant"
    end

    return {
        targets = {
            { page_id = "citizen:" .. tostring(unit.id), section = "History & Timeline", entry = entry },
            { page_id = "events", section = "Population", entry = entry },
        },
        year = year,
        season = get_season(tick),
        category = "population",
        event_type = event_type,
        is_major = false,
        importance = 1,
        summary = unit_name .. " " .. event_type,
    }
end

---------------------------------------------------------------------------
--- Public API: parse_invasion(invasion_id)
--- Called from eventful onInvasion hook
---------------------------------------------------------------------------

function EventParser.parse_invasion(invasion_id)
    local year = df.global.cur_year
    local tick = df.global.cur_year_tick
    local date_str = formatted_date(year, tick)

    local invader_count = 0
    local invader_race = "unknown"
    local invader_civ = "unknown"

    pcall(function()
        local invaders = {}
        for _, unit in ipairs(df.global.world.units.active) do
            if dfhack.units.isAlive(unit) and dfhack.units.isInvader(unit) and not dfhack.units.isAnimal(unit) then
                table.insert(invaders, unit)
            end
        end
        invader_count = #invaders
        if invader_count > 0 then
            local first = invaders[1]
            pcall(function()
                local raw = df.creature_raw.find(first.race)
                if raw then invader_race = raw.creature_id end
            end)
            pcall(function()
                if first.civ_id >= 0 then
                    local civ = df.historical_entity.find(first.civ_id)
                    if civ then
                        invader_civ = dfhack.translation.translateName(civ.name, true)
                        invader_civ = utils.sanitize(invader_civ)
                    end
                end
            end)
        end
    end)

    local entry = entry_line(date_str .. ": SIEGE! " .. invader_count .. " " .. invader_race .. " from " .. invader_civ .. " attack the fortress")

    return {
        targets = {
            { page_id = "events", section = "Sieges & Invasions", entry = entry },
            { page_id = "fort", section = "Military", entry = entry },
            { page_id = "enemies", section = "Notable Encounters", entry = entry },
        },
        year = year,
        season = get_season(tick),
        category = "threat",
        event_type = "siege",
        is_major = true,
        importance = 4,
        summary = "Siege: " .. invader_count .. " " .. invader_race,
    }
end

---------------------------------------------------------------------------
--- Public API: parse_syndrome(unit, syndrome_id)
--- Called from eventful onSyndrome hook
---------------------------------------------------------------------------

function EventParser.parse_syndrome(unit, syndrome_id)
    if not unit then return nil end
    local year = df.global.cur_year
    local tick = df.global.cur_year_tick
    local date_str = formatted_date(year, tick)

    if not is_our_unit(unit) then return nil end

    local syndrome_name = "unknown"
    local syndrome_class = ""
    pcall(function()
        local syn = df.syndrome.find(syndrome_id)
        if syn then
            if syn.syn_name and syn.syn_name ~= "" then
                syndrome_name = syn.syn_name
            end
            for _, cls in ipairs(syn.syn_class) do
                if cls and cls.value then
                    syndrome_class = syndrome_class .. cls.value .. " "
                end
            end
        end
    end)

    -- Skip mundane syndromes (alcohol, minor ailments)
    local lower = syndrome_name:lower()
    if lower:match("alcohol") or lower:match("beer") or lower:match("wine") or lower:match("inebriat") then
        return nil
    end

    local unit_link = EventParser.get_unit_link(unit.id)
    local entry = entry_line(date_str .. ": " .. unit_link .. " afflicted by " .. syndrome_name)

    return {
        targets = {
            { page_id = "citizen:" .. tostring(unit.id), section = "History & Timeline", entry = entry },
            { page_id = "events", section = "Syndromes & Afflictions", entry = entry },
        },
        year = year,
        season = get_season(tick),
        category = "crisis",
        event_type = "syndrome",
        is_major = syndrome_class:match("were") and true or false,
        importance = syndrome_class:match("were") and 3 or 2,
        summary = unit_link .. " afflicted by " .. syndrome_name,
    }
end

---------------------------------------------------------------------------
--- Historical parse: parse(event) — for historical batch scan
--- Processes df.history_event objects from world.history.events
--- Called by both Chronicle (background poll) and Initializer (catch-up).
--- Main site filtering is done by the caller; we do secondary HF-citizen checks.
--- Returns {page_id, section, text, importance} or nil
---------------------------------------------------------------------------

function EventParser.parse(event)
    local etype = event:getType()
    local year = event.year or df.global.cur_year

    -- Helper to get citizen page_id from an HF
    local function citizen_page(hf_id)
        if hf_id == -1 then return nil end
        local hf = df.historical_figure.find(hf_id)
        if hf and hf.unit_id ~= -1 then
            return "citizen:" .. tostring(hf.unit_id)
        end
        return nil
    end

    -- + HIST_FIGURE_DIED
    if etype == df.history_event_type.HIST_FIGURE_DIED then
        local victim_hf = event.victim_hf
        if EventParser.is_our_hf(victim_hf) then
            local cause = "unknown"
            pcall(function()
                cause = tostring(df.death_type[event.death_cause]):lower():gsub("_", " ")
            end)
            local page = citizen_page(victim_hf)
            local killer_name = ""
            pcall(function()
                if event.killer_hf and event.killer_hf ~= -1 then
                    killer_name = " by " .. hf_link(event.killer_hf)
                end
            end)
            local text = "Died in year " .. year .. ", cause: " .. cause .. killer_name
            local result = {
                section = "History & Timeline",
                text = text,
                importance = 1,
            }
            if page then
                result.page_id = page
            else
                result.page_id = "events"
                result.section = "Deaths"
            end
            return result
        end
        return nil

    -- + HIST_FIGURE_NEW_PET (adoptions / births)
    elseif etype == df.history_event_type.HIST_FIGURE_NEW_PET then
        if EventParser.is_our_hf(event.group_hf) then
            local page = citizen_page(event.group_hf)
            if page then
                return {
                    page_id = page,
                    section = "History & Timeline",
                    text = "Adopted a pet or child in year " .. year,
                    importance = 1
                }
            end
        end
        return nil

    -- + ARTIFACT_CREATED
    elseif etype == df.history_event_type.ARTIFACT_CREATED then
        local artifact_name = ""
        pcall(function()
            local art = df.artifact_record.find(event.artifact_id)
            if art and art.name and art.name.has_name then
                artifact_name = ": " .. utils.get_readable_name(art.name)
            end
        end)
        return {
            page_id = "artifacts",
            section = "Recent Events",
            text = "Artifact created in year " .. year .. artifact_name,
            importance = 1
        }

    -- + HIST_FIGURE_RENAME
    elseif etype == df.history_event_type.HIST_FIGURE_RENAME then
        if EventParser.is_our_hf(event.hf) then
            local page = citizen_page(event.hf)
            if page then
                return {
                    page_id = page,
                    section = "History & Timeline",
                    text = "Earned a new name in year " .. year,
                    importance = 1
                }
            end
        end
        return nil

    -- + HIST_FIGURE_ATTACK (citizen attacked or was attacked)
    elseif etype == df.history_event_type.HIST_FIGURE_ATTACK then
        local is_us_attacker = EventParser.is_our_hf(event.attacker_hf)
        local is_us_defender = EventParser.is_our_hf(event.defender_hf)
        if is_us_attacker or is_us_defender then
            local attacker = hf_link(event.attacker_hf)
            local defender = hf_link(event.defender_hf)
            local target_page = nil
            if is_us_attacker then
                target_page = citizen_page(event.attacker_hf)
            elseif is_us_defender then
                target_page = citizen_page(event.defender_hf)
            end
            local result = {
                page_id = "events",
                section = "Combat & Conflicts",
                text = attacker .. " attacked " .. defender .. " in year " .. year,
                importance = 1,
            }
            if target_page then
                -- Also log on the citizen's page
                result.page_id = target_page
                result.section = "History & Timeline"
            end
            return result
        end
        return nil

    -- + HIST_FIGURE_SITE_CONFLICT (battle at our site)
    elseif etype == df.history_event_type.HIST_FIGURE_SITE_CONFLICT then
        local conflict_type = "conflict"
        pcall(function()
            conflict_type = tostring(event.conflict_type or "conflict"):lower()
        end)
        return {
            page_id = "events",
            section = "Sieges & Invasions",
            text = "Site conflict (" .. conflict_type .. ") in year " .. year,
            importance = 2,
        }

    -- + HIST_FIGURE_ABDUCTED (someone kidnapped)
    elseif etype == df.history_event_type.HIST_FIGURE_ABDUCTED then
        if EventParser.is_our_hf(event.target_hf) then
            local target = hf_link(event.target_hf)
            local snatcher = ""
            pcall(function()
                if event.snatcher_hf and event.snatcher_hf ~= -1 then
                    snatcher = " by " .. hf_link(event.snatcher_hf)
                end
            end)
            local page = citizen_page(event.target_hf)
            local result = {
                section = "History & Timeline",
                text = "Abducted in year " .. year .. snatcher,
                importance = 3,
            }
            if page then
                result.page_id = page
            else
                result.page_id = "events"
                result.section = "Incidents & Crises"
            end
            return result
        end
        return nil

    -- + HIST_FIGURE_BECAME_VAMPIRE
    elseif etype == df.history_event_type.HIST_FIGURE_BECAME_VAMPIRE then
        if EventParser.is_our_hf(event.hf) then
            local page = citizen_page(event.hf)
            local result = {
                section = "History & Timeline",
                text = "Became a vampire in year " .. year,
                importance = 3,
            }
            if page then
                result.page_id = page
            else
                result.page_id = "events"
                result.section = "Syndromes & Afflictions"
            end
            return result
        end
        return nil

    -- + HIST_FIGURE_BECAME_WEREBEAST
    elseif etype == df.history_event_type.HIST_FIGURE_BECAME_WEREBEAST then
        if EventParser.is_our_hf(event.hf) then
            local page = citizen_page(event.hf)
            local result = {
                section = "History & Timeline",
                text = "Became a werebeast in year " .. year,
                importance = 3,
            }
            if page then
                result.page_id = page
            else
                result.page_id = "events"
                result.section = "Syndromes & Afflictions"
            end
            return result
        end
        return nil

    -- + HIST_FIGURE_GAINS_SYNDROME
    elseif etype == df.history_event_type.HIST_FIGURE_GAINS_SYNDROME then
        if EventParser.is_our_hf(event.hf) then
            local syn_name = "a syndrome"
            pcall(function()
                if event.syndrome then
                    syn_name = tostring(event.syndrome)
                end
            end)
            local page = citizen_page(event.hf)
            local result = {
                section = "History & Timeline",
                text = "Gained " .. syn_name .. " in year " .. year,
                importance = 2,
            }
            if page then
                result.page_id = page
            else
                result.page_id = "events"
                result.section = "Syndromes & Afflictions"
            end
            return result
        end
        return nil

    -- + HIST_FIGURE_ENTITY_MIGRANT (joined our civilization)
    elseif etype == df.history_event_type.HIST_FIGURE_ENTITY_MIGRANT then
        if event.entity_id == df.global.plotinfo.civ_id then
            local hf_name = get_hf_name(event.hfid)
            return {
                page_id = "events",
                section = "Population",
                text = hf_name .. " joined the civilization in year " .. year,
                importance = 1,
            }
        end
        return nil

    -- + MASTERPIECE types
    elseif etype == df.history_event_type.MASTERPIECE_ITEM
        or etype == df.history_event_type.MASTERPIECE_ENGRAVING
        or etype == df.history_event_type.MASTERPIECE_FOOD
        or etype == df.history_event_type.MASTERPIECE_ARCH_DESIGN
        or etype == df.history_event_type.MASTERPIECE_ARCH_CONSTRUCT then

        local maker = ""
        pcall(function()
            if event.maker_hf and event.maker_hf ~= -1 then
                maker = " by " .. hf_link(event.maker_hf)
            end
        end)
        local master_type = "masterpiece"
        pcall(function()
            local raw = tostring(etype)
            master_type = raw:gsub("MASTERPIECE_", ""):lower():gsub("_", " ")
        end)
        return {
            page_id = "events",
            section = "Achievements",
            text = master_type .. " created in year " .. year .. maker,
            importance = 2,
        }

    -- + CREATURE_DEVOURED (devouring at our site)
    elseif etype == df.history_event_type.CREATURE_DEVOURED then
        if EventParser.is_our_hf(event.devoured_hf) then
            local victim = hf_link(event.devoured_hf)
            local devourer = ""
            pcall(function()
                if event.devourer_hf and event.devourer_hf ~= -1 then
                    devourer = " by " .. hf_link(event.devourer_hf)
                end
            end)
            local page = citizen_page(event.devoured_hf)
            local result = {
                section = "History & Timeline",
                text = "Devoured in year " .. year .. devourer,
                importance = 3,
            }
            if page then
                result.page_id = page
            else
                result.page_id = "events"
                result.section = "Deaths"
            end
            return result
        end
        return nil

    -- + ADD_HF_HF_LINK (relationships recorded in history: marriage, parent, etc.)
    elseif etype == df.history_event_type.ADD_HF_HF_LINK then
        local is_us_1 = EventParser.is_our_hf(event.hf)
        local is_us_2 = EventParser.is_our_hf(event.hf_target)
        if is_us_1 or is_us_2 then
            local link_type = "relationship"
            pcall(function() link_type = tostring(event.link_type):lower() end)
            local name1 = hf_link(event.hf)
            local name2 = hf_link(event.hf_target)
            local text = name1 .. " formed " .. link_type .. " with " .. name2 .. " in year " .. year
            -- Route to citizen page if one is ours
            local target_page = nil
            if is_us_1 then
                target_page = citizen_page(event.hf)
            elseif is_us_2 then
                target_page = citizen_page(event.hf_target)
            end
            local result = {
                section = "History & Timeline",
                text = text,
                importance = 1,
            }
            if target_page then
                result.page_id = target_page
            else
                result.page_id = "events"
                result.section = "Social Events"
            end
            return result
        end
        return nil

    -- + CREATED_STRUCTURE (notable structure built at our site)
    elseif etype == df.history_event_type.CREATED_STRUCTURE then
        return {
            page_id = "events",
            section = "Fort Timeline",
            text = "Notable structure built in year " .. year,
            importance = 1,
        }

    end

    return nil
end

return EventParser
