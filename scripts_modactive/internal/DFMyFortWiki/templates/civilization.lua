--@ module = true
local utils = reqscript('internal/DFMyFortWiki/utils')

local function get_civ_template()
    local civ_id = df.global.ui.civ_id
    local civ = df.historical_entity.find(civ_id)
    local civ_name = "Unknown Civilization"
    if civ then
        civ_name = utils.sanitize(dfhack.df2utf(dfhack.TranslateName(civ.name)))
    end

    local content = "# Civilization: " .. civ_name .. "\n\n"
    
    if civ then
        content = content .. "**Type:** " .. tostring(df.historical_entity_type[civ.type]) .. "\n"
        
        -- Find leaders (Position: MONARCH, etc.)
        content = content .. "## Hierarchy & Leadership\n"
        for _, pos in ipairs(civ.positions.own) do
            if pos.responsibilities.DETERMINE_GOVERNMENT_TYPE or pos.name == "monarch" then
                -- This is a bit complex to find who currently holds the position
                -- Simplification for now
                content = content .. "* " .. pos.name .. ": [To be determined]\n"
            end
        end
    end

    content = content .. "\n## Ethics & Values\n"
    content = content .. "*Describe the core beliefs of your civilization here.*\n\n"

    content = content .. "## Diplomatic Relations\n"
    content = content .. "*   **Elves:** Neutral\n"
    content = content .. "*   **Goblins:** WAR\n\n"

    content = content .. "## Major History\n"
    content = content .. "*Record the founding and major events of the civilization.*\n"

    return content
end

return get_civ_template
