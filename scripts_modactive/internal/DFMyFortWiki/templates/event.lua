--@ module = true
local utils = reqscript('internal/DFMyFortWiki/wiki_utils')

local function get_event_template(event_data)
    local title = event_data and event_data.title or "New Event"
    local date = event_data and event_data.date or utils.get_date_str()
    
    local content = "# Event: " .. title .. "\n\n"
    content = content .. "**Date:** " .. date .. "\n"
    content = content .. "**Status:** Logged\n\n"
    
    content = content .. "## Summary\n"
    content = content .. "*Provide a brief summary of what happened.*\n\n"
    
    content = content .. "## Key Participants\n"
    content = content .. "*   [Name](link)\n\n"
    
    content = content .. "## Detailed Account\n"
    content = content .. "*Write the full story here...*\n\n"
    
    content = content .. "## Consequences & Aftermath\n"
    content = content .. "*What changed because of this event?*\n"
    
    return content
end

return get_event_template
