--@ module = true
local utils = reqscript('internal/DFMyFortWiki/utils')

local EventParser = {}

function EventParser.get_unit_link(unit_id)
    local unit = df.unit.find(unit_id)
    if unit then
        local name = utils.sanitize(dfhack.units.getReadableName(unit))
        return "[" .. name .. "](citizen:" .. tostring(unit_id) .. ")"
    end
    return "Unknown Dwarf"
end

function EventParser.get_hf_link(hf_id)
    local hf = df.historical_figure.find(hf_id)
    if hf then
        local name = utils.sanitize(dfhack.df2utf(dfhack.TranslateName(hf.name)))
        local unit_id = hf.unit_id
        if unit_id ~= -1 then
            return "[" .. name .. "](citizen:" .. tostring(unit_id) .. ")"
        end
        return name
    end
    return "Unknown Figure"
end

-- Check if an HF is a citizen
function EventParser.is_citizen(hf_id)
    if hf_id == -1 then return false end
    local hf = df.historical_figure.find(hf_id)
    if not hf then return false end
    local unit = df.unit.find(hf.unit_id)
    if not unit then return false end
    return dfhack.units.isCitizen(unit)
end

function EventParser.parse(event)
    local type = event:getType()
    local year = event.year
    
    if type == df.history_event_type.HIST_FIGURE_NEW_PET then
        -- Often used for births in history
        if EventParser.is_citizen(event.group_hf) then
            return {
                page_id = "citizen:" .. tostring(df.historical_figure.find(event.group_hf).unit_id),
                section = "History & Timeline",
                text = "Adopted a pet or child in year " .. year, -- Births are sometimes represented this way
                importance = 1
            }
        end
    elseif type == df.history_event_type.HIST_FIGURE_DIED then
        if EventParser.is_citizen(event.victim_hf) then
            local cause = tostring(df.death_type[event.death_cause]):lower():gsub("_", " ")
            return {
                page_id = "citizen:" .. tostring(df.historical_figure.find(event.victim_hf).unit_id),
                section = "History & Timeline",
                text = "Died in year " .. year .. ", cause: " .. cause,
                importance = 1
            }
        end
    elseif type == df.history_event_type.ARTIFACT_CREATED then
        -- Check if it happened at our site
        -- (Site check usually happens in Chronicle loop but we can double check here)
        return {
            page_id = "artifacts",
            section = "Recent Events",
            text = "Artifact created in year " .. year,
            importance = 1
        }
    elseif type == df.history_event_type.HIST_FIGURE_RENAME then
        if EventParser.is_citizen(event.hf) then
            return {
                page_id = "citizen:" .. tostring(df.historical_figure.find(event.hf).unit_id),
                section = "History & Timeline",
                text = "Earned a new name in year " .. year,
                importance = 1
            }
        end
    end
    
    return nil
end

return EventParser
