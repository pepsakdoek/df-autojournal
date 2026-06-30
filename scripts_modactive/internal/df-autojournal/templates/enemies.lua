--@ module = true
-- Enemies page template.
-- Renders a root page with a sortable enemy registry table
-- and an encounter log section.

local utils = reqscript('internal/df-autojournal/wiki_utils')

--- Render the enemies page.
--- enemies: array of { name, enemy_type, first_year, first_season, defeated, encounters, notes }
function render(enemies)
    local content = {}

    table.insert(content, { text = "# Enemies & Notable Threats", pen = COLOR_YELLOW })
    table.insert(content, "\n\n")

    -- Summary
    local total = #enemies
    local defeated = 0
    for _, e in ipairs(enemies) do
        if e.defeated then defeated = defeated + 1 end
    end

    table.insert(content, { text = "Total Enemies: ", pen = COLOR_LIGHTCYAN })
    table.insert(content, { text = tostring(total), pen = COLOR_WHITE })
    table.insert(content, "  |  ")
    table.insert(content, { text = "Defeated: ", pen = COLOR_LIGHTCYAN })
    table.insert(content, { text = tostring(defeated), pen = COLOR_LIGHTGREEN })
    table.insert(content, "  |  ")
    table.insert(content, { text = "Active Threats: ", pen = COLOR_LIGHTCYAN })
    table.insert(content, { text = tostring(total - defeated), pen = COLOR_LIGHTRED })
    table.insert(content, "\n\n")

    if total == 0 then
        table.insert(content, { text = "No enemies recorded yet.", pen = COLOR_DARKGREY })
        table.insert(content, "\n")
        return content
    end

    -- Registry table
    local rows = {}
    for _, e in ipairs(enemies) do
        local defeated_text = e.defeated and "Yes" or "No"
        local defeated_pen = e.defeated and COLOR_GREEN or COLOR_LIGHTRED

        local type_name = e.enemy_type or "Unknown"
        local type_pen = COLOR_LIGHTRED
        local lower_type = type_name:lower()
        if lower_type:match("clown") or lower_type:match("demon") then
            type_pen = COLOR_RED
        elseif lower_type:match("goblin") then
            type_pen = COLOR_LIGHTMAGENTA
        elseif lower_type:match("beast") or lower_type:match("monster") then
            type_pen = COLOR_LIGHTRED
        end

        table.insert(rows, {
            { text = e.name or "Unknown", pen = COLOR_WHITE },
            { text = type_name, pen = type_pen },
            { text = tostring(e.first_year), pen = COLOR_LIGHTCYAN },
            { text = defeated_text, pen = defeated_pen },
            { text = tostring(e.encounters or 1), pen = COLOR_WHITE },
            { text = e.notes or "", pen = COLOR_DARKGREY },
        })
    end

    -- Sort by most recent first year ascending (oldest first)
    table.sort(rows, function(a, b)
        return tonumber(a[3].text or "0") < tonumber(b[3].text or "0")
    end)

    table.insert(content, {
        type = 'table',
        columns = {
            { header = 'Name', align = 'left', min_width = 20, stretch = true },
            { header = 'Type', align = 'left', min_width = 12, stretch = false },
            { header = 'First Year', align = 'right', min_width = 6, stretch = false },
            { header = 'Defeated', align = 'left', min_width = 6, stretch = false },
            { header = 'Encounters', align = 'right', min_width = 6, stretch = false },
            { header = 'Notes', align = 'left', min_width = 20, stretch = true },
        },
        rows = rows,
        max_rows = 100,
    })

    -- Encounter log section header (entries appended by listener/catch-up)
    table.insert(content, "\n\n")
    table.insert(content, { text = "## Encounter Log", pen = COLOR_YELLOW })
    table.insert(content, "\n")

    return content
end

return _ENV
