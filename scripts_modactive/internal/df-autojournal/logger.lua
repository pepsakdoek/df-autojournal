--@ module = true
-- Centralized logging for df-autojournal
-- Logs to wiki_debug.log in the DF root directory

local LOG_FILE = dfhack.getDFPath() .. "/wiki_debug.log"

function log(msg)
    local f = io.open(LOG_FILE, "a")
    if f then
        f:write(os.date("%Y-%m-%d %H:%M:%S") .. " - " .. tostring(msg) .. "\n")
        f:close()
    else
        -- Fallback if we can't open the file
        dfhack.printerr("df-autojournal: Could not open log file at " .. LOG_FILE)
    end
    -- Also print to DFHack console
    dfhack.println("df-autojournal: " .. tostring(msg))
end

function log_error(msg)
    local trace = debug.traceback()
    log("ERROR: " .. tostring(msg) .. "\n" .. trace)
    dfhack.printerr("df-autojournal Error: " .. tostring(msg))
end
