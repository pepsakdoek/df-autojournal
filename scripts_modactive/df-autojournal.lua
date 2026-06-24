-- My Fort Wiki
-- Barebones entry point that delegates to the internal main_gui logic

local main_gui = reqscript('internal/df-autojournal/main_gui')

if not dfhack_flags.module then
    main_gui.main()
end
