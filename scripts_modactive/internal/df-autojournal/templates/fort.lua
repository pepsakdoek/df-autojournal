--@ module = true
local utils = reqscript('internal/df-autojournal/wiki_utils')
local mfw_settings = reqscript('internal/df-autojournal/wiki_settings')

function render(site_id)
    local cfg = mfw_settings.get_settings().fort
    local settings = cfg.init
    local site_name = "Unknown Fort"
    local site
    if site_id then
        site = df.world_site.find(site_id)
    else
        site = dfhack.world.getCurrentSite()
    end
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

    -- Links to section pages
    table.insert(content, "\n")
    table.insert(content, { text = "## Pages", pen = COLOR_YELLOW })
    table.insert(content, "\n")
    local section_links = {
        { id = 'fort:' .. tostring(site_id) .. '/citizens', label = 'Citizens' },
        { id = 'fort:' .. tostring(site_id) .. '/artifacts', label = 'Artifacts' },
        { id = 'fort:' .. tostring(site_id) .. '/events', label = 'Events' },
        { id = 'fort:' .. tostring(site_id) .. '/visitors', label = 'Visitors' },
        { id = 'fort:' .. tostring(site_id) .. '/enemies', label = 'Enemies' },
    }
    for _, sl in ipairs(section_links) do
        table.insert(content, "* ")
        table.insert(content, { text = sl.label, pen = COLOR_LIGHTBLUE, link = sl.id })
        table.insert(content, "\n")
    end
    table.insert(content, "\n")

    if settings.location and site and site.pos then
        local pos_info = utils.describe_site_position(site)
        if pos_info then
            table.insert(content, "\n")
            table.insert(content, { text = "## Location", pen = COLOR_YELLOW })
            table.insert(content, "\n")

            table.insert(content, { text = site_name, pen = COLOR_LIGHTBLUE })
            table.insert(content, " is located in ")
            table.insert(content, { text = pos_info.continent or pos_info.region_name or "an uncharted area", pen = COLOR_LIGHTCYAN })
            table.insert(content, ", ")
            table.insert(content, { text = pos_info.description, pen = COLOR_WHITE })

            if pos_info.world_name and not pos_info.description:match("world$") then
                table.insert(content, " of ")
                table.insert(content, { text = pos_info.world_name, pen = COLOR_LIGHTCYAN })
            end
            table.insert(content, ".\n")

            if pos_info.continent and pos_info.region_name then
                table.insert(content, { text = "Region: ", pen = COLOR_LIGHTCYAN })
                table.insert(content, { text = pos_info.region_name, pen = COLOR_WHITE })
                table.insert(content, "\n")
            end

            if pos_info.temperature then
                table.insert(content, { text = "Climate: ", pen = COLOR_LIGHTCYAN })
                if pos_info.temperature:match("cold") or pos_info.temperature:match("frigid") then
                    table.insert(content, { text = pos_info.temperature, pen = COLOR_LIGHTCYAN })
                elseif pos_info.temperature:match("hot") or pos_info.temperature:match("scorch") then
                    table.insert(content, { text = pos_info.temperature, pen = COLOR_LIGHTRED })
                else
                    table.insert(content, { text = pos_info.temperature, pen = COLOR_GREEN })
                end
                table.insert(content, "\n")
            end
        end
    end

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

    if settings.timeline or settings.defense then
        -- Combined fort timeline section
        table.insert(content, "\n")
        table.insert(content, { text = "## Fort Timeline", pen = COLOR_YELLOW })
        table.insert(content, "\n")
        local founding_year = site and site.created_year and site.created_year > 0 and site.created_year or df.global.cur_year
        table.insert(content, "* Founding of ")
        table.insert(content, { text = site_name, pen = COLOR_LIGHTBLUE, link = "fort" })
        table.insert(content, " in year ")
        table.insert(content, { text = tostring(founding_year), pen = COLOR_WHITE })
        table.insert(content, "\n")
        if settings.defense then
            table.insert(content, "\n")
            table.insert(content, { text = "### Notable Visitors & Sieges", pen = COLOR_YELLOW })
            table.insert(content, "\n")
            table.insert(content, { text = "Record sieges, military campaigns, and notable visitors here.", pen = COLOR_DARKGREY })
            table.insert(content, "\n")
        end
    end

    return content
end

return _ENV
