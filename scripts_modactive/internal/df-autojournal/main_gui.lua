--@ module = true
local gui = require('gui')
local widgets = require('gui.widgets')
local json = require('json')

local logger = reqscript('internal/df-autojournal/logger')
local wiki_widgets = reqscript('internal/df-autojournal/wiki_widgets')
local wiki_initializer = reqscript('internal/df-autojournal/initializer')
local wiki_settings = reqscript('internal/df-autojournal/settings_gui')
local chronicle = reqscript('internal/df-autojournal/chronicle')
local utils = reqscript('internal/df-autojournal/wiki_utils')
local HyperTextArea = reqscript('internal/df-autojournal/wiki_widgets/hyper_text_area').HyperTextArea

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
    resize_min={w=56, h=20},
    frame_inset={l=0,r=0,t=0,b=0},
    on_initialize=DEFAULT_NIL,
    on_page_change=DEFAULT_NIL,
    on_page_tree_toggle=DEFAULT_NIL,
    on_text_change=DEFAULT_NIL,
    on_link_click=DEFAULT_NIL,
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
                    initial_option=function()
                        local data = dfhack.persistent.getSiteData('mfw_auto_journal_enabled')
                        return data and data.val and data.val[1] == 1
                    end,
                    on_change=function(val)
                        logger.log("Auto-Journaling toggled: " .. tostring(val))
                        dfhack.persistent.saveSiteData('mfw_auto_journal_enabled', {val={val and 1 or 0}})
                    end,
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
        HyperTextArea{
            view_id='editor',
            frame={t=1, b=3, l=26, r=0},
            text_pen=COLOR_LIGHTCYAN,
            link_pen=COLOR_LIGHTBLUE,
            link_hover_pen=COLOR_WHITE,
            link_pages=PAGES,
            on_link_click=function(link_data)
                if self.on_link_click then
                    self.on_link_click(link_data)
                end
            end,
            on_text_change=function(raw, display)
                self:onTextChange(raw, display)
            end,
            on_cursor_change=function(cursor, old)
                self:onCursorChange(cursor, old)
            end,
        },
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
    if choice.is_parent then
        local list = self.subviews.wiki_page_list
        if list then
            local mx = list:getMousePos()
            if mx and mx >= 0 and mx <= 3 then
                if self.on_page_tree_toggle then
                    self.on_page_tree_toggle(choice.id)
                end
                return
            end
        end
        if self.on_page_change then
            self.on_page_change(choice.id)
        end
    elseif self.on_page_change then
        self.on_page_change(choice.id)
    end
end

function WikiWindow:onLinkClick(link_data)
    if self.on_link_click then
        self.on_link_click(link_data)
    end
end

function WikiWindow:onJournalTocSubmit(idx, section)
    self.subviews.editor.hyper_text_area:setCursor(section.line_cursor)
end

function WikiWindow:onTextChange(raw, display)
    if self.on_text_change then
        self.on_text_change(display)
    end
    self:reloadJournalToc()
end

function WikiWindow:onCursorChange(cursor, old)
    self.subviews.journal_toc_panel.text_cursor = cursor
    local section_index = self.subviews.journal_toc_panel:currentSection()
    self.subviews.journal_toc_panel:setSelectedSection(section_index)
end

function WikiWindow:reloadJournalToc()
    self.subviews.journal_toc_panel:reload(
        self.subviews.editor:getRawText(),
        self.subviews.editor.hyper_text_area.cursor or 1
    )
end

function WikiWindow:setPageContent(display_text, cursor)
    self.subviews.editor:setDisplayText(display_text)
    self.subviews.editor.hyper_text_area:setCursor(cursor or 1)
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
    save_prefix = 'mfw_',
}

function WikiContext:get_key(page_id)
    return self.save_prefix .. 'p_' .. page_id
end

function WikiContext:save_content(page_id, display_text, cursor)
    if dfhack.isWorldLoaded() then
        local key = self:get_key(page_id)
        logger.log("WikiContext: Saving page " .. page_id .. " (key: " .. key .. ")")
        local ok, err = pcall(dfhack.persistent.saveSiteData, key, {content=display_text, cursor={cursor}})
        if not ok then
            logger.log_error("WikiContext: Failed to persist page " .. page_id .. ": " .. tostring(err))
        end
    end
end

function WikiContext:load_content(page_id)
    if dfhack.isWorldLoaded() then
        local key = self:get_key(page_id)
        local ok, data = pcall(function()
            return dfhack.persistent.getSiteData(key) or {}
        end)
        if not ok or not data then
            logger.log("WikiContext: Failed to load page " .. page_id .. " or no data found.")
            data = {}
        end
        if not data.content then
            data.content = {}
        elseif type(data.content) == 'string' then
            data.content = {{text=data.content, pen=COLOR_LIGHTCYAN}}
        end
        data.cursor = data.cursor or {1}
        logger.log("WikiContext: Loaded page " .. page_id)
        return data
    end
    return {content={}, cursor={1}}
end

function WikiContext:get_dynamic_pages()
    if not dfhack.isWorldLoaded() then return {} end
    local ok, data = pcall(function()
        return dfhack.persistent.getSiteData(self.save_prefix .. 'dynamic_pages') or {}
    end)
    if not ok or not data then return {} end
    local pages = data.pages or {}
    logger.log("WikiContext: Loaded " .. #pages .. " dynamic pages.")
    return pages
end

function WikiContext:save_dynamic_pages(pages)
    if dfhack.isWorldLoaded() then
        logger.log("WikiContext: Saving " .. #pages .. " dynamic pages.")
        dfhack.persistent.saveSiteData(self.save_prefix .. 'dynamic_pages', {pages=pages})
    end
end

function WikiContext:save_window_frame(frame)
    if dfhack.isWorldLoaded() then
        dfhack.persistent.saveSiteData(self.save_prefix .. 'window_frame', frame)
    end
end

function WikiContext:load_window_frame()
    if not dfhack.isWorldLoaded() then return nil end
    local ok, data = pcall(function()
        return dfhack.persistent.getSiteData(self.save_prefix .. 'window_frame') or {}
    end)
    if ok and data and data.w and data.h then
        return {w=data.w, h=data.h}
    end
    return nil
end

WikiScreen = defclass(WikiScreen, gui.ZScreen)
WikiScreen.ATTRS {
    focus_path='my-fort-wiki',
    pass_pause=false,
}

function WikiScreen:init()
    self.context = WikiContext{}
    self.current_page_id = 'fort'
    self.expanded = {}

    -- Start background chronicle if not already running
    -- chronicle.start_background_task(self.context)

    local win_frame = self.context:load_window_frame() or {w=100, h=50}

    self:addviews{
        WikiWindow{
            view_id='wiki_window',
            frame=win_frame,
            on_initialize=self:callback('onInitialize'),
            on_page_change=self:callback('onPageChange'),
            on_page_tree_toggle=self:callback('onPageTreeToggle'),
            on_text_change=self:callback('onTextChange'),
            on_link_click=function(link_data) self:onPageChange(link_data) end,
        }
    }

    self:refreshPageList()
    self:updateLinkPages()
    self:onPageChange(self.current_page_id, true)
end

function WikiScreen:refreshPageList()
    local dynamic = self.context:get_dynamic_pages()

    local page_tree = wiki_widgets.build_page_tree(PAGES, dynamic)
    local flat = wiki_widgets.flatten_page_tree(page_tree, self.expanded)

    local list = self.subviews.wiki_window.subviews.wiki_page_list
    list:setChoices(flat)

    -- Restore selection
    for idx, p in ipairs(flat) do
        if p.id == self.current_page_id then
            list:setSelected(idx)
            break
        end
    end
end

function WikiScreen:onPageTreeToggle(page_id)
    if self.expanded[page_id] then
        self.expanded[page_id] = nil
    else
        self.expanded[page_id] = true
    end
    self:refreshPageList()
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
            self:updateLinkPages()
            self:onPageChange(self.current_page_id, true)
        end
    }

    initializer:perform(self)
    self.initializing = false
end

function WikiScreen:onPageChange(page_id, no_save)
    -- Save current page before switching
    if not no_save then
        local editor = self.subviews.wiki_window.subviews.editor
        self.context:save_content(self.current_page_id, editor.display_text, editor.hyper_text_area.cursor)
    end

    -- Load new page
    self.current_page_id = page_id
    local data = self.context:load_content(page_id)

    -- Default placeholder if page is empty
    if #data.content == 0 or (type(data.content[1]) == 'string' and data.content[1] == '') then
        local title = page_id:gsub("^%l", string.upper)
        for _, p in ipairs(PAGES) do
            if p.id == page_id then title = p.text break end
        end
        local dynamic = self.context:get_dynamic_pages()
        for _, p in ipairs(dynamic) do
            if p.id == page_id then title = p.text break end
        end

        data.content = {
            { text = "# " .. title, pen = COLOR_YELLOW },
            "\n\nWelcome to the ",
            { text = title, pen = COLOR_LIGHTCYAN },
            " page.",
        }
    end

    self.subviews.wiki_window:setPageContent(data.content, data.cursor[1] or 1)
end

function WikiScreen:onTextChange(display_text)
    local editor = self.subviews.wiki_window.subviews.editor
    self.context:save_content(self.current_page_id, display_text, editor.hyper_text_area.cursor)
end

function WikiScreen:updateLinkPages()
    local dynamic = self.context:get_dynamic_pages()
    local all_pages = {}
    for _, p in ipairs(PAGES) do table.insert(all_pages, p) end
    for _, p in ipairs(dynamic) do table.insert(all_pages, p) end
    self.subviews.wiki_window.subviews.editor.link_pages = all_pages
end

function WikiScreen:onDismiss()
    local win = self.subviews.wiki_window
    if win and win.frame_body then
        self.context:save_window_frame({
            w=win.frame_body.width,
            h=win.frame_body.height
        })
    end
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
