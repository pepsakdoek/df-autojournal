--@ module=true
local gui = require('gui')
local widgets = require('gui.widgets')

-- File logging helper
local function log_to_file(msg)
    local f = io.open("wiki_debug.log", "a")
    if f then
        f:write(os.date("%Y-%m-%d %H:%M:%S") .. " - " .. tostring(msg) .. "\n")
        f:close()
    end
end

WikiScreen = defclass(WikiScreen, gui.ZScreen)
WikiScreen.ATTRS {
    focus_path = 'my-fort-wiki',
}

function WikiScreen:init()
    log_to_file("Wiki: init called")
    self.pages = {
        ["Home"] = {
            title = "Welcome to My Fort Wiki",
            content = {
                "This is the start of your fortress documentation. ",
                "You can explore the ",
                {text = "History", pen = dfhack.pen.parse{fg=COLOR_CYAN}, on_click = function() self:go_to_page("History") end},
                " or check the ",
                {text = "Champion", pen = dfhack.pen.parse{fg=COLOR_CYAN}, on_click = function() self:go_to_page("Champion") end},
                "."
            }
        },
        ["History"] = {
            title = "Fortress History",
            content = {
                "The fortress was founded in the year 123. ",
                "Return to ",
                {text = "Home", pen = dfhack.pen.parse{fg=COLOR_CYAN}, on_click = function() self:go_to_page("Home") end},
                "."
            }
        },
        ["Champion"] = {
            title = "The Fort Champion",
            content = {
                "Our champion is Urist McGladiator. ",
                "Return to ",
                {text = "Home", pen = dfhack.pen.parse{fg=COLOR_CYAN}, on_click = function() self:go_to_page("Home") end},
                "."
            }
        }
    }
    self.current_page = "Home"

    self:addviews{
        widgets.Window{
            view_id = 'main',
            frame = {w = 80, h = 30, align_x = 0.5, align_y = 0.5},
            frame_title = "My Fort Wiki",
            resizable = true,
            resize_min = {w = 40, h = 15},
            subviews = {
                -- Sidebar
                widgets.Panel{
                    view_id = 'sidebar',
                    frame = {t = 0, l = 0, w = 20, b = 0},
                    frame_style = gui.GREY_LINE_FRAME,
                    subviews = {
                        widgets.Label{
                            frame = {t = 0, l = 1},
                            text = "Index"
                        },
                        widgets.List{
                            view_id = 'page_list',
                            frame = {t = 2, l = 0, b = 2},
                            on_select = function(idx, item) 
                                if item and item.full_text then 
                                    log_to_file("Wiki: Sidebar select: " .. tostring(item.full_text))
                                    self:go_to_page(item.full_text) 
                                end 
                            end,
                            on_submit = function(idx, item) 
                                if item and item.full_text then 
                                    log_to_file("Wiki: Sidebar submit: " .. tostring(item.full_text))
                                    self:go_to_page(item.full_text) 
                                end 
                            end,
                        },
                        widgets.TextButton{
                            frame = {b = 0, l = 0},
                            text = "New Page",
                            on_click = function() self:add_random_page() end
                        }
                    }
                },
                -- Content area
                widgets.Panel{
                    view_id = 'content_panel',
                    frame = {t = 0, l = 21, r = 0, b = 0},
                    subviews = {
                        widgets.Label{
                            view_id = 'page_title',
                            frame = {t = 0, l = 0, r = 0},
                            text = "Title",
                            text_pen = dfhack.pen.parse{fg=COLOR_YELLOW, bold=true}
                        },
                        -- Container for scrollable content
                        widgets.Panel{
                            view_id = 'scroll_container',
                            frame = {t = 2, l = 0, r = 2, b = 0},
                            subviews = {
                                widgets.WrappedLabel{
                                    view_id = 'page_content',
                                    frame = {t = 0, l = 0, r = 0}, 
                                    text = ""
                                }
                            }
                        },
                        widgets.Scrollbar{
                            view_id = 'content_scrollbar',
                            frame = {t = 2, r = 0, b = 0},
                            on_scroll = function(val)
                                self.subviews.page_content.frame.t = -val
                            end
                        }
                    }
                }
            }
        }
    }
end

function WikiScreen:onRenderBody(dc)
    if not self.initialized then
        self.initialized = true
        log_to_file("Wiki: first render - initializing")
        self:refresh_page_list()
        self:go_to_page(self.current_page)
    end
    WikiScreen.super.onRenderBody(self, dc)
end

function WikiScreen:refresh_page_list()
    log_to_file("Wiki: refresh_page_list")
    local list_items = {}
    local sorted_keys = {}
    for k in pairs(self.pages) do table.insert(sorted_keys, k) end
    table.sort(sorted_keys)

    for _, k in ipairs(sorted_keys) do
        local display_text = " " .. k
        table.insert(list_items, {text = display_text, full_text = k})
    end
    self.subviews.page_list:setChoices(list_items)
end

function WikiScreen:go_to_page(page_name)
    log_to_file("Wiki: go_to_page: " .. tostring(page_name))
    if self.in_go_to_page then 
        log_to_file("Wiki: go_to_page BLOCKED (recursion)")
        return 
    end
    
    local page = self.pages[page_name]
    if not page then 
        log_to_file("Wiki: ERROR - Page not found: " .. tostring(page_name))
        return 
    end

    self.in_go_to_page = true
    self.current_page = page_name
    
    self.subviews.page_title:setText(page.title)
    self.subviews.page_content:setText(page.content)
    
    self.subviews.page_content.frame.t = 0
    -- local scrollbar = self.subviews.content_scrollbar
    -- if scrollbar.scrollTo then
    --     scrollbar:scrollTo(0)
    -- else
    --     scrollbar.val = 0
    -- end

    -- -- Update layout
    -- self:updateLayout()
    
    -- -- Configure scrollbar
    -- local container_h = self.subviews.scroll_container.frame.h or 1
    -- local content_h = self.subviews.page_content.frame.h or 0
    -- scrollbar:setPageSize(container_h)
    -- scrollbar:setRange(0, math.max(0, content_h - container_h))

    -- Update list selection visuals
    local list = self.subviews.page_list
    for i, item in ipairs(list:getChoices()) do
        if item.full_text == page_name then
            if list:getSelected() ~= i then
                list:setSelected(i)
            end
            break
        end
    end

    self.in_go_to_page = false
    self:updateLayout()
    log_to_file("Wiki: go_to_page DONE")
end

function WikiScreen:add_random_page()
    log_to_file("Wiki: add_random_page")
    local new_id = tostring(math.random(1000, 9999))
    local new_name = "Page " .. new_id
    
    local existing_pages = {}
    for k in pairs(self.pages) do table.insert(existing_pages, k) end
    local back_link = existing_pages[math.random(#existing_pages)]

    self.pages[new_name] = {
        title = "Auto-generated " .. new_name,
        content = {
            "This page was created programmatically. ",
            "It contains a link back to ",
            {text = back_link, pen = dfhack.pen.parse{fg=COLOR_CYAN}, on_click = function() self:go_to_page(back_link) end},
            "."
        }
    }

    self:refresh_page_list()
    self:go_to_page(new_name)
end

function WikiScreen:onInput(keys)
    if keys.LEAVESCREEN then
        self:dismiss()
        return true
    end
    if keys._MOUSE_L or keys._MOUSE_R then
        -- This helps capture mouse focus for panels
    end
    return WikiScreen.super.onInput(self, keys)
end

function show_wiki()
    local screen = WikiScreen()
    screen:show()
end

if not dfhack_flags.module then
    show_wiki()
end

return _ENV
