--@ module = true
local utils = reqscript('internal/df-autojournal/wiki_utils')
local mfw_settings = reqscript('internal/df-autojournal/wiki_settings')

function render()
    local cfg = mfw_settings.get_settings().fort
    local settings = cfg.init
    local site_name = "Unknown Fort"
    local site = dfhack.world.getCurrentSite()
    if site then
        site_name = utils.get_readable_name(site.name)
    end

    local content = {}

    table.insert(content, { text = "# Fort: " .. site_name, pen = COLOR_YELLOW })
    table.insert(content, "\n\n")

    local citizens = 0
    for _, unit in ipairs(df.global.world.units.active) do
        if dfhack.units.isCitizen(unit) then
            citizens = citizens + 1
        end
    end
    table.insert(content, { text = "Population: ", pen = COLOR_LIGHTCYAN })
    table.insert(content, { text = tostring(citizens) .. " Citizens", pen = COLOR_WHITE })
    table.insert(content, "\n")

    if settings.gov then
        table.insert(content, "\n")
        table.insert(content, { text = "## Local Government", pen = COLOR_YELLOW })
        table.insert(content, "\n")
        local found_gov = false
        if site and site.entity_links then
            for _, link in ipairs(site.entity_links) do
                local entity = df.historical_entity.find(link.entity_id)
                if entity and entity.type == df.historical_entity_type.SiteGovernment then
                    table.insert(content, { text = "Government: ", pen = COLOR_LIGHTCYAN })
                    table.insert(content, { text = utils.get_readable_name(entity.name), pen = COLOR_WHITE })
                    table.insert(content, "\n")
                    found_gov = true
                end
            end
        end
        if not found_gov then
            table.insert(content, { text = "No local government recorded.", pen = COLOR_DARKGREY })
            table.insert(content, "\n")
        end
    end

    if settings.links then
        table.insert(content, "\n")
        table.insert(content, { text = "## Economic & Political Links", pen = COLOR_YELLOW })
        table.insert(content, "\n")
        table.insert(content, { text = "No major economic links established yet.", pen = COLOR_DARKGREY })
        table.insert(content, "\n")
    end

    if settings.districts then
        table.insert(content, "\n")
        table.insert(content, { text = "## Infrastructure & Districts", pen = COLOR_YELLOW })
        table.insert(content, "\n")
        table.insert(content, { text = "Log important areas of your fort here.", pen = COLOR_DARKGREY })
        table.insert(content, "\n\n")
    end

    if settings.timeline then
        table.insert(content, "\n")
        table.insert(content, { text = "## History & Timeline", pen = COLOR_YELLOW })
        table.insert(content, "\n")
        table.insert(content, "* Founding of ")
        table.insert(content, { text = site_name, pen = COLOR_LIGHTBLUE, link = "fort" })
        table.insert(content, " in year ")
        table.insert(content, { text = tostring(df.global.cur_year), pen = COLOR_WHITE })
        table.insert(content, "\n")
    end

    if settings.defense then
        table.insert(content, "\n")
        table.insert(content, { text = "## Defense Status", pen = COLOR_YELLOW })
        table.insert(content, "\n")
        table.insert(content, { text = "Describe your military and traps here.", pen = COLOR_DARKGREY })
        table.insert(content, "\n")
    end

    -- Fort Timeline — populated by event listener / catch-up
    table.insert(content, "\n")
    table.insert(content, { text = "## Fort Timeline", pen = COLOR_YELLOW })
    table.insert(content, "\n")
    table.insert(content, "* " .. site_name .. " founded.\n")

    return content
end

return _ENV
