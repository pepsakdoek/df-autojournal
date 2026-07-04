--@module = true
-- hyper_table.lua
--
-- Table block class for HyperTextArea.
-- Renders multi-column sortable tables as padded text lines inside the
-- HyperTextArea's scrollable document.  No borders — columns are separated
-- by fixed spacing and each cell is padded to its column width.
--
-- Each cell is a standard HyperTextArea span: {text, pen, link}.
-- Column headers are clickable to toggle ascending/descending sort.
-- Sorting auto-detects numeric values when possible.

local CH_UP = string.char(30)  -- ▲ CP437 up triangle
local CH_DN = string.char(31)  -- ▼ CP437 down triangle

HyperTable = defclass(HyperTable)

HyperTable.ATTRS {
    columns  = {},
    rows     = {},
    sort_col = DEFAULT_NIL,
    sort_asc = true,
    max_rows = DEFAULT_NIL,
}

function HyperTable:init()
    self:normalize()
end

function HyperTable:normalize()
    for _, col in ipairs(self.columns) do
        col.header    = col.header or ''
        col.align     = col.align or 'left'
        col.width     = col.width or 0
        col.min_width = col.min_width or 3
        col.max_width = col.max_width or 0
        col.stretch   = col.stretch or false
    end
    for _, row in ipairs(self.rows) do
        for j, cell in ipairs(row) do
            if type(cell) == 'string' then
                row[j] = { text = cell, pen = nil, link = nil }
            elseif not cell.text then
                row[j] = { text = tostring(cell), pen = nil, link = nil }
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Width calculation
-- ---------------------------------------------------------------------------

local CELL_GAP = 2

function HyperTable:calc_column_widths(avail_width)
    local widths = {}
    for j, col in ipairs(self.columns) do
        local max_w = #col.header
        for _, row in ipairs(self.rows) do
            local cell = row[j]
            if cell then
                local w = #(cell.text or '')
                if w > max_w then max_w = w end
            end
        end
        if col.width and col.width > 0 then
            widths[j] = col.width
        else
            local w = math.max(max_w, col.min_width)
            if col.max_width and col.max_width > 0 then
                w = math.min(w, col.max_width)
            end
            widths[j] = w
        end
    end

    -- Shrink auto columns to fit available width
    if avail_width then
        local total_gaps = (#self.columns - 1) * CELL_GAP
        local avail = avail_width - total_gaps
        local total = 0
        for _, w in ipairs(widths) do total = total + w end
        if total > avail and total > 0 then
            local auto_cols = {}
            local fixed_total = 0
            for j, col in ipairs(self.columns) do
                if col.width and col.width > 0 then
                    fixed_total = fixed_total + widths[j]
                else
                    table.insert(auto_cols, j)
                end
            end
            local avail_for_auto = avail - fixed_total
            if avail_for_auto < 1 then avail_for_auto = 1 end
            if #auto_cols > 0 then
                -- Save natural widths (from Phase 1) before clamping
                local natural = {}
                local total_overflow = 0
                for _, j in ipairs(auto_cols) do
                    natural[j] = widths[j]
                    local overflow = math.max(0, widths[j] - self.columns[j].min_width)
                    total_overflow = total_overflow + overflow
                end

                -- Clamp all auto columns to min_width
                local remaining = avail_for_auto
                for _, j in ipairs(auto_cols) do
                    widths[j] = self.columns[j].min_width
                    remaining = remaining - widths[j]
                end

                if remaining > 0 and total_overflow > 0 then
                    -- Distribute remaining space proportionally by content need
                    local orig_remaining = remaining
                    for _, j in ipairs(auto_cols) do
                        if remaining <= 0 then break end
                        local overflow = math.max(0, natural[j] - self.columns[j].min_width)
                        if overflow > 0 then
                            local share = math.floor(overflow * orig_remaining / total_overflow)
                            local give = math.min(share, remaining, overflow)
                            widths[j] = widths[j] + give
                            remaining = remaining - give
                        end
                    end
                    -- Give any rounding leftovers to the column with most need
                    if remaining > 0 then
                        for _, j in ipairs(auto_cols) do
                            if remaining <= 0 then break end
                            local overflow = math.max(0, natural[j] - self.columns[j].min_width)
                            local taken = widths[j] - self.columns[j].min_width
                            local headroom = overflow - taken
                            if headroom > 0 then
                                local give = math.min(headroom, remaining)
                                widths[j] = widths[j] + give
                                remaining = remaining - give
                            end
                        end
                    end
                elseif remaining > 0 then
                    -- All at min_width, no content overflow: equal distribution
                    local each = math.floor(remaining / #auto_cols)
                    local extra = remaining - each * #auto_cols
                    for idx, j in ipairs(auto_cols) do
                        widths[j] = widths[j] + each + (idx <= extra and 1 or 0)
                    end
                end
            end
        end
    end

    -- Stretch columns marked with stretch=true to fill remaining space
    if avail_width then
        local stretch_cols = {}
        local total_gaps = (#self.columns - 1) * CELL_GAP
        for j, col in ipairs(self.columns) do
            if col.stretch then
                table.insert(stretch_cols, j)
            end
        end
        if #stretch_cols > 0 then
            local total = total_gaps
            for _, w in ipairs(widths) do total = total + w end
            local leftover = avail_width - total
            if leftover > 0 then
                local each = math.floor(leftover / #stretch_cols)
                local remainder = leftover - each * #stretch_cols
                for idx, j in ipairs(stretch_cols) do
                    widths[j] = widths[j] + each + (idx <= remainder and 1 or 0)
                    local max_w = self.columns[j].max_width
                    if max_w and max_w > 0 and widths[j] > max_w then
                        widths[j] = max_w
                    end
                end
            end
        end
    end

    return widths
end

-- ---------------------------------------------------------------------------
-- Value extraction & comparison (auto-detect numeric)
-- ---------------------------------------------------------------------------

local function cell_text(cell)
    return cell and cell.text or ''
end

local function try_tonumber(s)
    local trimmed = s:match('^%s*(.-)%s*$')
    if trimmed and tonumber(trimmed) then
        return tonumber(trimmed)
    end
    return nil
end

local function compare_cells(a, b)
    local ta, tb = cell_text(a), cell_text(b)
    local na, nb = try_tonumber(ta), try_tonumber(tb)
    if na and nb then return na < nb end
    if na then return true  end
    if nb then return false end
    return ta:lower() < tb:lower()
end

-- ---------------------------------------------------------------------------
-- Sorting
-- ---------------------------------------------------------------------------

-- Apply the current sort_col/sort_asc state without toggling.
function HyperTable:sort_column_internal()
    if self.sort_col and self.sort_col > 0 then
        local col = self.sort_col
        local asc = self.sort_asc
        table.sort(self.rows, function(a, b)
            local ca, cb = a[col], b[col]
            if asc then
                return compare_cells(ca, cb)
            else
                return compare_cells(cb, ca)
            end
        end)
    end
end

function HyperTable:sort_column(col_idx)
    if col_idx < 1 or col_idx > #self.columns then return end
    if self.sort_col and self.sort_col == col_idx then
        self.sort_asc = not self.sort_asc
    else
        self.sort_col = col_idx
        self.sort_asc = true
    end
    local asc = self.sort_asc
    table.sort(self.rows, function(a, b)
        local ca, cb = a[col_idx], b[col_idx]
        if asc then
            return compare_cells(ca, cb)
        else
            return compare_cells(cb, ca)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Line rendering helpers
-- ---------------------------------------------------------------------------

local function pad_text(text, width, align)
    local t = #text > width and text:sub(1, width) or text
    local diff = width - #t
    if diff <= 0 then return t end
    if align == 'right' then
        return string.rep(' ', diff) .. t
    elseif align == 'center' then
        local l = math.floor(diff / 2)
        local r = diff - l
        return string.rep(' ', l) .. t .. string.rep(' ', r)
    else
        return t .. string.rep(' ', diff)
    end
end

local function add_gap_fragment(spans, line_parts)
    local gap = string.rep(' ', CELL_GAP)
    table.insert(line_parts, gap)
    table.insert(spans, { text = gap, pen = nil, link = nil })
end

function HyperTable:render_header(col_widths)
    local spans = {}
    local line_parts = {}
    for j, col in ipairs(self.columns) do
        local w = col_widths[j]
        if self.sort_col and self.sort_col == j then
            local indicator = self.sort_asc and CH_UP or CH_DN
            local hdr_max = w - 1
            local truncated = #col.header > hdr_max and col.header:sub(1, hdr_max) or col.header
            local padded = pad_text(truncated, hdr_max, col.align) .. indicator
            table.insert(line_parts, padded)
            table.insert(spans, {
                text = padded,
                pen = col.header_pen or COLOR_WHITE,
                link = nil,
            })
        else
            local padded = pad_text(col.header, w, col.align)
            table.insert(line_parts, padded)
            table.insert(spans, {
                text = padded,
                pen = col.header_pen or COLOR_WHITE,
                link = nil,
            })
        end
        if j < #self.columns then
            add_gap_fragment(spans, line_parts)
        end
    end
    local line = table.concat(line_parts)
    return line, spans
end

function HyperTable:render_row(row_idx, col_widths)
    local row = self.rows[row_idx]
    local spans = {}
    local line_parts = {}
    for j, col in ipairs(self.columns) do
        local cell = row[j] or { text = '' }
        local w = col_widths[j]
        local padded = pad_text(cell.text or '', w, col.align)
        table.insert(line_parts, padded)
        table.insert(spans, {
            text = padded,
            pen  = cell.pen,
            link = cell.link,
        })
        if j < #self.columns then
            add_gap_fragment(spans, line_parts)
        end
    end
    local line = table.concat(line_parts)
    return line, spans
end

-- ---------------------------------------------------------------------------
-- Public render  – returns (lines[], line_spans[])
-- ---------------------------------------------------------------------------

function HyperTable:render(avail_width)
    self._last_avail_width = avail_width

    if #self.columns == 0 then
        return {}, {}
    end
    if #self.rows == 0 then
        local msg = '(empty table)'
        return { msg }, {{{ text = msg, pen = COLOR_GREY }}}
    end

    local cw = self:calc_column_widths(avail_width)

    local lines, line_spans = {}, {}
    local hdr_line, hdr_spans = self:render_header(cw)
    table.insert(lines, hdr_line)
    table.insert(line_spans, hdr_spans)

    local target = self.max_rows and math.min(self.max_rows, #self.rows) or #self.rows
    for i = 1, target do
        local dl, ds = self:render_row(i, cw)
        table.insert(lines, dl)
        table.insert(line_spans, ds)
    end

    if self.max_rows and #self.rows > self.max_rows then
        local rem = #self.rows - self.max_rows
        local msg = string.format("... and %d more", rem)
        table.insert(lines, msg)
        table.insert(line_spans, {{ text = msg, pen = COLOR_GREY }})
    end

    return lines, line_spans
end

-- ---------------------------------------------------------------------------
-- Hit-testing
-- ---------------------------------------------------------------------------

-- Given a 1-based x position and a table-local line index (1 = header),
-- return {type='sort', col=j} for header clicks,
-- {type='link', data=link} for data-cell link clicks,
-- or nil.
function HyperTable:get_handler_at(local_y, x)
    local cw = self:calc_column_widths(self._last_avail_width)

    local col_start = 1
    for j, col in ipairs(self.columns) do
        local w = cw[j]
        if x >= col_start and x < col_start + w then
            if local_y == 1 then
                return { type = 'sort', col = j }
            end
            local data_idx = local_y - 1
            if data_idx >= 1 and data_idx <= #self.rows then
                if not self.max_rows or data_idx <= self.max_rows then
                    local row = self.rows[data_idx]
                    local cell = row[j]
                    if cell and cell.link then
                        return { type = 'link', data = cell.link }
                    end
                end
            end
            return nil
        end
        col_start = col_start + w + CELL_GAP
    end

    return nil
end

return HyperTable
