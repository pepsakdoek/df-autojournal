--@ module=true
local gui = require('gui')
local widgets = require('gui.widgets')

WikiScreen = defclass(WikiScreen, gui.ZScreen)
WikiScreen.ATTRS {
    focus_path = 'my-fort-wiki',
}

function WikiScreen:init()
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
                            frame = {t = 0, l = 0},
                            -- add space in fron for the [ ] that surrounds the 'pages'
                            text = " Index"
                        },
                        widgets.List{
                            view_id = 'page_list',
                            frame = {t = 2, l = 0, b = 2},
                            on_select = function(idx, item) self:go_to_page(item.full_text) end,
                            on_submit = function(idx, item) self:go_to_page(item.full_text) end,
                        },
                        widgets.TextButton{
                            frame = {b = 1, l = 0},
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
                                widgets.TextArea{
                                    view_id = 'page_content',
                                    frame = {t = 0, l = 0, r = 0},
                                    text = "",
                                    text_to_wrap = true
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
        self:refresh_page_list()
        self:go_to_page(self.current_page)
    end
    WikiScreen.super.onRenderBody(self, dc)
end

function WikiScreen:refresh_page_list()
    local list_items = {}
    local sorted_keys = {}
    for k in pairs(self.pages) do table.insert(sorted_keys, k) end
    table.sort(sorted_keys)

    for _, k in ipairs(sorted_keys) do
        -- Keeping user style: ' ' .. k
        local display_text = ' ' .. k
        table.insert(list_items, {text = display_text, full_text = k})
    end
    self.subviews.page_list:setChoices(list_items)
end

function WikiScreen:go_to_page(page_name)
    if self.in_go_to_page then return end
    local page = self.pages[page_name]
    if not page then return end

    self.in_go_to_page = true
    self.current_page = page_name
    self.subviews.page_title:setText(page.title)
    
    local content_label = self.subviews.page_content
    content_label:setText(page.content)
    
    -- Reset scroll
    content_label.frame.t = 0
    if self.subviews.content_scrollbar.scrollTo then
        self.subviews.content_scrollbar:scrollTo(0)
    else
        self.subviews.content_scrollbar.val = 0
    end

    -- Update layout to calculate new height
    self:updateLayout()
    
    -- Configure scrollbar
    local container_h = self.subviews.scroll_container.frame.h or 1
    local content_h = content_label.frame.h or 0
    self.subviews.content_scrollbar:setPageSize(container_h)
    self.subviews.content_scrollbar:setRange(0, math.max(0, content_h - container_h))

    -- Update list selection
    for i, item in ipairs(self.subviews.page_list:getChoices()) do
        if item.full_text == page_name then
            if self.subviews.page_list:getSelected() ~= i then
                self.subviews.page_list:setSelected(i)
            end
            break
        end
    end
    self.in_go_to_page = false
end

function WikiScreen:add_random_page()
    local new_id = tostring(math.random(1000, 9999))
    local new_name = "Page " .. new_id
    
    -- Pick a random existing page to link back to
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
    return WikiScreen.super.onInput(self, keys)
end

function show_wiki()
    local screen = WikiScreen()
    screen:show()
end

if not dfhack_flags.module then
    show_wiki()
end
