--@module = true
-- table_editor_modal.lua
--
-- A resizable modal dialog for editing or creating table blocks.
--
-- Three editing areas (HyperTextAreaContent, so newlines render
-- correctly in CP437):
--   Table name – plain text
--   Columns    – one per line:  name|align|stretch|min_width
--                Defaults: align=left, stretch=on, min_width=10
--                Number columns (inferred from data) default to right align
--   Data       – pipe-delimited rows (all rows are data)
--
-- Alt+S saves, Esc cancels.  Window is resizable.

local gui     = require('gui')
local widgets = require('gui.widgets')
local Scrollbar = require('gui.widgets.scrollbar')
local HyperTextAreaContent = reqscript('internal/df-autojournal/wiki_widgets/hyper_text_area_content').HyperTextAreaContent

-- ---------------------------------------------------------------------------
-- Serialisation helpers
-- ---------------------------------------------------------------------------

local function columns_to_text(columns)
    if not columns or #columns == 0 then return '' end
    local lines = {}
    for _, col in ipairs(columns) do
        local a = col.align or 'left'
        local s = col.stretch == false and 'false' or 'true'
        local mw = col.min_width or 10
        table.insert(lines, col.header .. '|' .. a .. '|' .. s .. '|' .. mw)
    end
    return table.concat(lines, '\n')
end

local function text_to_columns(text)
    local cols = {}
    for line in text:gmatch('[^\n]+') do
        local parts = {}
        for p in line:gmatch('[^|]+') do
            table.insert(parts, p)
        end
        if #parts >= 1 then
            local align = parts[2]
            local stretch = #parts >= 3 and parts[3] == 'false' and false or true
            local min_width = #parts >= 4 and tonumber(parts[4]) or 10
            table.insert(cols, {
                header    = parts[1],
                align     = align,
                width     = 0,
                min_width = math.max(1, min_width),
                max_width = 0,
                stretch   = stretch,
            })
        end
    end
    return cols
end

local function is_numeric_value(s)
    return s ~= '' and tonumber(s:gsub(',', '')) ~= nil
end

local function data_to_text(rows, columns)
    if not rows or #rows == 0 then
        if not columns or #columns == 0 then return '' end
        local hdrs = {}
        for _, col in ipairs(columns) do
            table.insert(hdrs, col.header)
        end
        return table.concat(hdrs, '|') .. '\n'
    end
    local lines = {}
    local ncols = #(columns or rows[1] or {})
    for _, row in ipairs(rows) do
        local cells = {}
        for j = 1, ncols do
            table.insert(cells, (row[j] and row[j].text) or '')
        end
        table.insert(lines, table.concat(cells, '|'))
    end
    return table.concat(lines, '\n')
end

local function read_text(editor)
    local text = editor.raw_text or ''
    local rows = {}
    for line in text:gmatch('[^\n]+') do
        local cells = {}
        for cell in line:gmatch('[^|]*') do
            table.insert(cells, cell)
        end
        table.insert(rows, cells)
    end
    return rows
end

local function build_row_data(data_rows, col_count)
    local rows = {}
    for _, row in ipairs(data_rows) do
        local r = {}
        for j = 1, col_count do
            local text = (row and row[j]) or ''
            table.insert(r, { text = text, pen = nil, link = nil })
        end
        table.insert(rows, r)
    end
    return rows
end

-- ---------------------------------------------------------------------------
-- Modal
-- ---------------------------------------------------------------------------

TableEditorModal = defclass(TableEditorModal, gui.ZScreen)
TableEditorModal.ATTRS {
    table_block = DEFAULT_NIL,  -- nil = create new
    on_submit   = DEFAULT_NIL,
}

function TableEditorModal:init()
    local existing = self.table_block
    local existing_cols = existing and existing.columns
    local existing_name = existing and existing.name or ''

    -- Table name – single line
    local name_text = existing_name ~= '' and existing_name or '(unnamed)'
    self.name_editor = HyperTextAreaContent{
        frame = {l=0, r=0, t=1, h=1},
        display_text = { name_text },
        text_pen  = COLOR_LIGHTCYAN,
        link_pen  = COLOR_LIGHTBLUE,
        link_hover_pen = COLOR_WHITE,
    }

    -- Column editor – HyperTextAreaContent so multi-line text renders
    -- correctly in CP437 (each column on its own line).
    local col_text = columns_to_text(existing_cols)
    self.col_editor = HyperTextAreaContent{
        frame = {l=0, r=0, t=3, h=5},
        display_text = { col_text },
        text_pen  = COLOR_LIGHTCYAN,
        link_pen  = COLOR_LIGHTBLUE,
        link_hover_pen = COLOR_WHITE,
    }

    -- Data editor
    local data_text = existing
        and (data_to_text(existing.rows, existing.columns)
             or (function()
                    local hdrs = {}
                    for _, c in ipairs(existing.columns) do
                        table.insert(hdrs, c.header)
                    end
                    return table.concat(hdrs, '|') .. '\n'
                end)())
        or ''

    local existing_max_rows = existing and existing.max_rows
    local max_rows_text = existing_max_rows and tostring(existing_max_rows) or ''

    self.data_render_start = 1

    self.data_editor = HyperTextAreaContent{
        frame = {l=0, r=1, t=10, b=4},
        display_text = { data_text == '' and '(empty table)' or data_text },
        text_pen  = COLOR_LIGHTCYAN,
        link_pen  = COLOR_LIGHTBLUE,
        link_hover_pen = COLOR_WHITE,
        on_text_change = function() self:updateDataScrollbar() end,
    }

    self.data_scrollbar = Scrollbar{
        frame = {r=0, t=10, b=4},
        on_scroll = function(spec) self:onDataScroll(spec) end,
    }

    self.max_rows_editor = HyperTextAreaContent{
        frame = {l=29, r=0, b=2, h=1},
        display_text = { max_rows_text },
        text_pen  = COLOR_LIGHTCYAN,
        link_pen  = COLOR_LIGHTBLUE,
        link_hover_pen = COLOR_WHITE,
    }

    self:addviews{
        widgets.Window{
            frame = {w=70, h=26},
            frame_title = 'Edit Table',
            resizable = true,
            subviews = {
                widgets.Label{
                    frame = {t=0, l=0},
                    text = {
                        {text = "Table Name", pen = COLOR_YELLOW},
                        "  defaults: (unnamed)",
                    },
                    pen = COLOR_GREY,
                },
                self.name_editor,
                widgets.Label{
                    frame = {t=2, l=0},
                    text = {
                        {text = "Columns", pen = COLOR_YELLOW},
                        "  name|align|stretch|min_width  (defaults: left, stretch, 10)",
                    },
                    pen = COLOR_GREY,
                },
                self.col_editor,
                widgets.Label{
                    frame = {t=9, l=0},
                    text = {
                        {text = "Data", pen = COLOR_YELLOW},
                        "  pipe | separated data rows",
                    },
                    pen = COLOR_GREY,
                },
                self.data_editor,
                self.data_scrollbar,
                widgets.Label{
                    frame = {b=2, l=0},
                    text = {
                        {text = "Max Rows", pen = COLOR_YELLOW},
                        " (blank = show all):",
                    },
                    pen = COLOR_GREY,
                },
                self.max_rows_editor,
                widgets.Label{
                    frame = {b=0, l=0},
                    text = {
                        {text = "Alt+S", pen = COLOR_LIGHTCYAN}, ": Save  ",
                        {text = "Esc", pen = COLOR_LIGHTCYAN}, ": Cancel",
                    },
                    pen = COLOR_GREY,
                },
            }
        }
    }

    self.name_editor:setFocus(true)
end

function TableEditorModal:onInput(keys)
    if keys.CUSTOM_ALT_S then
        self:submit()
        return true
    end
    if keys.LEAVESCREEN then
        self:dismiss()
        return true
    end

    if keys._MOUSE_L then
        local function focus_editor(editor)
            self.name_editor:setFocus(editor == self.name_editor)
            self.col_editor:setFocus(editor == self.col_editor)
            self.data_editor:setFocus(editor == self.data_editor)
            self.max_rows_editor:setFocus(editor == self.max_rows_editor)
        end
        if self.name_editor:getMousePos() then
            focus_editor(self.name_editor)
            return TableEditorModal.super.onInput(self, keys)
        end
        if self.col_editor:getMousePos() then
            focus_editor(self.col_editor)
            return TableEditorModal.super.onInput(self, keys)
        end
        if self.data_editor:getMousePos() then
            focus_editor(self.data_editor)
            self:updateDataScrollbar()
            return TableEditorModal.super.onInput(self, keys)
        end
        if self.max_rows_editor:getMousePos() then
            focus_editor(self.max_rows_editor)
            return TableEditorModal.super.onInput(self, keys)
        end
    end

    if keys._MOUSE_WHEEL_DOWN and self.data_editor:getMousePos() then
        self:onDataScroll('down_small')
        return true
    end
    if keys._MOUSE_WHEEL_UP and self.data_editor:getMousePos() then
        self:onDataScroll('up_small')
        return true
    end

    return TableEditorModal.super.onInput(self, keys)
end

function TableEditorModal:updateDataScrollbar()
    local lines_count = #self.data_editor.wrapped_text.lines
    local view_h = self.data_editor.frame_body and self.data_editor.frame_body.height or 1
    local clamped = math.max(1, math.min(self.data_render_start, lines_count - view_h + 1))
    if view_h >= lines_count then clamped = 1 end
    self.data_render_start = clamped
    self.data_scrollbar:update(clamped, view_h, lines_count)
    self.data_editor:setRenderStartLineY(clamped)
end

function TableEditorModal:onDataScroll(scroll_spec)
    local lines_count = #self.data_editor.wrapped_text.lines
    local view_h = self.data_editor.frame_body and self.data_editor.frame_body.height or 1
    local line = self.data_render_start
    if     scroll_spec == 'down_large' then line = line + math.ceil(view_h / 2)
    elseif scroll_spec == 'up_large'   then line = line - math.ceil(view_h / 2)
    elseif scroll_spec == 'down_small' then line = line + 1
    elseif scroll_spec == 'up_small'   then line = line - 1
    else                                    line = tonumber(scroll_spec)
    end
    local clamped = math.max(1, math.min(line, lines_count - view_h + 1))
    if view_h >= lines_count then clamped = 1 end
    self.data_render_start = clamped
    self.data_scrollbar:update(clamped, view_h, lines_count)
    self.data_editor:setRenderStartLineY(clamped)
end

function TableEditorModal:submit()
    local raw_name = (self.name_editor.raw_text or ''):match('^%s*(.-)%s*$')
    local name = (raw_name and raw_name ~= '' and raw_name ~= '(unnamed)') and raw_name or nil

    local col_text = self.col_editor.raw_text or ''
    local cols = text_to_columns(col_text)
    if #cols == 0 then
        dfhack.printerr("Table editor: no columns defined")
        return
    end

    local data_raw = read_text(self.data_editor)
    local rows
    if #data_raw >= 1 then
        rows = build_row_data(data_raw, #cols)
    else
        rows = {}
    end

    -- Infer alignment for columns where align was not explicitly set:
    -- if all non-empty values in a column are numeric, use right alignment
    for i, col in ipairs(cols) do
        if not col.align then
            local all_numeric = true
            for _, row in ipairs(data_raw) do
                local val = row[i]
                if val and val ~= '' and not is_numeric_value(val) then
                    all_numeric = false
                    break
                end
            end
            col.align = all_numeric and 'right' or 'left'
        end
    end

    local raw_max = (self.max_rows_editor.raw_text or ''):match('^%s*(.-)%s*$')
    local max_rows = raw_max and raw_max ~= '' and tonumber(raw_max)
    if max_rows then max_rows = math.max(1, max_rows) end

    if self.on_submit then
        self.on_submit(name, cols, rows, max_rows)
    end
    self:dismiss()
end

return TableEditorModal
