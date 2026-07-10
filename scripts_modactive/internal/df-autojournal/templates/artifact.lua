--@ module = true
local utils = reqscript('internal/df-autojournal/wiki_utils')
local mfw_settings = reqscript('internal/df-autojournal/wiki_settings')

local function describe_artifact_location(unit, site_name)
    if unit and dfhack.units.isCitizen(unit) then
        local uname = utils.sanitize(dfhack.units.getReadableName(unit))
        return { text = "Carried by " .. uname, pen = COLOR_LIGHTBLUE, link = "citizen:" .. tostring(unit.id) }
    elseif site_name then
        return { text = "Located in " .. site_name, pen = COLOR_LIGHTCYAN }
    end
    return nil
end

function render(item, artifact_record)
    local cfg = mfw_settings.get_settings().artifact
    local settings = cfg.init
    local journal = cfg.journal
    artifact_record = artifact_record or (function()
        local ref = dfhack.items.getGeneralRef(item, df.general_ref_type.ARTIFACT)
        return ref and df.artifact_record.find(ref.artifact_id) or nil
    end)()
    local short_desc = utils.sanitize(dfhack.items.getDescription(item, 1))
    local art_name = artifact_record and artifact_record.name and utils.get_readable_name(artifact_record.name) or ""
    local name = art_name ~= "" and art_name or (utils.sanitize(dfhack.items.getReadableDescription(item)):gsub('[%z\1-\31]', ''))
    local itype = item:getType()
    local type_name = tostring(df.item_type[itype]):gsub("_", " "):lower():gsub("^%l", string.upper)

    local material_name = "?"
    pcall(function()
        local m = dfhack.matinfo.decode(item.mat_type, item.mat_index)
        if m then material_name = m:toString() end
    end)

    local content = {}

    table.insert(content, { text = "# " .. name, pen = COLOR_YELLOW })
    table.insert(content, "\n\n")

    -- Richer header line
    table.insert(content, "This is a ")
    table.insert(content, { text = short_desc, pen = COLOR_LIGHTCYAN })
    table.insert(content, ".\n")

    if settings.description then
        local long_desc = utils.sanitize(dfhack.items.getDescription(item, 0))
        if long_desc and long_desc ~= "" and long_desc ~= short_desc then
            table.insert(content, "\n")
            table.insert(content, { text = "## Description", pen = COLOR_YELLOW })
            table.insert(content, "\n")
            table.insert(content, { text = long_desc, pen = COLOR_WHITE })
            table.insert(content, "\n\n")
        end
    end

    if settings.history then
        table.insert(content, { text = "## History", pen = COLOR_YELLOW })
        table.insert(content, "\n")

        local creator_link = nil
        local creator_name = nil
        if artifact_record and settings.creator then
            local ok, maker_id = pcall(function() return item.maker end)
            if ok and maker_id and maker_id > 0 then
                local hf = df.historical_figure.find(maker_id)
                if hf then
                    creator_name = utils.get_readable_name(hf.name)
                    if hf.unit_id and hf.unit_id > 0 then
                        local unit = df.unit.find(hf.unit_id)
                        if unit and dfhack.units.isCitizen(unit) then
                            creator_link = {
                                text = creator_name,
                                pen = COLOR_LIGHTBLUE,
                                link = "citizen:" .. tostring(hf.unit_id)
                            }
                        end
                    end
                end
            end
        end

        local year_info = ""
        if artifact_record and artifact_record.year and artifact_record.year > 0 then
            local age = df.global.cur_year - artifact_record.year
            year_info = " in year " .. tostring(artifact_record.year) .. " (" .. tostring(age) .. " years ago)"
        end

        if creator_name and year_info ~= "" then
            table.insert(content, "Created by ")
            if creator_link then
                table.insert(content, creator_link)
            else
                table.insert(content, { text = creator_name, pen = COLOR_WHITE })
            end
            table.insert(content, year_info)
            table.insert(content, ".\n")
        elseif creator_name then
            table.insert(content, "Created by ")
            if creator_link then
                table.insert(content, creator_link)
            else
                table.insert(content, { text = creator_name, pen = COLOR_WHITE })
            end
            table.insert(content, ".\n")
        elseif year_info ~= "" then
            table.insert(content, "Created")
            table.insert(content, year_info)
            table.insert(content, " by an unknown hand.\n")
        else
            table.insert(content, "Created by an unknown hand in an unknown year.\n")
        end
    end

    if settings.location then
        table.insert(content, "\n")
        table.insert(content, { text = "## Location & Status", pen = COLOR_YELLOW })
        table.insert(content, "\n")

        local holder_unit = nil
        if artifact_record and artifact_record.holder_hf and artifact_record.holder_hf >= 0 then
            local hf = df.historical_figure.find(artifact_record.holder_hf)
            if hf and hf.unit_id and hf.unit_id >= 0 then
                holder_unit = df.unit.find(hf.unit_id)
            end
        end

        local pos = item.pos
        if pos and pos.x ~= -30000 then
            local holder_desc = describe_artifact_location(holder_unit, nil)
            if holder_desc then
                table.insert(content, holder_desc)
            else
                table.insert(content, { text = "Housed in the fortress.", pen = COLOR_WHITE })
            end
        elseif artifact_record and artifact_record.abs_tile_x and artifact_record.abs_tile_x ~= -1000000 then
            local site = artifact_record.site >= 0 and df.world_site.find(artifact_record.site)
            if site then
                local sname = utils.get_readable_name(site.name)
                table.insert(content, { text = "Located in " .. sname .. ".", pen = COLOR_WHITE })
            else
                table.insert(content, { text = "Its current whereabouts are unknown.", pen = COLOR_DARKGREY })
            end
        else
            table.insert(content, { text = "Its current whereabouts are unknown.", pen = COLOR_DARKGREY })
        end
        table.insert(content, "\n")
    end

    if journal and journal.decorations and item.improvements and #item.improvements > 0 then
        table.insert(content, "\n")
        table.insert(content, { text = "## Decorations", pen = COLOR_YELLOW })
        table.insert(content, "\n")
        for j = 0, math.min(#item.improvements, 10) - 1 do
            local imp = item.improvements[j]
            local imp_type = tostring(df.improvement_type[imp:getType()] or "Unknown"):gsub("_", " "):lower()
            local imp_mat = "?"
            pcall(function()
                local m = dfhack.matinfo.decode(imp.mat_type, imp.mat_index)
                if m then imp_mat = m:toString() end
            end)
            local line = "* It is " .. imp_type .. " in " .. imp_mat .. ".\n"
            table.insert(content, line)
        end
    end

    return utils.sanitize_content(content)
end

return _ENV
