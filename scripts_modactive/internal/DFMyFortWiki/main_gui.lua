--@ module = true
local gui = require('gui')
local widgets = require('gui.widgets')
local utils = require('utils')
local json = require('json')

local logger = reqscript('internal/DFMyFortWiki/logger')
local wiki_widgets = reqscript('internal/DFMyFortWiki/widgets')
local wiki_initializer = reqscript('internal/DFMyFortWiki/initializer')
local wiki_settings = reqscript('internal/DFMyFortWiki/settings_gui')

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
    on_initialize=DEFAULT_NIL,
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
                    frame={t=2, l=0, r=0, b=12},
                    choices=PAGES,
                    on_submit=self:callback('onWikiPageSubmit'),
                },
                -- Buttons at the bottom of Wiki TOC
                widgets.HotkeyLabel{
                    view_id='initialize_btn',
                    frame={b=8, l=0},
                    label='Initialize Wiki',
                    key='CUSTOM_ALT_I',
                    on_activate=self:callback('onInitialize'),
                },
                wiki_widgets.ToggleLabel{
                    view_id='toggle_auto',
                    frame={b=6, l=0},
                    label='Auto-Journaling ',
                    key='CUSTOM_ALT_A',
                    initial_option=false,
                    on_change=function(val) logger.log("Auto-Journaling toggled: " .. tostring(val)) end,
                },
                widgets.HotkeyLabel{
                    frame={b=4, l=0},
                    label='Settings',
                    key='CUSTOM_ALT_S',
                    on_activate=function() wiki_settings.show_settings() end,
                },
                widgets.HotkeyLabel{
                    frame={b=2, l=0},
                    label='Export to HTML',
                    key='CUSTOM_ALT_X',
                    on_activate=function() logger.log("Export triggered") end,
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
        wiki_widgets.TableOfContents{
            view_id='journal_toc_panel',
            frame={l=26, w=25, t=0, b=1},
            frame_inset={l=1, t=0, b=1, r=1},
            visible=false,
            on_submit=self:callback('onJournalTocSubmit'),
        },
        wiki_widgets.Shifter{
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

function WikiWindow:onInitialize()
    if self.on_initialize then
        self.on_initialize()
    end
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

--------------------------------------------------------------------------------
--- Wiki Context & Screen

WikiContext = defclass(WikiContext)
WikiContext.ATTRS{
    save_prefix = 'mfw:',
}

function WikiContext:get_key(page_id)
    return self.save_prefix .. 'p:' .. page_id
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

function WikiContext:get_dynamic_pages()
    if not dfhack.isWorldLoaded() then return {} end
    local data = dfhack.persistent.getSiteData(self.save_prefix .. 'dynamic_pages') or {}
    return data.pages or {}
end

function WikiContext:save_dynamic_pages(pages)
    if dfhack.isWorldLoaded() then
        dfhack.persistent.saveSiteData(self.save_prefix .. 'dynamic_pages', {pages=pages})
    end
end

WikiScreen = defclass(WikiScreen, gui.ZScreen)
WikiScreen.ATTRS {
    focus_path='my-fort-wiki',
}

function WikiScreen:init()
    self.context = WikiContext{}
    self.current_page_id = 'fort'

    self:addviews{
        WikiWindow{
            view_id='wiki_window',
            frame={w=100, h=50},
            on_initialize=self:callback('onInitialize'),
            on_page_change=self:callback('onPageChange'),
            on_text_change=self:callback('onTextChange'),
        }
    }

    self:refreshPageList()
    self:onPageChange(self.current_page_id, true)
end

function WikiScreen:refreshPageList()
    local pages = {}
    for _, p in ipairs(PAGES) do
        table.insert(pages, p)
    end
    
    local dynamic = self.context:get_dynamic_pages()
    for _, p in ipairs(dynamic) do
        table.insert(pages, p)
    end
    
    self.subviews.wiki_window.subviews.wiki_page_list:setChoices(pages)
    
    -- Restore selection
    for idx, p in ipairs(pages) do
        if p.id == self.current_page_id then
            self.subviews.wiki_window.subviews.wiki_page_list:setSelected(idx)
            break
        end
    end
end

function WikiScreen:onInitialize()
    local initialized = dfhack.persistent.getSiteData(self.context.save_prefix .. 'initialized')
    if initialized then
        gui.showYesNoPrompt('Re-initialize Wiki?',
            'The wiki has already been initialized. Re-initializing will overwrite existing pages. Continue?',
            COLOR_LIGHTRED,
            function() self:performInitialization() end
        )
    else
        self:performInitialization()
    end
end

function WikiScreen:performInitialization()
    if self.initializing then
        logger.log("Initialization already in progress. Ignoring.")
        return
    end
    self.initializing = true

    local initializer = wiki_initializer.WikiInitializer{
        context = self.context,
        on_complete = function()
            self:refreshPageList()
            self:onPageChange(self.current_page_id, true)
        end
    }
    
    initializer:perform(self)
    self.initializing = false
end

function WikiScreen:onPageChange(page_id, no_save)
    -- Save current page before switching
    if not no_save then
        local text = self.subviews.wiki_window.subviews.editor:getText()
        local cursor = self.subviews.wiki_window.subviews.editor:getCursor()
        self.context:save_content(self.current_page_id, text, cursor)
    end

    -- Load new page
    self.current_page_id = page_id
    local content = self.context:load_content(page_id)

    -- Default placeholder if page is new
    if content.text[1] == '' then
        local title = page_id:gsub("^%l", string.upper)
        -- Try to find name in PAGES or dynamic pages
        for _, p in ipairs(PAGES) do
            if p.id == page_id then title = p.text break end
        end
        local dynamic = self.context:get_dynamic_pages()
        for _, p in ipairs(dynamic) do
            if p.id == page_id then title = p.text break end
        end

        content.text[1] = "# " .. title .. "\n\nWelcome to the " .. title .. " page."
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
