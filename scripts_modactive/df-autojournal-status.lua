--@ overlay df-autojournal-status
-- Status indicator icons for DF Autojournal event listener.
-- Shows two icons: [ON] for listening active and [OFF] for disabled.
-- The current state's icon is bright, the other is dim.

local widgets = require('gui.widgets')
local event_listener = reqscript('internal/df-autojournal/event_listener')

local function ensure_state()
    if not dfhack.mfw_state then dfhack.mfw_state = {} end
end

local function check_persisted()
    local ok, data = pcall(function()
        return dfhack.persistent.getSiteData('mfw_auto_journal_enabled')
    end)
    return ok and data and data.val and data.val[1] == 1
end

-- Auto-start listener on map load if it was enabled
dfhack.onStateChange.auto_journal_listener = function(code)
    if code == SC_MAP_LOADED then
        if dfhack.isWorldLoaded() and dfhack.world.isFortressMode() then
            ensure_state()
            dfhack.mfw_state.listener_enabled = check_persisted()
            if dfhack.mfw_state.listener_enabled and event_listener.start then
                event_listener.start()
            end
        end
    elseif code == SC_WORLD_UNLOADED then
        ensure_state()
        dfhack.mfw_state.listener_enabled = false
        if event_listener.stop then
            event_listener.stop()
        end
    end
end

-- If world already loaded at script init, apply persisted state
if dfhack.isWorldLoaded() and dfhack.world.isFortressMode() then
    ensure_state()
    dfhack.mfw_state.listener_enabled = check_persisted()
    if dfhack.mfw_state.listener_enabled and event_listener.start then
        event_listener.start()
    end
end

OVERLAY_VIEWS = {
    panel = widgets.Panel{
        view_id = 'listener_status',
        frame = {t = 0, r = 2, w = 14, h = 1},
        subviews = {
            widgets.Label{
                view_id = 'status_text',
                text = function()
                    local enabled = dfhack.mfw_state and dfhack.mfw_state.listener_enabled
                    return {
                        { text = string.char(15) .. " ", pen = COLOR_LIGHTCYAN },
                        { text = "ON", pen = enabled and COLOR_GREEN or COLOR_DARKGREY },
                        { text = "/", pen = COLOR_DARKGREY },
                        { text = "OFF", pen = enabled and COLOR_DARKGREY or COLOR_LIGHTRED },
                    }
                end,
            },
        }
    }
}
