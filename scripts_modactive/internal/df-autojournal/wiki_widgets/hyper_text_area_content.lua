--@module = true
-- hyper_text_area_content.lua
--
-- The internal rendering and editing logic for HyperTextArea.
--

local gui    = require('gui')
local Widget = require('gui.widgets.widget')

local HUtils = reqscript('internal/df-autojournal/wiki_widgets/hta_utils')
local HistoryStore  = reqscript('internal/df-autojournal/wiki_widgets/history_store').HistoryStore
local HyperWrappedText = reqscript('internal/df-autojournal/wiki_widgets/hyper_wrapped_text').HyperWrappedText

local HISTORY_ENTRY = HistoryStore.HISTORY_ENTRY

 HyperTextAreaContent = defclass(HyperTextAreaContent, Widget)

HyperTextAreaContent.ATTRS {
    raw_text          = '',
    display_text      = {},
    text_pen          = COLOR_LIGHTCYAN,
    link_pen          = COLOR_LIGHTBLUE,
    link_hover_pen    = COLOR_WHITE,
    pen_selection     = COLOR_CYAN,
    on_click          = DEFAULT_NIL,
    on_text_change    = DEFAULT_NIL,
    on_cursor_change  = DEFAULT_NIL,
    on_link_click     = DEFAULT_NIL,
    debug             = false,
    active_pen        = DEFAULT_NIL,
    active_link       = DEFAULT_NIL,
    history_size      = 25,
}

function HyperTextAreaContent:init()
    self.render_start_line_y = 1
    self.sel_end             = nil
    self.cursor              = 1
    self.last_cursor_x       = nil

    self.main_pen = dfhack.pen.parse({bg = COLOR_RESET, bold = true}, self.text_pen)
    self.sel_pen  = dfhack.pen.parse(self.main_pen, nil, self.pen_selection)

    self.table_blocks = {}
    self:_extract_table_blocks()

    self.char_list = HUtils.build_char_list(self.display_text)
    self.cursor    = math.max(1, #self.char_list + 1)

    self.wrapped_text = HyperWrappedText {
        display_text = self.display_text,
        wrap_width   = 256,
    }

    self._next_table_id = 1
    for _, tb in ipairs(self.table_blocks) do
        if tb.id and tb.id >= self._next_table_id then
            self._next_table_id = tb.id + 1
        end
    end

    self.history = HistoryStore{history_size=self.history_size}
    self.nav_time = 0
end

function HyperTextAreaContent:setRenderStartLineY(y)
    self.render_start_line_y = y
end

-- Extract table blocks from display_text and store them with position tracking.
-- Each entry: { pos = char_index, columns, rows, sort_col, sort_asc, max_rows }
function HyperTextAreaContent:_extract_table_blocks()
    self.table_blocks = {}
    local text_pos = 1  -- current position in char_list
    for _, entry in ipairs(self.display_text) do
        if HUtils.is_table_block(entry) then
            local id = entry.id
            if not id then
                id = self._next_table_id
                self._next_table_id = self._next_table_id + 1
            elseif id >= self._next_table_id then
                self._next_table_id = id + 1
            end
            table.insert(self.table_blocks, {
                pos      = text_pos,
                columns  = entry.columns,
                rows     = copyall(entry.rows),
                sort_col = entry.sort_col,
                sort_asc = entry.sort_asc,
                max_rows = entry.max_rows,
                id       = id,
            })
        else
            local span = HUtils.to_span(entry)
            text_pos = text_pos + #span.text
        end
    end
end

-- Rebuild display_text from char_list + table_blocks.
-- Table blocks are inserted at their tracked positions in the character stream.
function HyperTextAreaContent:rebuild_display_text()
    local display = {}
    local char_idx = 1

    table.sort(self.table_blocks, function(a, b) return a.pos < b.pos end)

    for _, tb in ipairs(self.table_blocks) do
        if tb.pos > char_idx then
            local seg_chars = {}
            for i = char_idx, math.min(tb.pos - 1, #self.char_list) do
                table.insert(seg_chars, self.char_list[i])
            end
            if #seg_chars > 0 then
                local spans = HUtils.collapse_chars(seg_chars)
                for _, span in ipairs(spans) do
                    table.insert(display, span)
                end
            end
            char_idx = tb.pos
        end
        table.insert(display, {
            type     = 'table',
            columns  = tb.columns,
            rows     = tb.rows,
            sort_col = tb.sort_col,
            sort_asc = tb.sort_asc,
            max_rows = tb.max_rows,
            id       = tb.id,
            name     = tb.name,
        })
    end

    if char_idx <= #self.char_list then
        local seg_chars = {}
        for i = char_idx, #self.char_list do
            table.insert(seg_chars, self.char_list[i])
        end
        if #seg_chars > 0 then
            local spans = HUtils.collapse_chars(seg_chars)
            for _, span in ipairs(spans) do
                table.insert(display, span)
            end
        end
    end

    self.display_text = display
end

function HyperTextAreaContent:cursor_at_table(cursor)
    local c = cursor or self.cursor
    for _, tb in ipairs(self.table_blocks) do
        if tb.pos == c then return true end
    end
    return false
end

function HyperTextAreaContent:_find_table_pos(entry_id)
    for _, tb in ipairs(self.table_blocks) do
        if tb.id == entry_id then
            return tb.pos
        end
    end
    return nil
end

function HyperTextAreaContent:_adjust_table_positions_after_insert(at_pos, count)
    for _, tb in ipairs(self.table_blocks) do
        if tb.pos >= at_pos then
            tb.pos = tb.pos + count
        end
    end
end

function HyperTextAreaContent:_adjust_table_positions_after_delete(from_pos, to_pos)
    local range_len = to_pos - from_pos + 1
    for _, tb in ipairs(self.table_blocks) do
        if tb.pos > to_pos then
            tb.pos = tb.pos - range_len
        elseif tb.pos > from_pos and tb.pos <= to_pos then
            tb.pos = from_pos
        end
    end
end

function HyperTextAreaContent:postComputeFrame()
    self:recomputeLines()
end

function HyperTextAreaContent:recomputeLines()
    if not self.frame_body then
        self.char_list = HUtils.build_char_list(self.display_text)
        self.raw_text = HUtils.char_list_to_raw(self.char_list)
        return
    end
    self.wrapped_text:update(
        self.display_text,
        self.frame_body.width - 1
    )
    self.raw_text = self.wrapped_text.raw_text
    self.char_list = self.wrapped_text.char_list
end

function HyperTextAreaContent:updateContent()
    self.raw_text = HUtils.char_list_to_raw(self.char_list)
    self:rebuild_display_text()
    if self.on_text_change then
        self.on_text_change(self.raw_text, self.display_text)
    end
    self:recomputeLines()
end

function HyperTextAreaContent:setCursor(offset)
    local old = self.cursor
    self.cursor = math.max(1, math.min(#self.char_list + 1, offset))
    self.sel_end = nil
    self.last_cursor_x = nil
    if self.on_cursor_change and self.cursor ~= old then
        self.on_cursor_change(self.cursor, old)
    end
end

function HyperTextAreaContent:maxCursor()
    return #self.char_list + 1
end

function HyperTextAreaContent:hasSelection()
    if not self.sel_end then return false end
    if self.cursor < 1 or self.cursor > self:maxCursor() then return false end
    if self.sel_end < 1 or self.sel_end > self:maxCursor() then return false end
    return true
end

function HyperTextAreaContent:eraseSelection()
    if self:hasSelection() then
        local from, to = self.cursor, self.sel_end
        if from > to then from, to = to, from end
        for i = to, from, -1 do
            table.remove(self.char_list, i)
        end
        self:_adjust_table_positions_after_delete(from, to)
        self:setCursor(from)
        self:updateContent()
    end
end

function HyperTextAreaContent:insert(char_obj)
    self:eraseSelection()
    table.insert(self.char_list, self.cursor, char_obj)
    self:_adjust_table_positions_after_insert(self.cursor, 1)
    self:setCursor(self.cursor + 1)
    self:updateContent()
end

function HyperTextAreaContent:setContent(display_text)
    self.display_text = display_text
    self.cursor       = 1
    self.sel_end      = nil
    self.render_start_line_y = 1
    self.nav_time     = 0
    self:_extract_table_blocks()
    self:recomputeLines()
end

-- Clipboard Logic Integration
function HyperTextAreaContent:getClipboardText()
    if dfhack.internal.getClipboardTextCp437Multiline then
        return table.concat(dfhack.internal.getClipboardTextCp437Multiline(), '\n')
    else
        return dfhack.internal.getClipboardTextCp437()
    end
end

function HyperTextAreaContent:setClipboardText(text)
    if dfhack.internal.setClipboardTextCp437Multiline then
        dfhack.internal.setClipboardTextCp437Multiline(text)
    else
        dfhack.internal.setClipboardTextCp437(text)
    end
end

function HyperTextAreaContent:copy()
    if not self:hasSelection() then return end
    local from, to = self.cursor, self.sel_end
    if from > to then from, to = to, from end
    
    local selected_chars = {}
    for i = from, to - 1 do
        table.insert(selected_chars, self.char_list[i].char)
    end
    self:setClipboardText(table.concat(selected_chars))
end

function HyperTextAreaContent:cut()
    if not self:hasSelection() then return end
    self:copy()
    self:eraseSelection()
end

function HyperTextAreaContent:paste()
    local clipboard = self:getClipboardText()
    if not clipboard or clipboard == "" then return end
    
    self:eraseSelection()
    local insert_pos = self.cursor
    for i = 1, #clipboard do
        local c = clipboard:sub(i, i)
        table.insert(self.char_list, self.cursor, {
            char = c,
            pen = self.active_pen,
            link = self.active_link
        })
        self.cursor = self.cursor + 1
    end
    self:_adjust_table_positions_after_insert(insert_pos, #clipboard)
    self:updateContent()
end

local function strip_newline(s)
    if s:sub(-1) == '\n' then return s:sub(1, -2) end
    return s
end

function HyperTextAreaContent:onRenderBody(dc)
    local lines       = self.wrapped_text.lines
    local line_spans  = self.wrapped_text.line_spans
    local start_y     = self.render_start_line_y
    local end_y       = math.min(start_y + dc.height - 1, #lines)

    local hover_mx, hover_my = self:getMousePos()
    local hover_wx = hover_mx and (hover_mx + 1) or nil
    local hover_wy = hover_my and (hover_my + start_y) or nil

    local sel_from, sel_to
    if self:hasSelection() then
        sel_from = math.min(self.cursor, self.sel_end)
        sel_to   = math.max(self.cursor, self.sel_end)
    end

    local char_idx = 1
    for i = 1, start_y - 1 do
        if not self.wrapped_text:is_table_line(i) then
            char_idx = char_idx + #lines[i]
        end
    end

    for line_idx = start_y, end_y do
        local frags   = line_spans[line_idx]
        local draw_y  = line_idx - start_y
        local col     = 0
        local is_table_line = self.wrapped_text:is_table_line(line_idx)

        if not frags or #frags == 0 then
            dc:seek(0, draw_y):newline()
        else
            for _, frag in ipairs(frags) do
                local frag_text = frag.text
                if col + #frag_text >= #lines[line_idx] then
                    frag_text = strip_newline(frag_text)
                end

                for i = 1, #frag_text do
                    local c = frag_text:sub(i, i)
                    local is_selected = not is_table_line and
                        sel_from and (char_idx >= sel_from and char_idx < sel_to)
                    
                    local pen
                    if is_selected then
                        pen = self.sel_pen
                    elseif frag.link then
                        local is_hovered = hover_wx and hover_wy and
                            (hover_wy == line_idx) and (hover_wx == col + i)
                        pen = is_hovered and
                            dfhack.pen.parse({bg=COLOR_RESET, bold=true}, self.link_hover_pen) or
                            dfhack.pen.parse({bg=COLOR_RESET, bold=true}, self.link_pen)
                    elseif frag.pen then
                        pen = dfhack.pen.parse({bg=COLOR_RESET, bold=true}, frag.pen)
                    else
                        pen = self.main_pen
                    end

                    dc:pen(pen):seek(col + i - 1, draw_y):string(c)
                    if not is_table_line then
                        char_idx = char_idx + 1
                    end
                end
                col = col + #frag.text
            end
            if not is_table_line and line_idx < #lines then
                char_idx = char_idx + (#lines[line_idx] - #strip_newline(lines[line_idx]))
            end
        end
    end

    local show_focus = not self:hasSelection() and (self.focus and gui.blink_visible(500))
    if show_focus then
        local cx, cy = self.wrapped_text:indexToCoords(self.cursor)
        local draw_y = cy - start_y
        if draw_y >= 0 and draw_y < dc.height then
            dc:pen(COLOR_WHITE):seek(cx - 1, draw_y):string("_")
        end
    end
end

function HyperTextAreaContent:lineStartOffset(offset)
    local loc_offset = offset or self.cursor
    local raw = HUtils.char_list_to_raw(self.char_list)
    return raw:sub(1, loc_offset - 1):match(".*\n()") or 1
end

function HyperTextAreaContent:lineEndOffset(offset)
    local loc_offset = offset or self.cursor
    local raw = HUtils.char_list_to_raw(self.char_list)
    return raw:find("\n", loc_offset) or #self.char_list + 1
end

function HyperTextAreaContent:wordStartOffset(offset)
    local raw = HUtils.char_list_to_raw(self.char_list)
    return raw:sub(1, (offset or self.cursor) - 1):match('.*%s()[^%s]') or 1
end

function HyperTextAreaContent:wordEndOffset(offset)
    local raw = HUtils.char_list_to_raw(self.char_list)
    return raw:match('%s*[^%s]*()', offset or self.cursor) or #self.char_list + 1
end

function HyperTextAreaContent:onInput(keys)
    if self.focus then
        if self:onHistoryInput(keys) then return true end
        if self:onTextManipulationInput(keys) then return true end
        if self:onCursorInput(keys) then return true end
        
        -- Structural Clipboard & Selection macro handlers
        if keys.CUSTOM_CTRL_C then
            self:copy()
            return true
        elseif keys.CUSTOM_CTRL_X then
            if self:cursor_at_table() then return true end
            self.history:store(HISTORY_ENTRY.OTHER, self.char_list, self.cursor, self.table_blocks)
            self:cut()
            return true
        elseif keys.CUSTOM_CTRL_V then
            if self:cursor_at_table() then return true end
            self.history:store(HISTORY_ENTRY.OTHER, self.char_list, self.cursor, self.table_blocks)
            self:paste()
            return true
        elseif keys.CUSTOM_CTRL_A then
            self.cursor = 1
            self.sel_end = #self.char_list + 1
            return true
        end
    end

    if keys._MOUSE_L then
        local mx, my = self:getMousePos()
        local modifiers = dfhack.internal.getModifiers()
        if mx and my then
            local wx, wy = mx + 1, my + self.render_start_line_y

            -- Check table lines first
            local tr, local_y = self.wrapped_text:get_table_at_line(wy)
            if tr then
                local handler = tr.table:get_handler_at(local_y, wx)
                if handler then
                    if handler.type == 'sort' then
                        tr.table:sort_column(handler.col)
                        if tr.entry then
                            tr.entry.sort_col = tr.table.sort_col
                            tr.entry.sort_asc = tr.table.sort_asc
                            -- Sync back to the matching table_blocks entry
                            for _, tb in ipairs(self.table_blocks) do
                                if tb.id == tr.entry.id then
                                    tb.sort_col = tr.table.sort_col
                                    tb.sort_asc = tr.table.sort_asc
                                    break
                                end
                            end
                        end
                        self:updateContent()
                        return true
                    elseif handler.type == 'link' then
                        if modifiers.ctrl then
                            if self.on_link_click then
                                self.on_link_click(handler.data)
                            end
                            self.sel_end = nil
                            self.nav_time = os.clock()
                            return true
                        end
                    end
                end
                -- Snap cursor to the nearest text boundary at this table
                if tr.entry then
                    local tb_pos = self:_find_table_pos(tr.entry.id)
                    if tb_pos then
                        self:setCursor(tb_pos)
                    end
                end
                self.sel_end = nil
                return true
            end

            local link_data, start_idx = self.wrapped_text:getClickHandlerAt(wx, wy)
            if link_data and modifiers.ctrl then
                self:setCursor(start_idx)
                if self.on_link_click then
                    self.on_link_click(link_data)
                end
                self.sel_end = nil
                self.nav_time = os.clock()
                return true
            end
            self:setCursor(self.wrapped_text:coordsToIndex(wx, wy))
            return true
        end
    elseif keys._MOUSE_L_DOWN then
        local mx, my = self:getMousePos()
        if mx and my then
            if self.nav_time > 0 and os.clock() - self.nav_time < 0.25 then
                self.sel_end = nil
                return true
            end
            local modifiers = dfhack.internal.getModifiers()
            local wx, wy = mx + 1, my + self.render_start_line_y

            -- Don't start a drag selection on table lines
            local tr = self.wrapped_text:get_table_at_line(wy)
            if tr then
                self.sel_end = nil
                if tr.entry then
                    local tb_pos = self:_find_table_pos(tr.entry.id)
                    if tb_pos then
                        self:setCursor(tb_pos)
                    end
                end
                return true
            end

            local link_data = self.wrapped_text:getClickHandlerAt(wx, wy)
            if link_data and modifiers.ctrl then
                self.sel_end = nil
                return true
            end

            local offset = self.wrapped_text:coordsToIndex(wx, wy)
            if self.cursor ~= offset then
                self.sel_end = offset
            else
                self.sel_end = nil
            end
            return true
        end
    end
    return HyperTextAreaContent.super.onInput(self, keys)
end

function HyperTextAreaContent:onHistoryInput(keys)
    if keys.CUSTOM_CTRL_Z then
        local entry = self.history:undo(self.char_list, self.cursor, self.table_blocks)
        if entry then
            self.char_list    = copyall(entry.char_list)
            self.cursor       = entry.cursor
            self.table_blocks = copyall(entry.table_blocks or {})
            self:updateContent()
        end
        return true
    elseif keys.CUSTOM_CTRL_Y then
        local entry = self.history:redo(self.char_list, self.cursor, self.table_blocks)
        if entry then
            self.char_list    = copyall(entry.char_list)
            self.cursor       = entry.cursor
            self.table_blocks = copyall(entry.table_blocks or {})
            self:updateContent()
        end
        return true
    end
end

function HyperTextAreaContent:onCursorInput(keys)
    if keys.KEYBOARD_CURSOR_LEFT then
        if self:hasSelection() then
            self:setCursor(math.min(self.cursor, self.sel_end))
        else
            self:setCursor(self.cursor - 1)
        end
        return true
    elseif keys.KEYBOARD_CURSOR_RIGHT then
        if self:hasSelection() then
            self:setCursor(math.max(self.cursor, self.sel_end))
        else
            self:setCursor(self.cursor + 1)
        end
        return true
    elseif keys.KEYBOARD_CURSOR_UP then
        local x, y = self.wrapped_text:indexToCoords(self.cursor)
        local last_x = self.last_cursor_x or x
        local target_y = y - 1
        while target_y >= 1 and (self.wrapped_text:is_table_line(target_y) or #self.wrapped_text.lines[target_y] == 0) do
            target_y = target_y - 1
        end
        if target_y >= 1 then
            self:setCursor(self.wrapped_text:coordsToIndex(last_x, target_y))
        else
            self:setCursor(1)
        end
        self.last_cursor_x = last_x
        return true
    elseif keys.KEYBOARD_CURSOR_DOWN then
        local x, y = self.wrapped_text:indexToCoords(self.cursor)
        local last_x = self.last_cursor_x or x
        local target_y = y + 1
        while target_y <= #self.wrapped_text.lines and (self.wrapped_text:is_table_line(target_y) or #self.wrapped_text.lines[target_y] == 0) do
            target_y = target_y + 1
        end
        if target_y <= #self.wrapped_text.lines then
            self:setCursor(self.wrapped_text:coordsToIndex(last_x, target_y))
        else
            self:setCursor(#self.char_list + 1)
        end
        self.last_cursor_x = last_x
        return true
    elseif keys.KEY_HOME or keys.CUSTOM_HOME then
        self:setCursor(self:lineStartOffset())
        return true
    elseif keys.KEY_END or keys.CUSTOM_END then
        self:setCursor(self:lineEndOffset())
        return true
    elseif keys.CUSTOM_CTRL_HOME then
        self:setCursor(1)
        return true
    elseif keys.CUSTOM_CTRL_END then
        self:setCursor(#self.char_list + 1)
        return true
    elseif keys.CUSTOM_CTRL_LEFT then
        self:setCursor(self:wordStartOffset())
        return true
    elseif keys.CUSTOM_CTRL_RIGHT then
        self:setCursor(self:wordEndOffset())
        return true
    end
end

function HyperTextAreaContent:onTextManipulationInput(keys)
    if self:cursor_at_table() then
        -- Block all text input when cursor is at a table boundary
        if keys.SELECT or keys.KEY_ENTER or keys._STRING or keys._STRING == 13 or keys._STRING == 10
           or keys.KEY_BACKSPACE or keys.KEY_DELETE or keys.KEYBOARD_CURSOR_DELETE or keys.CUSTOM_DELETE then
            return true
        end
    end

    if keys.SELECT or keys.KEY_ENTER or keys._STRING == 13 or keys._STRING == 10 then
        self.history:store(HISTORY_ENTRY.WHITESPACE_BLOCK, self.char_list, self.cursor, self.table_blocks)
        self:insert({char = '\n', pen = self.active_pen, link = self.active_link})
        return true
    elseif keys.KEY_BACKSPACE then
        self.history:store(HISTORY_ENTRY.BACKSPACE, self.char_list, self.cursor, self.table_blocks)
        if self:hasSelection() then
            self:eraseSelection()
        elseif self.cursor > 1 then
            table.remove(self.char_list, self.cursor - 1)
            self:_adjust_table_positions_after_delete(self.cursor - 1, self.cursor - 1)
            self:setCursor(self.cursor - 1)
            self:updateContent()
        end
        return true
    elseif keys.KEY_DELETE or keys.KEYBOARD_CURSOR_DELETE or keys.CUSTOM_DELETE then
        self.history:store(HISTORY_ENTRY.DELETE, self.char_list, self.cursor, self.table_blocks)
        if self:hasSelection() then
            self:eraseSelection()
        elseif self.cursor <= #self.char_list then
            table.remove(self.char_list, self.cursor)
            self:_adjust_table_positions_after_delete(self.cursor, self.cursor)
            self:updateContent()
        end
        return true
    elseif keys._STRING then
        if keys._STRING == 0 then -- Handle backspace via _STRING fallback
            self.history:store(HISTORY_ENTRY.BACKSPACE, self.char_list, self.cursor, self.table_blocks)
            if self:hasSelection() then
                self:eraseSelection()
            elseif self.cursor > 1 then
                table.remove(self.char_list, self.cursor - 1)
                self:_adjust_table_positions_after_delete(self.cursor - 1, self.cursor - 1)
                self:setCursor(self.cursor - 1)
                self:updateContent()
            end
            return true
        end
        local char = string.char(keys._STRING)
        local entry_type = char == ' ' and HISTORY_ENTRY.WHITESPACE_BLOCK or HISTORY_ENTRY.TEXT_BLOCK
        self.history:store(entry_type, self.char_list, self.cursor, self.table_blocks)
        self:insert({char = char, pen = self.active_pen, link = self.active_link})
        return true
    end
end

return HyperTextAreaContent
