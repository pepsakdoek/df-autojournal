--@ module = true
-- Timeline rendering for Events root page and Fort page.
-- Generates sortable table blocks from event registry entries,
-- plus category summary counts.

local utils = reqscript('internal/df-autojournal/wiki_utils')

-- Season ordering for sorting (earlier season = higher sort value for reverse chrono)
local SEASON_ORDER = {
    ["late winter"] = 0,
    ["mid-winter"] = 1,
    ["early winter"] = 2,
    ["late autumn"] = 3,
    ["mid-autumn"] = 4,
    ["early autumn"] = 5,
    ["late summer"] = 6,
    ["mid-summer"] = 7,
    ["early summer"] = 8,
    ["late spring"] = 9,
    ["mid-spring"] = 10,
    ["early spring"] = 11,
    ["winter"] = 1,
    ["autumn"] = 4,
    ["summer"] = 7,
    ["spring"] = 10,
}

local CATEGORY_LABELS = {
    death = "Deaths",
    threat = "Threats",
    achievement = "Achievements",
    crisis = "Crises",
    social = "Social Events",
    trade = "Trade & Diplomacy",
    military = "Military",
    environment = "Environment",
    world = "World Events",
    population = "Population",
    combat = "Combat",
}

local CATEGORY_COLORS = {
    death = COLOR_LIGHTRED,
    threat = COLOR_RED,
    achievement = COLOR_GREEN,
    crisis = COLOR_YELLOW,
    social = COLOR_LIGHTCYAN,
    trade = COLOR_LIGHTGREEN,
    military = COLOR_LIGHTRED,
    environment = COLOR_CYAN,
    world = COLOR_LIGHTMAGENTA,
    population = COLOR_LIGHTCYAN,
    combat = COLOR_LIGHTRED,
}

--- Render a timeline table block from an array of event entries.
--- entries: { year, season, category, event_type, summary, link? }[]
--- Returns display_text content array (table block)
function render_timeline(entries)
    if not entries or #entries == 0 then
        return {
            { text = "No events recorded yet.", pen = COLOR_DARKGREY },
            "\n",
        }
    end

    -- Sort by year descending, then season descending (most recent first)
    local sorted = {}
    for _, e in ipairs(entries) do
        table.insert(sorted, e)
    end
    table.sort(sorted, function(a, b)
        if a.year ~= b.year then return a.year > b.year end
        local sa = SEASON_ORDER[a.season or ""] or 0
        local sb = SEASON_ORDER[b.season or ""] or 0
        return sa > sb
    end)

    -- Cap display to most recent 200 entries
    local display_count = math.min(#sorted, 200)

    local rows = {}
    for i = 1, display_count do
        local e = sorted[i]
        local season_display = e.season and e.season:gsub("^early ", "E "):gsub("^mid%-", "M "):gsub("^late ", "L ") or ""
        local cat_color = CATEGORY_COLORS[e.category] or COLOR_WHITE
        local cat_label = CATEGORY_LABELS[e.category] or (e.category:gsub("^%l", string.upper))

        local summary_parts = {}
        local summary_text = e.summary or ""
        -- Strip wiki markup from summary for cleaner display
        summary_text = summary_text:gsub("%* ", ""):gsub("\n", ""):gsub("%[([^%]]+)%]%([^%)]+%)", "%1")
        if #summary_text > 80 then
            summary_text = summary_text:sub(1, 77) .. "..."
        end

        local row = {
            { text = tostring(e.year), pen = COLOR_WHITE },
            { text = season_display, pen = COLOR_LIGHTCYAN },
            { text = cat_label, pen = cat_color },
            { text = summary_text, pen = COLOR_LIGHTGREY },
        }

        -- Link to detail page if available
        if e.link then
            table.insert(row, { text = "View", pen = COLOR_LIGHTBLUE, link = e.link })
        else
            table.insert(row, { text = "", pen = COLOR_DARKGREY })
        end

        table.insert(rows, row)
    end

    local table_block = {
        type = 'table',
        columns = {
            { header = 'Year', align = 'right', min_width = 5, stretch = false },
            { header = 'Season', align = 'left', min_width = 4, stretch = false },
            { header = 'Category', align = 'left', min_width = 10, stretch = false },
            { header = 'Summary', align = 'left', min_width = 40, stretch = true },
            { header = '', align = 'left', min_width = 5, stretch = false },
        },
        rows = rows,
        max_rows = display_count,
    }

    local result = {}
    table.insert(result, table_block)

    if #sorted > 200 then
        table.insert(result, "\n")
        table.insert(result, { text = "... and " .. (#sorted - 200) .. " more entries", pen = COLOR_DARKGREY })
        table.insert(result, "\n")
    end

    return result
end

--- Render category count summary.
--- categories: { category_name = count, ... }
--- Returns display_text content array
function render_counts(categories)
    if not categories then
        return { { text = "No events recorded.", pen = COLOR_DARKGREY }, "\n" }
    end

    local content = {}
    local total = 0
    for _, count in pairs(categories) do
        total = total + count
    end

    table.insert(content, { text = "Total Events: ", pen = COLOR_LIGHTCYAN })
    table.insert(content, { text = tostring(total), pen = COLOR_WHITE })
    table.insert(content, "\n\n")

    -- Sort categories by count descending
    local sorted_cats = {}
    for cat, count in pairs(categories) do
        table.insert(sorted_cats, { cat = cat, count = count })
    end
    table.sort(sorted_cats, function(a, b) return a.count > b.count end)

    for _, pair in ipairs(sorted_cats) do
        if pair.count > 0 then
            local cat_color = CATEGORY_COLORS[pair.cat] or COLOR_WHITE
            local cat_label = CATEGORY_LABELS[pair.cat] or (pair.cat:gsub("^%l", string.upper))
            table.insert(content, { text = "* ", pen = COLOR_DARKGREY })
            table.insert(content, { text = cat_label .. ": ", pen = cat_color })
            table.insert(content, { text = tostring(pair.count), pen = COLOR_WHITE })
            table.insert(content, "\n")
        end
    end
    table.insert(content, "\n")

    return content
end

return _ENV
