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
---   gen_params: { title, seed, history_seed, name_seed, creature_seed, dim_x, dim_y,
---     end_year, beast_end_year, mineral_scarcity, total_civ_number, site_cap,
---     megabeast_cap, semimegabeast_cap, titan_number, demon_number,
---     total_civ_population, embark_points } (or nil),
---   mountain_peaks: { name }[] (or nil),
---   rivers_count: int (or nil),
--- }
function render(data)
    data = data or {}
    local cfg = mfw_settings.get_settings().world
    local settings = cfg and cfg.init or {}
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

    -- Geography: mountain peaks and rivers
    local geo_detail = settings.geography_detail or 'major'
    if geo_detail ~= 'none' and data.rivers_count and data.rivers_count > 0 then
        table.insert(content, "\n")
        table.insert(content, { text = "## Geography", pen = COLOR_YELLOW })
        table.insert(content, "\n")

        -- Mountain ranges (sorted by size descending)
        local ranges = data.mountain_ranges or {}
        if #ranges > 0 then
            table.insert(content, { text = "### Mountain Ranges", pen = COLOR_YELLOW })
            table.insert(content, "\n")
            table.insert(content, { text = "Total: ", pen = COLOR_LIGHTCYAN })
            table.insert(content, { text = tostring(#ranges), pen = COLOR_WHITE })
            table.insert(content, "\n")

            if geo_detail == 'major' then
                local display_n = math.min(#ranges, 8)
                for i = 1, display_n do
                    table.insert(content, "* " .. (ranges[i].name or "Unknown") .. "\n")
                end
                if #ranges > 8 then
                    table.insert(content, "... and " .. (#ranges - 8) .. " more\n")
                end
                table.insert(content, "\n")
            elseif geo_detail == 'all' then
                for _, r in ipairs(ranges) do
                    table.insert(content, "* " .. (r.name or "Unknown") .. "\n")
                end
                table.insert(content, "\n")
            end
        end

        -- Mountain peaks (highest points within ranges)
        local peaks = data.mountain_peaks or {}
        if #peaks > 0 then
            table.insert(content, { text = "### Named Peaks", pen = COLOR_YELLOW })
            table.insert(content, "\n")
            table.insert(content, { text = "Total: ", pen = COLOR_LIGHTCYAN })
            table.insert(content, { text = tostring(#peaks), pen = COLOR_WHITE })
            table.insert(content, "\n")

            if geo_detail == 'major' or geo_detail == 'all' then
                for _, p in ipairs(peaks) do
                    table.insert(content, "* " .. (p.name or "Unnamed Peak"))
                    if p.is_volcano then
                        table.insert(content, " (")
                        table.insert(content, { text = "volcano", pen = COLOR_LIGHTRED })
                        table.insert(content, ")")
                    end
                    table.insert(content, "\n")
                end
                table.insert(content, "\n")
            end
        end

        -- Rivers
        if data.rivers_count and data.rivers_count > 0 then
            table.insert(content, { text = "### Rivers & Waterways", pen = COLOR_YELLOW })
            table.insert(content, "\n")
            table.insert(content, { text = "Total: ", pen = COLOR_LIGHTCYAN })
            table.insert(content, { text = tostring(data.rivers_count) .. " named", pen = COLOR_WHITE })
            if data.major_rivers_count and data.major_rivers_count > 0 then
                table.insert(content, " (")
                table.insert(content, { text = tostring(data.major_rivers_count) .. " major", pen = COLOR_LIGHTCYAN })
                table.insert(content, ")")
            end
            table.insert(content, "\n")
        end

        if geo_detail == 'all' and data.rivers and #data.rivers > 0 then
            table.insert(content, "\n")
            for _, r in ipairs(data.rivers) do
                table.insert(content, "* " .. (r.name or "Unnamed River") .. "\n")
            end
        elseif geo_detail == 'major' and data.major_rivers and #data.major_rivers > 0 then
            table.insert(content, "\n")
            for _, r in ipairs(data.major_rivers) do
                table.insert(content, "* " .. (r.name or "Unnamed River") .. " (")
                table.insert(content, { text = "flow " .. tostring(r.flow), pen = COLOR_LIGHTCYAN })
                table.insert(content, ")\n")
            end
        end
    end

    -- World generation parameters
    local gen = settings.world_gen and data.gen_params
    if gen then
        table.insert(content, "\n")
        table.insert(content, { text = "## World Generation", pen = COLOR_YELLOW })
        table.insert(content, "\n")

        table.insert(content, { text = "Preset: ", pen = COLOR_LIGHTCYAN })
        table.insert(content, { text = gen.title or "Custom", pen = COLOR_WHITE })
        table.insert(content, "\n")

        table.insert(content, { text = "Dimensions: ", pen = COLOR_LIGHTCYAN })
        table.insert(content, { text = tostring(gen.dim_x or 0) .. " x " .. tostring(gen.dim_y or 0), pen = COLOR_WHITE })
        table.insert(content, "\n")

        table.insert(content, { text = "History Length: ", pen = COLOR_LIGHTCYAN })
        table.insert(content, { text = tostring(gen.end_year or 0) .. " years", pen = COLOR_WHITE })
        table.insert(content, "\n")

        table.insert(content, { text = "Mineral Scarcity: ", pen = COLOR_LIGHTCYAN })
        table.insert(content, { text = tostring(gen.mineral_scarcity or "?") .. "%", pen = COLOR_WHITE })
        table.insert(content, "\n")

        table.insert(content, { text = "Civilizations: ", pen = COLOR_LIGHTCYAN })
        table.insert(content, { text = tostring(gen.total_civ_number or 0) .. " (" .. tostring(gen.total_civ_population or 0) .. " pop, " .. tostring(gen.site_cap or 0) .. " site cap)", pen = COLOR_WHITE })
        table.insert(content, "\n")

        table.insert(content, { text = "Megabeasts: ", pen = COLOR_LIGHTCYAN })
        table.insert(content, { text = tostring(gen.megabeast_cap or 0) .. " / Semimegabeasts: ", pen = COLOR_WHITE })
        table.insert(content, { text = tostring(gen.semimegabeast_cap or 0) .. " / Titans: ", pen = COLOR_WHITE })
        table.insert(content, { text = tostring(gen.titan_number or 0), pen = COLOR_WHITE })
        table.insert(content, "\n")

        table.insert(content, { text = "Embark Points: ", pen = COLOR_LIGHTCYAN })
        table.insert(content, { text = tostring(gen.embark_points or 0), pen = COLOR_WHITE })
        table.insert(content, "\n\n")

        -- Seeds in a sub-section
        if settings.seeds then
            table.insert(content, { text = "### World Seeds", pen = COLOR_LIGHTCYAN })
            table.insert(content, "\n")
            table.insert(content, "* Seed: " .. (gen.seed or "?") .. "\n")
            table.insert(content, "* History Seed: " .. (gen.history_seed or "?") .. "\n")
            table.insert(content, "* Name Seed: " .. (gen.name_seed or "?") .. "\n")
            table.insert(content, "* Creature Seed: " .. (gen.creature_seed or "?") .. "\n")
        end
    end

    return content
end

return _ENV
