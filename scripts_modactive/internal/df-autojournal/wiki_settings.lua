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
    }
}

local DEFAULT_JOURNAL = {
    civ = { diplomacy = true, wars = true, leadership = true },
    fort = { population = true, construction = true, defense = true },
    citizen = { pet_adopted = true, died = true, renamed = true },
    artifact = { created = true },
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
}

local logger = reqscript('internal/df-autojournal/logger')
local json = require('json')

local function has_init_structure(settings)
    if type(settings) ~= 'table' then return false end
    for _, t in ipairs{'civ', 'fort', 'citizen', 'artifact', 'event'} do
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
            new[template] = def
        end
    end
    return new
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
                        merged[template][category][key] = (cat_current[key] ~= nil) and cat_current[key] or val
                    end
                else
                    for key, val in pairs(cat_def) do
                        merged[template][category][key] = val
                    end
                end
            end
        else
            merged[template] = def
        end
    end
    return merged
end

function get_settings()
    local ok, data = pcall(function()
        return dfhack.persistent.getSiteData(SETTINGS_KEY)
    end)
    if ok and data and data.val then
        if type(data.val) == "string" and data.val ~= "" then
            local ok_json, decoded = pcall(json.decode, data.val)
            if ok_json and type(decoded) == "table" then
                if not has_init_structure(decoded) then
                    decoded = migrate_from_old(decoded)
                    save_settings(decoded)
                end
                return merge_with_defaults(decoded)
            end
        elseif type(data.val) == "table" then
            local tbl = data.val
            if not has_init_structure(tbl) then
                tbl = migrate_from_old(tbl)
            end
            save_settings(tbl)
            return merge_with_defaults(tbl)
        end
        logger.log("get_settings: failed to decode settings or invalid type, returning default")
    end
    return DEFAULT_SETTINGS
end

function save_settings(settings)
    local ok, encoded = pcall(json.encode, settings)
    if ok then
        dfhack.persistent.saveSiteData(SETTINGS_KEY, {val=encoded})
    else
        logger.log_error("save_settings: failed to encode settings")
    end
end

function set_preset(settings, template, preset)
    local t = settings[template]
    if not t then return end
    if preset == 'all' then
        for _, category in pairs{'init', 'journal'} do
            if t[category] then
                for k, _ in pairs(t[category]) do
                    t[category][k] = true
                end
            end
        end
    elseif preset == 'minimal' then
        for _, category in pairs{'init', 'journal'} do
            if t[category] then
                for k, _ in pairs(t[category]) do
                    t[category][k] = false
                end
            end
        end
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
                for k, _ in pairs(t.journal) do
                    t.journal[k] = true
                end
            end
        else
            for _, category in pairs{'init', 'journal'} do
                if t[category] then
                    for k, _ in pairs(t[category]) do
                        t[category][k] = true
                    end
                end
            end
        end
    end
    save_settings(settings)
end

return _ENV
