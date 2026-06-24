--@ module = true
local utils = reqscript('internal/df-autojournal/wiki_utils')
local mfw_settings = reqscript('internal/df-autojournal/wiki_settings')

function render(unit)
    local settings = mfw_settings.get_settings().citizen
    local name = utils.sanitize(dfhack.units.getReadableName(unit))
    local prof = utils.sanitize(dfhack.units.getProfessionName(unit))
    local sex = "Unknown"
    if unit.sex == 0 then sex = "Female"
    elseif unit.sex == 1 then sex = "Male" end
    
    local age = dfhack.units.getAge(unit)
    
    local content = "# " .. name .. "\n\n"
    content = content .. "**Profession:** " .. prof .. "\n"
    content = content .. "**Gender:** " .. sex .. "\n"
    -- Don't do age, because it changes the whole time, and we don't want to update values the whole time
    -- TODO: Maybe add a "Birth Year" field instead, which is static and doesn't change over time?
    -- content = content .. "**Age:** " .. age .. "\n\n"
    
    content = content .. "## Personal Journal\n"
    content = content .. "*Log your thoughts here...*\n\n"
    
    if settings.values and unit.status.current_soul then
        local soul = unit.status.current_soul
        content = content .. "## Attributes & Personality\n"
        content = content .. "### Values\n"
        if soul.personality and soul.personality.values then
            local found_val = false
            for _, val in ipairs(soul.personality.values) do
                if math.abs(val.strength) > 10 then
                    content = content .. "* " .. tostring(df.value_type[val.type]):gsub("_", " "):lower() .. "\n"
                    found_val = true
                end
            end
            if not found_val then content = content .. "No strong values recorded.\n" end
        end
    end

    -- TODO: Fix error with getAppearanceDescription
    -- if settings.appearance then
    --     content = content .. "\n## Appearance\n"
    --     local desc = dfhack.units.getAppearanceDescription(unit)
    --     if desc then
    --         content = content .. utils.sanitize(desc) .. "\n"
    --     else
    --         content = content .. "A citizen of average appearance.\n"
    --     end
    -- end

    -- TODO: Fix error with soul.personality.needs 
    -- if settings.needs and unit.status.current_soul then
    --     content = content .. "\n## Needs & Health\n"
    --     local soul = unit.status.current_soul
    --     if soul.personality and soul.personality.needs then
    --         content = content .. "### Current Needs\n"
    --         for _, need in ipairs(soul.personality.needs) do
    --             if need.level > 0 then
    --                 content = content .. "* " .. tostring(df.need_type[need.id]):lower():gsub("_", " ") .. "\n"
    --             end
    --         end
    --     end
        
    --     -- Health/Medical status
    --     local health_info = dfhack.units.getHealthInfo(unit)
    --     if health_info and #health_info > 0 then
    --         content = content .. "### Health Issues\n"
    --         for _, issue in ipairs(health_info) do
    --             content = content .. "* " .. utils.sanitize(issue) .. "\n"
    --         end
    --     end
    -- end
    
    -- TODO: Fix error with hist_figure_links
    -- if settings.relationships then
    --     content = content .. "\n## Relationships\n"
    --     local hfid = unit.hist_figure_id
    --     if hfid ~= -1 then
    --         local hf = df.historical_figure.find(hfid)
    --         if hf then
    --             for _, link in ipairs(hf.hist_figure_links) do
    --                 local type = link:getType()
    --                 local target_hf = df.historical_figure.find(link.target_hf)
    --                 if target_hf then
    --                     local target_name = utils.get_readable_name(target_hf.name)
    --                     local target_id = nil
    --                     local target_unit = df.unit.find(target_hf.unit_id)
    --                     if target_unit then
    --                         target_id = "citizen:" .. tostring(target_unit.id)
    --                     end
    --                     local link_str = target_name
    --                     if target_id then
    --                         link_str = "[" .. target_name .. "](" .. target_id .. ")"
    --                     end
    --                     content = content .. "* " .. tostring(df.hist_figure_link_type[type]):lower():gsub("^%l", string.upper) .. ": " .. link_str .. "\n"
    --                 end
    --             end
    --         end
    --     else
    --         content = content .. "No known family records.\n"
    --     end
    -- end

    -- TODO: fix error with concatenation with nil value
    -- if settings.skills and unit.status.current_soul then
    --     content = content .. "\n## Notable Skills\n"
    --     for _, skill in ipairs(unit.status.current_soul.skills) do
    --         if skill.rating > 5 then
    --             content = content .. "* " .. tostring(df.job_skill[skill.id]):gsub("_", " "):lower():gsub("^%l", string.upper) .. ": " .. df.skill_rating[skill.rating] .. "\n"
    --         end
    --     end
    -- end

    if settings.timeline then
        content = content .. "\n## History & Timeline\n"
        content = content .. "* Arrived / Logged on " .. utils.get_date_str() .. "\n"
    end
    
    return utils.sanitize(content)
end

return _ENV
