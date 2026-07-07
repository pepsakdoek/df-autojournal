--@ module = true
-- Generalized entity template.
-- Reusable for citizens, enemies, and visitors with section toggling.
-- Delegates to the citizen template when a unit is available;
-- renders a simpler page for registry-based entities (visitors/enemies without DF units).

local citizen_template = reqscript('internal/df-autojournal/templates/citizen')
local mfw_settings = reqscript('internal/df-autojournal/wiki_settings')

local ENTITY_PROFILES = {
    citizen = {
        no_personal_journal = false,
        settings_key = 'citizen',
    },
    enemy = {
        no_personal_journal = true,
        settings_key = 'citizen',
    },
    visitor = {
        no_personal_journal = true,
        settings_key = 'citizen',
    },
}

function render(unit, opts)
    opts = opts or {}
    local entity_type = opts.entity_type or 'citizen'
    local profile = ENTITY_PROFILES[entity_type] or ENTITY_PROFILES.citizen

    -- If no unit object, render a basic page from registry data
    if not unit then
        local name = opts.name or "Unknown"
        local content = {}
        table.insert(content, { text = "# " .. name, pen = COLOR_YELLOW })
        table.insert(content, "\n\n")
        if opts.subtitle then
            table.insert(content, { text = opts.subtitle, pen = COLOR_LIGHTCYAN })
            table.insert(content, "\n\n")
        end
        if entity_type == 'visitor' then
            table.insert(content, { text = "## Visits", pen = COLOR_YELLOW })
            table.insert(content, "\n")
        elseif entity_type == 'enemy' then
            table.insert(content, { text = "## Encounters", pen = COLOR_YELLOW })
            table.insert(content, "\n")
        else
            table.insert(content, { text = "## Personal Journal", pen = COLOR_YELLOW })
            table.insert(content, "\n")
            table.insert(content, { text = "Log your thoughts here...", pen = COLOR_DARKGREY })
            table.insert(content, "\n")
        end
        return content
    end

    -- Full citizen-style rendering with a unit object
    local settings
    if opts.settings then
        settings = opts.settings
    else
        local cfg = mfw_settings.get_settings()
        settings = cfg[profile.settings_key] and cfg[profile.settings_key].init or {}
    end

    local template_opts = {
        settings_override = settings,
        no_personal_journal = profile.no_personal_journal,
    }

    return citizen_template.render(unit, template_opts)
end

return _ENV
