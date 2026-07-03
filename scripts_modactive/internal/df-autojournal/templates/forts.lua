--@ module = true
-- Forts index page template.
-- Renders a table of all known player forts.

--- Render the forts index page.
--- forts: array of { site_id, name, civ_id, civ_name, first_year, is_active }
--- current_site_id: the player's current fort site ID
function render(forts, current_site_id)
    local content = {}

    table.insert(content, { text = "# Forts", pen = COLOR_YELLOW })
    table.insert(content, "\n\n")
    table.insert(content, { text = "Known Forts: ", pen = COLOR_LIGHTCYAN })
    table.insert(content, { text = tostring(#forts), pen = COLOR_WHITE })
    table.insert(content, "\n\n")

    if #forts == 0 then
        table.insert(content, { text = "No forts known yet.", pen = COLOR_DARKGREY })
        table.insert(content, "\n")
        return content
    end

    local rows = {}
    for _, f in ipairs(forts) do
        local is_active = (f.site_id == current_site_id)
        local status = is_active and "Active" or ""
        local status_pen = is_active and COLOR_GREEN or COLOR_DARKGREY

        table.insert(rows, {
            { text = f.name or "Unknown", pen = is_active and COLOR_LIGHTGREEN or COLOR_WHITE, link = "fort:" .. tostring(f.site_id) },
            { text = f.civ_name or "Unknown", pen = COLOR_LIGHTBLUE, link = "civ:" .. tostring(f.civ_id) },
            { text = tostring(f.first_year or "?"), pen = COLOR_WHITE },
            { text = status, pen = status_pen },
        })
    end

    table.insert(content, {
        type = 'table',
        columns = {
            { header = 'Name', align = 'left', min_width = 25, stretch = true },
            { header = 'Civilization', align = 'left', min_width = 20, stretch = true },
            { header = 'Founded', align = 'right', min_width = 8, stretch = false },
            { header = 'Status', align = 'left', min_width = 6, stretch = false },
        },
        rows = rows,
        max_rows = 50,
    })

    return content
end

return _ENV
