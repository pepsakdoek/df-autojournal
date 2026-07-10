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

    if settings.religion then
        pcall(function()
            local site_id_actual = site_id or (site and site.id)
            if not site_id_actual then return end
            local civ_id = df.global.plotinfo and df.global.plotinfo.civ_id
            if not civ_id then return end
            local civ = df.historical_entity.find(civ_id)
            if not civ or not civ.relations then return end
            local rels = civ.relations

            local deity_counts = {}
            local rel_members = {}
            local all_units = df.global.world.units.all
            if all_units then
                for i = 0, #all_units - 1 do
                    local u = all_units[i]
                    if u and u.civ_id == civ_id then
                        local hf = df.historical_figure.find(u.hist_figure_id)
                        if hf then
                            if hf.histfig_links then
                                for _, link in ipairs(hf.histfig_links) do
                                    if df.histfig_hf_link_deityst and df.histfig_hf_link_deityst:is_instance(link) then
                                        deity_counts[link.target_hf] = (deity_counts[link.target_hf] or 0) + 1
                                    end
                                end
                            end
                            if hf.entity_links then
                                for _, l in ipairs(hf.entity_links) do
                                    local e = df.historical_entity.find(l.entity_id)
                                    if e and e.type == df.historical_entity_type.Religion then
                                        rel_members[l.entity_id] = (rel_members[l.entity_id] or 0) + 1
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- Gather locations from site abstract buildings (temples, shrines)
            local location_rows = {}
            pcall(function()
                local site = site_id_actual and df.world_site.find(site_id_actual)
                if site and site.buildings then
                    local locs = site.buildings
                    for i = 0, #locs - 1 do
                        local ab = locs[i]
                        if ab then
                            local ab_type = -1
                            pcall(function() ab_type = ab:getType() end)
                            if ab_type ~= df.abstract_building_type.TEMPLE then goto continue end
                            local name = ''
                            pcall(function()
                                name = dfhack.translation.translateName(ab.name, true)
                            end)
                            if name and name ~= '' then
                                local tier = -1
                                local val = 0
                                pcall(function()
                                    if ab.contents then
                                        tier = ab.contents.location_tier
                                        val = ab.contents.location_value
                                    end
                                end)
                                local deity_id = -1
                                pcall(function()
                                    deity_id = ab.deity_data.Deity
                                end)
                                local dname = ''
                                if deity_id >= 0 then
                                    local dhf = df.historical_figure.find(deity_id)
                                    if dhf then
                                        dname = utils.get_readable_name(dhf.name)
                                    end
                                end
                                local tier_name = tier == 0 and 'Shrine' or (tier == 1 and 'Temple' or (tier == 2 and 'Grand Temple' or ''))
                                local tier_pen = tier == 0 and COLOR_GREY or (tier == 1 and COLOR_WHITE or (tier == 2 and COLOR_YELLOW or COLOR_WHITE))
                                table.insert(location_rows, {
                                    { text = name, pen = tier_pen },
                                    { text = tier_name, pen = tier_pen },
                                    { text = tostring(val), pen = COLOR_WHITE },
                                    { text = dname ~= '' and dname or 'None', pen = dname ~= '' and COLOR_LIGHTBLUE or COLOR_GREY },
                                })
                            end
                            ::continue::
                        end
                    end
                end
            end)

            table.insert(content, "\n")
            table.insert(content, { text = "## Religion", pen = COLOR_YELLOW })
            table.insert(content, "\n")

            if location_rows and #location_rows > 0 then
                table.insert(content, { text = "### Temples & Shrines", pen = COLOR_YELLOW })
                table.insert(content, "\n")
                table.insert(content, {
                    type = 'table',
                    columns = {
                        { header = 'Name', align = 'left', min_width = 20, stretch = true },
                        { header = 'Type', align = 'left', min_width = 14, stretch = false },
                        { header = 'Value', align = 'left', min_width = 8, stretch = false },
                        { header = 'Deity', align = 'left', min_width = 20, stretch = true },
                    },
                    rows = location_rows,
                    max_rows = 25,
                })
                table.insert(content, "\n")
            end

            -- Deities followed by fort citizens
            local deities = rels.deities
            if deities and #deities > 0 then
                local deity_rows = {}
                for i = 0, #deities - 1 do
                    local hf = df.historical_figure.find(deities[i])
                    if hf and hf.name then
                        local dname = utils.get_readable_name(hf.name)
                        local spheres_list = {}
                        pcall(function()
                            local meta = hf.info and hf.info.metaphysical
                            if meta and meta.spheres then
                                for j = 0, #meta.spheres - 1 do
                                    local sn = df.sphere_type[meta.spheres[j]]
                                    if sn then
                                        table.insert(spheres_list, sn:sub(1, 1) .. sn:sub(2):lower())
                                    end
                                end
                            end
                        end)
                        local spheres_text = #spheres_list > 0 and table.concat(spheres_list, ', ') or ''
                        local favor_val = (i < #rels.worship) and rels.worship[i] or 0
                        local favor_text = tostring(favor_val)
                        local favor_pen = COLOR_GREY
                        if favor_val > 0 then
                            favor_pen = COLOR_LIGHTGREEN
                        elseif favor_val < 0 then
                            favor_pen = COLOR_LIGHTRED
                        end
                        local follower_count = deity_counts[deities[i]] or 0
                        table.insert(deity_rows, {
                            { text = dname, pen = COLOR_LIGHTBLUE },
                            { text = spheres_text, pen = COLOR_WHITE },
                            { text = favor_text, pen = favor_pen },
                            { text = tostring(follower_count), pen = COLOR_WHITE },
                        })
                    end
                end
                if #deity_rows > 0 then
                    table.insert(content, { text = "### Deities", pen = COLOR_YELLOW })
                    table.insert(content, "\n")
                    table.insert(content, {
                        type = 'table',
                        columns = {
                            { header = 'Deity', align = 'left', min_width = 20, stretch = true },
                            { header = 'Spheres', align = 'left', min_width = 20, stretch = true },
                            { header = 'Favor', align = 'left', min_width = 8, stretch = false },
                            { header = 'Followers', align = 'left', min_width = 10, stretch = false },
                        },
                        rows = deity_rows,
                        max_rows = 20,
                    })
                    table.insert(content, "\n")
                end
            end

            -- Religious organizations present at the fort
            local world_data = df.global.world.world_data
            local org_rows = {}
            if world_data and world_data.sites then
                for _, site in ipairs(world_data.sites) do
                    if site and site.entity_links then
                        for _, link in ipairs(site.entity_links) do
                            if link.entity_id == civ_id then
                                for _, slink in ipairs(site.entity_links) do
                                    local ee = df.historical_entity.find(slink.entity_id)
                                    if ee and ee.type == df.historical_entity_type.Religion then
                                        local d_names = {}
                                        if ee.relations and ee.relations.deities then
                                            for j = 0, #ee.relations.deities - 1 do
                                                local ef = df.historical_figure.find(ee.relations.deities[j])
                                                if ef and ef.name then
                                                    table.insert(d_names, utils.get_readable_name(ef.name))
                                                end
                                            end
                                        end
                                        local found = false
                                        for _, o in ipairs(org_rows) do
                                            if o[1].text == utils.get_readable_name(ee.name) then
                                                found = true; break
                                            end
                                        end
                                        if not found then
                                            table.insert(org_rows, {
                                                { text = utils.get_readable_name(ee.name), pen = COLOR_LIGHTBLUE, link = "religion:" .. tostring(ee.id) },
                                                { text = tostring(rel_members[ee.id] or 0) .. " followers", pen = COLOR_WHITE },
                                                { text = #d_names > 0 and table.concat(d_names, ', ') or 'None', pen = COLOR_WHITE },
                                            })
                                        end
                                    end
                                end
                                break
                            end
                        end
                    end
                end
            end
            if #org_rows > 0 then
                table.insert(content, { text = "### Religious Organizations", pen = COLOR_YELLOW })
                table.insert(content, "\n")
                table.insert(content, {
                    type = 'table',
                    columns = {
                        { header = 'Organization', align = 'left', min_width = 20, stretch = true },
                        { header = 'Followers', align = 'left', min_width = 12, stretch = false },
                        { header = 'Deities', align = 'left', min_width = 25, stretch = true },
                    },
                    rows = org_rows,
                    max_rows = 10,
                })
                table.insert(content, "\n")
            end
        end)
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
