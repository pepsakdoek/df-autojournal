--@ module = true
local utils = reqscript('internal/df-autojournal/wiki_utils')
local mfw_settings = reqscript('internal/df-autojournal/wiki_settings')
local logger = reqscript('internal/df-autojournal/logger')

local function find_position_by_id(civ, position_id)
    if not civ or not civ.positions or not civ.positions.own then return nil end
    for _, pos in ipairs(civ.positions.own) do
        if pos.id == position_id then
            return pos
        end
    end
    return nil
end



--- Build a table of sites belonging to the civilization.
local function get_forts_table(civ)
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
                    if link.entity_id == civ_id then
                        owns = true
                        break
                    end
                end
            end
            if not owns then goto continue end
            local is_player = (site.id == current_site_id)
            local site_type = tostring(df.world_site_type[site.type] or "Unknown")
            -- Only include fort/city type sites
            if site.type == df.world_site_type.Fortress or site.type == df.world_site_type.City then
                local name = utils.get_readable_name(site.name)
                if name and name ~= "" then
                    local type_pen = (site.type == df.world_site_type.Fortress) and COLOR_LIGHTBLUE or COLOR_LIGHTCYAN

                    local row = {
                        { text = name, pen = is_player and COLOR_LIGHTGREEN or COLOR_WHITE, link = is_player and "fort" or nil },
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

function render()
    local ok, result = xpcall(function()
        local cfg = mfw_settings.get_settings().civ
        local settings = cfg.init
        local civ_id = utils.get_civ_id()
        local civ = df.historical_entity.find(civ_id)
        local civ_name = "Unknown Civilization"
        if civ then
            civ_name = utils.get_readable_name(civ.name)
        end

        local content = {}

        table.insert(content, { text = "# Civilization: " .. civ_name, pen = COLOR_YELLOW })
        table.insert(content, "\n\n")

        if civ then
            table.insert(content, { text = "Type: ", pen = COLOR_LIGHTCYAN })
            table.insert(content, { text = tostring(df.historical_entity_type[civ.type]), pen = COLOR_WHITE })
            table.insert(content, "\n")

            -- World position
            if settings.position then
                local pos = utils.describe_world_position(civ)
                table.insert(content, "\n")
                table.insert(content, { text = "## World Position", pen = COLOR_YELLOW })
                table.insert(content, "\n")
                if pos then
                    table.insert(content, { text = civ_name, pen = COLOR_LIGHTBLUE })
                    table.insert(content, " is located in ")
                    table.insert(content, { text = pos.description, pen = COLOR_WHITE })
                    table.insert(content, " of ")
                    table.insert(content, { text = pos.world_name, pen = COLOR_LIGHTCYAN })
                    if pos.continent and #pos.continent > 0 then
                        table.insert(content, ", on the continent of ")
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
                local fort_rows = get_forts_table(civ)
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

            if (settings.relations or settings.wars) and civ.relations then
                table.insert(content, "\n")
                table.insert(content, { text = "## Diplomatic Relations", pen = COLOR_YELLOW })
                table.insert(content, "\n")
                local found = false
                for _, rel in ipairs(civ.relations) do
                    local other_civ = df.historical_entity.find(rel.entity_id)
                    if other_civ and other_civ.type == df.historical_entity_type.Civilization then
                        local other_name = utils.get_readable_name(other_civ.name)
                        local rel_type = "Neutral"
                        if rel.relation == df.entity_relation_type.War then
                            rel_type = "WAR"
                        elseif rel.relation == df.entity_relation_type.Peace then
                            rel_type = "Peace"
                        end

                        if (settings.wars and rel_type == "WAR") or settings.relations then
                            table.insert(content, "* ")
                            table.insert(content, { text = other_name, pen = COLOR_LIGHTBLUE, link = "civ:" .. tostring(other_civ.id) })
                            table.insert(content, ": ")
                            if rel_type == "WAR" then
                                table.insert(content, { text = rel_type, pen = COLOR_LIGHTRED })
                            else
                                table.insert(content, { text = rel_type, pen = COLOR_LIGHTGREEN })
                            end
                            table.insert(content, "\n")
                            found = true
                        end
                    end
                end
                if not found then
                    table.insert(content, { text = "No diplomatic relations recorded.", pen = COLOR_DARKGREY })
                    table.insert(content, "\n")
                end
            end

            if settings.ethics then
                table.insert(content, "\n")
                table.insert(content, { text = "## Ethics & Values", pen = COLOR_YELLOW })
                table.insert(content, "\n")
                table.insert(content, { text = "Describe the core beliefs of your civilization here.", pen = COLOR_DARKGREY })
                table.insert(content, "\n")
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
