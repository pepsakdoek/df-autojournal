--@module = true
-- hyper_wrapped_text.lua
--
-- Process display_text (text spans + table blocks) into a flat line array
-- for rendering.  Text spans are wrapped using string:wrap(); table blocks
-- are rendered by the HyperTable class and their lines inserted at the
-- correct document position.
--
-- After :update() the public fields are:
--   self.lines        -- array of raw line strings
--   self.line_spans   -- array (indexed by line number) of span-fragment lists
--   self.table_ranges -- array of {table, start_line, end_line, entry}
--   self.raw_text     -- plain text content (excluding tables)
--   self.char_list    -- per-character array (excluding tables)

local HUtils = reqscript('internal/df-autojournal/wiki_widgets/hta_utils')
local HyperTable = reqscript('internal/df-autojournal/wiki_widgets/hyper_table').HyperTable

HyperWrappedText = defclass(HyperWrappedText)

HyperWrappedText.ATTRS {
    display_text = {},
    wrap_width   = math.huge,
}

function HyperWrappedText:init()
    self.lines        = {}
    self.line_spans   = {}
    self.table_ranges = {}
    self.raw_text     = ''
    self.char_list    = {}
    self:update(self.display_text, self.wrap_width)
end

-- ---------------------------------------------------------------------------
-- main update
-- ---------------------------------------------------------------------------

function HyperWrappedText:update(display_text, wrap_width, fn_evaluator)
    self.display_text = display_text
    self.wrap_width   = wrap_width

    self.lines        = {}
    self.line_spans   = {}
    self.table_ranges = {}
    self.char_list    = {}

    local text_entries = {}

    local function flush_text()
        if #text_entries == 0 then return end

        local raw_parts = {}
        for _, entry in ipairs(text_entries) do
            local span = HUtils.to_span(entry)
            table.insert(raw_parts, span.text)
        end
        local raw = table.concat(raw_parts)

        local chars = HUtils.build_char_list(text_entries)
        for _, c in ipairs(chars) do
            table.insert(self.char_list, c)
        end

        local wrapped = raw:wrap(wrap_width, {
            return_as_table        = true,
            keep_trailing_spaces   = true,
            keep_original_newlines = true,
        })
        if raw:sub(-1) == '\n' then
            table.insert(wrapped, '')
        end

        local char_idx = 1
        for _, raw_line in ipairs(wrapped) do
            local line_len  = #raw_line
            local line_chars = {}
            for _ = 1, line_len do
                line_chars[#line_chars + 1] = chars[char_idx] or
                    { char = ' ', pen = nil, link = nil }
                char_idx = char_idx + 1
            end
            table.insert(self.lines, raw_line)
            table.insert(self.line_spans, HUtils.collapse_chars(line_chars))
        end

        text_entries = {}
    end

    for _, entry in ipairs(display_text) do
        if HUtils.is_table_block(entry) then
            flush_text()

            local tbl = HyperTable{
                columns  = entry.columns,
                rows     = entry.rows,
                sort_col = entry.sort_col,
                sort_asc = (entry.sort_asc ~= false),
                max_rows = entry.max_rows,
            }
            tbl:sort_column_internal()

            local tbl_lines, tbl_spans = tbl:render(wrap_width)
            local start_line = #self.lines + 1
            for i, line in ipairs(tbl_lines) do
                table.insert(self.lines, line)
                table.insert(self.line_spans, tbl_spans[i])
            end
            local end_line = #self.lines
            table.insert(self.table_ranges, {
                table      = tbl,
                start_line = start_line,
                end_line   = end_line,
                entry      = entry,
            })
        elseif HUtils.is_function_block(entry) then
            -- Evaluate the function block and insert its output as text
            local result = ''
            if fn_evaluator then
                result = fn_evaluator(entry) or ''
            else
                result = '[' .. (entry.fn_key or '?') .. ']'
            end
            table.insert(text_entries, { text = result, pen = COLOR_GREEN })
        else
            table.insert(text_entries, entry)
        end
    end

    flush_text()

    self.raw_text = HUtils.char_list_to_raw(self.char_list)
end

-- Re-render only the table at the given table_ranges index (after sorting).
function HyperWrappedText:rerender_table(range_idx)
    local tr = self.table_ranges[range_idx]
    if not tr then return end

    local tbl = tr.table
    local tbl_lines, tbl_spans = tbl:render(self.wrap_width)

    local old_count = tr.end_line - tr.start_line + 1

    -- Replace lines in the table's range
    for i = tr.start_line, tr.end_line do
        local idx = i - tr.start_line + 1
        if idx <= #tbl_lines then
            self.lines[i]     = tbl_lines[idx]
            self.line_spans[i] = tbl_spans[idx]
        end
    end

    -- If the table now produces more lines, insert extras
    if #tbl_lines > old_count then
        local extra = #tbl_lines - old_count
        local insert_at = tr.end_line + 1
        for i = 1, extra do
            table.insert(self.lines, insert_at + i - 1, tbl_lines[old_count + i])
            table.insert(self.line_spans, insert_at + i - 1, tbl_spans[old_count + i])
        end
        -- Update subsequent table ranges
        local offset = extra
        for _, later in ipairs(self.table_ranges) do
            if later.start_line > tr.end_line then
                later.start_line = later.start_line + offset
                later.end_line   = later.end_line   + offset
            end
        end
        tr.end_line = tr.end_line + extra
    elseif #tbl_lines < old_count then
        local missing = old_count - #tbl_lines
        local remove_at = tr.start_line + #tbl_lines
        for i = 1, missing do
            table.remove(self.lines, remove_at)
            table.remove(self.line_spans, remove_at)
        end
        local offset = -missing
        for _, later in ipairs(self.table_ranges) do
            if later.start_line > tr.end_line then
                later.start_line = later.start_line + offset
                later.end_line   = later.end_line   + offset
            end
        end
        tr.end_line = tr.end_line - missing
    end

    -- Update the entry so persistence sees sorted state
    if tr.entry then
        tr.entry.sort_col = tbl.sort_col
        tr.entry.sort_asc = tbl.sort_asc
    end
end

-- ---------------------------------------------------------------------------
-- coordinate conversion (text-only – table lines are transparent gaps)
-- ---------------------------------------------------------------------------

function HyperWrappedText:total_line_count()
    return #self.lines
end

-- Return true if the given line number falls inside a table block.
function HyperWrappedText:is_table_line(line_y)
    for _, tr in ipairs(self.table_ranges) do
        if line_y >= tr.start_line and line_y <= tr.end_line then
            return true, tr
        end
    end
    return false, nil
end

-- Given a document line number, return the table_range entry and
-- the 1-based line offset within that table.
function HyperWrappedText:get_table_at_line(line_y)
    for _, tr in ipairs(self.table_ranges) do
        if line_y >= tr.start_line and line_y <= tr.end_line then
            return tr, line_y - tr.start_line + 1
        end
    end
    return nil, nil
end

-- ---------------------------------------------------------------------------
-- text-only coordinate conversion
-- (maps char_list indices to/from text-line space, skipping table lines)
-- ---------------------------------------------------------------------------

function HyperWrappedText:coordsToIndex(x, y)
    local text_y = y
    for _, tr in ipairs(self.table_ranges) do
        if tr.start_line <= y then
            text_y = text_y - (tr.end_line - tr.start_line + 1)
        end
    end
    if text_y < 1 then return 1 end

    local offset = 0
    local text_line = 0
    local last_text_doc_line = nil
    for doc_line = 1, #self.lines do
        if not self:is_table_line(doc_line) then
            last_text_doc_line = doc_line
        end
    end

    for doc_line = 1, #self.lines do
        if not self:is_table_line(doc_line) then
            text_line = text_line + 1
            if text_line == text_y then
                local line_bonus = (doc_line == last_text_doc_line) and 1 or 0
                local nx = math.max(1, math.min(x, #self.lines[doc_line] + line_bonus))
                return offset + nx
            end
            offset = offset + #self.lines[doc_line]
        end
    end
    return offset + 1
end

function HyperWrappedText:indexToCoords(index)
    local offset = index
    local last_text_line = 1
    local last_text_len = 0
    local last_text_doc_line = nil
    for doc_line = 1, #self.lines do
        if not self:is_table_line(doc_line) then
            last_text_doc_line = doc_line
        end
    end
    for doc_line = 1, #self.lines do
        if not self:is_table_line(doc_line) then
            last_text_line = doc_line
            last_text_len = #self.lines[doc_line]
            local line_bonus = (doc_line == last_text_doc_line) and 1 or 0
            if offset <= last_text_len + line_bonus then
                return offset, doc_line
            end
            offset = offset - last_text_len
        end
    end
    return last_text_len + 1, last_text_line
end

-- ---------------------------------------------------------------------------
-- hit-test: given (x, y) in document coordinates, return link data and
-- the character index of the start of the fragment.
-- Tables are handled separately – for text lines we delegate to fragment
-- walk logic.
-- ---------------------------------------------------------------------------

function HyperWrappedText:getClickHandlerAt(x, y)
    local norm_y = math.max(1, math.min(y, #self.line_spans))
    local frags  = self.line_spans[norm_y]
    if not frags then return nil end

    local offset = 0
    -- Count chars from previous TEXT lines only
    for doc_line = 1, norm_y - 1 do
        if not self:is_table_line(doc_line) then
            offset = offset + #self.lines[doc_line]
        end
    end

    local col = 0
    for _, frag in ipairs(frags) do
        local frag_end = col + #frag.text
        if x > col and x <= frag_end then
            return frag.link, offset + col + 1
        end
        col = frag_end
    end
    return nil
end

return HyperWrappedText
