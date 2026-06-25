--@ module = true
local utils = reqscript('internal/df-autojournal/wiki_utils')
local mfw_settings = reqscript('internal/df-autojournal/wiki_settings')

function render(unit)
    local cfg = mfw_settings.get_settings().citizen
    local settings = cfg.init
    local name = utils.sanitize(dfhack.units.getReadableName(unit))
    local prof = utils.sanitize(dfhack.units.getProfessionName(unit))
    local sex = "Unknown"
    if unit.sex == 0 then sex = "Female"
    elseif unit.sex == 1 then sex = "Male" end

    local content = {}

    table.insert(content, { text = "# " .. name, pen = COLOR_YELLOW })
    table.insert(content, "\n\n")

    table.insert(content, { text = "Profession: ", pen = COLOR_LIGHTCYAN })
    table.insert(content, { text = prof, pen = COLOR_WHITE })
    table.insert(content, "\n")

    table.insert(content, { text = "Gender: ", pen = COLOR_LIGHTCYAN })
    table.insert(content, { text = sex, pen = COLOR_WHITE })
    table.insert(content, "\n")

    table.insert(content, "\n")
    table.insert(content, { text = "## Personal Journal", pen = COLOR_YELLOW })
    table.insert(content, "\n")
    table.insert(content, { text = "Log your thoughts here...", pen = COLOR_DARKGREY })
    table.insert(content, "\n\n")

    if settings.values and unit.status.current_soul then
        local soul = unit.status.current_soul
        table.insert(content, { text = "## Attributes & Personality", pen = COLOR_YELLOW })
        table.insert(content, "\n")
        table.insert(content, { text = "### Values", pen = COLOR_YELLOW })
        table.insert(content, "\n")
        if soul.personality and soul.personality.values then
            local found_val = false
            for _, val in ipairs(soul.personality.values) do
                if math.abs(val.strength) > 10 then
                    table.insert(content, "* ")
                    local val_name = tostring(df.value_type[val.type]):gsub("_", " "):lower()
                    table.insert(content, { text = val_name, pen = COLOR_WHITE })
                    table.insert(content, "\n")
                    found_val = true
                end
            end
            if not found_val then
                table.insert(content, { text = "No strong values recorded.", pen = COLOR_DARKGREY })
                table.insert(content, "\n")
            end
        end
    end

    if settings.timeline then
        table.insert(content, "\n")
        table.insert(content, { text = "## History & Timeline", pen = COLOR_YELLOW })
        table.insert(content, "\n")
        table.insert(content, "* Arrived / Logged on ")
        table.insert(content, { text = utils.get_date_str(), pen = COLOR_WHITE })
        table.insert(content, "\n")
    end

    return utils.sanitize_content(content)
end

return _ENV
