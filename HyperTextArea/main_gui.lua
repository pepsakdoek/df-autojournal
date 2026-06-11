--@module = true

-- example_usage.lua
--
-- Demonstrates HyperTextArea with coloured text, a clickable link, and
-- inline mixed-colour spans.
--
-- Drop hyper_wrapped_text.lua and hyper_text_area.lua into:
--   library/lua/gui/widgets/hyper_text_area/
-- Then require 'gui.widgets.hyper_text_area.hyper_text_area'

local gui        = require('gui')
local widgets    = require('gui.widgets')
local HyperTextAreaLib = reqscript('internal/hta2/hyper_text_area')

local LOG_FILE = dfhack.getDFPath() .. "/wiki_debug.log"
-- ---------------------------------------------------------------------------
-- Build the content.
-- raw_text must equal the concatenation of all span .text fields.
-- ---------------------------------------------------------------------------
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


local display_text = {
    -- Plain string span – uses default text_pen.
    "Welcome to the ",

    -- Coloured span (no click).
    { text = "Dwarf Fortress", pen = COLOR_YELLOW },

    " wiki!\n\n",

    -- Normal paragraph text.
    "You can read more about constructions on the ",

    -- Clickable link span.
    {
        text     = "Constructions page",
        pen      = COLOR_LIGHTBLUE,
        on_click = function()
            local ok, err = xpcall(function()
                log("Constructions link clicked!")
            end, function(err)
                return debug.traceback(err)
            end)
        end,
    },

    ".\n\n",

    -- Multi-colour inline example.
    { text = "[INFO]",    pen = COLOR_LIGHTGREEN },
    " This widget is ",
    { text = "read-only", pen = COLOR_LIGHTRED },
    " - it supports colours and clickable links but not editing.\n\n",

    "Scroll down for more text.\n",
    string.rep("Line filler text to make the area scrollable.\n", 20),
}

-- Build raw_text by concatenating all .text fields (or the string itself).
local function build_raw(spans)
    local t = {}
    for _, s in ipairs(spans) do
        t[#t + 1] = type(s) == 'string' and s or s.text
    end
    return table.concat(t)
end

local raw_text = build_raw(display_text)

-- ---------------------------------------------------------------------------
-- Simple screen wrapper
-- ---------------------------------------------------------------------------

ExampleScreen = defclass(ExampleScreen, gui.ZScreen)
ExampleScreen.ATTRS { focus_path = 'hyper_text_area_example' }

function ExampleScreen:init()
    self:addviews {
        widgets.Window {
            frame       = { w = 60, h = 30 },
            frame_title = 'HyperTextArea Example',
            subviews    = {
                HyperTextAreaLib.HyperTextArea {
                    frame          = { l=1, r=1, t=1, b=1 },
                    raw_text       = raw_text,
                    display_text   = display_text,
                    text_pen       = COLOR_LIGHTCYAN,
                    link_pen       = COLOR_LIGHTBLUE,
                    link_hover_pen = COLOR_WHITE,
                },
            },
        }
    }
end

function ExampleScreen:onDismiss()
    view = nil
end

function show_screen()
    if not dfhack.isMapLoaded() or not dfhack.world.isFortressMode() then
        qerror('wiki requires a fortress map to be loaded')
    end

    view = view and view:raise() or ExampleScreen{}:show()
end

function main()
    show_screen()
end

if not dfhack_flags.module then
    main()
end

return _ENV
