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

            local function cap(s)
                return s and s:sub(1,1):upper() .. s:sub(2) or ""
            end

            table.insert(content, { text = site_name, pen = COLOR_LIGHTBLUE })
            table.insert(content, " is situated in ")
            if pos_info.region_name then
                table.insert(content, { text = pos_info.region_name, pen = COLOR_LIGHTCYAN })
                table.insert(content, ", ")
            end
            table.insert(content, { text = pos_info.description, pen = COLOR_WHITE })
            if pos_info.world_name and not pos_info.description:match("world$") then
                table.insert(content, " of ")
                table.insert(content, { text = pos_info.world_name, pen = COLOR_LIGHTCYAN })
            end
            table.insert(content, ".\n")

            -- Build a descriptive paragraph about the area
            local desc_parts = {}
            if pos_info.continent then
                table.insert(desc_parts, "The surrounding region is part of " .. pos_info.continent)
            end
            local rt = pos_info.region_type or ""
            if rt ~= "" then
                local biome_adj = rt:lower()
                if biome_adj == "swamp" or biome_adj == "marsh" then
                    if pos_info.vegetation and pos_info.vegetation > 70 then
                        biome_adj = "densely forested swampland"
                    else
                        biome_adj = "swampland"
                    end
                elseif biome_adj == "mountains" then biome_adj = "mountainous area"
                elseif biome_adj == "glacier" then biome_adj = "glacial expanse"
                elseif biome_adj == "tundra" then biome_adj = "tundra"
                elseif biome_adj == "grassland" then biome_adj = "grassland"
                elseif biome_adj == "hills" then biome_adj = "hills"
                elseif biome_adj == "lake" then biome_adj = "lakeside area"
                elseif biome_adj == "ocean" then biome_adj = "coastal area"
                elseif biome_adj == "forest" then biome_adj = "forested area"
                end
                table.insert(desc_parts, "a " .. biome_adj)
            end
            if pos_info.temperature then
                local t = pos_info.temperature:lower()
                local temp_word = t:match("^[^,]+") or t
                table.insert(desc_parts, "with a " .. temp_word .. " climate")
            end
            if pos_info.vegetation_desc then
                table.insert(desc_parts, pos_info.vegetation_desc)
            end
            if pos_info.nearby_volcano then
                table.insert(desc_parts, "built atop the volcano " .. pos_info.nearby_volcano)
            end
            local rivers = pos_info.nearby_rivers or {}
            if #rivers > 0 then
                local river_text
                if #rivers == 1 then
                    river_text = "along the banks of " .. rivers[1]
                elseif #rivers == 2 then
                    river_text = "at the confluence of " .. rivers[1] .. " and " .. rivers[2]
                else
                    local parts = {}
                    for i = 1, #rivers - 1 do
                        table.insert(parts, rivers[i])
                    end
                    river_text = "at the confluence of " .. table.concat(parts, ", ") .. ", and " .. rivers[#rivers]
                end
                table.insert(desc_parts, river_text)
            end

            if #desc_parts > 0 then
                table.insert(content, "\n")
                local line = cap(desc_parts[1])
                for i = 2, #desc_parts do
                    if i == #desc_parts then
                        line = line .. ", and " .. desc_parts[i]
                    else
                        line = line .. ", " .. desc_parts[i]
                    end
                end
                line = line .. "."
                table.insert(content, { text = line, pen = COLOR_WHITE })
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
