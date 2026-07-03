--@ module = true
-- Civilizations index page template.
-- Renders a table of all known civilizations.

--- Render the civilizations index page.
--- civs: array of { civ_id, name, race, site_count, is_current }
--- current_civ_id: the player's current civilization ID
function render(civs, current_civ_id)
    local content = {}

    table.insert(content, { text = "# Civilizations", pen = COLOR_YELLOW })
    table.insert(content, "\n\n")
    table.insert(content, { text = "Known Civilizations: ", pen = COLOR_LIGHTCYAN })
    table.insert(content, { text = tostring(#civs), pen = COLOR_WHITE })
    table.insert(content, "\n\n")

    if #civs == 0 then
        table.insert(content, { text = "No civilizations known yet.", pen = COLOR_DARKGREY })
        table.insert(content, "\n")
        return content
    end

    local rows = {}
    for _, c in ipairs(civs) do
        local is_current = (c.civ_id == current_civ_id)
        local status = is_current and "Current" or ""
        local status_pen = is_current and COLOR_GREEN or COLOR_DARKGREY

        table.insert(rows, {
            { text = c.name or "Unknown", pen = COLOR_LIGHTBLUE, link = "civ:" .. tostring(c.civ_id) },
            { text = c.race or "Unknown", pen = COLOR_WHITE },
            { text = tostring(c.site_count or 0), pen = COLOR_LIGHTCYAN },
            { text = status, pen = status_pen },
        })
    end

    table.insert(content, {
        type = 'table',
        columns = {
            { header = 'Name', align = 'left', min_width = 25, stretch = true },
            { header = 'Race', align = 'left', min_width = 10, stretch = false },
            { header = 'Settlements', align = 'right', min_width = 6, stretch = false },
            { header = 'Status', align = 'left', min_width = 6, stretch = false },
        },
        rows = rows,
        max_rows = 50,
    })

    return content
end

return _ENV
