--@ module = true
local utils = reqscript('internal/df-autojournal/wiki_utils')
local mfw_settings = reqscript('internal/df-autojournal/wiki_settings')

function render(item)
    local cfg = mfw_settings.get_settings().artifact
    local settings = cfg.init
    local name = utils.sanitize(dfhack.items.getReadableDescription(item))
    local itype = item:getType()
    local type_name = tostring(df.item_type[itype]):gsub("_", " "):lower():gsub("^%l", string.upper)

    local art_ref = dfhack.items.getGeneralRef(item, df.general_ref_type.ARTIFACT)
    local artifact_record = nil
    if art_ref then
        artifact_record = df.artifact_record.find(art_ref.artifact_id)
    end

    local content = {}

    table.insert(content, { text = "# " .. name, pen = COLOR_YELLOW })
    table.insert(content, "\n\n")

    table.insert(content, { text = "Type: ", pen = COLOR_LIGHTCYAN })
    table.insert(content, { text = type_name, pen = COLOR_WHITE })
    table.insert(content, "\n")

    if artifact_record then
        table.insert(content, { text = "Artifact ID: ", pen = COLOR_LIGHTCYAN })
        table.insert(content, { text = tostring(artifact_record.id), pen = COLOR_WHITE })
        table.insert(content, "\n")
    end

    local value = dfhack.items.getValue(item)
    table.insert(content, { text = "Estimated Value: ", pen = COLOR_LIGHTCYAN })
    table.insert(content, { text = tostring(value) .. ":registered:", pen = COLOR_LIGHTGREEN })
    table.insert(content, "\n\n")

    if settings.description then
        table.insert(content, { text = "## Description", pen = COLOR_YELLOW })
        table.insert(content, "\n")
        local long_desc = utils.sanitize(dfhack.items.getDescription(item, 0))
        table.insert(content, { text = long_desc, pen = COLOR_WHITE })
        table.insert(content, "\n\n")
    end

    if settings.history then
        table.insert(content, { text = "## History", pen = COLOR_YELLOW })
        table.insert(content, "\n")
        local creator_link = nil
        if artifact_record and settings.creator then
            local creator_ref = dfhack.items.getGeneralRef(item, df.general_ref_type.UNIT_CREATOR)
            if creator_ref then
                local unit = df.unit.find(creator_ref.unit_id)
                if unit then
                    local unit_name = utils.sanitize(dfhack.units.getReadableName(unit))
                    creator_link = {
                        text = unit_name,
                        pen = COLOR_LIGHTBLUE,
                        link = "citizen:" .. tostring(unit.id)
                    }
                end
            end
        end

        table.insert(content, "Created by ")
        if creator_link then
            table.insert(content, creator_link)
        elseif artifact_record and artifact_record.name then
            table.insert(content, { text = utils.get_readable_name(artifact_record.name), pen = COLOR_WHITE })
            table.insert(content, " by its creator")
        else
            table.insert(content, { text = "Unknown", pen = COLOR_DARKGREY })
        end
        table.insert(content, ".\n")
    end

    if settings.location then
        table.insert(content, "\n")
        table.insert(content, { text = "## Location & Holder", pen = COLOR_YELLOW })
        table.insert(content, "\n")
        local pos = dfhack.items.getPosition(item)
        if pos and type(pos) == 'table' then
            table.insert(content, { text = "Location: ", pen = COLOR_LIGHTCYAN })
            table.insert(content, { text = "(" .. pos.x .. ", " .. pos.y .. ", " .. pos.z .. ")", pen = COLOR_WHITE })
            table.insert(content, "\n")
        end
    end

    return utils.sanitize_content(content)
end

return _ENV
