--@ module = true

local SETTINGS_KEY = 'mfw_settings'

local DEFAULT_SETTINGS = {
    civ = {
        leadership = true,
        ethics = true,
        relations = true,
        history = true,
        wars = true,
    },
    fort = {
        wealth = true,
        gov = true,
        districts = true,
        defense = true,
        links = true,
        timeline = true,
    },
    citizen = {
        values = true,
        relationships = true,
        skills = true,
        appearance = true,
        needs = true,
        medical = true,
        timeline = true,
    },
    artifact = {
        description = true,
        history = true,
        creator = true,
        location = true,
    },
    event = {
        participants = true,
        summary = true,
        consequences = true,
    }
}

local logger = reqscript('internal/DFMyFortWiki/logger')
local json = require('json')

function get_settings()
    local ok, data = pcall(function()
        return dfhack.persistent.getSiteData(SETTINGS_KEY)
    end)
    if ok and data and data.val then
        if type(data.val) == "string" and data.val ~= "" then
            local ok_json, decoded = pcall(json.decode, data.val)
            if ok_json and type(decoded) == "table" then
                return decoded
            end
        elseif type(data.val) == "table" then
            -- Legacy support: it was already a table
            -- Migrating to JSON
            save_settings(data.val)
            return data.val
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
    if preset == 'all' then
        for k, v in pairs(settings[template]) do
            settings[template][k] = true
        end
    elseif preset == 'minimal' then
        for k, v in pairs(settings[template]) do
            settings[template][k] = false
        end
    elseif preset == 'recommended' then
        -- Define recommended sets if needed, for now just a middle ground or same as default
        if template == 'citizen' then
            settings.citizen.values = true
            settings.citizen.relationships = true
            settings.citizen.skills = true
            settings.citizen.appearance = false
            settings.citizen.needs = false
            settings.citizen.medical = false
            settings.citizen.timeline = true
        else
            -- Default recommended is all for others for now
            for k, v in pairs(settings[template]) do
                settings[template][k] = true
            end
        end
    end
    save_settings(settings)
end

return _ENV
