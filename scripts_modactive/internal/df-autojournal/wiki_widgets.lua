--@ module = true
local gui = require('gui')
local widgets = require('gui.widgets')
local utils = require('utils')
local textures = require('gui.textures')

HyperTextArea = reqscript('internal/df-autojournal/wiki_widgets/hyper_text_area').HyperTextArea

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
    if idx > 1 then
        -- Assume the last token is the "On/Off" text from ToggleHotkeyLabel
        text[idx] =     { tile = function() return self:getOptionValue() and ENABLED_PEN_LEFT or DISABLED_PEN_LEFT end }
        text[idx + 1] = { tile = function() return self:getOptionValue() and ENABLED_PEN_CENTER or DISABLED_PEN_CENTER end }
        text[idx + 2] = { tile = function() return self:getOptionValue() and ENABLED_PEN_RIGHT or DISABLED_PEN_RIGHT end }
    else
        -- Just append if it's just the label or empty
        table.insert(text, { tile = function() return self:getOptionValue() and ENABLED_PEN_LEFT or DISABLED_PEN_LEFT end })
        table.insert(text, { tile = function() return self:getOptionValue() and ENABLED_PEN_CENTER or DISABLED_PEN_CENTER end })
        table.insert(text, { tile = function() return self:getOptionValue() and ENABLED_PEN_RIGHT or DISABLED_PEN_RIGHT end })
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

return _ENV
