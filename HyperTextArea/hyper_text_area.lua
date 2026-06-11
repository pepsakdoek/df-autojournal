--@module = true
-- hyper_text_area.lua
--
-- A read-only, scrollable rich-text display area for DFHack.
--
-- Differences from TextArea:
--  * Read-only – no editing, no cursor, no history.
--  * display_text  – list of span tables (or plain strings) that describe
--                    what is actually rendered.  A span table looks like:
--                      { text = "Click me", pen = COLOR_LIGHTBLUE,
--                        on_click = function() … end }
--    Plain strings inside the list are rendered with the default text_pen.
--  * raw_text      – the plain-ASCII equivalent of display_text concatenated.
--                    Used for line-wrapping width calculations and mouse
--                    hit-testing.  Must match the visible character sequence
--                    of display_text exactly.
--  * Clickable links: any span with an on_click field fires that callback
--                     when left-clicked.
--  * Hover highlight: hovered clickable spans are rendered with link_hover_pen.

local Panel     = require('gui.widgets.containers.panel')
local Scrollbar = require('gui.widgets.scrollbar')
local Widget    = require('gui.widgets.widget')
local gui       = require('gui')

local HyperWrappedTextLib = reqscript('internal/hta2/hyper_wrapped_text')

-- ===========================================================================
-- HyperTextAreaContent  (internal rendering widget)
-- ===========================================================================

HyperTextAreaContent = defclass(HyperTextAreaContent, Widget)

HyperTextAreaContent.ATTRS {
    raw_text          = '',
    display_text      = {},
    text_pen          = COLOR_LIGHTCYAN,
    link_pen          = COLOR_LIGHTBLUE,
    link_hover_pen    = COLOR_WHITE,
    on_click          = DEFAULT_NIL,   -- fallback global click handler
    debug             = false,
}

function HyperTextAreaContent:init()
    self.render_start_line_y = 1
    self.hovered_span        = nil   -- { y, frag_index } of hovered clickable

    self.main_pen = dfhack.pen.parse({bg = COLOR_RESET, bold = true}, self.text_pen)

    self.wrapped_text = HyperWrappedTextLib.HyperWrappedText {
        raw_text     = self.raw_text,
        display_text = self.display_text,
        wrap_width   = 256,
    }
end

function HyperTextAreaContent:setRenderStartLineY(y)
    self.render_start_line_y = y
end

function HyperTextAreaContent:postComputeFrame()
    self:recomputeLines()
end

function HyperTextAreaContent:recomputeLines()
    if not self.frame_body then return end
    -- -1 because the original TextAreaContent reserves one column for cursor
    self.wrapped_text:update(
        self.raw_text,
        self.display_text,
        self.frame_body.width - 1
    )
end

-- Set both texts at once and reflow.
function HyperTextAreaContent:setContent(raw_text, display_text)
    self.raw_text     = raw_text
    self.display_text = display_text
    self:recomputeLines()
end

-- ---------------------------------------------------------------------------
-- rendering
-- ---------------------------------------------------------------------------

-- Strip trailing newline from a raw line string so it is not printed.
local function strip_newline(s)
    if s:sub(-1) == '\n' then return s:sub(1, -2) end
    return s
end

function HyperTextAreaContent:onRenderBody(dc)
    local lines       = self.wrapped_text.lines
    local line_spans  = self.wrapped_text.line_spans
    local start_y     = self.render_start_line_y
    local end_y       = math.min(start_y + dc.height - 1, #lines)

    -- Detect hovered position for link highlighting.
    local hover_mx, hover_my = self:getMousePos()
    -- hover_mx/my are 0-based within frame_body; convert to 1-based wrapped coords.
    local hover_wx = hover_mx and (hover_mx + 1) or nil
    local hover_wy = hover_my and (hover_my + start_y) or nil   -- wrapped-text row

    for line_idx = start_y, end_y do
        local frags   = line_spans[line_idx]
        local draw_y  = line_idx - start_y   -- 0-based screen row

        if not frags or #frags == 0 then
            dc:seek(0, draw_y):newline()
        else
            local col = 0  -- current column within the line (0-based)
            for _, frag in ipairs(frags) do
                local frag_text = frag.text
                -- strip newline from last fragment of a line
                if col + #frag_text >= #lines[line_idx] then
                    frag_text = strip_newline(frag_text)
                end

                if #frag_text == 0 then
                    -- nothing to draw for this frag
                else
                    -- Choose pen.
                    local pen
                    if frag.on_click then
                        -- Check if mouse is hovering over this fragment.
                        local is_hovered = hover_wx and hover_wy and
                            (hover_wy == line_idx) and
                            (hover_wx > col) and
                            (hover_wx <= col + #frag_text)

                        pen = is_hovered and
                            dfhack.pen.parse({bg=COLOR_RESET, bold=true}, self.link_hover_pen) or
                            dfhack.pen.parse({bg=COLOR_RESET, bold=true}, self.link_pen)
                    elseif frag.pen then
                        pen = dfhack.pen.parse({bg=COLOR_RESET, bold=true}, frag.pen)
                    else
                        pen = self.main_pen
                    end

                    dc:pen(pen):seek(col, draw_y):string(frag_text)
                end

                col = col + #frag.text
            end
        end
    end

    if self.debug then
        local dbg = string.format(
            'lines:%d start:%d hover:(%s,%s)',
            #lines,
            start_y,
            tostring(hover_wx),
            tostring(hover_wy)
        )
        dc:pen({fg=COLOR_LIGHTRED, bg=COLOR_RESET})
            :seek(0, dc.height - 1)
            :string(dbg)
    end
end

-- ---------------------------------------------------------------------------
-- input
-- ---------------------------------------------------------------------------

function HyperTextAreaContent:onInput(keys)
    if keys._MOUSE_L then
        local mx, my = self:getMousePos()
        if mx and my then
            -- Convert to 1-based wrapped-text coordinates.
            local wx = mx + 1
            local wy = my + self.render_start_line_y

            local handler = self.wrapped_text:getClickHandlerAt(wx, wy)
            if handler then
                handler()
                return true
            elseif self.on_click then
                -- global fallback with raw-text index
                local idx = self.wrapped_text:coordsToIndex(wx, wy)
                self.on_click(idx)
                return true
            end
        end
    end

    return HyperTextAreaContent.super.onInput(self, keys)
end

-- ===========================================================================
-- HyperTextArea  (public widget – mirrors TextArea's panel structure)
-- ===========================================================================

HyperTextArea = defclass(HyperTextArea, Panel)

HyperTextArea.ATTRS {
    -- Plain ASCII equivalent; drives wrapping calculations.
    raw_text       = '',
    -- Rich display spans.  Each entry is either a plain string or a table:
    --   { text=string, pen=COLOR_xxx, on_click=function }
    display_text   = {},
    text_pen       = COLOR_LIGHTCYAN,
    link_pen       = COLOR_LIGHTBLUE,
    link_hover_pen = COLOR_WHITE,
    on_click       = DEFAULT_NIL,
    debug          = false,
}

function HyperTextArea:init()
    self.render_start_line_y = 1

    self.text_area = HyperTextAreaContent {
        frame          = {l=0, r=3, t=0},
        raw_text       = self.raw_text,
        display_text   = self.display_text,
        text_pen       = self.text_pen,
        link_pen       = self.link_pen,
        link_hover_pen = self.link_hover_pen,
        on_click       = self.on_click,
        debug          = self.debug,
    }

    self.scrollbar = Scrollbar {
        frame     = {r=0, t=1},
        on_scroll = self:callback('onScrollbar'),
    }

    self:addviews { self.text_area, self.scrollbar }
end

-- ---------------------------------------------------------------------------
-- public API
-- ---------------------------------------------------------------------------

-- Set content.  raw_text must be the plain-text equivalent of display_text.
function HyperTextArea:setContent(raw_text, display_text)
    self.raw_text    = raw_text
    self.display_text = display_text
    self.text_area:setContent(raw_text, display_text)
    if self.frame_body then
        self:updateLayout()
    end
end

function HyperTextArea:getRawText()
    return self.raw_text
end

-- ---------------------------------------------------------------------------
-- scrolling (mirrors TextArea)
-- ---------------------------------------------------------------------------

function HyperTextArea:postUpdateLayout()
    self:updateScrollbar(self.render_start_line_y)
end

function HyperTextArea:onScrollbar(scroll_spec)
    local height = self.text_area.frame_body and self.text_area.frame_body.height or 1
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
    local lines_count = #self.text_area.wrapped_text.lines
    local view_h      = self.text_area.frame_body and self.text_area.frame_body.height or 1

    local clamped = math.max(1, math.min(target_y, lines_count - view_h + 1))

    self.scrollbar:update(clamped, self.frame_body and self.frame_body.height or 1, lines_count)

    if view_h >= lines_count then
        clamped = 1
    end

    self.render_start_line_y = clamped
    self.text_area:setRenderStartLineY(clamped)
end

-- ---------------------------------------------------------------------------
-- render & input
-- ---------------------------------------------------------------------------

function HyperTextArea:renderSubviews(dc)
    -- Slide the content widget upward by the scroll offset (same trick as TextArea).
    self.text_area.frame_body.y1 = self.frame_body.y1 - (self.render_start_line_y - 1)
    HyperTextArea.super.renderSubviews(self, dc)
end

function HyperTextArea:onInput(keys)
    if self.scrollbar.is_dragging then
        return self.scrollbar:onInput(keys)
    end
    if keys._MOUSE_L and self:getMousePos() then
        self:setFocus(true)
    end
    return HyperTextArea.super.onInput(self, keys)
end

return HyperTextArea
