--@ module = true
-- Visitors page template.
-- Renders a root page with a sortable visitor registry table
-- and section headers for auto-appended entries.

local utils = reqscript('internal/df-autojournal/wiki_utils')

local VISITOR_TYPE_PENS = {
    trader = COLOR_LIGHTGREEN,
    entertainer = COLOR_LIGHTMAGENTA,
    scholar = COLOR_LIGHTCYAN,
    monster_slayer = COLOR_LIGHTRED,
    mercenary = COLOR_YELLOW,
    diplomat = COLOR_LIGHTBLUE,
    petitioner = COLOR_LIGHTGREEN,
}

local VISITOR_TYPE_LABELS = {
    trader = "Trader",
    entertainer = "Entertainer",
    scholar = "Scholar",
    monster_slayer = "Monster Slayer",
    mercenary = "Mercenary",
    diplomat = "Diplomat",
    petitioner = "Petitioner",
}

--- Render the visitors page.
--- visitors:  array of { name, visitor_type, first_year, first_season, last_year, departed, encounters, notes }
--- settings: { init={registry, departed}, journal={track_*} }
function render(visitors, settings)
    settings = settings or { init={registry=true, departed=true}, journal={track_traders=true, track_entertainers=true, track_scholars=true, track_monster_slayers=true, track_mercenaries=true, track_diplomats=true, track_petitioners=true} }

    local content = {}

    table.insert(content, { text = "# Visitors", pen = COLOR_YELLOW })
    table.insert(content, "\n\n")

    local total = #visitors
    local present = 0
    for _, v in ipairs(visitors) do
        if not v.departed then present = present + 1 end
    end

    if settings.init.registry then
        local summary_parts = {}

        table.insert(summary_parts, { text = "Total: ", pen = COLOR_LIGHTCYAN })
        table.insert(summary_parts, { text = tostring(total), pen = COLOR_WHITE })

        if total > 0 then
            table.insert(summary_parts, "  |  ")
            table.insert(summary_parts, { text = "Present: ", pen = COLOR_LIGHTCYAN })
            table.insert(summary_parts, { text = tostring(present), pen = COLOR_LIGHTGREEN })
            table.insert(summary_parts, "  |  ")
            table.insert(summary_parts, { text = "Departed: ", pen = COLOR_LIGHTCYAN })
            table.insert(summary_parts, { text = tostring(total - present), pen = COLOR_GREY })
        end

        table.insert(summary_parts, "\n\n")
        for _, part in ipairs(summary_parts) do
            table.insert(content, part)
        end
    end

    if total == 0 then
        table.insert(content, { text = "No visitors recorded yet.", pen = COLOR_DARKGREY })
        table.insert(content, "\n")
        return content
    end

    -- Registry table
    if settings.init.registry then
        local rows = {}
        for _, v in ipairs(visitors) do
            local type_label = VISITOR_TYPE_LABELS[v.visitor_type] or v.visitor_type or "Unknown"
            local type_pen = VISITOR_TYPE_PENS[v.visitor_type] or COLOR_WHITE

            local departed_text = v.departed and "Yes" or "No"
            local departed_pen = v.departed and COLOR_GREY or COLOR_LIGHTGREEN

            local last_arrival = tostring(v.last_year or v.first_year or "?")
            if v.last_season and v.last_season ~= "" then
                last_arrival = v.last_season .. " " .. last_arrival
            end

            local safe_name = tostring(v.name or "")
            local name_cell = { text = safe_name, pen = COLOR_WHITE }
            if settings.init and settings.init.create_pages and safe_name ~= "" then
                name_cell = { text = safe_name, pen = COLOR_LIGHTBLUE, link = "visitor:" .. safe_name:lower():gsub("[^%w]", "_") }
            end

            local row = {
                name_cell,
                { text = type_label, pen = type_pen },
                { text = last_arrival, pen = COLOR_LIGHTCYAN },
            }

            if settings.init.departed then
                table.insert(row, { text = departed_text, pen = departed_pen })
            end

            table.insert(row, { text = tostring(v.encounters or 1), pen = COLOR_WHITE })
            table.insert(row, { text = v.notes or "", pen = COLOR_DARKGREY })
            table.insert(rows, row)
        end

        table.sort(rows, function(a, b)
            local ay = tonumber(a[3].text:match("(%d+)")) or 0
            local by = tonumber(b[3].text:match("(%d+)")) or 0
            return ay > by
        end)

        local columns = {
            { header = 'Name', align = 'left', min_width = 20, stretch = true },
            { header = 'Type', align = 'left', min_width = 14, stretch = false },
            { header = 'Last Arrival', align = 'right', min_width = 12, stretch = false },
        }
        if settings.init.departed then
            table.insert(columns, { header = 'Departed', align = 'left', min_width = 6, stretch = false })
        end
        table.insert(columns, { header = 'Visits', align = 'right', min_width = 5, stretch = false })
        table.insert(columns, { header = 'Notes', align = 'left', min_width = 15, stretch = true })

        table.insert(content, {
            type = 'table',
            columns = columns,
            rows = rows,
            max_rows = 100,
        })
        table.insert(content, "\n")
    end

    -- Visitor Log section header
    table.insert(content, "\n")
    table.insert(content, { text = "## Visitor Log", pen = COLOR_YELLOW })
    table.insert(content, "\n")

    return content
end

return _ENV
