--@ module = true
local gui = require('gui')
local widgets = require('gui.widgets')
local utils = require('utils')
local textures = require('gui.textures')

HyperTextArea = reqscript('internal/df-autojournal/wiki_widgets/hyper_text_area').HyperTextArea
FunctionModal = reqscript('internal/df-autojournal/wiki_widgets/function_modal').FunctionModal

--------------------------------------------------------------------------------
--- ToggleLabel
local function get_icon_pens()
    local enabled_pen_left = dfhack.pen.parse{fg=COLOR_CYAN,
            tile=utils.curry(textures.tp_control_panel, 1), ch=string.byte('[')}
    local enabled_pen_center = dfhack.pen.parse{fg=COLOR_LIGHTGREEN,
            tile=utils.curry(textures.tp_control_panel, 2), ch=251}
    local enabled_pen_right = dfhack.pen.parse{fg=COLOR_CYAN,
            tile=utils.curry(textures.tp_control_panel, 3), ch=string.byte(']')}
    local disabled_pen_left = dfhack.pen.parse{fg=COLOR_CYAN,
            tile=utils.curry(textures.tp_control_panel, 4), ch=string.byte('[')}
    local disabled_pen_center = dfhack.pen.parse{fg=COLOR_RED,
            tile=utils.curry(textures.tp_control_panel, 5), ch=string.byte('x')}
    local disabled_pen_right = dfhack.pen.parse{fg=COLOR_CYAN,
            tile=utils.curry(textures.tp_control_panel, 6), ch=string.byte(']')}
    return enabled_pen_left, enabled_pen_center, enabled_pen_right,
            disabled_pen_left, disabled_pen_center, disabled_pen_right
end
local ENABLED_PEN_LEFT, ENABLED_PEN_CENTER, ENABLED_PEN_RIGHT,
      DISABLED_PEN_LEFT, DISABLED_PEN_CENTER, DISABLED_PEN_RIGHT = get_icon_pens()

ToggleLabel = defclass(ToggleLabel, widgets.ToggleHotkeyLabel)

function ToggleLabel:init()
    -- Evaluate initial_option function before super.init (CycleHotkeyLabel:init
    -- calls setOption directly without resolving functions)
    if type(self.initial_option) == 'function' then
        self.initial_option = self.initial_option()
    end
    ToggleLabel.super.init(self)
    
    -- Ensure self.text is a table of tokens
    if type(self.text) == 'string' then
        self.text = {self.text}
    elseif type(self.text) ~= 'table' then
        self.text = {}
    end

    local text = self.text
    -- ToggleHotkeyLabel appends an "On"/"Off" token at the end. 
    -- We want to replace it with our custom icons.
    -- If there's only one token (the label), we append our icons.
    local idx = #text
    local function opt_is_on()
        local opt = self:getOptionValue()
        return opt == 'On' or opt == true
    end

    if idx > 1 then
        -- Assume the last token is the "On/Off" text from ToggleHotkeyLabel
        text[idx] =     { tile = function() return opt_is_on() and ENABLED_PEN_LEFT or DISABLED_PEN_LEFT end }
        text[idx + 1] = { tile = function() return opt_is_on() and ENABLED_PEN_CENTER or DISABLED_PEN_CENTER end }
        text[idx + 2] = { tile = function() return opt_is_on() and ENABLED_PEN_RIGHT or DISABLED_PEN_RIGHT end }
    else
        -- Just append if it's just the label or empty
        table.insert(text, { tile = function() return opt_is_on() and ENABLED_PEN_LEFT or DISABLED_PEN_LEFT end })
        table.insert(text, { tile = function() return opt_is_on() and ENABLED_PEN_CENTER or DISABLED_PEN_CENTER end })
        table.insert(text, { tile = function() return opt_is_on() and ENABLED_PEN_RIGHT or DISABLED_PEN_RIGHT end })
    end
    self:setText(text)
end

--------------------------------------------------------------------------------
--- Shifter
local TO_THE_RIGHT = string.char(16)
local TO_THE_LEFT = string.char(17)

local function get_shifter_text(state)
    local ch = state and TO_THE_RIGHT or TO_THE_LEFT
    return {
        ' ', NEWLINE,
        ch, NEWLINE,
        ch, NEWLINE,
        ' ', NEWLINE,
    }
end

Shifter = defclass(Shifter, widgets.Widget)
Shifter.ATTRS {
    frame={l=0, w=1, t=0, b=0},
    collapsed=false,
    on_changed=DEFAULT_NIL,
}

function Shifter:init()
    self:addviews{
        widgets.Label{
            view_id='shifter_label',
            frame={l=0, r=0, t=0, b=0},
            text=get_shifter_text(self.collapsed),
            on_click=function ()
                self:toggle(not self.collapsed)
            end
        }
    }
end

function Shifter:toggle(state)
    if state == nil then
        self.collapsed = not self.collapsed
    else
        self.collapsed = state
    end

    self.subviews.shifter_label:setText(
        get_shifter_text(self.collapsed)
    )

    if self.on_changed then
        self.on_changed(self.collapsed)
    end
end

--------------------------------------------------------------------------------
--- ProgressBarScreen — modal ZScreen showing initialization progress
local function make_bracket_pen(fg, tile_offset, ch)
    return dfhack.pen.parse{fg=fg, tile=utils.curry(textures.tp_control_panel, tile_offset), ch=ch}
end

local PROGRESS_ENABLED_LEFT  = make_bracket_pen(COLOR_CYAN,      1, string.byte('['))
local PROGRESS_ENABLED_MID   = make_bracket_pen(COLOR_LIGHTGREEN,2, 251)
local PROGRESS_ENABLED_RIGHT = make_bracket_pen(COLOR_CYAN,      3, string.byte(']'))
local PROGRESS_DISABLED_LEFT  = make_bracket_pen(COLOR_CYAN,     4, string.byte('['))
local PROGRESS_DISABLED_MID   = make_bracket_pen(COLOR_DARKGREY, 5, string.byte('x'))
local PROGRESS_DISABLED_RIGHT = make_bracket_pen(COLOR_CYAN,     6, string.byte(']'))

local STEP_COLORS = {
    done = COLOR_LIGHTCYAN,
    current = COLOR_WHITE,
    pending = COLOR_DARKGREY,
}

ProgressBarScreen = defclass(ProgressBarScreen, gui.ZScreen)
ProgressBarScreen.ATTRS{
    focus_path = 'mfw-progress',
    pass_pause = true,
    steps = {},
    status_text = '',
    current_step = 0,
    sub_completed = 0,
    sub_total = 0,
    frame_title = 'Progress',
}

function ProgressBarScreen:init()
    local h = math.max(8, #self.steps * 2 + 6)
    self:addviews{
        widgets.Window{
            view_id='progress_win',
            frame={w=48, h=h},
            frame_title=self.frame_title,
            resizable=false,
            subviews={
                widgets.Label{
                    view_id='progress_content',
                    frame={l=1, t=1, r=1, b=1},
                    auto_height=false,
                },
            }
        }
    }
    self._last_step = 0
    self:renderContent()
end

function ProgressBarScreen:setCurrent(step_index, status_text)
    self.current_step = step_index
    if status_text then self.status_text = status_text end
    if step_index ~= self._last_step then
        self.sub_total = 0
        self.sub_completed = 0
        self._last_step = step_index
    end
    self:renderContent()
end

function ProgressBarScreen:setSubProgress(scanned, total, matched)
    self.sub_completed = scanned
    self.sub_total = total
    self.status_text = string.format("Scanning events... %d/%d (%d matched)", scanned, total, matched or 0)
    self:renderContent()
end

function ProgressBarScreen:renderContent()
    local text = {}
    local total = #self.steps

    for i, label in ipairs(self.steps) do
        local enabled = i <= self.current_step
        local label_pen = STEP_COLORS.pending
        if enabled then
            label_pen = STEP_COLORS.done
        elseif i == self.current_step + 1 then
            label_pen = STEP_COLORS.current
        end
        local left = enabled and PROGRESS_ENABLED_LEFT or PROGRESS_DISABLED_LEFT
        local mid = enabled and PROGRESS_ENABLED_MID or PROGRESS_DISABLED_MID
        local right = enabled and PROGRESS_ENABLED_RIGHT or PROGRESS_DISABLED_RIGHT
        table.insert(text, { tile = left })
        table.insert(text, { tile = mid })
        table.insert(text, { tile = right })
        table.insert(text, ' ')
        table.insert(text, { text = label, pen = label_pen })
        table.insert(text, NEWLINE)
    end

    table.insert(text, NEWLINE)
    table.insert(text, { tile = PROGRESS_ENABLED_LEFT })
    local bar_width = 16
    local filled = total > 0 and math.floor(self.current_step / total * bar_width) or 0
    for j = 1, bar_width do
        local tile = j <= filled and PROGRESS_ENABLED_MID or PROGRESS_DISABLED_MID
        table.insert(text, { tile = tile })
    end
    table.insert(text, { tile = PROGRESS_DISABLED_RIGHT })
    table.insert(text, NEWLINE)

    if self.sub_total > 0 and self.sub_completed < self.sub_total then
        table.insert(text, { tile = PROGRESS_ENABLED_LEFT })
        local sub_filled = math.floor(self.sub_completed / math.max(self.sub_total, 1) * bar_width)
        for j = 1, bar_width do
            local tile = j <= sub_filled and PROGRESS_ENABLED_MID or PROGRESS_DISABLED_MID
            table.insert(text, { tile = tile })
        end
        table.insert(text, { tile = PROGRESS_DISABLED_RIGHT })
        table.insert(text, NEWLINE)
        table.insert(text, { text = self.status_text, pen = COLOR_LIGHTCYAN })
    elseif self.status_text and self.status_text ~= '' then
        table.insert(text, { text = self.status_text, pen = COLOR_LIGHTCYAN })
    end

    self.subviews.progress_win.subviews.progress_content:setText(text)
end

function ProgressBarScreen:onDismiss()
end

--------------------------------------------------------------------------------
--- TableOfContents
local df_major_version = tonumber(dfhack.getCompiledDFVersion():match('%d+'))

local INVISIBLE_FRAME = {
    frame_pen=gui.CLEAR_PEN,
    signature_pen=false,
}

TableOfContents = defclass(TableOfContents, widgets.Panel)
TableOfContents.ATTRS {
    frame_style=INVISIBLE_FRAME,
    frame_background = gui.CLEAR_PEN,
    on_submit=DEFAULT_NIL,
    text_cursor=DEFAULT_NIL
}

function TableOfContents:init()
    self:addviews{
        widgets.List{
            frame={l=0, t=0, r=0, b=3},
            view_id='table_of_contents',
            choices={},
            on_submit=self.on_submit
        },
    }

    if df_major_version >= 51 then
        local function can_prev()
            local toc = self.subviews.table_of_contents
            return #toc:getChoices() > 0
        end

        self:addviews{
            widgets.HotkeyLabel{
                frame={b=1, l=0},
                key='A_MOVE_N_DOWN',
                label='Prev Section',
                auto_width=true,
                on_activate=self:callback('previousSection'),
                enabled=can_prev,
            },
            widgets.Label{
                frame={l=5, b=1, w=1},
                text_pen=function() return can_prev() and COLOR_LIGHTGREEN or COLOR_GREEN end,
                text=string.char(24),
            },
            widgets.HotkeyLabel{
                frame={b=0, l=0},
                key='A_MOVE_S_DOWN',
                label='Next Section',
                auto_width=true,
                on_activate=self:callback('nextSection'),
                enabled=can_prev,
            },
            widgets.Label{
                frame={l=5, b=0, w=1},
                text_pen=function() return can_prev() and COLOR_LIGHTGREEN or COLOR_GREEN end,
                text=string.char(25),
            },
        }
    end
end

function TableOfContents:previousSection()
    local section_cursor, section = self:currentSection()
    if section == nil then return end
    if section.line_cursor == self.text_cursor then
        self.subviews.table_of_contents:setSelected(section_cursor - 1)
    end
    self.subviews.table_of_contents:submit()
end

function TableOfContents:nextSection()
    local section_cursor, section = self:currentSection()
    if section == nil then return end
    local curr_sel = self.subviews.table_of_contents:getSelected()
    local target_sel = self.text_cursor and section_cursor + 1 or curr_sel + 1
    if curr_sel ~= target_sel then
        self.subviews.table_of_contents:setSelected(target_sel)
        self.subviews.table_of_contents:submit()
    end
end

function TableOfContents:setSelectedSection(section_index)
    local curr_sel = self.subviews.table_of_contents:getSelected()
    if curr_sel ~= section_index then
        self.subviews.table_of_contents:setSelected(section_index)
    end
end

function TableOfContents:currentSection()
    local section_ind = nil
    for ind, choice in ipairs(self.subviews.table_of_contents.choices) do
        if choice.line_cursor > (self.text_cursor or 1) then
            break
        end
        section_ind = ind
    end
    return section_ind, self.subviews.table_of_contents.choices[section_ind]
end

function TableOfContents:reload(text, cursor)
    if not self.visible then return end
    local sections = {}
    local line_cursor = 1
    for line in text:gmatch("[^\n]*") do
        local header, section = line:match("^(#+)%s(.+)")
        if header ~= nil then
            table.insert(sections, {
                line_cursor=line_cursor,
                text=string.rep(" ", #header - 1) .. section,
            })
        end
        line_cursor = line_cursor + #line + 1
    end
    self.text_cursor = cursor
    self.subviews.table_of_contents:setChoices(sections)
end

--------------------------------------------------------------------------------
--- Page Tree helpers for collapsible Wiki TOC (multi-level)

local PAGE_PARENT_RULES = {
    {prefix='citizen:', parent='citizens'},
    {prefix='artifact:', parent='artifacts'},
    {prefix='civ:', parent='civilizations'},
    {prefix='fort:', parent='forts'},
    {prefix='visitor:', parent='visitors'},
}

-- Resolve parent page_id for multi-level nested IDs.
-- Path-based IDs (fort:100/citizens -> fort:100) take priority.
-- Falls back to prefix rules for flat IDs (citizen:12345 -> citizens).
function get_page_parent(page_id)
    local slash = page_id:find('/')
    if slash then
        return page_id:sub(1, slash - 1)
    end
    for _, rule in ipairs(PAGE_PARENT_RULES) do
        if page_id:sub(1, #rule.prefix) == rule.prefix then
            return rule.parent
        end
    end
    return nil
end

-- Build an N-level page tree from a flat list of page descriptors.
-- membership_map, if provided, maps entity page_ids to their section page_ids
-- (e.g. "citizen:12345" -> "fort:100/citizens"), overriding get_page_parent.
function build_page_tree(static_pages, dynamic_pages, membership_map)
    local node_map = {}
    local children_of = {}
    local root_nodes = {}

    for _, p in ipairs(static_pages) do
        local node = {text = p.text, id = p.id, children = {}}
        node_map[p.id] = node
        children_of[p.id] = children_of[p.id] or {}
        table.insert(root_nodes, node)
    end

    for _, dp in ipairs(dynamic_pages) do
        local node = node_map[dp.id] or {text = dp.text, id = dp.id, children = {}}
        node_map[dp.id] = node
        children_of[dp.id] = children_of[dp.id] or {}

        -- membership_map takes priority over prefix rules (places entities under their fort section)
        local parent_id = membership_map and membership_map[dp.id]
        if not parent_id then
            parent_id = get_page_parent(dp.id)
        end

        if parent_id then
            children_of[parent_id] = children_of[parent_id] or {}
            table.insert(children_of[parent_id], node)
        else
            table.insert(root_nodes, node)
        end
    end

    -- Ensure parent stub nodes exist for any parent_id referenced by path-based IDs
    for parent_id, kids in pairs(children_of) do
        if #kids > 0 and not node_map[parent_id] then
            local label = parent_id:gsub("^%l", string.upper)
            local stub = {text = label, id = parent_id, children = kids}
            node_map[parent_id] = stub
            local grandparent = get_page_parent(parent_id)
            if grandparent then
                children_of[grandparent] = children_of[grandparent] or {}
                table.insert(children_of[grandparent], stub)
            else
                table.insert(root_nodes, stub)
            end
        end
    end

    -- Attach children to each node
    for id, node in pairs(node_map) do
        local kids = children_of[id]
        node.children = (kids and #kids > 0) and kids or nil
    end

    -- Rebuild root_nodes in static order, preserving any extra orphans appended
    local ordered = {}
    for _, p in ipairs(static_pages) do
        if node_map[p.id] then
            table.insert(ordered, node_map[p.id])
            node_map[p.id] = nil
        end
    end
    for _, node in ipairs(root_nodes) do
        if node_map[node.id] then
            table.insert(ordered, node)
            node_map[node.id] = nil
        end
    end

    return ordered
end

function tree_contains_id(tree, id)
    for _, node in ipairs(tree) do
        if node.id == id then return true end
        if node.children then
            for _, child in ipairs(node.children) do
                if child.id == id then return true end
            end
        end
    end
    return false
end

-- Recursively flatten an N-level tree into a flat choice list.
-- The [+] / [-] icon stays at column 0; text is indented depth+1 spaces.
function flatten_page_tree(tree, expanded, depth)
    depth = depth or 0
    local result = {}
    for _, node in ipairs(tree) do
        local has_children = node.children and #node.children > 0
        local icon = has_children and (expanded[node.id] and '[-]' or '[+]') or '   '
        local pad = string.rep(' ', depth + 1)
        table.insert(result, {
            text = icon .. pad .. node.text,
            id = node.id,
            is_parent = has_children,
        })
        if has_children and expanded[node.id] then
            local kids = flatten_page_tree(node.children, expanded, depth + 1)
            for _, child in ipairs(kids) do
                table.insert(result, child)
            end
        end
    end
    return result
end

return _ENV
