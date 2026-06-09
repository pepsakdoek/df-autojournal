-- Centralized logging for DFMyFortWiki
-- Logs to wiki_debug.log in the DF root directory

-- local _ENV = mkmodule('internal.DFMyFortWiki.logger')

local LOG_FILE = "wiki_debug.log"

function log(msg)
    local f = io.open(LOG_FILE, "a")
    if f then
        f:write(os.date("%Y-%m-%d %H:%M:%S") .. " - " .. tostring(msg) .. "\n")
        f:close()
    end
    -- Also print to DFHack console just in case it is visible
    print("DFMyFortWiki: " .. tostring(msg))
end

-- return _ENV
