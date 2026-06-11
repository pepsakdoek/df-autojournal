--@ module = true
local utils = reqscript('internal/DFMyFortWiki/utils')

local function get_citizen_template(unit)
    local name = dfhack.units.getReadableName(unit)
    local prof = utils.sanitize(dfhack.units.getProfessionName(unit))
    local sex = "Unknown"
    if unit.sex == 0 then sex = "Female"
    elseif unit.sex == 1 then sex = "Male" end
    
    local age = dfhack.units.getAge(unit)
    
    local content = "# " .. name .. "\n\n"
    content = content .. "**Profession:** " .. prof .. "\n"
    content = content .. "**Gender:** " .. sex .. "\n"
    content = content .. "**Age:** " .. age .. "\n\n"
    
    content = content .. "## Personal Journal\n"
    content = content .. "*Log your thoughts here...*\n\n"
    
    content = content .. "## Attributes & Personality\n"
    if unit.status.current_soul then
        local soul = unit.status.current_soul
        -- Simplistic values representation
        content = content .. "### Values\n"
        if soul.personality and soul.personality.values then
            for _, val in ipairs(soul.personality.values) do
                if math.abs(val.strength) > 10 then
                    content = content .. "* " .. tostring(df.value_type[val.type]):gsub("_", " "):lower() .. "\n"
                end
            end
        end
    end
    
    content = content .. "\n## Relationships\n"
    -- Try to find family
    local hfid = unit.hist_figure_id
    if hfid ~= -1 then
        local hf = df.historical_figure.find(hfid)
        if hf then
            for _, link in ipairs(hf.hist_figure_links) do
                local type = link:getType()
                local target_hf = df.historical_figure.find(link.target_hf)
                if target_hf then
                    local target_name = utils.sanitize(dfhack.df2utf(dfhack.TranslateName(target_hf.name)))
                    local target_id = nil
                    
                    -- Check if target is a unit in world
                    local target_unit = df.unit.find(target_hf.unit_id)
                    if target_unit then
                        target_id = "citizen:" .. tostring(target_unit.id)
                    end
                    
                    local link_str = target_name
                    if target_id then
                        link_str = "[" .. target_name .. "](" .. target_id .. ")"
                    end
                    
                    content = content .. "* " .. tostring(df.hist_figure_link_type[type]):lower():gsub("^%l", string.upper) .. ": " .. link_str .. "\n"
                end
            end
        end
    else
        content = content .. "No known family records.\n"
    end
    
    content = content .. "\n## Notable Skills\n"
    if unit.status.current_soul then
        for _, skill in ipairs(unit.status.current_soul.skills) do
            if skill.rating > 5 then
                content = content .. "* " .. tostring(df.job_skill[skill.id]):gsub("_", " "):lower():gsub("^%l", string.upper) .. ": " .. df.skill_rating[skill.rating] .. "\n"
            end
        end
    end
    content = content .. "\n"

    content = content .. "## History & Timeline\n"
    content = content .. "* Arrived / Logged on " .. utils.get_date_str() .. "\n"
    
    return content
end

return get_citizen_template
