--@ module = true
local utils = reqscript('internal/df-autojournal/wiki_utils')
local mfw_settings = reqscript('internal/df-autojournal/wiki_settings')
local logger = reqscript('internal/df-autojournal/logger')

--- Build a table of sites currently settled by the civilization.
--- Checks entity_site_link type == 0 to confirm active ownership.
--- known_fort_set: optional set of { [site_id] = true }
local function get_forts_table(civ, known_fort_set)
    if not civ then return nil end
    local world_data = df.global.world.world_data
    if not world_data or not world_data.sites then return nil end
    local current_site_id = df.global.plotinfo.site_id
    local civ_id = civ.id

    local rows = {}
    for _, site in ipairs(world_data.sites) do
        if site then
            local owns = false
            if site.entity_links then
                for _, link in ipairs(site.entity_links) do
                    if link.entity_id == civ_id and link.type == 0 then
                        owns = true
                        break
                    end
                end
            end
            if not owns then goto continue end
            local is_player = (site.id == current_site_id)
            local site_type = tostring(df.world_site_type[site.type] or "Unknown")
            local name = utils.get_readable_name(site.name)
            if name and name ~= "" then
                local type_pen = COLOR_WHITE
                local lower_type = site_type:lower()
                if lower_type:match("fortress") then
                    type_pen = COLOR_LIGHTBLUE
                elseif lower_type:match("mountain") or lower_type:match("hall") then
                    type_pen = COLOR_LIGHTCYAN
                elseif lower_type:match("dark") or lower_type:match("pit") then
                    type_pen = COLOR_LIGHTRED
                elseif lower_type:match("forest") or lower_type:match("retreat") then
                    type_pen = COLOR_GREEN
                elseif lower_type:match("town") or lower_type:match("city") then
                    type_pen = COLOR_LIGHTCYAN
                elseif lower_type:match("hamlet") then
                    type_pen = COLOR_DARKGREY
                end

                local has_page = known_fort_set and known_fort_set[site.id]
                local row = {
                    { text = name, pen = is_player and COLOR_LIGHTGREEN or (has_page and COLOR_WHITE or COLOR_DARKGREY), link = has_page and "fort:" .. tostring(site.id) or nil },
                    { text = site_type, pen = type_pen },
                }

                if is_player then
                    table.insert(row, { text = "Yes", pen = COLOR_GREEN })
                else
                    table.insert(row, { text = "", pen = COLOR_DARKGREY })
                end

                table.insert(row, { text = "", pen = COLOR_DARKGREY })
                table.insert(rows, { row = row, is_player = is_player, name = name })
            end
            ::continue::
        end
    end

    -- Sort: player fort first, then alphabetically
    table.sort(rows, function(a, b)
        if a.is_player ~= b.is_player then
            return a.is_player
        end
        return (a.name or "") < (b.name or "")
    end)

    local result = {}
    for _, entry in ipairs(rows) do
        table.insert(result, entry.row)
    end
    return result
end

local function get_civ_population(civ_id)
    local total = 0
    pcall(function()
        local pops = df.global.world.entity_populations
        if not pops then return end
        for i = 0, #pops - 1 do
            local pop = pops[i]
            if pop.civ_id == civ_id then
                for j = 0, #pop.counts - 1 do
                    total = total + pop.counts[j]
                end
            end
        end
    end)
    return total
end

function render(civ_id, known_fort_set)
    local ok, result = xpcall(function()
        local cfg = mfw_settings.get_settings().civ
        local settings = cfg.init
        civ_id = civ_id or utils.get_civ_id()
        local civ = df.historical_entity.find(civ_id)
        local civ_name = "Unknown Civilization"
        if civ then
            civ_name = utils.get_readable_name(civ.name)
        end

        local content = {}

        table.insert(content, { text = "# Civilization: " .. civ_name, pen = COLOR_YELLOW })
        table.insert(content, "\n\n")

        if civ then
            local race_name = ""
            pcall(function()
                if civ.race then
                    local raw = df.creature_raw.find(civ.race)
                    if raw and raw.name then
                        race_name = utils.sanitize(raw.name[0]) or ""
                        if race_name ~= "" then
                            race_name = race_name:sub(1, 1):upper() .. race_name:sub(2)
                        end
                    end
                end
            end)

            table.insert(content, { text = "Type: ", pen = COLOR_LIGHTCYAN })
            local type_str = tostring(df.historical_entity_type[civ.type] or "Unknown")
            if race_name ~= "" then
                table.insert(content, { text = race_name .. " " .. type_str, pen = COLOR_WHITE })
            else
                table.insert(content, { text = type_str, pen = COLOR_WHITE })
            end
            table.insert(content, "\n")

            -- Total population (live via function block)
            table.insert(content, { text = "Total Population: ", pen = COLOR_LIGHTCYAN })
            table.insert(content, { type = 'function', fn_key = 'civ_population', args = { civ_id = civ_id } })
            table.insert(content, "\n")

            -- Ruler(s)
            if settings.leadership then
                pcall(function()
                    if civ.positions and civ.positions.assignments then
                        local function get_position_name(pos_id)
                            if civ.positions.own then
                                for _, p in ipairs(civ.positions.own) do
                                    if p.id == pos_id then
                                        local ok, pname = pcall(utils.sanitize, p.name and p.name[0] or '')
                                        if ok and pname and pname ~= '' then return pname end
                                    end
                                end
                            end
                            return nil
                        end

                        local function to_camel_case(s)
                            if not s or s == '' then return nil end
                            local words = {}
                            for w in s:gmatch('%S+') do
                                table.insert(words, w:sub(1, 1):upper() .. w:sub(2):lower())
                            end
                            return table.concat(words, ' ')
                        end

                        local function make_ruler_link(hf)
                            if hf.unit_id and hf.unit_id ~= -1 then
                                return "citizen:" .. tostring(hf.unit_id)
                            end
                            return nil
                        end

                        -- Find monarch (position ID 0) first
                        local monarch = nil
                        for _, assign in ipairs(civ.positions.assignments) do
                            if assign.position_id == 0 and assign.histfig ~= -1 then
                                monarch = df.historical_figure.find(assign.histfig)
                                break
                            end
                        end

                        if monarch and monarch.name then
                            local name = utils.get_readable_name(monarch.name)
                            local link = make_ruler_link(monarch)
                            table.insert(content, { text = "Ruler: ", pen = COLOR_LIGHTCYAN })
                            if link then
                                table.insert(content, { text = name, pen = COLOR_LIGHTBLUE, link = link })
                            else
                                table.insert(content, { text = name, pen = COLOR_WHITE })
                            end
                            table.insert(content, "\n")
                        end

                        -- Collect other royalty for table (max 10)
                        local royal_rows = {}
                        for _, assign in ipairs(civ.positions.assignments) do
                            if assign.position_id ~= 0 and assign.histfig ~= -1 then
                                local hf = df.historical_figure.find(assign.histfig)
                                if hf and hf.name then
                                    local name = utils.get_readable_name(hf.name)
                                    local link = make_ruler_link(hf)
                                    local title = to_camel_case(get_position_name(assign.position_id)) or "Leader"
                                    table.insert(royal_rows, {
                                        { text = title, pen = COLOR_WHITE },
                                        { text = name, pen = link and COLOR_LIGHTBLUE or COLOR_WHITE, link = link },
                                    })
                                    if #royal_rows >= 10 then break end
                                end
                            end
                        end
                        if #royal_rows > 0 then
                            table.insert(content, "\n")
                            table.insert(content, {
                                type = 'table',
                                columns = {
                                    { header = 'Title', align = 'left', min_width = 15, stretch = true },
                                    { header = 'Name', align = 'left', min_width = 20, stretch = true },
                                },
                                rows = royal_rows,
                                max_rows = 10,
                            })
                            table.insert(content, "\n")
                        end
                    end
                end)
            end

            -- World position
            if settings.position then
                local pos = utils.describe_world_position(civ)
                table.insert(content, "\n")
                table.insert(content, { text = "## World Position", pen = COLOR_YELLOW })
                table.insert(content, "\n")
                if pos then
                    table.insert(content, { text = civ_name, pen = COLOR_LIGHTBLUE })
                    if pos.description:match("^scattered") then
                        table.insert(content, " is ")
                        table.insert(content, { text = pos.description, pen = COLOR_WHITE })
                        table.insert(content, " of ")
                        table.insert(content, { text = pos.world_name, pen = COLOR_LIGHTCYAN })
                    elseif pos.description:match("^the entire") then
                        table.insert(content, " spans ")
                        table.insert(content, { text = pos.description, pen = COLOR_WHITE })
                    else
                        table.insert(content, " is located in ")
                        table.insert(content, { text = pos.description, pen = COLOR_WHITE })
                        if not pos.description:match("world$") then
                            table.insert(content, " of ")
                            table.insert(content, { text = pos.world_name, pen = COLOR_LIGHTCYAN })
                        end
                    end
                    if pos.continent and #pos.continent > 0 then
                        table.insert(content, #pos.continent > 1 and ", on the continents of " or ", on the continent of ")
                        local cont_names = {}
                        for i, cname in ipairs(pos.continent) do
                            cont_names[i] = { text = cname, pen = COLOR_LIGHTCYAN }
                        end
                        if #cont_names == 1 then
                            table.insert(content, cont_names[1])
                        else
                            for i, cn in ipairs(cont_names) do
                                if i > 1 then
                                    table.insert(content, i < #cont_names and ", " or " and ")
                                end
                                table.insert(content, cn)
                            end
                        end
                    end
                    if pos.site_count and pos.site_count > 0 then
                        table.insert(content, " (")
                        table.insert(content, { text = tostring(pos.site_count), pen = COLOR_WHITE })
                        table.insert(content, " settlement" .. (pos.site_count ~= 1 and "s" or "") .. ")")
                    end
                    table.insert(content, ".\n")
                else
                    table.insert(content, { text = "Settled across the world.", pen = COLOR_GREY })
                    table.insert(content, "\n")
                end
            end

            -- Forts table
            if settings.forts then
                table.insert(content, "\n")
                table.insert(content, { text = "## Settlements & Forts", pen = COLOR_YELLOW })
                table.insert(content, "\n")
                local fort_rows = get_forts_table(civ, known_fort_set)
                if fort_rows and #fort_rows > 0 then
                    table.insert(content, {
                        type = 'table',
                        columns = {
                            { header = 'Name', align = 'left', min_width = 20, stretch = true },
                            { header = 'Type', align = 'left', min_width = 10, stretch = false },
                            { header = 'Active Fort', align = 'left', min_width = 8, stretch = false },
                            { header = 'Notes', align = 'left', min_width = 10, stretch = true },
                        },
                        rows = fort_rows,
                        max_rows = 50,
                    })
                    table.insert(content, "\n")
                    table.insert(content, { text = "Active Fort ", pen = COLOR_DARKGREY })
                    table.insert(content, { text = "indicates your current fortress.", pen = COLOR_GREEN })
                    table.insert(content, "\n")
                else
                    table.insert(content, { text = "No settlements recorded.", pen = COLOR_DARKGREY })
                    table.insert(content, "\n")
                end
            end

            if settings.religion then
                pcall(function()
                    local has_religion = false
                    local rels = civ.relations
                    if rels then
                        -- Single pass: count deity followers + religion members for all civ units
                        local deity_counts = {}
                        local rel_members = {}
                        local all_units = df.global.world.units.all
                        if all_units then
                            for i = 0, #all_units - 1 do
                                local u = all_units[i]
                                if u and u.civ_id == civ.id then
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

                        -- Build deity_id -> religion info, and find religion entities linked through sites
                        local deity_religions = {}
                        local religion_entities = {}
                        local world_data = df.global.world.world_data
                        if world_data and world_data.sites then
                            for _, site in ipairs(world_data.sites) do
                                if site and site.entity_links then
                                    for _, link in ipairs(site.entity_links) do
                                        if link.entity_id == civ.id then
                                            for _, slink in ipairs(site.entity_links) do
                                                local ee = df.historical_entity.find(slink.entity_id)
                                                if ee and ee.type == df.historical_entity_type.Religion
                                                        and not religion_entities[ee.id] then
                                                    local d_names = {}
                                                    if ee.relations and ee.relations.deities then
                                                        for j = 0, #ee.relations.deities - 1 do
                                                            local hf = df.historical_figure.find(ee.relations.deities[j])
                                                            if hf and hf.name then
                                                                local dname = utils.get_readable_name(hf.name)
                                                                table.insert(d_names, dname)
                                                                deity_religions[ee.relations.deities[j]] =
                                                                    deity_religions[ee.relations.deities[j]] or
                                                                    {name = dname, followers = rel_members[ee.id] or 0}
                                                            end
                                                        end
                                                    end
                                                    religion_entities[ee.id] = {
                                                        name = utils.get_readable_name(ee.name),
                                                        deity_names = d_names,
                                                        followers = rel_members[ee.id] or 0,
                                                    }
                                                end
                                            end
                                            break
                                        end
                                    end
                                end
                            end
                        end

                        -- Spheres from entity_raw
                        local spheres = civ.entity_raw and civ.entity_raw.religion_sphere
                        if spheres and #spheres > 0 then
                            if not has_religion then
                                table.insert(content, "\n")
                                table.insert(content, { text = "## Major Gods & Religions", pen = COLOR_YELLOW })
                                table.insert(content, "\n")
                                has_religion = true
                            end
                            table.insert(content, { text = "Spheres: ", pen = COLOR_LIGHTCYAN })
                            local sphere_names = {}
                            for i = 0, #spheres - 1 do
                                local sname = pcall(function() return df.sphere_type[spheres[i]] end) and df.sphere_type[spheres[i]] or tostring(spheres[i])
                                if sname then
                                    table.insert(sphere_names, { text = sname:gsub("_", " "):lower():gsub("^%l", string.upper), pen = COLOR_WHITE })
                                end
                            end
                            for i, sn in ipairs(sphere_names) do
                                if i > 1 then table.insert(content, ", ") end
                                table.insert(content, sn)
                            end
                            table.insert(content, "\n\n")
                        end

                        -- Deities
                        local deities = rels.deities
                        if deities and #deities > 0 then
                            if not has_religion then
                                table.insert(content, "\n")
                                table.insert(content, { text = "## Major Gods & Religions", pen = COLOR_YELLOW })
                                table.insert(content, "\n")
                                has_religion = true
                            end
                            table.insert(content, { text = "### Deities", pen = COLOR_YELLOW })
                            table.insert(content, "\n")
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
                                    local follower_text = tostring(follower_count)
                                    table.insert(deity_rows, {
                                        { text = dname, pen = COLOR_LIGHTBLUE },
                                        { text = spheres_text, pen = COLOR_WHITE },
                                        { text = favor_text, pen = favor_pen },
                                        { text = follower_text, pen = COLOR_WHITE },
                                    })
                                end
                            end
                            if #deity_rows > 0 then
                                table.insert(content, {
                                    type = 'table',
                                    columns = {
                                        { header = 'Deity', align = 'left', min_width = 20, stretch = true },
                                        { header = 'Spheres', align = 'left', min_width = 20, stretch = true },
                                        { header = 'Favor', align = 'left', min_width = 20, stretch = false },
                                        { header = 'Followers', align = 'left', min_width = 10, stretch = false },
                                    },
                                    rows = deity_rows,
                                    max_rows = 20,
                                })
                                table.insert(content, "\n")
                            end
                        end

                        local rel_ids = {}
                        for id, _ in pairs(religion_entities) do
                            table.insert(rel_ids, id)
                        end
                        table.sort(rel_ids)
                        if #rel_ids > 0 then
                            if not has_religion then
                                table.insert(content, "\n")
                                table.insert(content, { text = "## Major Gods & Religions", pen = COLOR_YELLOW })
                                table.insert(content, "\n")
                                has_religion = true
                            end
                            table.insert(content, { text = "### Religious Organizations", pen = COLOR_YELLOW })
                            table.insert(content, "\n")
                            local org_rows = {}
                            for _, id in ipairs(rel_ids) do
                                local info = religion_entities[id]
                                local deities_text = #info.deity_names > 0 and table.concat(info.deity_names, ', ') or 'None'
                                table.insert(org_rows, {
                                    { text = info.name, pen = COLOR_LIGHTBLUE, link = "religion:" .. tostring(id) },
                                    { text = tostring(info.followers) .. " followers", pen = COLOR_WHITE },
                                    { text = deities_text, pen = COLOR_WHITE },
                                })
                            end
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
                    end
                end)
            end

            if (settings.relations or settings.wars) and civ.relations then
                table.insert(content, "\n")
                table.insert(content, { text = "## Diplomatic Relations", pen = COLOR_YELLOW })
                table.insert(content, "\n")
                local found = false
                pcall(function()
                    local dip = civ.relations.diplomacy
                    if dip and dip.state then
                        for i = 0, #dip.state - 1 do
                            local s = dip.state[i]
                            local other_entity = df.historical_entity.find(s.group_id)
                            if other_entity and other_entity.type == df.historical_entity_type.Civilization
                                    and other_entity.id ~= civ.id then
                                local other_name = utils.get_readable_name(other_entity.name)
                                local is_war = (s.war_event_collection ~= -1)
                                local is_peace = (s.war_event_collection == -1)

                                if (settings.wars and is_war) or (settings.relations and is_peace) then
                                    table.insert(content, "* ")
                                    if is_war then
                                        table.insert(content, { text = civ_name, pen = COLOR_LIGHTBLUE, link = "civ:" .. tostring(civ.id) })
                                        table.insert(content, " are at war with ")
                                        table.insert(content, { text = other_name, pen = COLOR_LIGHTRED, link = "civ:" .. tostring(other_entity.id) })
                                    else
                                        table.insert(content, { text = civ_name, pen = COLOR_LIGHTBLUE, link = "civ:" .. tostring(civ.id) })
                                        table.insert(content, " are at peace with ")
                                        table.insert(content, { text = other_name, pen = COLOR_LIGHTGREEN, link = "civ:" .. tostring(other_entity.id) })
                                    end
                                    table.insert(content, "\n")
                                    found = true
                                end
                            end
                        end
                    end
                end)
                if not found then
                    table.insert(content, { text = "No diplomatic relations recorded.", pen = COLOR_DARKGREY })
                    table.insert(content, "\n")
                end
            end

            if settings.ethics then
                table.insert(content, "\n")
                table.insert(content, { text = "## Ethics & Values", pen = COLOR_YELLOW })
                table.insert(content, "\n")

                -- Core Values from entity_raw
                local strong_values = {}
                local despised_values = {}
                pcall(function()
                    local er = civ.entity_raw
                    if er and er.values then
                        for i = 0, #er.values - 1 do
                            local v = er.values[i]
                            if math.abs(v) >= 15 then
                                local ok, vname = pcall(function() return df.value_type[i] end)
                                if ok and vname then
                                    local label = vname:gsub("_", " "):lower():gsub("^%l", string.upper)
                                    if v > 0 then
                                        table.insert(strong_values, label)
                                    else
                                        table.insert(despised_values, label)
                                    end
                                end
                            end
                        end
                    end
                end)

                if #strong_values > 0 then
                    table.insert(content, { text = "### Core Values", pen = COLOR_YELLOW })
                    table.insert(content, "\n")
                    for _, val in ipairs(strong_values) do
                        table.insert(content, "* " .. val .. "\n")
                    end
                    table.insert(content, "\n")
                end

                if #despised_values > 0 then
                    table.insert(content, { text = "### Despised", pen = COLOR_YELLOW })
                    table.insert(content, "\n")
                    for _, val in ipairs(despised_values) do
                        table.insert(content, "* " .. val .. "\n")
                    end
                    table.insert(content, "\n")
                end

                -- Ethics from entity_raw
                local ethic_rows = {}
                pcall(function()
                    local er = civ.entity_raw
                    if er and er.ethic then
                        for i = 0, #er.ethic - 1 do
                            local resp = er.ethic[i]
                            if resp ~= 0 then
                                local ok, ename = pcall(function() return df.ethic_type[i] end)
                                local ok2, rname = pcall(function() return df.ethic_response[resp] end)
                                if ok and ok2 and ename and rname then
                                    local label = ename:gsub("_", " "):lower():gsub("^%l", string.upper)
                                    local resp_label = rname:gsub("_", " "):lower():gsub("^%l", string.upper)
                                    local resp_pen = COLOR_WHITE
                                    if rname == "UNTHINKABLE" or rname == "APPALLING" then
                                        resp_pen = COLOR_LIGHTRED
                                    elseif rname == "ACCEPTABLE" then
                                        resp_pen = COLOR_LIGHTGREEN
                                    elseif rname:match("PUNISH") then
                                        resp_pen = COLOR_YELLOW
                                    end
                                    table.insert(ethic_rows, {
                                        { text = label, pen = COLOR_WHITE },
                                        { text = resp_label, pen = resp_pen },
                                    })
                                end
                            end
                        end
                    end
                end)

                if #ethic_rows > 0 then
                    table.insert(content, { text = "### Ethics", pen = COLOR_YELLOW })
                    table.insert(content, "\n")
                    table.insert(content, {
                        type = 'table',
                        columns = {
                            { header = 'Topic', align = 'left', min_width = 25, stretch = true },
                            { header = 'Stance', align = 'left', min_width = 30, stretch = true },
                        },
                        rows = ethic_rows,
                        max_rows = 30,
                    })
                    table.insert(content, "\n")
                end
            end
        end

        if settings.history then
            table.insert(content, "\n")
            table.insert(content, { text = "## Major History", pen = COLOR_YELLOW })
            table.insert(content, "\n")
            table.insert(content, { text = "Record the founding and major events of the civilization.", pen = COLOR_DARKGREY })
            table.insert(content, "\n")
        end

        return content
    end, function(err)
        return debug.traceback(err)
    end)

    if not ok then
        logger.log_error("Civ template initialization failed: " .. tostring(result))
        return "# Civilization\n\nError generating template.\n"
    end

    return result
end

return _ENV
