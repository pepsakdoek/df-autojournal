--@ module = true

local SETTINGS_KEY = 'mfw:settings'

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

function get_settings()
    local data = dfhack.persistent.getSiteData(SETTINGS_KEY)
    if data and data.val then
        return data.val
    end
    return DEFAULT_SETTINGS
end

function save_settings(settings)
    dfhack.persistent.saveSiteData(SETTINGS_KEY, {val=settings})
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
