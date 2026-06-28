-- My Fort Wiki
-- Entry point that loads the event listener and wiki UI

local event_listener = reqscript('internal/df-autojournal/event_listener')
local main_gui = reqscript('internal/df-autojournal/main_gui')

if not dfhack_flags.module then
    main_gui.main()
end
