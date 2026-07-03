--@ module = true
-- Enemies page template.
-- Renders a root page with a sortable enemy registry table,
-- notable kills per enemy, and section headers for auto-appended entries.

local utils = reqscript('internal/df-autojournal/wiki_utils')

--- Render the enemies page.
--- enemies:  array of { name, enemy_type, first_year, first_season, defeated, encounters, notes, last_year }
--- settings: { init={registry, stats}, journal={encounter_log, kill_list, notable_victories} }
--- kills:    table of { enemy_name, count, victims[] } indexed by normalized enemy name
function render(enemies, settings, kills)
    settings = settings or { init={registry=true, stats=true}, journal={encounter_log=true, kill_list=true, notable_victories=true} }
    kills = kills or {}

    local content = {}

    table.insert(content, { text = "# Enemies & Notable Threats", pen = COLOR_YELLOW })
    table.insert(content, "\n\n")

    local total = #enemies
    local defeated = 0
    for _, e in ipairs(enemies) do
        if e.defeated then defeated = defeated + 1 end
    end

    if settings.init.stats then
        local summary_parts = {}

        table.insert(summary_parts, { text = "Total: ", pen = COLOR_LIGHTCYAN })
        table.insert(summary_parts, { text = tostring(total), pen = COLOR_WHITE })

        if total > 0 then
            table.insert(summary_parts, "  |  ")
            table.insert(summary_parts, { text = "Defeated: ", pen = COLOR_LIGHTCYAN })
            table.insert(summary_parts, { text = tostring(defeated), pen = COLOR_LIGHTGREEN })
            table.insert(summary_parts, "  |  ")
            table.insert(summary_parts, { text = "Active: ", pen = COLOR_LIGHTCYAN })
            table.insert(summary_parts, { text = tostring(total - defeated), pen = COLOR_LIGHTRED })
        end

        table.insert(summary_parts, "\n\n")
        for _, part in ipairs(summary_parts) do
            table.insert(content, part)
        end
    end

    if total == 0 then
        table.insert(content, { text = "No enemies recorded yet.", pen = COLOR_DARKGREY })
        table.insert(content, "\n")
        return content
    end

    -- Registry table
    if settings.init.registry then
        local rows = {}
        local has_kills = false
        for _, e in ipairs(enemies) do
            local ek = (e.name or ""):lower():gsub("[^%w]", "_")
            local kill_data = kills[ek]
            if kill_data and kill_data.count > 0 then has_kills = true end
        end

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
            elseif lower_type:match("elf") then
                type_pen = COLOR_GREEN
            elseif lower_type:match("human") then
                type_pen = COLOR_LIGHTCYAN
            elseif lower_type:match("kobold") or lower_type:match("thief") then
                type_pen = COLOR_BROWN
            elseif lower_type:match("invasion") then
                type_pen = COLOR_LIGHTMAGENTA
            end

            local row = {
                { text = e.name or "Unknown", pen = COLOR_WHITE },
                { text = type_name, pen = type_pen },
                { text = tostring(e.first_year), pen = COLOR_LIGHTCYAN },
                { text = defeated_text, pen = defeated_pen },
                { text = tostring(e.encounters or 1), pen = COLOR_WHITE },
            }

            if has_kills then
                local kill_count = 0
                local ek = (e.name or ""):lower():gsub("[^%w]", "_")
                if kills[ek] then
                    kill_count = kills[ek].count or 0
                end
                table.insert(row, { text = tostring(kill_count), pen = kill_count > 0 and COLOR_LIGHTRED or COLOR_DARKGREY })
            end

            table.insert(row, { text = e.notes or "", pen = COLOR_DARKGREY })
            table.insert(rows, row)
        end

        table.sort(rows, function(a, b)
            return tonumber(a[3].text or "0") < tonumber(b[3].text or "0")
        end)

        local columns = {
            { header = 'Name', align = 'left', min_width = 20, stretch = true },
            { header = 'Type', align = 'left', min_width = 12, stretch = false },
            { header = 'First Year', align = 'right', min_width = 8, stretch = false },
            { header = 'Defeated', align = 'left', min_width = 6, stretch = false },
            { header = 'Enc.', align = 'right', min_width = 4, stretch = false },
        }

        local has_kills_final = false
        for _, e in ipairs(enemies) do
            local ek = (e.name or ""):lower():gsub("[^%w]", "_")
            if kills[ek] and kills[ek].count > 0 then has_kills_final = true end
        end
        if has_kills_final then
            table.insert(columns, { header = 'Kills', align = 'right', min_width = 5, stretch = false })
        end

        table.insert(columns, { header = 'Notes', align = 'left', min_width = 15, stretch = true })

        table.insert(content, {
            type = 'table',
            columns = columns,
            rows = rows,
            max_rows = 100,
        })
        table.insert(content, "\n")
    end

    -- Notable Victories section (enemies that were defeated)
    if settings.journal.notable_victories then
        local defeated_enemies = {}
        for _, e in ipairs(enemies) do
            if e.defeated then
                local ek = (e.name or ""):lower():gsub("[^%w]", "_")
                local kd = kills[ek]
                local kill_count = kd and kd.count or 0
                table.insert(defeated_enemies, {
                    name = e.name or "Unknown",
                    year = e.last_year or e.first_year,
                    encounters = e.encounters or 1,
                    kills = kill_count,
                })
            end
        end

        if #defeated_enemies > 0 then
            table.sort(defeated_enemies, function(a, b) return (a.year or 0) > (b.year or 0) end)
            table.insert(content, "\n")
            table.insert(content, { text = "## Notable Victories", pen = COLOR_YELLOW })
            table.insert(content, "\n")
            for _, de in ipairs(defeated_enemies) do
                local line = "* " .. de.name .. " — defeated in " .. tostring(de.year)
                if de.kills > 0 then
                    line = line .. ", had slain " .. tostring(de.kills) .. " citizen" .. (de.kills ~= 1 and "s" or "")
                end
                table.insert(content, line .. "\n")
            end
            table.insert(content, "\n")
        end
    end

    -- Notable Encounters section header (entries appended by listener/catch-up)
    if settings.journal.encounter_log then
        table.insert(content, "\n")
        table.insert(content, { text = "## Notable Encounters", pen = COLOR_YELLOW })
        table.insert(content, "\n")
    end

    -- Kill List section header (entries appended on enemy deaths)
    if settings.journal.kill_list then
        table.insert(content, "\n")
        table.insert(content, { text = "## Kill List", pen = COLOR_YELLOW })
        table.insert(content, "\n")
    end

    return content
end

return _ENV
