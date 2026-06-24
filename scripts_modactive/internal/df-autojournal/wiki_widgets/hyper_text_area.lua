--@module = true
-- hyper_text_area.lua
--
-- A scrollable rich-text display and editing area for DFHack.
--

local Panel     = require('gui.widgets.containers.panel')
local Scrollbar = require('gui.widgets.scrollbar')
local gui       = require('gui')
local widgets   = require('gui.widgets')

local Toolbar              = reqscript('internal/df-autojournal/wiki_widgets/toolbar').Toolbar
local LinkModal            = reqscript('internal/df-autojournal/wiki_widgets/link_modal').LinkModal
local HyperTextAreaContent = reqscript('internal/df-autojournal/wiki_widgets/hyper_text_area_content').HyperTextAreaContent

-- ===========================================================================
-- HyperTextArea  (public widget)
-- ===========================================================================

HyperTextArea = defclass(HyperTextArea, Panel)
HyperTextArea.ATTRS {
    raw_text         = '',
    display_text     = {},
    text_pen         = COLOR_LIGHTCYAN,
    link_pen         = COLOR_LIGHTBLUE,
    link_hover_pen   = COLOR_WHITE,
    on_click         = DEFAULT_NIL,
    on_text_change   = DEFAULT_NIL,
    on_cursor_change = DEFAULT_NIL,
    on_link_click    = DEFAULT_NIL,
    link_pages       = DEFAULT_NIL,
    debug            = false,
}

function HyperTextArea:init()
    self.render_start_line_y = 1
    self.active_pen = self.text_pen
    self.active_link = nil

    self.toolbar = Toolbar {
        frame = {l=0, w=4, t=0, b=3},
        selected_color = self.active_pen,
        on_color_change = function(color)
            self.active_pen = color
            self.hyper_text_area.active_pen = color
        end,
        on_link_request = function() self:openLinkModal() end,
    }

    self.hyper_text_area = HyperTextAreaContent {   
        frame           = {l=4, r=4, t=0, b=3},
        raw_text        = self.raw_text,
        display_text    = self.display_text,
        text_pen        = self.text_pen,
        link_pen        = self.link_pen,
        link_hover_pen  = self.link_hover_pen,
        on_click        = self.on_click,
        on_text_change  = function(raw, display)
            self.raw_text = raw
            self.display_text = display
            if self.on_text_change then
                self.on_text_change(raw, display)
            end
        end,
        on_cursor_change = function(cursor, old)
            self:onCursorChange(cursor, old)
            if self.on_cursor_change then
                self.on_cursor_change(cursor, old)
            end
        end,
        on_link_click   = function(link_data)
            if self.on_link_click then
                self.on_link_click(link_data)
            end
        end,
        debug           = self.debug,
        active_pen      = self.active_pen,
        active_link     = self.active_link,
    }

    self.scrollbar = Scrollbar {
        frame     = {r=0, t=0, b=3},
        on_scroll = self:callback('onScrollbar'),
    }

    self.info_box = widgets.Label{
        frame = {l=0, r=0, b=0, h=3},
        text = {
            {text = "Shortcuts: ", pen = COLOR_GREY},
            "Ctrl+Shift+Up/Down: Color | Ctrl+Ins: Link | Ctrl+Z/Y: Undo/Redo\n",
            "Left-click: Cursor | ",
            {text = "Ctrl+Click: Follow Link", pen = COLOR_LIGHTCYAN},
            " | Drag: Select"
        }
    }

    self:addviews { self.toolbar, self.hyper_text_area, self.scrollbar, self.info_box }
end

function HyperTextArea:openLinkModal()
    LinkModal{
        pages = self.link_pages,
        on_submit = function(text, page)
            for i = 1, #text do
                table.insert(self.hyper_text_area.char_list, self.hyper_text_area.cursor, {
                    char = text:sub(i, i),
                    pen = self.link_pen,
                    link = page
                })
                self.hyper_text_area.cursor = self.hyper_text_area.cursor + 1
            end
            -- Always add a space after a link to prevent 'end of text' bugs
            table.insert(self.hyper_text_area.char_list, self.hyper_text_area.cursor, {
                char = ' ',
                pen = self.active_pen
            })
            self.hyper_text_area.cursor = self.hyper_text_area.cursor + 1
            self.hyper_text_area:updateContent()
        end
    }:show()
end

function HyperTextArea:setContent(raw_text, display_text)
    self.raw_text    = raw_text
    self.display_text = display_text
    self.render_start_line_y = 1
    self.hyper_text_area:setContent(raw_text, display_text)
    if self.frame_body then self:updateLayout() end
end

function HyperTextArea:setDisplayText(display_text)
    local t = {}
    for _, s in ipairs(display_text) do
        t[#t+1] = type(s) == 'string' and s or s.text
    end
    local raw_text = table.concat(t)
    self:setContent(raw_text, display_text)
end

function HyperTextArea:getRawText() return self.raw_text end

function HyperTextArea:onCursorChange(cursor, old_cursor)
    local x, y = self.hyper_text_area.wrapped_text:indexToCoords(cursor)
    if self.hyper_text_area.frame_body then
        local height = self.hyper_text_area.frame_body.height
        if y >= self.render_start_line_y + height then
            self:updateScrollbar(y - height + 1)
        elseif y < self.render_start_line_y then
            self:updateScrollbar(y)
        end
    end
end

function HyperTextArea:postUpdateLayout()
    self:updateScrollbar(self.render_start_line_y)
end

function HyperTextArea:onScrollbar(scroll_spec)
    local height = self.hyper_text_area.frame_body and self.hyper_text_area.frame_body.height or 1
    local line   = self.render_start_line_y
    if     scroll_spec == 'down_large' then line = line + math.ceil(height / 2)
    elseif scroll_spec == 'up_large'   then line = line - math.ceil(height / 2)
    elseif scroll_spec == 'down_small' then line = line + 1
    elseif scroll_spec == 'up_small'   then line = line - 1
    else                                    line = tonumber(scroll_spec)
    end
    self:updateScrollbar(line)
end

function HyperTextArea:updateScrollbar(target_y)
    local lines_count = #self.hyper_text_area.wrapped_text.lines
    local view_h      = self.hyper_text_area.frame_body and self.hyper_text_area.frame_body.height or 1
    local clamped = math.max(1, math.min(target_y, lines_count - view_h + 1))
    self.scrollbar:update(clamped, view_h, lines_count)
    if view_h >= lines_count then clamped = 1 end
    self.render_start_line_y = clamped
    self.hyper_text_area:setRenderStartLineY(clamped)
end

function HyperTextArea:renderSubviews(dc)
    self.hyper_text_area.frame_body.y1 = self.frame_body.y1 - (self.render_start_line_y - 1)
    HyperTextArea.super.renderSubviews(self, dc)
end

function HyperTextArea:onInput(keys)
    if self.scrollbar.is_dragging then return self.scrollbar:onInput(keys) end

    if keys._MOUSE_L and self:getMousePos() then
        self:setFocus(true)
        self.hyper_text_area:setFocus(true)
    end

    -- Process color and link shortcuts before subviews to ensure they always work
    if keys.CUSTOM_CTRL_SHIFT_UP or keys.CUSTOM_CTRL_SHIFT_DOWN then
        if self.toolbar:onInput(keys) then return true end
    elseif (keys._CTRL or keys._ALT) and keys.KEY_INSERT then
        self:openLinkModal()
        return true
    elseif keys.CUSTOM_CTRL_INSERT then
        self:openLinkModal()
        return true
    end

    if self.toolbar:onInput(keys) then return true end
    return HyperTextArea.super.onInput(self, keys)
end

return HyperTextArea
