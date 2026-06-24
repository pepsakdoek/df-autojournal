--@ module = true
local logger = reqscript('internal/df-autojournal/logger')
local event_parser = reqscript('internal/df-autojournal/event_parser')

local Chronicle = {}
local CHRONICLE_KEY = 'mfw_chronicle_state'

function Chronicle.get_state()
    local ok, data = pcall(function()
        return dfhack.persistent.getSiteData(CHRONICLE_KEY)
    end)
    if ok and data and data.val then
        return data.val
    end
    return {
        last_event_id = df.global.world.history.event_id - 1,
        is_running = false
    }
end

function Chronicle.save_state(state)
    dfhack.persistent.saveSiteData(CHRONICLE_KEY, {val=state})
end

function Chronicle.append_to_page(context, page_id, section_title, text)
    local content = context:load_content(page_id)
    local raw_text = content.text[1] or ""
    
    local section_header = "## " .. section_title
    local start_pos, end_pos = raw_text:find(section_header, 1, true)
    
    if start_pos then
        local next_section = raw_text:find("\n## ", end_pos + 1, true)
        if next_section then
            raw_text = raw_text:sub(1, next_section - 1) .. "\n* " .. text .. raw_text:sub(next_section)
        else
            raw_text = raw_text .. "\n* " .. text .. "\n"
        end
    else
        raw_text = raw_text .. "\n\n" .. section_header .. "\n* " .. text .. "\n"
    end
    
    context:save_content(page_id, raw_text, content.cursor[1])
end

function Chronicle.process_events(context)
    local state = Chronicle.get_state()
    if state.is_running then return end
    state.is_running = true
    Chronicle.save_state(state)

    local current_max_id = df.global.world.history.event_id
    local last_id = state.last_event_id
    
    if last_id >= current_max_id then
        state.is_running = false
        Chronicle.save_state(state)
        return
    end

    logger.log("Chronicle: Processing events from " .. last_id .. " to " .. current_max_id)
    
    local current_site = dfhack.world.getCurrentSite()
    local current_site_id = current_site and current_site.id or -1

    local events = df.global.world.history.events
    local count = 0
    for i = #events - 1, 0, -1 do
        local ev = events[i]
        if ev.id <= last_id then break end
        
        -- Filter by site if possible
        local ev_site = -1
        if ev.getSite then ev_site = ev:getSite() end
        
        if ev_site == -1 or ev_site == current_site_id then
            local parsed = event_parser.parse(ev)
            if parsed and parsed.page_id then
                Chronicle.append_to_page(context, parsed.page_id, parsed.section, parsed.text)
            end
        end
        count = count + 1
        if count > 500 then break end -- Increased limit for scanning, but still bounded
    end
    
    state.last_event_id = current_max_id
    state.is_running = false
    Chronicle.save_state(state)
    logger.log("Chronicle: Processed " .. count .. " events.")
end

function Chronicle.start_background_task(context)
    local function tick()
        if not dfhack.isWorldLoaded() then return end
        
        local data = dfhack.persistent.getSiteData('mfw_auto_journal_enabled')
        local enabled = data and data.val and data.val[1] == 1
        
        if enabled and dfhack.world.isFortressMode() then
            Chronicle.process_events(context)
        end
        
        dfhack.timeout(1, 'min', tick) -- Run every 1 minute if enabled
    end
    
    tick()
end

return Chronicle
