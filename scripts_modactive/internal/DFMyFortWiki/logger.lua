--@ module = true
-- Centralized logging for DFMyFortWiki
-- Logs to wiki_debug.log in the DF root directory

local LOG_FILE = dfhack.getDFPath() .. "/wiki_debug.log"

function log(msg)
    local f = io.open(LOG_FILE, "a")
    if f then
        f:write(os.date("%Y-%m-%d %H:%M:%S") .. " - " .. tostring(msg) .. "\n")
        f:close()
    else
        -- Fallback if we can't open the file
        dfhack.printerr("DFMyFortWiki: Could not open log file at " .. LOG_FILE)
    end
    -- Also print to DFHack console
    dfhack.println("DFMyFortWiki: " .. tostring(msg))
end

return _ENV
