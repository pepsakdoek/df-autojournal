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
    local settings = template_opts.settings_override or cfg.init
    local name = utils.sanitize(dfhack.units.getReadableName(unit))
    local prof = utils.sanitize(dfhack.units.getProfessionName(unit))
    local sex = "Unknown"
    if unit.sex == 0 then sex = "Female"
    elseif unit.sex == 1 then sex = "Male" end

    local content = {}

    table.insert(content, { text = "# " .. name, pen = COLOR_YELLOW })
    table.insert(content, "\n\n")

    table.insert(content, { text = "Profession: ", pen = COLOR_LIGHTCYAN })
    table.insert(content, { text = prof, pen = COLOR_WHITE })
    table.insert(content, "\n")

    table.insert(content, { text = "Gender: ", pen = COLOR_LIGHTCYAN })
    table.insert(content, { text = sex, pen = COLOR_WHITE })
    table.insert(content, "\n")

    -- Age (replaces raw birth year)
    local age = df.global.cur_year - unit.birth_year
    table.insert(content, { text = "Age: ", pen = COLOR_LIGHTCYAN })
    table.insert(content, { text = tostring(age), pen = COLOR_WHITE })
    table.insert(content, "\n")

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

    -- Skills (master-level shown)
    if settings.skills and unit.status.current_soul then
        local soul = unit.status.current_soul
        if soul.skills and #soul.skills > 0 then
            local master_skills = {}
            for _, skill in ipairs(soul.skills) do
                local rate = skill.rating
                if rate >= 10 then
                    local sk_name = tostring(df.job_skill[skill.id]):gsub("_", " "):lower()
                    table.insert(master_skills, { name = sk_name, rate = rate })
                end
            end
            if #master_skills > 0 then
                table.insert(content, "\n")
                table.insert(content, { text = "## Skills", pen = COLOR_YELLOW })
                table.insert(content, "\n")
                for _, ms in ipairs(master_skills) do
                    table.insert(content, "* " .. ms.name)
                    table.insert(content, "\n")
                end
            end
        end
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
        local ny, nm, nd = utils.get_current_date()
        table.insert(content, "* Arrived ")
        table.insert(content, { text = utils.get_nice_date(ny, nm, nd), pen = COLOR_WHITE })
        table.insert(content, " (logged on)\n")
    end

    return utils.sanitize_content(content)
end

return _ENV
