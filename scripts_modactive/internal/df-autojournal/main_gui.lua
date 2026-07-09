--@ module = true
local gui = require('gui')
local dialogs = require('gui.dialogs')
local widgets = require('gui.widgets')
local json = require('json')
local gui_script = require('gui.script')

local logger = reqscript('internal/df-autojournal/logger')
local wiki_widgets = reqscript('internal/df-autojournal/wiki_widgets')
local wiki_initializer = reqscript('internal/df-autojournal/initializer')
local wiki_settings = reqscript('internal/df-autojournal/settings_gui')
local chronicle = reqscript('internal/df-autojournal/chronicle')
local event_listener = reqscript('internal/df-autojournal/event_listener')
local utils = reqscript('internal/df-autojournal/wiki_utils')
local wiki_functions = reqscript('internal/df-autojournal/wiki_functions')
local HyperTextArea = reqscript('internal/df-autojournal/wiki_widgets/hyper_text_area').HyperTextArea

local function extract_plain_text(content)
    local parts = {}
    for _, item in ipairs(content or {}) do
        if type(item) == 'string' then
            table.insert(parts, item)
        elseif type(item) == 'table' then
            if item.text then
                table.insert(parts, tostring(item.text))
            elseif item.type == 'table' then
                if item.columns then
                    for _, col in ipairs(item.columns) do
                        if col.header then
                            table.insert(parts, tostring(col.header) .. ' ')
                        end
                    end
                end
                if item.rows then
                    for _, row in ipairs(item.rows) do
                        for _, cell in ipairs(row) do
                            if type(cell) == 'table' and cell.text then
                                table.insert(parts, tostring(cell.text) .. ' ')
                            end
                        end
                    end
                end
            end
        end
    end
    return table.concat(parts)
end

local function analyze_search_tree(nodes, query, context)
    local any_match = false
    for _, node in ipairs(nodes) do
        local data = context:load_content(node.id)
        local plain_text = extract_plain_text(data.content)
        node._direct_match = plain_text:lower():find(query, 1, true) ~= nil

        node._descendant_match = false
        if node.children and #node.children > 0 then
            if analyze_search_tree(node.children, query, context) then
                node._descendant_match = true
            end
        end

        node._visible = node._direct_match or node._descendant_match
        if node._visible then
            any_match = true
        end
    end
    return any_match
end

local function flatten_search_tree(tree, depth)
    depth = depth or 0
    local result = {}
    for _, node in ipairs(tree) do
        if node._visible then
            local pad = string.rep(' ', depth + 1)
            local text_color = node._direct_match and COLOR_LIGHTCYAN or COLOR_DARKGREY

            table.insert(result, {
                text = {
                    { text = pad, pen = text_color },
                    { text = node.text, pen = text_color },
                },
                id = node.id,
            })

            if node.children and #node.children > 0 then
                local kids = flatten_search_tree(node.children, depth + 1)
                for _, child in ipairs(kids) do
                    table.insert(result, child)
                end
            end
        end
    end
    return result
end

--------------------------------------------------------------------------------
--- Wiki Pages Logic

local PAGES = {
    {text='World', id='world'},
    {text='Civilizations', id='civilizations'},
    {text='Forts', id='forts'},
}

WikiWindow = defclass(WikiWindow, widgets.Window)
WikiWindow.ATTRS {
    frame_title='My Fort Wiki',
    resizable=true,
    resize_min={w=56, h=26},
    frame_inset={l=0,r=0,t=0,b=0},
    on_initialize=DEFAULT_NIL,
    on_page_change=DEFAULT_NIL,
    on_page_tree_toggle=DEFAULT_NIL,
    on_text_change=DEFAULT_NIL,
    on_link_click=DEFAULT_NIL,
    on_search_change=DEFAULT_NIL,
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
                widgets.Label{
                    frame={t=2, l=0},
                    text='SEARCH:',
                    text_pen=COLOR_WHITE,
                },
                widgets.EditField{
                    view_id='wiki_search',
                    frame={t=2, l=8, r=0},
                    text='',
                    on_change=function(new_text, old_text)
                        if self.on_search_change then
                            self.on_search_change(new_text)
                        end
                    end,
                },
                widgets.List{
                    view_id='wiki_page_list',
                    frame={t=4, l=0, r=0, b=12},
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
                        return event_listener.is_running and event_listener.is_running() or false
                    end,
                    on_change=function(val)
                        if val == 'On' or val == true then
                            if event_listener.start then
                                pcall(event_listener.start)
                            end
                        else
                            if event_listener.stop then
                                pcall(event_listener.stop)
                            end
                        end
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
            fn_evaluator=function(fn_block)
                return wiki_functions.evaluate(fn_block)
            end,
            fn_functions=wiki_functions.list_functions(),
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
    logger.log("WikiWindow:onInitialize called")
    if self.on_initialize then
        self.on_initialize()
    else
        logger.log("WikiWindow:onInitialize - on_initialize is nil!")
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
        -- logger.log("WikiContext: Saving page " .. page_id .. " (key: " .. key .. ")")
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
            logger.log_error("WikiContext: Failed to load page " .. page_id .. " or no data found.")
            data = {}
        end
        if not data.content then
            data.content = {}
        elseif type(data.content) == 'string' then
            data.content = {{text=data.content, pen=COLOR_LIGHTCYAN}}
        end
        data.cursor = data.cursor or {1}
        -- logger.log("WikiContext: Loaded page " .. page_id)
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
    -- logger.log("WikiContext: Loaded " .. #pages .. " dynamic pages.")
    return pages
end

function WikiContext:save_dynamic_pages(pages)
    if dfhack.isWorldLoaded() then
        -- logger.log("WikiContext: Saving " .. #pages .. " dynamic pages.")
        dfhack.persistent.saveSiteData(self.save_prefix .. 'dynamic_pages', {pages=pages})
    end
end

function WikiContext:reset_all_data()
    if not dfhack.isWorldLoaded() then return end
    local function clear_key(key)
        pcall(dfhack.persistent.saveSiteData, key, nil)
    end
    local keys_to_clear = {
        'initialized', 'catchup_last_id', 'event_timeline', 'enemies',
        'visitors', 'seen_units', 'dynamic_pages',
    }
    for _, suffix in ipairs(keys_to_clear) do
        clear_key(self.save_prefix .. suffix)
    end
    -- Clear all wiki page content keys (mfw_p_*)
    local known_dynamic = self:get_dynamic_pages()
    for _, page in ipairs(known_dynamic) do
        clear_key(self:get_key(page.id))
    end
    -- Clear root pages
    for _, page in ipairs(PAGES) do
        clear_key(self:get_key(page.id))
    end
    logger.log("reset_all_data: wiped all wiki data")
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
    force_pause=true,
    pass_pause=true,
}

function WikiScreen:init()
    self.context = WikiContext{}
    self.current_page_id = 'world'
    self.expanded = {}
    self.search_mode = false
    self.search_query = ''

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
            on_search_change=function(query) self:onSearch(query) end,
        }
    }

    self:refreshPageList()
    self:updateLinkPages()
    self:onPageChange(self.current_page_id, true)
end

function WikiScreen:onSearch(query)
    self.search_query = query or ''
    if #self.search_query == 0 then
        self.search_mode = false
        self:refreshPageList()
        return
    end

    self.search_mode = true
    self:displaySearchResults(self.search_query)
end

function WikiScreen:displaySearchResults(query)
    local dynamic = self.context:get_dynamic_pages()

    local membership = {}
    pcall(function()
        local data = dfhack.persistent.getSiteData('mfw_fort_members')
        if data and data.members then membership = data.members end
    end)

    local page_tree = wiki_widgets.build_page_tree(PAGES, dynamic, membership)
    analyze_search_tree(page_tree, query:lower(), self.context)
    local flat = flatten_search_tree(page_tree)

    local list = self.subviews.wiki_window.subviews.wiki_page_list
    list:setChoices(flat)

    if #flat > 0 then
        list:setSelected(1)
    end
end

function WikiScreen:refreshPageList()
    if self.search_mode then return end
    local dynamic = self.context:get_dynamic_pages()

    local membership = {}
    pcall(function()
        local data = dfhack.persistent.getSiteData('mfw_fort_members')
        if data and data.members then membership = data.members end
    end)

    local page_tree = wiki_widgets.build_page_tree(PAGES, dynamic, membership)
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
    logger.log("onInitialize: initialized=" .. tostring(initialized))
    if initialized then
        self._reinit_stage = 1
        logger.log("onInitialize: showing first reinit dialog")
        dialogs.showYesNoPrompt('Re-initialize Wiki?',
            'You already have a wiki. Re-initializing will OVERWRITE ALL existing pages. This cannot be undone. Continue?',
            COLOR_LIGHTRED,
            function()
                logger.log("onReinitConfirmed: stage 1 confirmed")
                self._reinit_stage = 2
                dialogs.showYesNoPrompt('REALLY Re-initialize?',
                    'FINAL WARNING: All wiki pages will be replaced with fresh templates. Manual edits, notes, and custom entries will be LOST. Proceed?',
                    COLOR_LIGHTRED,
                    function()
                        logger.log("onReinitConfirmed: stage 2 confirmed, running init")
                        self._reinit_stage = nil
                        self.context:reset_all_data()
                        self:performInitialization()
                    end
                )
            end
        )
    else
        logger.log("onInitialize: no flag set, calling performInitialization directly")
        self:performInitialization()
    end
end

function WikiScreen:performInitialization()
    if self.initializing then
        logger.log("Initialization already in progress. Ignoring.")
        return
    end
    self.initializing = true

    local progress = wiki_widgets.ProgressBarScreen{
        frame_title = 'Initializing Wiki',
        steps = {
            'Tracking civilizations & forts',
            'Rendering index pages',
            'World page',
            'Citizens',
            'Artifacts',
            'Creating section pages',
            'Saving dynamic pages',
            'Historical catch-up',
            'Finalizing',
        },
    }
    progress:show()

    local initializer = wiki_initializer.WikiInitializer{
        context = self.context,
        on_complete = function()
            progress:dismiss()
            self:refreshPageList()
            self:updateLinkPages()
            self:onPageChange(self.current_page_id, true)
            self.initializing = false
        end,
    }

    initializer.on_step = function(idx, total, name)
        progress:setCurrent(idx, 'Working on ' .. name .. '...')
    end
    initializer.on_batch = function(scanned, total, matched)
        progress:setSubProgress(scanned, total, matched)
    end

    gui_script.start(function()
        local ok = initializer:perform_async()
        if not ok then
            progress:dismiss()
            self.initializing = false
        end
    end)
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

    -- Set editor context based on page type (for function arg pre-fill)
    local editor = self.subviews.wiki_window.subviews.editor
    local ctx = {}
    local entity_id = page_id:match('/([^/]+)$') or page_id
    local prefix, id = entity_id:match("^(%a+):(%d+)$")
    if prefix and id then
        if prefix == 'citizen' then
            local uid = tonumber(id)
            ctx.unit_id = uid
            local unit = df.unit.find(uid)
            if unit and unit.birth_year then
                ctx.birth_year = unit.birth_year
            end
        elseif prefix == 'artifact' then
            ctx.item_id = tonumber(id)
        end
    end
    editor.fn_context = ctx

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
    if win then
        local editor = win.subviews.editor
        if editor then
            self.context:save_content(self.current_page_id, editor.display_text, editor.hyper_text_area.cursor)
        end
        if win.frame_body then
            self.context:save_window_frame({
                w=win.frame_body.width,
                h=win.frame_body.height
            })
        end
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
