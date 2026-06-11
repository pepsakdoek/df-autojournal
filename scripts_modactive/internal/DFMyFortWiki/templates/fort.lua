--@ module = true
local utils = reqscript('internal/DFMyFortWiki/utils')
local mfw_settings = reqscript('internal/DFMyFortWiki/settings')

local function get_fort_template()
    local settings = mfw_settings.get_settings().fort
    local site_name = "Unknown Fort"
    local site = dfhack.world.getCurrentSite()
    if site then
        site_name = utils.sanitize(dfhack.df2utf(dfhack.TranslateName(site.name)))
    end

    local content = "# Fort: " .. site_name .. "\n\n"
    
    -- Population
    local citizens = 0
    for _, unit in ipairs(df.global.world.units.active) do
        if dfhack.units.isCitizen(unit) then
            citizens = citizens + 1
        end
    end
    content = content .. "**Population:** " .. citizens .. " Citizens\n"
    
    if settings.wealth and df.global.ui.tasks and df.global.ui.tasks.wealth then
        local w = df.global.ui.tasks.wealth
        content = content .. "**Total Wealth:** " .. tostring(w.total) .. "☼\n"
    end
    
    if settings.gov then
        content = content .. "\n## Local Government\n"
        if site and site.entity_links then
            for _, link in ipairs(site.entity_links) do
                local entity = df.historical_entity.find(link.entity_id)
                if entity and entity.type == df.historical_entity_type.SiteGovernment then
                    content = content .. "Government: " .. utils.sanitize(dfhack.df2utf(dfhack.TranslateName(entity.name))) .. "\n"
                end
            end
        end
    end

    if settings.links then
        content = content .. "\n## Economic & Political Links\n"
        -- This is a bit complex, but we can look for trade agreements or linked sites
        local found_link = false
        if site then
            -- Check for linked sites in world data
            for _, other_site in ipairs(df.global.world.world_data.sites) do
                -- Simplified check for proximity or shared entity
                -- Real economic links are in entities
            end
        end
        if not found_link then
            content = content .. "No major economic links established yet.\n"
        end
    end

    if settings.districts then
        content = content .. "\n## Infrastructure & Districts\n"
        content = content .. "*Log important areas of your fort here.*\n\n"
    end

    if settings.timeline then
        content = content .. "## History & Timeline\n"
        content = content .. "* Founding of " .. site_name .. " in year " .. tostring(df.global.cur_year) .. "\n"
    end

    if settings.defense then
        content = content .. "\n## Defense Status\n"
        content = content .. "Describe your military and traps here.\n"
    end

    return content
end

return get_fort_template
