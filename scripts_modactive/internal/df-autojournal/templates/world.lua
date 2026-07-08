--@ module = true
-- World page template.
-- Renders a root page describing the world, its eras, and inhabited landmasses.

local utils = reqscript('internal/df-autojournal/wiki_utils')
local mfw_settings = reqscript('internal/df-autojournal/wiki_settings')

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

    -- Current date (long format with season)
    local nice_date = utils.get_nice_date(data.current_year, data.current_month, data.current_day)
    table.insert(content, { text = "Current Date: ", pen = COLOR_LIGHTCYAN })
    table.insert(content, { text = nice_date, pen = COLOR_WHITE })
    if data.current_season and data.current_season ~= "" then
        table.insert(content, " (")
        table.insert(content, { text = data.current_season, pen = COLOR_WHITE })
        table.insert(content, ")")
    end
    table.insert(content, "\n")

    -- Eras timeline
    local eras = data.eras
    if eras and #eras > 0 then
        table.insert(content, "\n")
        table.insert(content, { text = "## Ages of the World", pen = COLOR_YELLOW })
        table.insert(content, "\n")
        for _, era in ipairs(eras) do
            local year_label = (era.year and era.year >= 0) and "Year " .. tostring(era.year) or "Prehistory"
            local line = "* " .. year_label .. " - " .. (era.name or "Unknown")
            table.insert(content, line .. (era.is_current and " (current era)" or "") .. "\n")
        end
    end

    -- Inhabited landmasses (sorted by population descending)
    local landmasses = data.landmasses
    if landmasses and #landmasses > 0 then
        table.insert(content, "\n")
        table.insert(content, { text = "## Inhabited Regions", pen = COLOR_YELLOW })
        table.insert(content, "\n")
        local lm_rows = {}
        for _, lm in ipairs(landmasses) do
            table.insert(lm_rows, {
                { text = lm.name or "Unknown Landmass", pen = COLOR_LIGHTCYAN },
                { text = tostring(lm.total_population or 0), pen = COLOR_WHITE },
            })
        end
        table.insert(content, {
            type = 'table',
            columns = {
                { header = 'Landmass', align = 'left', min_width = 25, stretch = true },
                { header = 'Population', align = 'right', min_width = 8, stretch = false },
            },
            rows = lm_rows,
            max_rows = #lm_rows,
        })
        table.insert(content, "\n")
    end

    return content
end

return _ENV
