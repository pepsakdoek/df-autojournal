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
    fn_evaluator      = DEFAULT_NIL,
}

function HyperTextAreaContent:init()
    self.render_start_line_y = 1
    self.sel_end             = nil
    self.cursor              = 1
    self.last_cursor_x       = nil

    self.main_pen = dfhack.pen.parse({bg = COLOR_RESET, bold = true}, self.text_pen)
    self.sel_pen  = dfhack.pen.parse(self.main_pen, nil, self.pen_selection)

    self.table_blocks = {}
    self.fn_blocks    = {}
    self:_extract_special_blocks()

    self.char_list = self:_build_char_list_with_fns(self.display_text)
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

--- Build char_list from display_text, evaluating function blocks inline.
function HyperTextAreaContent:_build_char_list_with_fns(display_text)
    local chars = {}
    for _, entry in ipairs(display_text) do
        if HUtils.is_table_block(entry) then
            -- skip
        elseif HUtils.is_function_block(entry) then
            local result = self:_evaluate_fn_block(entry) or ''
            local pen = COLOR_GREEN
            for i = 1, #result do
                chars[#chars + 1] = { char = result:sub(i, i), pen = pen }
            end
        else
            local span = HUtils.to_span(entry)
            for i = 1, #span.text do
                chars[#chars + 1] = {
                    char = span.text:sub(i, i),
                    pen  = span.pen,
                    link = span.link,
                }
            end
        end
    end
    return chars
end

--- Evaluate a function block, returning the display string.
function HyperTextAreaContent:_evaluate_fn_block(fn_block)
    if self.fn_evaluator then
        return self.fn_evaluator(fn_block)
    end
    return '[' .. (fn_block.fn_key or '?') .. ']'
end

-- Extract table blocks and function blocks from display_text with position tracking.
function HyperTextAreaContent:_extract_special_blocks()
    self.table_blocks = {}
    self.fn_blocks    = {}
    local text_pos = 1
    for _, entry in ipairs(self.display_text) do
        if HUtils.is_table_block(entry) then
            local id = entry.id
            if not id then
                id = self._next_table_id
                self._next_table_id = self._next_table_id + 1
            elseif id >= self._next_table_id then
                self._next_table_id = id + 1
            end
            local rows = copyall(entry.rows)
            table.insert(self.table_blocks, {
                pos          = text_pos,
                columns      = copyall(entry.columns),
                rows         = rows,
                sort_col     = entry.sort_col,
                sort_asc     = entry.sort_asc,
                max_rows     = entry.max_rows,
                id           = id,
                search_query = '',
            })
        elseif HUtils.is_function_block(entry) then
            table.insert(self.fn_blocks, {
                pos    = text_pos,
                fn_key = entry.fn_key,
                args   = copyall(entry.args or {}),
            })
        else
            local span = HUtils.to_span(entry)
            text_pos = text_pos + #span.text
        end
    end
end

-- Rebuild display_text from char_list + table_blocks + fn_blocks.
function HyperTextAreaContent:rebuild_display_text()
    -- Sync fn_block lengths before rebuild so skip counts are current
    self:_sync_fn_block_lengths()

    local display = {}
    local char_idx = 1

    table.sort(self.table_blocks, function(a, b) return a.pos < b.pos end)
    table.sort(self.fn_blocks, function(a, b) return a.pos < b.pos end)

    local tbi = 1
    local fbi = 1

    while char_idx <= #self.char_list or tbi <= #self.table_blocks or fbi <= #self.fn_blocks do
        local next_tb_pos = tbi <= #self.table_blocks and self.table_blocks[tbi].pos or math.huge
        local next_fb_pos = fbi <= #self.fn_blocks and self.fn_blocks[fbi].pos or math.huge

        if next_tb_pos <= next_fb_pos and next_tb_pos <= #self.char_list + 1 then
            -- Insert chars before this table block
            if next_tb_pos > char_idx then
                local seg_chars = {}
                for i = char_idx, math.min(next_tb_pos - 1, #self.char_list) do
                    table.insert(seg_chars, self.char_list[i])
                end
                if #seg_chars > 0 then
                    local spans = HUtils.collapse_chars(seg_chars)
                    for _, span in ipairs(spans) do
                        table.insert(display, span)
                    end
                end
                char_idx = next_tb_pos
            end
            -- Insert table block entry
            local tb = self.table_blocks[tbi]

            table.insert(display, {
                type         = 'table',
                columns      = tb.columns,
                rows         = tb.rows,
                sort_col     = tb.sort_col,
                sort_asc     = tb.sort_asc,
                max_rows     = tb.max_rows,
                id           = tb.id,
                name         = tb.name,
                search_query = tb.search_query or '',
            })
            tbi = tbi + 1
            -- char_idx stays at table position
        elseif next_fb_pos <= #self.char_list + 1 then
            -- Insert chars before this function block
            if next_fb_pos > char_idx then
                local seg_chars = {}
                for i = char_idx, math.min(next_fb_pos - 1, #self.char_list) do
                    table.insert(seg_chars, self.char_list[i])
                end
                if #seg_chars > 0 then
                    local spans = HUtils.collapse_chars(seg_chars)
                    for _, span in ipairs(spans) do
                        table.insert(display, span)
                    end
                end
                char_idx = next_fb_pos
            end
            -- Insert function block entry
            local fb = self.fn_blocks[fbi]
            table.insert(display, {
                type   = 'function',
                fn_key = fb.fn_key,
                args   = copyall(fb.args or {}),
            })
            -- Skip function output chars in char_list
            local skip_count = fb.len or 0
            char_idx = char_idx + skip_count
            fbi = fbi + 1
        else
            -- Remaining chars are regular text
            break
        end
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

--- Determine if cursor is at a table boundary.
function HyperTextAreaContent:cursor_at_table(cursor)
    local c = cursor or self.cursor
    for _, tb in ipairs(self.table_blocks) do
        if tb.pos == c then return true end
    end
    return false
end

--- Find a table block position by its id.
function HyperTextAreaContent:_find_table_pos(entry_id)
    for _, tb in ipairs(self.table_blocks) do
        if tb.id == entry_id then
            return tb.pos
        end
    end
    return nil
end

--- Re-render a table after its search_query changes.
function HyperTextAreaContent:_rerender_table_by_id(tb_id)
    for range_idx, tr in ipairs(self.wrapped_text.table_ranges) do
        if tr.entry.id == tb_id then
            for _, tb in ipairs(self.table_blocks) do
                if tb.id == tb_id then
                    tr.table.search_query = tb.search_query or ''
                    tr.entry.search_query = tb.search_query or ''
                    break
                end
            end
            self.wrapped_text:rerender_table(range_idx)
            break
        end
    end
end

--- Adjust table block positions after a character insert.
function HyperTextAreaContent:_adjust_table_positions_after_insert(at_pos, count)
    for _, tb in ipairs(self.table_blocks) do
        if tb.pos >= at_pos then
            tb.pos = tb.pos + count
        end
    end
end

--- Adjust table block positions after a character delete.
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

--- Adjust fn block positions after a character insert.
function HyperTextAreaContent:_adjust_fn_positions_after_insert(at_pos, count)
    for _, fb in ipairs(self.fn_blocks) do
        if fb.pos >= at_pos then
            fb.pos = fb.pos + count
        end
    end
end

--- Adjust fn block positions after a character delete.
function HyperTextAreaContent:_adjust_fn_positions_after_delete(from_pos, to_pos)
    local range_len = to_pos - from_pos + 1
    for _, fb in ipairs(self.fn_blocks) do
        if fb.pos > to_pos then
            fb.pos = fb.pos - range_len
        elseif fb.pos > from_pos and fb.pos <= to_pos then
            fb.pos = from_pos
        end
    end
end

--- Destroy any fn_block whose range overlaps with the given position range.
-- Returns true if any fn_block was destroyed.
function HyperTextAreaContent:_destroy_fn_blocks_overlapping(from_pos, to_pos)
    local destroyed = false
    local surviving = {}
    for _, fb in ipairs(self.fn_blocks) do
        local fb_end = fb.pos + (fb.len or 0) - 1
        -- Check overlap: fb.pos..fb_end overlaps with from_pos..to_pos
        if fb.pos > to_pos or fb_end < from_pos then
            table.insert(surviving, fb)
        else
            destroyed = true
        end
    end
    self.fn_blocks = surviving
    return destroyed
end

function HyperTextAreaContent:postComputeFrame()
    self:recomputeLines()
end

function HyperTextAreaContent:recomputeLines()
    if not self.frame_body then
        self.char_list = self:_build_char_list_with_fns(self.display_text)
        self.raw_text = HUtils.char_list_to_raw(self.char_list)
        return
    end
    -- Sync table data from table_blocks into display_text
    for _, entry in ipairs(self.display_text) do
        if HUtils.is_table_block(entry) then
            for _, tb in ipairs(self.table_blocks) do
                if tb.id == entry.id then
                    entry.rows = tb.rows
                    break
                end
            end
        end
    end
    self.wrapped_text:update(
        self.display_text,
        self.frame_body.width - 1,
        self.fn_evaluator
    )
    self.raw_text = self.wrapped_text.raw_text
    self.char_list = self.wrapped_text.char_list

    -- Update fn_block lengths from current char_list state
    self:_sync_fn_block_lengths()
end

--- Update fn_block lengths to match the number of chars their output
-- occupies in char_list at their tracked positions.
local function fn_block_char_count(result)
    if type(result) == 'string' then
        return #result
    elseif type(result) == 'table' then
        if result.type == 'table' then
            return 0
        elseif result.text then
            return #(result.text or '')
        else
            local total = 0
            for _, v in ipairs(result) do
                if type(v) == 'string' then
                    total = total + #v
                elseif type(v) == 'table' and v.text then
                    total = total + #v.text
                end
            end
            return total
        end
    end
    return #tostring(result)
end

function HyperTextAreaContent:_sync_fn_block_lengths()
    table.sort(self.fn_blocks, function(a, b) return a.pos < b.pos end)
    for _, fb in ipairs(self.fn_blocks) do
        local result = self:_evaluate_fn_block({fn_key=fb.fn_key, args=fb.args}) or ''
        fb.len = fn_block_char_count(result)
    end
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
        self:_destroy_fn_blocks_overlapping(from, to - 1)
        for i = to, from, -1 do
            table.remove(self.char_list, i)
        end
        self:_adjust_table_positions_after_delete(from, to)
        self:_adjust_fn_positions_after_delete(from, to)
        self:setCursor(from)
        self:updateContent()
    end
end

function HyperTextAreaContent:insert(char_obj)
    self:eraseSelection()
    self:_destroy_fn_blocks_overlapping(self.cursor, self.cursor)
    table.insert(self.char_list, self.cursor, char_obj)
    self:_adjust_table_positions_after_insert(self.cursor, 1)
    self:_adjust_fn_positions_after_insert(self.cursor, 1)
    self:setCursor(self.cursor + 1)
    self:updateContent()
end

--- Insert a function block at the current cursor position.
-- Destroys any existing fn_block that overlaps the insertion point.
-- @param fn_key  string  registered function key
-- @param args    table   arguments for the function
function HyperTextAreaContent:insertFunctionBlock(fn_key, args)
    local fn_block = { fn_key = fn_key, args = args or {} }
    local result = self:_evaluate_fn_block(fn_block) or ''
    local pen = COLOR_GREEN

    -- Destroy any fn_block at the insertion point
    self:_destroy_fn_blocks_overlapping(self.cursor, self.cursor)

    -- Insert evaluated chars into char_list
    local pos = self.cursor
    for i = 1, #result do
        table.insert(self.char_list, self.cursor, { char = result:sub(i, i), pen = pen })
        self.cursor = self.cursor + 1
    end

    -- Adjust positions of existing blocks after the insertion point
    self:_adjust_table_positions_after_insert(pos, #result)
    self:_adjust_fn_positions_after_insert(pos, #result)

    -- Add fn_block tracking (pos is before the adjustment so it stays at the right spot)
    table.insert(self.fn_blocks, {
        pos    = pos,
        fn_key = fn_key,
        args   = copyall(args or {}),
        len    = #result,
    })
    table.sort(self.fn_blocks, function(a, b) return a.pos < b.pos end)

    self:updateContent()
end

function HyperTextAreaContent:setContent(display_text)
    self.display_text = display_text
    self.cursor       = 1
    self.sel_end      = nil
    self.render_start_line_y = 1
    self.nav_time     = 0
    self:_extract_special_blocks()
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

function HyperTextAreaContent:_serialize_table(tb)
    local parts = {}
    local hdrs = {}
    for _, col in ipairs(tb.columns) do
        table.insert(hdrs, col.header or '')
    end
    table.insert(parts, table.concat(hdrs, '|'))
    for _, row in ipairs(tb.rows) do
        local cells = {}
        for j, col in ipairs(tb.columns) do
            local cell = row[j]
            table.insert(cells, (cell and cell.text) or '')
        end
        table.insert(parts, table.concat(cells, '|'))
    end
    return table.concat(parts, '\n') .. '\n'
end

function HyperTextAreaContent:copy()
    if not self:hasSelection() then return end
    local from, to = self.cursor, self.sel_end
    if from > to then from, to = to, from end

    -- Build lookup of table blocks within selection range
    local tb_lookup = {}
    for _, tb in ipairs(self.table_blocks) do
        if tb.pos >= from and tb.pos < to then
            tb_lookup[tb.pos] = tb_lookup[tb.pos] or {}
            table.insert(tb_lookup[tb.pos], tb)
        end
    end

    local parts = {}
    for i = from, to - 1 do
        if tb_lookup[i] then
            for _, tb in ipairs(tb_lookup[i]) do
                table.insert(parts, self:_serialize_table(tb))
            end
        end
        table.insert(parts, self.char_list[i].char)
    end

    self:setClipboardText(table.concat(parts))
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
    self:_destroy_fn_blocks_overlapping(insert_pos, insert_pos + #clipboard - 1)

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
    self:_adjust_fn_positions_after_insert(insert_pos, #clipboard)
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

    -- Build selected-table set: which table IDs are within the selection
    local selected_table_ids = {}
    if sel_from then
        for _, tb in ipairs(self.table_blocks) do
            if tb.pos >= sel_from and tb.pos < sel_to then
                selected_table_ids[tb.id] = true
            end
        end
    end
    -- Map line index to whether its table is selected
    local table_selected_at = {}
    for _, tr in ipairs(self.wrapped_text.table_ranges) do
        if selected_table_ids[tr.entry.id] then
            for y = tr.start_line, tr.end_line do
                table_selected_at[y] = true
            end
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
                    local is_selected
                    if is_table_line then
                        is_selected = sel_from and table_selected_at[line_idx]
                    else
                        is_selected = sel_from and (char_idx >= sel_from and char_idx < sel_to)
                    end
                    
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
        -- If cursor is at a table position, place it on the search bar after "SEARCH: "
        for _, tb in ipairs(self.table_blocks) do
            if tb.pos == self.cursor then
                for _, tr in ipairs(self.wrapped_text.table_ranges) do
                    if tr.entry.id == tb.id then
                        cy = tr.start_line
                        local q = tr.entry.search_query or ''
                        cx = 9 + #q
                        break
                    end
                end
                break
            end
        end
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
            self.history:store(HISTORY_ENTRY.OTHER, self.char_list, self.cursor, self.table_blocks, self.fn_blocks)
            self:cut()
            return true
        elseif keys.CUSTOM_CTRL_V then
            if self:cursor_at_table() then return true end
            self.history:store(HISTORY_ENTRY.OTHER, self.char_list, self.cursor, self.table_blocks, self.fn_blocks)
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

            -- Skip table lines during drag — don't modify selection state
            if self.wrapped_text:get_table_at_line(wy) then
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
        local entry = self.history:undo(self.char_list, self.cursor, self.table_blocks, self.fn_blocks)
        if entry then
            self.char_list    = copyall(entry.char_list)
            self.cursor       = entry.cursor
            self.table_blocks = copyall(entry.table_blocks or {})
            self.fn_blocks    = copyall(entry.fn_blocks or {})
            self:updateContent()
        end
        return true
    elseif keys.CUSTOM_CTRL_Y then
        local entry = self.history:redo(self.char_list, self.cursor, self.table_blocks, self.fn_blocks)
        if entry then
            self.char_list    = copyall(entry.char_list)
            self.cursor       = entry.cursor
            self.table_blocks = copyall(entry.table_blocks or {})
            self.fn_blocks    = copyall(entry.fn_blocks or {})
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
        while target_y <= #self.wrapped_text.lines and self.wrapped_text:is_table_line(target_y) do
            target_y = target_y + 1
        end
        if target_y <= #self.wrapped_text.lines then
            self:setCursor(self.wrapped_text:coordsToIndex(last_x, target_y))
        else
            -- Past end: if the document ends with a table with no text after it,
            -- insert a newline so the cursor can type below the table.
            local last_entry = self.display_text[#self.display_text]
            if last_entry and HUtils.is_table_block(last_entry) then
                self.history:store(HISTORY_ENTRY.WHITESPACE_BLOCK, self.char_list, self.cursor, self.table_blocks, self.fn_blocks)
                table.insert(self.char_list, {char = '\n', pen = self.active_pen, link = self.active_link})
                self:setCursor(#self.char_list + 1)
                self:updateContent()
            else
                self:setCursor(#self.char_list + 1)
            end
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
        -- Route text input to table search when cursor is at a table boundary
        local function table_at_cursor()
            for _, tb in ipairs(self.table_blocks) do
                if tb.pos == self.cursor then return tb end
            end
            return nil
        end
        local tb = table_at_cursor()
        if tb then
            if keys._STRING == 0 or keys.KEY_BACKSPACE then
                local q = tb.search_query or ''
                if #q > 0 then
                    tb.search_query = q:sub(1, -2)
                    self:_rerender_table_by_id(tb.id)
                end
                return true
            elseif keys._STRING then
                local char = string.char(keys._STRING)
                if char:match('[ -~]') then
                    tb.search_query = (tb.search_query or '') .. char
                    self:_rerender_table_by_id(tb.id)
                    return true
                end
            elseif keys.LEAVESCREEN then
                if #(tb.search_query or '') > 0 then
                    tb.search_query = ''
                    self:_rerender_table_by_id(tb.id)
                    return true
                end
            end
        end
        -- Block destructive text input at table boundaries
        if keys.SELECT or keys.KEY_ENTER or keys._STRING or keys._STRING == 13 or keys._STRING == 10
           or keys.KEY_DELETE or keys.KEYBOARD_CURSOR_DELETE or keys.CUSTOM_DELETE then
            return true
        end
    end

    if keys.SELECT or keys.KEY_ENTER or keys._STRING == 13 or keys._STRING == 10 then
        self.history:store(HISTORY_ENTRY.WHITESPACE_BLOCK, self.char_list, self.cursor, self.table_blocks, self.fn_blocks)
        self:_destroy_fn_blocks_overlapping(self.cursor, self.cursor)
        self:insert({char = '\n', pen = self.active_pen, link = self.active_link})
        return true
    elseif keys.KEY_BACKSPACE then
        self.history:store(HISTORY_ENTRY.BACKSPACE, self.char_list, self.cursor, self.table_blocks, self.fn_blocks)
        if self:hasSelection() then
            self:eraseSelection()
        elseif self.cursor > 1 then
            self:_destroy_fn_blocks_overlapping(self.cursor - 1, self.cursor - 1)
            table.remove(self.char_list, self.cursor - 1)
            self:_adjust_table_positions_after_delete(self.cursor - 1, self.cursor - 1)
            self:_adjust_fn_positions_after_delete(self.cursor - 1, self.cursor - 1)
            self:setCursor(self.cursor - 1)
            self:updateContent()
        end
        return true
    elseif keys.KEY_DELETE or keys.KEYBOARD_CURSOR_DELETE or keys.CUSTOM_DELETE then
        self.history:store(HISTORY_ENTRY.DELETE, self.char_list, self.cursor, self.table_blocks, self.fn_blocks)
        if self:hasSelection() then
            self:eraseSelection()
        elseif self.cursor <= #self.char_list then
            self:_destroy_fn_blocks_overlapping(self.cursor, self.cursor)
            table.remove(self.char_list, self.cursor)
            self:_adjust_table_positions_after_delete(self.cursor, self.cursor)
            self:_adjust_fn_positions_after_delete(self.cursor, self.cursor)
            self:updateContent()
        end
        return true
    elseif keys._STRING then
        if keys._STRING == 0 then -- Handle backspace via _STRING fallback
            self.history:store(HISTORY_ENTRY.BACKSPACE, self.char_list, self.cursor, self.table_blocks, self.fn_blocks)
            if self:hasSelection() then
                self:eraseSelection()
            elseif self.cursor > 1 then
                self:_destroy_fn_blocks_overlapping(self.cursor - 1, self.cursor - 1)
                table.remove(self.char_list, self.cursor - 1)
                self:_adjust_table_positions_after_delete(self.cursor - 1, self.cursor - 1)
                self:_adjust_fn_positions_after_delete(self.cursor - 1, self.cursor - 1)
                self:setCursor(self.cursor - 1)
                self:updateContent()
            end
            return true
        end
        local char = string.char(keys._STRING)
        local entry_type = char == ' ' and HISTORY_ENTRY.WHITESPACE_BLOCK or HISTORY_ENTRY.TEXT_BLOCK
        self.history:store(entry_type, self.char_list, self.cursor, self.table_blocks, self.fn_blocks)
        self:_destroy_fn_blocks_overlapping(self.cursor, self.cursor)
        self:insert({char = char, pen = self.active_pen, link = self.active_link})
        return true
    end
end

return HyperTextAreaContent
