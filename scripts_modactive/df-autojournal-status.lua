--@ module=true

local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')
local event_listener = reqscript('internal/df-autojournal/event_listener')

local _DIR = debug.getinfo(1, 'S').source:match('^@(.*[/\\])') or ''

local TILE_W    = 8
local TILE_H    = 12
local LOGO_COLS = 4
local LOGO_ROWS = 3
local PNG_COLS  = 8

--- Load a PNG and return normal_pens, hover_pens (left/right halves).
local function load_png_pens(filename)
    local path = _DIR .. filename
    local ok, handles = pcall(dfhack.textures.loadTileset, path, TILE_W, TILE_H, true)
    if not ok or not handles or #handles == 0 then return nil, nil end
    local normal, hover = {}, {}
    for row = 0, LOGO_ROWS - 1 do
        for col = 0, LOGO_COLS - 1 do
            local ni = row * PNG_COLS + col + 1
            local hi = row * PNG_COLS + LOGO_COLS + col + 1
            normal[#normal + 1] =
                dfhack.pen.parse{tile=dfhack.textures.getTexposByHandle(handles[ni]), ch=32}
            hover[#hover + 1] =
                dfhack.pen.parse{tile=dfhack.textures.getTexposByHandle(handles[hi]), ch=32}
        end
    end
    return normal, hover
end

local on_normal, on_hover  = load_png_pens('AutoJournal_on.png')
local off_normal, off_hover = load_png_pens('AutoJournal_off.png')

local LogoButton = defclass(LogoButton, widgets.Panel)
LogoButton.ATTRS{
    normal_pens = DEFAULT_NIL,
    hover_pens  = DEFAULT_NIL,
    on_click    = DEFAULT_NIL,
}

function LogoButton:onRenderBody(dc)
    local hovered = self:getMousePos() ~= nil
    local pens = (hovered and self.hover_pens) or self.normal_pens
    for row = 0, LOGO_ROWS - 1 do
        for col = 0, LOGO_COLS - 1 do
            dc:seek(col, row):char(32, pens[row * LOGO_COLS + col + 1])
        end
    end
end

function LogoButton:onInput(keys)
    if keys._MOUSE_L and self:getMousePos() then
        if self.on_click then self.on_click() end
        return true
    end
    return LogoButton.super.onInput(self, keys)
end

AutoJournalButton = defclass(AutoJournalButton, overlay.OverlayWidget)

AutoJournalButton.ATTRS{
    default_pos     = {x=-3, y=-4},
    default_enabled = true,
    viewscreens     = {'dwarfmode', 'dwarfmode/'},
    frame           = {w=LOGO_COLS * 2, h=LOGO_ROWS},
    overlay_onupdate_max_freq_seconds = 0,
}

function AutoJournalButton:onInput(keys)
    if keys.CUSTOM_ALT_J then
        dfhack.run_command('df-autojournal')
        return true
    end
    return AutoJournalButton.super.onInput(self, keys)
end

function AutoJournalButton:overlay_onupdate()
    if not dfhack.mfw_state then dfhack.mfw_state = {} end
    if dfhack.mfw_state.listener_enabled == nil then
        dfhack.mfw_state.listener_enabled = false
    end
    local enabled = dfhack.mfw_state.listener_enabled
    if self._btn_on and self._btn_off then
        self._btn_on.visible  = enabled
        self._btn_off.visible = not enabled
    elseif self._text then
        self._text:setText(enabled and 'AJ:ON' or 'AJ:OFF')
        self._text.text_pen = enabled and COLOR_GREEN or COLOR_RED
    end
end

function AutoJournalButton:init()
    if not dfhack.mfw_state then dfhack.mfw_state = {} end
    if dfhack.mfw_state.listener_enabled == nil then
        local ok, data = pcall(function()
            return dfhack.persistent.getSiteData('mfw_auto_journal_enabled')
        end)
        dfhack.mfw_state.listener_enabled = ok and data and data.val and data.val[1] == 1
    end

    local has_png = on_normal and on_hover and off_normal and off_hover
    if has_png then
        self._btn_on = LogoButton{
            frame       = {l=0, t=0, w=LOGO_COLS, h=LOGO_ROWS},
            normal_pens = on_normal,
            hover_pens  = on_hover,
            on_click    = function() dfhack.run_command('df-autojournal') end,
        }
        self._btn_off = LogoButton{
            frame       = {l=LOGO_COLS, t=0, w=LOGO_COLS, h=LOGO_ROWS},
            normal_pens = off_normal,
            hover_pens  = off_hover,
            on_click    = function() dfhack.run_command('df-autojournal') end,
        }
        local enabled = dfhack.mfw_state.listener_enabled
        self._btn_on.visible  = enabled
        self._btn_off.visible = not enabled
        self:addviews{self._btn_on, self._btn_off}
    else
        local enabled = dfhack.mfw_state.listener_enabled
        self._text = widgets.TextButton{
            view_id     = 'aj_text',
            frame       = {l=0, t=0},
            label       = enabled and 'AJ:ON' or 'AJ:OFF',
            text_pen    = enabled and COLOR_GREEN or COLOR_RED,
            on_activate = function() dfhack.run_command('df-autojournal') end,
        }
        self:addviews{self._text}
    end
end

-- Auto-start/stop listener
local function ensure_state()
    if not dfhack.mfw_state then dfhack.mfw_state = {} end
end

local function check_persisted()
    local ok, data = pcall(function()
        return dfhack.persistent.getSiteData('mfw_auto_journal_enabled')
    end)
    return ok and data and data.val and data.val[1] == 1
end

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

if dfhack.isWorldLoaded() and dfhack.world.isFortressMode() then
    ensure_state()
    dfhack.mfw_state.listener_enabled = check_persisted()
    if dfhack.mfw_state.listener_enabled and event_listener.start then
        event_listener.start()
    end
end

OVERLAY_WIDGETS = {
    button = AutoJournalButton,
}

return _ENV
