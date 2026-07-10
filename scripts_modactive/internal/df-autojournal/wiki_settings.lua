--@ module = true

local SETTINGS_KEY = 'mfw_settings'

local DEFAULT_SETTINGS = {
    civ = {
        init = {
            leadership = true,
            ethics = true,
            relations = true,
            history = true,
            wars = true,
            position = true,
            forts = true,
            tracking = 'all_major',
        },
        journal = {
            diplomacy = true,
            wars = true,
            leadership = true,
        }
    },
    fort = {
        init = {
            wealth = true,
            gov = true,
            districts = true,
            defense = true,
            links = true,
            timeline = true,
            location = true,
        },
        journal = {
            population = true,
            construction = true,
            defense = true,
        }
    },
    citizen = {
        init = {
            values = true,
            relationships = true,
            skills = true,
            appearance = true,
            needs = true,
            medical = true,
            timeline = true,
        },
        journal = {
            pet_adopted = true,
            died = true,
            renamed = true,
            arrivals = true,
            new_relationships = true,
            master_skills = true,
            medical_history = true,
            military_history = true,
            timeline_events = true,
        }
    },
    artifact = {
        init = {
            description = true,
            history = true,
            creator = true,
            location = true,
        },
        journal = {
            created = true,
            decorations = true,
        }
    },
    event = {
        init = {
            participants = true,
            summary = true,
            consequences = true,
        },
        journal = {
            threat_events = true,
            achievement_events = true,
            social_events = true,
            trade_events = true,
            crisis_events = true,
            military_events = true,
            environment_events = true,
            world_events = true,
            death_events = true,
            birth_migrant_events = true,
            syndrome_events = true,
            siege_events = true,
        }
    },
    enemies = {
        init = {
            registry = true,
            stats = true,
        },
        journal = {
            encounter_log = true,
            kill_list = true,
            notable_victories = true,
        }
    },
    visitors = {
        init = {
            registry = true,
            departed = true,
            create_pages = false,
        },
        journal = {
            track_traders = true,
            track_entertainers = true,
            track_scholars = true,
            track_monster_slayers = true,
            track_mercenaries = true,
            track_diplomats = true,
            track_petitioners = true,
        }
    },
    world = {
        init = {
            era_timeline = true,
            landmass_list = true,
            landmass_detail = 'all',
            world_gen = true,
            seeds = true,
            geography_detail = 'major',
        },
        journal = {},
    }
}

local DEFAULT_JOURNAL = {
    civ = { diplomacy = true, wars = true, leadership = true },
    fort = { population = true, construction = true, defense = true },
    citizen = { pet_adopted = true, died = true, renamed = true, arrivals = true, new_relationships = true, master_skills = true, medical_history = true, military_history = true, timeline_events = true },
    artifact = { created = true, decorations = true },
    event = {
        threat_events = true,
        achievement_events = true,
        social_events = true,
        trade_events = true,
        crisis_events = true,
        military_events = true,
        environment_events = true,
        world_events = true,
        death_events = true,
        birth_migrant_events = true,
        syndrome_events = true,
        siege_events = true,
    },
    enemies = { encounter_log = true, kill_list = true, notable_victories = true },
    visitors = { track_traders = true, track_entertainers = true, track_scholars = true, track_monster_slayers = true, track_mercenaries = true, track_diplomats = true, track_petitioners = true },
    world = {},
}

local logger = reqscript('internal/df-autojournal/logger')
local json = require('json')

local function has_init_structure(settings)
    if type(settings) ~= 'table' then return false end
    for _, t in ipairs{'civ', 'fort', 'citizen', 'artifact', 'event', 'enemies', 'visitors', 'world'} do
        if type(settings[t]) == 'table' then
            if settings[t].init ~= nil then
                return true
            end
        end
    end
    return false
end

local function migrate_from_old(old)
    local new = {}
    for template, keys in pairs(old) do
        if type(keys) == 'table' then
            new[template] = {
                init = keys,
                journal = {}
            }
            if DEFAULT_JOURNAL[template] then
                for k, v in pairs(DEFAULT_JOURNAL[template]) do
                    new[template].journal[k] = v
                end
            end
        else
            new[template] = keys
        end
    end
    for template, def in pairs(DEFAULT_SETTINGS) do
        if not new[template] then
            new[template] = deep_copy(def)
        end
    end
    return new
end

local function deep_copy(t)
    if type(t) ~= 'table' then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = deep_copy(v)
    end
    return copy
end

local function merge_with_defaults(settings)
    local merged = {}
    for template, def in pairs(DEFAULT_SETTINGS) do
        merged[template] = {}
        local current = settings[template]
        if current then
            for category, cat_def in pairs(def) do
                merged[template][category] = {}
                local cat_current = current[category]
                if cat_current then
                    for key, val in pairs(cat_def) do
                        local raw = cat_current[key]
                        if raw ~= nil then
                            merged[template][category][key] = raw
                        else
                            merged[template][category][key] = val
                        end
                    end
                else
                    for key, val in pairs(cat_def) do
                        merged[template][category][key] = val
                    end
                end
            end
        else
            merged[template] = deep_copy(def)
        end
    end
    return merged
end

function get_settings()
    local ok, data = pcall(function()
        return dfhack.persistent.getSiteData(SETTINGS_KEY)
    end)
    if not ok then
        logger.log_error("LOAD: getSiteData threw error")
        return deep_copy(DEFAULT_SETTINGS)
    end
    if not data then
        -- logger.log("LOAD: getSiteData returned nil")
        return deep_copy(DEFAULT_SETTINGS)
    end

    -- logger.log("LOAD: data type=" .. type(data))
    if data then
        local keys = ""
        for k, _ in pairs(data) do keys = keys .. tostring(k) .. "," end
        -- logger.log("LOAD: data keys={" .. keys .. "}")
    end

    if data.val then
        -- logger.log("LOAD: data.val type=" .. type(data.val) ..
        --            (type(data.val) == "string" and " length=" .. #data.val or ""))

        if type(data.val) == "string" then
            local ok2, decoded = pcall(json.decode, data.val)
            -- logger.log("LOAD: json.decode ok=" .. tostring(ok2) .. " decoded type=" .. type(decoded))
            if ok2 and type(decoded) == "table" then
                -- logger.log("LOAD: decoded.civ.init.leadership=" .. tostring(decoded.civ.init.leadership) ..
                --            " ethics=" .. tostring(decoded.civ.init.ethics))
                if not has_init_structure(decoded) then
                    -- logger.log("LOAD: migrating old-format JSON")
                    decoded = migrate_from_old(decoded)
                    save_settings(decoded)
                end
                local merged = merge_with_defaults(decoded)
                -- logger.log("LOAD: merged.civ.init.leadership=" .. tostring(merged.civ.init.leadership) ..
                --            " ethics=" .. tostring(merged.civ.init.ethics))
                return merged
            end
        elseif type(data.val) == "table" then
            -- logger.log("LOAD: legacy table format, has_init=" .. tostring(has_init_structure(data.val)))
            local tbl = data.val
            if not has_init_structure(tbl) then
                -- logger.log("LOAD: migrating old-format table")
                tbl = migrate_from_old(tbl)
            end
            save_settings(tbl)
            return merge_with_defaults(tbl)
        end
    else
        -- logger.log("LOAD: data.val is nil")
    end
    -- logger.log("LOAD: falling through to defaults")
    return deep_copy(DEFAULT_SETTINGS)
end

function save_settings(settings)
    -- logger.log("SAVE: civ.init.leadership=" .. tostring(settings.civ.init.leadership) ..
    --            " civ.init.ethics=" .. tostring(settings.civ.init.ethics))  

    local ok, encoded = pcall(json.encode, settings)
    if not ok then
        logger.log_error("SAVE: json.encode failed: " .. tostring(encoded))
        return
    end
    -- logger.log("SAVE: json OK length=" .. #encoded .. " preview=" .. encoded:sub(1, 250))

    local ok2, result = pcall(dfhack.persistent.saveSiteData, SETTINGS_KEY, {val=encoded})
    -- logger.log("SAVE: saveSiteData ok=" .. tostring(ok2) .. " result=" .. tostring(result))
    if ok2 and result ~= false then
        -- logger.log("SAVE: success")
    else
        logger.log_error("SAVE: failed (" .. tostring(ok2) .. ", " .. tostring(result) .. ")")
    end
end

function set_preset(settings, template, preset)
    local t = settings[template]
    if not t then return end
    local function set_all(val)
        for _, category in pairs{'init', 'journal'} do
            if t[category] then
                for k, v in pairs(t[category]) do
                    if type(v) ~= 'string' then
                        t[category][k] = val
                    end
                end
            end
        end
    end
    if preset == 'all' then
        set_all(true)
    elseif preset == 'minimal' then
        set_all(false)
    elseif preset == 'recommended' then
        if template == 'citizen' then
            t.init.values = true
            t.init.relationships = true
            t.init.skills = true
            t.init.appearance = false
            t.init.needs = false
            t.init.medical = false
            t.init.timeline = true
            if t.journal then
                for k, v in pairs(t.journal) do
                    if type(v) ~= 'string' then
                        t.journal[k] = true
                    end
                end
            end
        else
            set_all(true)
        end
    end
    save_settings(settings)
end

return _ENV
