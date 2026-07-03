--@ module = true
-- World page template.
-- Renders a root page describing the world, its eras, and inhabited landmasses.

local utils = reqscript('internal/df-autojournal/wiki_utils')

--- Render the world page.
--- data: {
---   world_name: string (or nil),
---   current_year: int,
---   current_season: string (or nil),
---   eras: { year, name, is_current }[] (or nil),
---   landmasses: { name, known_civs, unknown_count, site_count }[] (or nil),
--- }
function render(data)
    data = data or {}
    local content = {}

    table.insert(content, { text = "# " .. (data.world_name and "World: " .. data.world_name or "World"), pen = COLOR_YELLOW })
    table.insert(content, "\n\n")

    -- Current date
    table.insert(content, { text = "Current Date: ", pen = COLOR_LIGHTCYAN })
    table.insert(content, { text = "Year " .. tostring(data.current_year or df.global.cur_year or 0), pen = COLOR_WHITE })
    if data.current_season and data.current_season ~= "" then
        table.insert(content, ", ")
        table.insert(content, { text = data.current_season, pen = COLOR_WHITE })
    end
    table.insert(content, "\n")

    -- Eras timeline
    local eras = data.eras
    if eras and #eras > 0 then
        table.insert(content, "\n")
        table.insert(content, { text = "## Ages of the World", pen = COLOR_YELLOW })
        table.insert(content, "\n")
        for _, era in ipairs(eras) do
            local line = "* Year " .. tostring(era.year or 0) .. " — " .. (era.name or "Unknown")
            table.insert(content, line .. (era.is_current and " (current era)" or "") .. "\n")
        end
    end

    -- Inhabited landmasses
    local landmasses = data.landmasses
    if landmasses and #landmasses > 0 then
        table.insert(content, "\n")
        table.insert(content, { text = "## Inhabited Regions", pen = COLOR_YELLOW })
        table.insert(content, "\n")
        for _, lm in ipairs(landmasses) do
            table.insert(content, { text = lm.name or "Unknown Landmass", pen = COLOR_LIGHTCYAN })
            table.insert(content, "\n")

            if lm.known_civs and #lm.known_civs > 0 then
                for _, civ in ipairs(lm.known_civs) do
                    table.insert(content, "    — ")
                    if civ.link then
                        table.insert(content, { text = civ.name, pen = COLOR_LIGHTBLUE, link = civ.link })
                    else
                        table.insert(content, { text = civ.name, pen = COLOR_WHITE })
                    end
                    table.insert(content, " (")
                    table.insert(content, { text = tostring(civ.site_count or 1), pen = COLOR_WHITE })
                    table.insert(content, " site" .. ((civ.site_count or 1) ~= 1 and "s" or "") .. ")\n")
                end
            end

            if lm.unknown_count and lm.unknown_count > 0 then
                table.insert(content, "    — ")
                table.insert(content, { text = tostring(lm.unknown_count), pen = COLOR_WHITE })
                table.insert(content, " other intelligent civilization" .. (lm.unknown_count ~= 1 and "s" or "") .. "\n")
            end

            table.insert(content, "\n")
        end
    end

    return content
end

return _ENV
