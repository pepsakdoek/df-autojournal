--@ module = true
local utils = reqscript('internal/DFMyFortWiki/utils')
local mfw_settings = reqscript('internal/DFMyFortWiki/settings')
local logger = reqscript('internal/DFMyFortWiki/logger')

local function get_civ_template()
    local content = ""
    local ok, err = xpcall(function()
        local settings = mfw_settings.get_settings().civ
        local civ_id = df.global.ui.civ_id
        local civ = df.historical_entity.find(civ_id)
        local civ_name = "Unknown Civilization"
        if civ then
            civ_name = utils.sanitize(dfhack.df2utf(dfhack.TranslateName(civ.name)))
        end

        content = "# Civilization: " .. civ_name .. "\n\n"
        
        if civ then
            content = content .. "**Type:** " .. tostring(df.historical_entity_type[civ.type]) .. "\n"
            
            if settings.leadership then
                content = content .. "\n## Hierarchy & Leadership\n"
                -- Find the monarch/leaders
                local found_leader = false
                if civ.positions and civ.positions.assignments then
                    for _, assignment in ipairs(civ.positions.assignments) do
                        local position = civ.positions.own[assignment.position_id]
                        if position and (position.responsibilities.DETERMINE_GOVERNMENT_TYPE or position.name == "monarch") then
                            if assignment.histfig_id ~= -1 then
                                local hf = df.historical_figure.find(assignment.histfig_id)
                                if hf then
                                    local leader_name = utils.sanitize(dfhack.df2utf(dfhack.TranslateName(hf.name)))
                                    content = content .. "* " .. position.name .. ": " .. leader_name .. "\n"
                                    found_leader = true
                                end
                            end
                        end
                    end
                end
                if not found_leader then
                    content = content .. "No clear leader identified in current records.\n"
                end
            end

            if (settings.relations or settings.wars) and civ.relations then
                content = content .. "\n## Diplomatic Relations\n"
                -- Parse relations
                for _, rel in ipairs(civ.relations) do
                    local other_civ = df.historical_entity.find(rel.entity_id)
                    if other_civ and other_civ.type == df.historical_entity_type.Civilization then
                        local other_name = utils.sanitize(dfhack.df2utf(dfhack.TranslateName(other_civ.name)))
                        local rel_type = "Neutral"
                        if rel.relation == df.entity_relation_type.War then
                            rel_type = "WAR"
                        elseif rel.relation == df.entity_relation_type.Peace then
                            rel_type = "Peace"
                        end
                        
                        if (settings.wars and rel_type == "WAR") or settings.relations then
                            content = content .. "* " .. other_name .. ": " .. rel_type .. "\n"
                        end
                    end
                end
            end

            if settings.ethics then
                content = content .. "\n## Ethics & Values\n"
                content = content .. "*Describe the core beliefs of your civilization here.*\n"
            end
        end

        if settings.history then
            content = content .. "\n## Major History\n"
            content = content .. "*Record the founding and major events of the civilization.*\n"
        end
    end, function(err)
        return debug.traceback(err)
    end)

    if not ok then
        logger.log_error("Civ template Initialization failed: " .. tostring(err))
    end

    return content
end

return get_civ_template
