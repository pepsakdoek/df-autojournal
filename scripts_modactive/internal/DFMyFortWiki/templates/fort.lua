--@ module = true
local utils = reqscript('internal/DFMyFortWiki/utils')

local function get_fort_template()
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
    
    -- Wealth (if available)
    if df.global.ui.tasks and df.global.ui.tasks.wealth then
        local w = df.global.ui.tasks.wealth
        content = content .. "**Total Wealth:** " .. tostring(w.total) .. "☼\n"
        content = content .. "* Imported: " .. tostring(w.imported) .. "☼\n"
        content = content .. "* Exported: " .. tostring(w.exported) .. "☼\n"
    end
    
    content = content .. "\n## Local Government\n"
    -- Try to find the site government entity
    if site and site.entity_links then
        for _, link in ipairs(site.entity_links) do
            local entity = df.historical_entity.find(link.entity_id)
            if entity and entity.type == df.historical_entity_type.SiteGovernment then
                content = content .. "Government: " .. utils.sanitize(dfhack.df2utf(dfhack.TranslateName(entity.name))) .. "\n"
            end
        end
    end

    content = content .. "\n## Infrastructure & Districts\n"
    content = content .. "*Log important areas of your fort here.*\n\n"

    content = content .. "## Goals & Projects\n"
    content = content .. "*   [ ] Finish the tavern\n"
    content = content .. "*   [ ] Build the magma forge\n\n"

    content = content .. "## Defense Status\n"
    content = content .. "Describe your military and traps here.\n"

    return content
end

return get_fort_template
