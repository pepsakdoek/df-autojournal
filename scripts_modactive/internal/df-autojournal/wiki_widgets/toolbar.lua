--@module = true
-- toolbar.lua
--
-- A vertical toolbar for HyperTextArea to select colors and insert links.
--

local Widget = require('gui.widgets.widget')

local COLOR_BLOCK   = string.char(219) -- █
local LINK_ICON     = string.char(21)  -- §
local TABLE_ICON    = string.char(30)  -- ▲
local FUNCTION_ICON = string.char(228) -- Σ

Toolbar = defclass(Toolbar, Widget)
Toolbar.ATTRS {
    on_color_change    = DEFAULT_NIL,
    on_link_request    = DEFAULT_NIL,
    on_table_request   = DEFAULT_NIL,
    on_function_request = DEFAULT_NIL,
    selected_color     = 15,
}

function Toolbar:onRenderBody(dc)
    for color = 1, 15 do
        local is_selected = (color == self.selected_color)
        local pen = dfhack.pen.parse({fg=color, bg=COLOR_BLACK})
        local y = color - 1

        if is_selected then
            dc:pen(COLOR_WHITE):seek(0, y):string("*")
            dc:pen(pen):seek(1, y):string(COLOR_BLOCK)
            dc:pen(COLOR_WHITE):seek(2, y):string("*")
        else
            dc:seek(0, y):string(" ")
            dc:pen(pen):seek(1, y):string(COLOR_BLOCK)
            dc:seek(2, y):string(" ")
        end
    end

    -- Function, Table, and Link buttons at the bottom
    dc:pen(COLOR_WHITE):seek(1, dc.height - 3):string(FUNCTION_ICON)
    dc:pen(COLOR_WHITE):seek(1, dc.height - 2):string(TABLE_ICON)
    dc:pen(COLOR_WHITE):seek(1, dc.height - 1):string(LINK_ICON)
end

function Toolbar:onInput(keys)
    if keys.CUSTOM_CTRL_SHIFT_UP then
            local new_color = self.selected_color - 1
            if new_color < 1 then new_color = 15 end
            self.selected_color = new_color
            if self.on_color_change then self.on_color_change(new_color) end
            return true
    elseif keys.CUSTOM_CTRL_SHIFT_DOWN then
            local new_color = self.selected_color + 1
            if new_color > 15 then new_color = 1 end
            self.selected_color = new_color
            if self.on_color_change then self.on_color_change(new_color) end
            return true
    elseif keys.CUSTOM_CTRL_INSERT then
        -- if self.on_link_request then self.on_link_request() end
        -- This is handled in HyperTextAreaContent to open the link modal.
        return true
    end

    if keys._MOUSE_L then
        local x, y = self:getMousePos()
        if x then
            if y >= 0 and y < 15 then
                local color_idx = y + 1
                self.selected_color = color_idx
                if self.on_color_change then self.on_color_change(color_idx) end
                return true
            elseif y == self.frame_body.height - 3 then
                if self.on_function_request then self.on_function_request() end
                return true
            elseif y == self.frame_body.height - 2 then
                if self.on_table_request then self.on_table_request() end
                return true
            elseif y == self.frame_body.height - 1 then
                if self.on_link_request then self.on_link_request() end
                return true
            end
        end
    end
end

return Toolbar
