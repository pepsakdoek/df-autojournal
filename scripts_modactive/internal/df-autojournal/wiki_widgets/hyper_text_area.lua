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
local TableEditorModal     = reqscript('internal/df-autojournal/wiki_widgets/table_editor_modal').TableEditorModal
local HyperTextAreaContent = reqscript('internal/df-autojournal/wiki_widgets/hyper_text_area_content').HyperTextAreaContent
local FunctionModal        = reqscript('internal/df-autojournal/wiki_widgets/function_modal').FunctionModal

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
    fn_functions     = {},  -- list from wiki_functions.list_functions()
    fn_evaluator     = DEFAULT_NIL,  -- function(fn_block) -> string
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
        on_table_request = function() self:openTableEditor() end,
        on_function_request = function() self:openFunctionModal() end,
    }

    self.hyper_text_area = HyperTextAreaContent {   
        frame           = {l=4, r=4, t=0, b=3},
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
        fn_evaluator    = self.fn_evaluator,
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
            " | Drag: Select | ",
            {text = string.char(30), pen = COLOR_LIGHTCYAN},
            ": Edit Table | ",
            {text = string.char(228), pen = COLOR_GREEN},
            ": Insert Function",
        }
    }

    self:addviews { self.toolbar, self.hyper_text_area, self.scrollbar, self.info_box }
end

function HyperTextArea:openTableEditor()
    local content = self.hyper_text_area
    local cursor = content.cursor
    local tbls = content.table_blocks

    if #tbls == 0 then
        -- No tables exist – open modal in create mode
        TableEditorModal{
            table_block = nil,
            on_submit = function(name, new_columns, new_rows, max_rows)
                local pos = cursor
                local id = content._next_table_id
                content._next_table_id = content._next_table_id + 1
                table.insert(content.table_blocks, {
                    pos      = pos,
                    columns  = new_columns,
                    rows     = new_rows,
                    sort_col = nil,
                    sort_asc = true,
                    max_rows = max_rows,
                    id       = id,
                    name     = name,
                })
                content:updateContent()
            end,
        }:show()
        return
    end

    local nearest = nil
    local nearest_dist = math.huge
    for i, tb in ipairs(tbls) do
        local dist = math.abs(tb.pos - cursor)
        if dist < nearest_dist then
            nearest_dist = dist
            nearest = i
        end
    end

    if nearest then
        local tb = tbls[nearest]
        TableEditorModal{
            table_block = {
                columns  = tb.columns,
                rows     = tb.rows,
                sort_col = tb.sort_col,
                sort_asc = tb.sort_asc,
                max_rows = tb.max_rows,
                name     = tb.name,
            },
            on_submit = function(name, new_columns, new_rows, max_rows)
                tb.columns = new_columns
                tb.rows    = new_rows
                tb.name    = name
                tb.max_rows = max_rows
                content:updateContent()
            end,
        }:show()
    end
end

function HyperTextArea:openLinkModal()
    LinkModal{
        on_submit = function(text, page)
            local content = self.hyper_text_area
            local insert_start = content.cursor
            for i = 1, #text do
                table.insert(content.char_list, content.cursor, {
                    char = text:sub(i, i),
                    pen = self.link_pen,
                    link = page
                })
                content.cursor = content.cursor + 1
            end
            -- Always add a space after a link to prevent 'end of text' bugs
            table.insert(content.char_list, content.cursor, {
                char = ' ',
                pen = self.active_pen
            })
            content.cursor = content.cursor + 1
            local chars_inserted = #text + 1
            content:_adjust_table_positions_after_insert(insert_start, chars_inserted)
            content:updateContent()
        end
    }:show()
end

function HyperTextArea:openFunctionModal()
    if not self.fn_evaluator or #self.fn_functions == 0 then return end
    FunctionModal{
        functions = self.fn_functions,
        on_submit = function(fn_key, args)
            self.hyper_text_area:insertFunctionBlock(fn_key, args)
        end,
    }:show()
end

function HyperTextArea:setContent(display_text)
    self.display_text = display_text
    self.raw_text     = ''
    self.render_start_line_y = 1
    self.hyper_text_area:setContent(display_text)
    self.raw_text = self.hyper_text_area.wrapped_text.raw_text
    if self.frame_body then self:updateLayout() end
end

function HyperTextArea:setDisplayText(display_text)
    self:setContent(display_text)
end

-- Add a table block at the current cursor position.
-- columns: { {header="Name", align="left", width=0, min_width=5}, ... }
-- rows:    { { {text="Urist", link="dwarf/1"}, {text="127"} }, ... }
-- opts:    { sort_col=nil, sort_asc=true, max_rows=nil }
function HyperTextArea:addTable(columns, rows, opts)
    opts = opts or {}
    local function new_table_block()
        return {
            type     = 'table',
            columns  = columns,
            rows     = rows,
            sort_col = opts.sort_col,
            sort_asc = (opts.sort_asc ~= false),
            max_rows = opts.max_rows,
        }
    end
    local content = self.hyper_text_area
    local pos = content.cursor
    local id = content._next_table_id
    content._next_table_id = content._next_table_id + 1
    table.insert(content.table_blocks, {
        pos      = pos,
        columns  = columns,
        rows     = rows,
        sort_col = opts.sort_col,
        sort_asc = (opts.sort_asc ~= false),
        max_rows = opts.max_rows,
        id       = id,
    })
    content:updateContent()
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
    -- No frame_body shift needed: onRenderBody and all coordinate
    -- conversions already use render_start_line_y as the scroll offset.
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