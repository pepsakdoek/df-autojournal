--@ module = true
-- Event detail page template.
-- Renders a structured wiki page for a notable event with
-- metadata header, participants list (with links), description,
-- and consequences sections.

local utils = reqscript('internal/df-autojournal/wiki_utils')

function render(event_data)
    local title = event_data and event_data.title or "Event"
    local year = event_data and event_data.year or df.global.cur_year
    local season = event_data and event_data.season or ""
    local category = event_data and event_data.category or "general"
    local participants = event_data and event_data.participants or {}
    local description = event_data and event_data.description or ""
    local consequences = event_data and event_data.consequences or ""
    local links = event_data and event_data.links or {}

    local content = {}

    table.insert(content, { text = "# " .. title, pen = COLOR_YELLOW })
    table.insert(content, "\n\n")

    table.insert(content, { text = "Date: ", pen = COLOR_LIGHTCYAN })
    table.insert(content, { text = "Year " .. year, pen = COLOR_WHITE })
    if season and season ~= "" then
        table.insert(content, ", ")
        table.insert(content, { text = season, pen = COLOR_LIGHTCYAN })
    end
    table.insert(content, "\n")

    table.insert(content, { text = "Category: ", pen = COLOR_LIGHTCYAN })
    local cat_display = category:gsub("^%l", string.upper)
    table.insert(content, { text = cat_display, pen = COLOR_WHITE })
    table.insert(content, "\n\n")

    if description then
        table.insert(content, { text = "## Summary", pen = COLOR_YELLOW })
        table.insert(content, "\n")
        table.insert(content, { text = description, pen = COLOR_WHITE })
        table.insert(content, "\n\n")
    end

    if #participants > 0 then
        table.insert(content, { text = "## Key Participants", pen = COLOR_YELLOW })
        table.insert(content, "\n")
        for _, p in ipairs(participants) do
            table.insert(content, "* ")
            if p.link then
                table.insert(content, { text = p.name or "Unknown", pen = COLOR_LIGHTBLUE, link = p.link })
            else
                table.insert(content, p.name or "Unknown")
            end
            table.insert(content, "\n")
        end
        table.insert(content, "\n")
    end

    if #links > 0 then
        table.insert(content, { text = "## Related", pen = COLOR_YELLOW })
        table.insert(content, "\n")
        for _, link in ipairs(links) do
            table.insert(content, "* ")
            table.insert(content, { text = link.text or "Link", pen = COLOR_LIGHTBLUE, link = link.target })
            table.insert(content, "\n")
        end
        table.insert(content, "\n")
    end

    table.insert(content, { text = "## Detailed Account", pen = COLOR_YELLOW })
    table.insert(content, "\n")
    table.insert(content, { text = "Write the full story here...", pen = COLOR_DARKGREY })
    table.insert(content, "\n\n")

    if consequences and consequences ~= "" then
        table.insert(content, { text = "## Consequences & Aftermath", pen = COLOR_YELLOW })
        table.insert(content, "\n")
        table.insert(content, { text = consequences, pen = COLOR_WHITE })
        table.insert(content, "\n")
    else
        table.insert(content, { text = "## Consequences & Aftermath", pen = COLOR_YELLOW })
        table.insert(content, "\n")
        table.insert(content, { text = "What changed because of this event?", pen = COLOR_DARKGREY })
        table.insert(content, "\n")
    end

    return content
end

return _ENV
