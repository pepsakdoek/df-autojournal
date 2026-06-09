--@ module = true
local gui = require('gui')
local widgets = require('gui.widgets')
local utils = require('utils')
local json = require('json')
local textures = require('gui.textures')

-- File logging helper (preserved from original for future placeholder use)
local function log_to_file(msg)
    local f = io.open("wiki_debug.log", "a")
    if f then
        f:write(os.date("%Y-%m-%d %H:%M:%S") .. " - " .. tostring(msg) .. "\n")
        f:close()
    end
end

--------------------------------------------------------------------------------
--- ToggleLabel (adapted from togglelabelExample/spectate.lua)
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
    self.text = self.text or {}
    local text = self.text
    -- the very last token is the On/Off text -- we'll repurpose it as an indicator
    -- we use a small offset to ensure we don't overwrite the label if it's too short
    local idx = #text > 0 and #text or 1
    text[idx] =     { tile = function() return self:getOptionValue() and ENABLED_PEN_LEFT or DISABLED_PEN_LEFT end }
    text[idx + 1] = { tile = function() return self:getOptionValue() and ENABLED_PEN_CENTER or DISABLED_PEN_CENTER end }
    text[idx + 2] = { tile = function() return self:getOptionValue() and ENABLED_PEN_RIGHT or DISABLED_PEN_RIGHT end }
    self:setText(text)
end

--------------------------------------------------------------------------------
--- Shifter (adapted from CurrentJournal/internal/journal/shifter.lua)
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
--- TableOfContents (adapted from CurrentJournal/internal/journal/table_of_contents.lua)
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
--- Wiki Pages Logic

local PAGES = {
    {text='Civilisation', id='civ'},
    {text='Fort', id='fort'},
    {text='Citizens', id='citizens'},
    {text='Artifacts', id='artifacts'},
    {text='Events', id='events'},
}

WikiWindow = defclass(WikiWindow, widgets.Window)
WikiWindow.ATTRS {
    frame_title='My Fort Wiki',
    resizable=true,
    resize_min={w=82, h=25},
    frame_inset={l=0,r=0,t=0,b=0},
    on_page_change=DEFAULT_NIL,
    on_text_change=DEFAULT_NIL,
}

function WikiWindow:init()
    self:addviews{
        -- Wiki TOC Panel (Left)
        widgets.Panel{
            view_id='wiki_toc_panel',
            frame={l=0, w=30, t=0, b=1},
            frame_inset={l=1, t=0, b=1, r=1},
            subviews={
                widgets.Label{
                    frame={t=0, l=0},
                    text='Wiki Pages',
                    text_pen=COLOR_LIGHTCYAN,
                },
                widgets.List{
                    view_id='wiki_page_list',
                    frame={t=2, l=0, r=0, b=10},
                    choices=PAGES,
                    on_submit=self:callback('onWikiPageSubmit'),
                },
                -- Buttons at the bottom of Wiki TOC
                ToggleLabel{
                    view_id='toggle_auto',
                    frame={b=6, l=0},
                    label='Auto-Journaling ',
                    key='CUSTOM_ALT_A',
                    initial_option=false,
                    on_change=function(val) log_to_file("Auto-Journaling toggled: " .. tostring(val)) end,
                },
                widgets.HotkeyLabel{
                    frame={b=4, l=0},
                    label='Settings',
                    key='CUSTOM_ALT_S',
                    on_activate=function() log_to_file("Settings opened") end,
                },
                widgets.HotkeyLabel{
                    frame={b=2, l=0},
                    label='Export to HTML',
                    key='CUSTOM_ALT_X',
                    on_activate=function() log_to_file("Export triggered") end,
                },
            }
        },
        widgets.Divider{
            view_id='wiki_toc_divider',
            frame={l=25, t=0, b=1, w=1},
            frame_style_t=false,
            interior_b=true,
        },
        -- Journal TOC Panel (Middle - Header TOC)
        TableOfContents{
            view_id='journal_toc_panel',
            frame={l=26, w=25, t=0, b=1},
            frame_inset={l=1, t=0, b=1, r=1},
            visible=false,
            on_submit=self:callback('onJournalTocSubmit'),
        },
        Shifter{
            view_id='shifter',
            frame={l=26, w=1, t=1, b=2},
            collapsed=true,
            on_changed = function (collapsed)
                self.subviews.journal_toc_panel.visible = not collapsed
                self.subviews.journal_toc_divider.visible = not collapsed
                if not collapsed then
                    self:reloadJournalToc()
                end
                self:updateLayout()
            end,
        },
        widgets.Divider{
            view_id='journal_toc_divider',
            frame={l=51, t=0, b=1, w=1},
            visible=false,
            frame_style_t=false,
            interior_b=true,
        },
        -- Editor (Right)
        widgets.TextArea{
            view_id='editor',
            frame={t=1, b=3, l=27, r=0},
            frame_inset={l=1, r=0},
            on_text_change=self:callback('onTextChange'),
            on_cursor_change=self:callback('onCursorChange'),
        },
        widgets.HelpButton{command="gui/journal", frame={r=0,t=1}},
        -- Bottom Bar
        widgets.Panel{
            frame={l=0, r=0, b=1, h=1},
            frame_inset={l=1, r=1},
            subviews={
                widgets.HotkeyLabel{
                    frame={l=0},
                    key='CUSTOM_CTRL_O',
                    label='Toggle page TOC',
                    on_activate=function() self.subviews.shifter:toggle() end
                }
            }
        }
    }
end

function WikiWindow:onWikiPageSubmit(idx, choice)
    if self.on_page_change then
        self.on_page_change(choice.id)
    end
end

function WikiWindow:onJournalTocSubmit(idx, section)
    self.subviews.editor:setCursor(section.line_cursor)
    self.subviews.editor:scrollToCursor(section.line_cursor)
end

function WikiWindow:onTextChange(text)
    if self.on_text_change then
        self.on_text_change(text)
    end
    self:reloadJournalToc()
end

function WikiWindow:onCursorChange(cursor)
    self.subviews.journal_toc_panel.text_cursor = cursor
    local section_index = self.subviews.journal_toc_panel:currentSection()
    self.subviews.journal_toc_panel:setSelectedSection(section_index)
end

function WikiWindow:reloadJournalToc()
    self.subviews.journal_toc_panel:reload(
        self.subviews.editor:getText(),
        self.subviews.editor:getCursor() or 1
    )
end

function WikiWindow:setPageContent(text, cursor)
    self.subviews.editor:setText(text)
    self.subviews.editor:setCursor(cursor or 1)
    self:reloadJournalToc()
end

function WikiWindow:ensurePanelsRelSize()
    local wiki_toc = self.subviews.wiki_toc_panel
    local wiki_divider = self.subviews.wiki_toc_divider
    local journal_toc = self.subviews.journal_toc_panel
    local journal_divider = self.subviews.journal_toc_divider
    local shifter = self.subviews.shifter
    local editor = self.subviews.editor

    local x = wiki_toc.frame.w
    wiki_divider.frame.l = x
    x = x + 1
    
    shifter.frame.l = x
    if journal_toc.visible then
        journal_toc.frame.l = x
        x = x + journal_toc.frame.w
        journal_divider.frame.l = x
        x = x + 1
    end
    
    editor.frame.l = x
end

function WikiWindow:preUpdateLayout()
    self:ensurePanelsRelSize()
end

function WikiWindow:onRenderBody(painter)
    WikiWindow.super.onRenderBody(self, painter)
end

--------------------------------------------------------------------------------
--- Wiki Context & Screen

WikiContext = defclass(WikiContext)
WikiContext.ATTRS{
    save_prefix = 'dfmyfortwiki:',
}

function WikiContext:get_key(page_id)
    return self.save_prefix .. 'page:' .. page_id
end

function WikiContext:save_content(page_id, text, cursor)
    if dfhack.isWorldLoaded() then
        dfhack.persistent.saveSiteData(
            self:get_key(page_id),
            {text={text}, cursor={cursor}}
        )
    end
end

function WikiContext:load_content(page_id)
    if dfhack.isWorldLoaded() then
        local data = dfhack.persistent.getSiteData(self:get_key(page_id)) or {}
        if not data.text then
            data.text = {''}
        end
        data.cursor = data.cursor or {#data.text[1] + 1}
        return data
    end
    return {text={''}, cursor={1}}
end

WikiScreen = defclass(WikiScreen, gui.ZScreen)
WikiScreen.ATTRS {
    focus_path='my-fort-wiki',
}

function WikiScreen:init()
    self.context = WikiContext{}
    self.current_page_id = 'fort'
    
    local content = self.context:load_content(self.current_page_id)
    
    self:addviews{
        WikiWindow{
            view_id='wiki_window',
            frame={w=100, h=50},
            on_page_change=self:callback('onPageChange'),
            on_text_change=self:callback('onTextChange'),
        }
    }
    
    -- Load initial page
    if content.text[1] == '' then
        content.text[1] = "# Fort\n\nWelcome to your fortress wiki page."
    end
    self.subviews.wiki_window:setPageContent(content.text[1], content.cursor[1])
    self.subviews.wiki_window.subviews.wiki_page_list:setSelected(2) -- Select 'Fort'
end

function WikiScreen:onPageChange(page_id)
    -- Save current page before switching
    local text = self.subviews.wiki_window.subviews.editor:getText()
    local cursor = self.subviews.wiki_window.subviews.editor:getCursor()
    self.context:save_content(self.current_page_id, text, cursor)
    
    -- Load new page
    self.current_page_id = page_id
    local content = self.context:load_content(page_id)
    
    -- Default placeholder if page is new
    if content.text[1] == '' then
        content.text[1] = "# " .. page_id:gsub("^%l", string.upper) .. "\n\nThis is a placeholder for the " .. page_id .. " page."
    end
    
    self.subviews.wiki_window:setPageContent(content.text[1], content.cursor[1])
end

function WikiScreen:onTextChange(text)
    local cursor = self.subviews.wiki_window.subviews.editor:getCursor()
    self.context:save_content(self.current_page_id, text, cursor)
end

function WikiScreen:onDismiss()
    view = nil
end

function show_wiki()
    if not dfhack.isMapLoaded() or not dfhack.world.isFortressMode() then
        qerror('wiki requires a fortress map to be loaded')
    end

    view = view and view:raise() or WikiScreen{}:show()
end

function main()
    show_wiki()
end

if not dfhack_flags.module then
    main()
end

return _ENV
