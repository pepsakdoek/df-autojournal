--@ module = true
local utils = reqscript('internal/df-autojournal/wiki_utils')
local mfw_settings = reqscript('internal/df-autojournal/wiki_settings')

--- Render a relationship line on the citizen page.
--- If the related HF has a live citizen unit, renders a clickable wiki link.
local function add_relation(content, hf, label)
    if not hf then return end
    local raw_name = dfhack.translation.translateName(hf.name, false)
    local name = utils.sanitize(raw_name)
    if not name or name == "" then return end

    table.insert(content, "* " .. label)
    if hf.unit_id ~= -1 then
        local unit = df.unit.find(hf.unit_id)
        if unit and dfhack.units.isCitizen(unit) then
            table.insert(content, { text = name, pen = COLOR_LIGHTBLUE, link = "citizen:" .. tostring(hf.unit_id) })
            table.insert(content, "\n")
            return
        end
    end
    table.insert(content, name)
    table.insert(content, "\n")
end

function render(unit, template_opts)
    template_opts = template_opts or {}
    local cfg = mfw_settings.get_settings().citizen
    local init_settings = template_opts.settings_override or cfg.init
    local journal_settings = cfg.journal
    local settings = init_settings
    local name = utils.sanitize(dfhack.units.getReadableName(unit))
    local prof = utils.sanitize(dfhack.units.getProfessionName(unit))
    local sex = "Unknown"
    if unit.sex == 0 then sex = "Female"
    elseif unit.sex == 1 then sex = "Male" end

    local content = {}

    table.insert(content, { text = "# " .. name, pen = COLOR_YELLOW })
    table.insert(content, "\n\n")

    table.insert(content, { text = "Profession: ", pen = COLOR_LIGHTCYAN })
    table.insert(content, { type = 'function', fn_key = 'current_profession', args = { unit_id = unit.id } })
    table.insert(content, "\n")

    table.insert(content, { text = "Gender: ", pen = COLOR_LIGHTCYAN })
    table.insert(content, { text = sex, pen = COLOR_WHITE })
    table.insert(content, "\n")

    -- Age (live via function block)
    table.insert(content, { text = "Age: ", pen = COLOR_LIGHTCYAN })
    table.insert(content, { type = 'function', fn_key = 'dwarf_age', args = { birth_year = unit.birth_year, unit_id = unit.id } })
    table.insert(content, "\n")

    -- Happiness (live via function block)
    table.insert(content, { text = "Happiness: ", pen = COLOR_LIGHTCYAN })
    table.insert(content, { type = 'function', fn_key = 'current_happiness', args = { unit_id = unit.id } })
    table.insert(content, "\n")

    -- Mood (live via function block, shows strange mood like fey/possessed or "Content")
    table.insert(content, { text = "Mood: ", pen = COLOR_LIGHTCYAN })
    table.insert(content, { type = 'function', fn_key = 'current_mood', args = { unit_id = unit.id } })
    table.insert(content, "\n")

    -- Health (live via function block)
    table.insert(content, { text = "Health: ", pen = COLOR_LIGHTCYAN })
    table.insert(content, { type = 'function', fn_key = 'current_health', args = { unit_id = unit.id } })
    table.insert(content, "\n")

    -- Needs (live via function block)
    if settings.needs then
        table.insert(content, { text = "Needs: ", pen = COLOR_LIGHTCYAN })
        table.insert(content, { type = 'function', fn_key = 'current_needs', args = { unit_id = unit.id } })
        table.insert(content, "\n")
    end

    -- Family & Relationships section
    if settings.relationships and unit.hist_figure_id ~= -1 then
        local hf = df.historical_figure.find(unit.hist_figure_id)
        if hf and hf.histfig_links and #hf.histfig_links > 0 then
            local spouses = {}
            local parents = {}
            local children = {}

            for _, link in ipairs(hf.histfig_links) do
                if link.target_hf == -1 then goto skip_link end
                local target = df.historical_figure.find(link.target_hf)
                if not target then goto skip_link end
                if df.is_instance(link, df.histfig_hf_link_spousest) then
                    table.insert(spouses, target)
                elseif df.is_instance(link, df.histfig_hf_link_childst) then
                    table.insert(parents, target)
                elseif df.is_instance(link, df.histfig_hf_link_parentst) then
                    table.insert(children, target)
                end
                ::skip_link::
            end

            if #spouses > 0 or #parents > 0 or #children > 0 then
                table.insert(content, "\n")
                table.insert(content, { text = "## Family & Relationships", pen = COLOR_YELLOW })
                table.insert(content, "\n")

                for _, s in ipairs(spouses) do
                    add_relation(content, s, "Spouse: ")
                end
                for _, p in ipairs(parents) do
                    add_relation(content, p, "Parent: ")
                end
                for _, c in ipairs(children) do
                    add_relation(content, c, "Child: ")
                end
            end
        end
    end

    -- Skills (live via function block)
    if settings.skills then
        table.insert(content, "\n")
        table.insert(content, { text = "## Skills", pen = COLOR_YELLOW })
        table.insert(content, "\n")
        table.insert(content, { type = 'function', fn_key = 'current_skills', args = { unit_id = unit.id } })
        table.insert(content, "\n")
    end

    -- Personal Journal
    if not template_opts.no_personal_journal then
        table.insert(content, "\n")
        table.insert(content, { text = "## Personal Journal", pen = COLOR_YELLOW })
        table.insert(content, "\n")
        table.insert(content, { text = "Log your thoughts here...", pen = COLOR_DARKGREY })
        table.insert(content, "\n\n")
    end

    -- Attributes & Personality
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

    -- History & Timeline
    if settings.timeline then
        table.insert(content, "\n")
        table.insert(content, { text = "## History & Timeline", pen = COLOR_YELLOW })
        table.insert(content, "\n")
        local arrived_year = nil
        if unit.hist_figure_id >= 0 then
            local hf = df.historical_figure.find(unit.hist_figure_id)
            if hf then
                if hf.appeared_year and hf.appeared_year > 0 then
                    arrived_year = hf.appeared_year
                end
            end
        end
        if arrived_year then
            table.insert(content, "* Born in year ")
            table.insert(content, { text = tostring(unit.birth_year), pen = COLOR_WHITE })
            table.insert(content, ", first appears in history in year ")
            table.insert(content, { text = tostring(arrived_year), pen = COLOR_WHITE })
            table.insert(content, "\n")
        else
            table.insert(content, "* Born in year ")
            table.insert(content, { text = tostring(unit.birth_year), pen = COLOR_WHITE })
            table.insert(content, "\n")
        end
    end

    -- Military History
    if journal_settings and journal_settings.military_history and unit.hist_figure_id >= 0 then
        local hf = df.historical_figure.find(unit.hist_figure_id)
        if hf and hf.info and hf.info.kills and hf.info.kills.killed_count then
            local total_kills = 0
            for j = 0, #hf.info.kills.killed_count - 1 do
                total_kills = total_kills + hf.info.kills.killed_count[j]
            end
            if total_kills > 0 then
                table.insert(content, "\n")
                table.insert(content, { text = "## Military History", pen = COLOR_YELLOW })
                table.insert(content, "\n")
                table.insert(content, { text = "Notable kills: ", pen = COLOR_LIGHTCYAN })
                table.insert(content, { text = tostring(total_kills), pen = COLOR_WHITE })
                table.insert(content, "\n")
                for j = 0, #hf.info.kills.killed_count - 1 do
                    local count = hf.info.kills.killed_count[j]
                    if count > 0 then
                        local race_id = hf.info.kills.killed_race[j]
                        local race_name = "?"
                        pcall(function()
                            local cr = df.creature_raw.find(race_id)
                            if cr and cr.name then race_name = cr.name[0] end
                        end)
                        table.insert(content, "* " .. tostring(count) .. "x ")
                        table.insert(content, { text = race_name, pen = COLOR_LIGHTRED })
                        table.insert(content, "\n")
                    end
                end
            end
        end
    end

    return utils.sanitize_content(content)
end

return _ENV
