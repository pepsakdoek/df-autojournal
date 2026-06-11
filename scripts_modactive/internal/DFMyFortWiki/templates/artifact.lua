--@ module = true
local utils = reqscript('internal/DFMyFortWiki/utils')

local function get_artifact_template(item)
    local name = utils.sanitize(dfhack.items.getReadableDescription(item))
    local itype = item:getType()
    local type_name = tostring(df.item_type[itype]):gsub("_", " "):lower():gsub("^%l", string.upper)
    
    local art_ref = dfhack.items.getGeneralRef(item, df.general_ref_type.ARTIFACT)
    local artifact_record = nil
    if art_ref then
        artifact_record = df.artifact_record.find(art_ref.artifact_id)
    end

    local content = "# " .. name .. "\n\n"
    content = content .. "**Type:** " .. type_name .. "\n"
    
    if artifact_record then
        content = content .. "**Artifact ID:** " .. tostring(artifact_record.id) .. "\n"
    end
    
    -- Value
    local value = dfhack.items.getValue(item)
    content = content .. "**Estimated Value:** " .. tostring(value) .. "☼\n\n"

    content = content .. "## Description\n"
    local long_desc = utils.sanitize(dfhack.items.getDescription(item, 0))
    content = content .. long_desc .. "\n\n"

    content = content .. "## History\n"
    -- Try to find creator
    local creator_link = nil
    if artifact_record then
        for _, event_id in ipairs(artifact_record.events) do
            -- This is too deep to parse all events here, but usually creator is in world history
        end
        -- Simpler: check item creators
        local creator_ref = dfhack.items.getGeneralRef(item, df.general_ref_type.UNIT_CREATOR)
        if creator_ref then
            local unit = df.unit.find(creator_ref.unit_id)
            if unit then
                local unit_name = utils.sanitize(dfhack.units.getReadableName(unit))
                creator_link = "[" .. unit_name .. "](citizen:" .. tostring(unit.id) .. ")"
            end
        end
    end

    if creator_link then
        content = content .. "Created by " .. creator_link .. ".\n"
    elseif artifact_record and artifact_record.name then
        content = content .. "Named " .. utils.sanitize(dfhack.df2utf(dfhack.TranslateName(artifact_record.name))) .. " by its creator.\n"
    end
    
    content = content .. "\n## Location & Holder\n"
    local pos = dfhack.items.getPosition(item)
    if pos then
        content = content .. "Location: (" .. pos.x .. ", " .. pos.y .. ", " .. pos.z .. ")\n"
    end

    return content
end

return get_artifact_template
