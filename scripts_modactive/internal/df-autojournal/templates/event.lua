--@ module = true
local utils = reqscript('internal/df-autojournal/wiki_utils')

function render(event_data)
    local title = event_data and event_data.title or "New Event"
    local date = event_data and event_data.date or utils.get_date_str()

    local content = {}

    table.insert(content, { text = "# Event: " .. title, pen = COLOR_YELLOW })
    table.insert(content, "\n\n")

    table.insert(content, { text = "Date: ", pen = COLOR_LIGHTCYAN })
    table.insert(content, { text = date, pen = COLOR_WHITE })
    table.insert(content, "\n")

    table.insert(content, { text = "Status: ", pen = COLOR_LIGHTCYAN })
    table.insert(content, { text = "Logged", pen = COLOR_LIGHTGREEN })
    table.insert(content, "\n\n")

    table.insert(content, { text = "## Summary", pen = COLOR_YELLOW })
    table.insert(content, "\n")
    table.insert(content, { text = "Provide a brief summary of what happened.", pen = COLOR_DARKGREY })
    table.insert(content, "\n\n")

    table.insert(content, { text = "## Key Participants", pen = COLOR_YELLOW })
    table.insert(content, "\n")
    table.insert(content, "* [Name](link)\n\n")

    table.insert(content, { text = "## Detailed Account", pen = COLOR_YELLOW })
    table.insert(content, "\n")
    table.insert(content, { text = "Write the full story here...", pen = COLOR_DARKGREY })
    table.insert(content, "\n\n")

    table.insert(content, { text = "## Consequences & Aftermath", pen = COLOR_YELLOW })
    table.insert(content, "\n")
    table.insert(content, { text = "What changed because of this event?", pen = COLOR_DARKGREY })
    table.insert(content, "\n")

    return content
end

return _ENV
