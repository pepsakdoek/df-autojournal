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
