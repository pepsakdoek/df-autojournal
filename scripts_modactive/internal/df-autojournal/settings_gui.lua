--@ module = true
local gui = require('gui')
local widgets = require('gui.widgets')
local TabBar = require('gui.widgets.tab_bar')
local mfw_settings = reqscript('internal/df-autojournal/wiki_settings')
local wiki_widgets = reqscript('internal/df-autojournal/wiki_widgets')

local logger = reqscript('internal/df-autojournal/logger')

local TEMPLATE_IDS = {'civ', 'fort', 'citizen', 'artifact', 'event'}
local TEMPLATE_LABELS = {'Civ', 'Fort', 'Citizen', 'Artifact', 'Event'}
local LABEL_WIDTH = 20

local function capitalize(str)
    return (str:gsub("^%l", string.upper):gsub("_", " "))
end

local SETTING_DESCRIPTIONS = {
    civ = {
        init = {
            leadership = "Show leadership hierarchy and government positions",
            ethics = "Show civilization ethics and value system",
            relations = "Show diplomatic relationships with other civilizations",
            history = "Show major historical events of the civilization",
            wars = "Show war and conflict records",
        },
        journal = {
            diplomacy = "Auto-record diplomatic events and treaty changes",
            wars = "Auto-record war declarations and peace treaties",
            leadership = "Auto-record leadership changes and succession",
        },
    },
    fort = {
        init = {
            wealth = "Show fort wealth and economic status",
            gov = "Show local government structure and ruling entities",
            districts = "Show infrastructure and district information",
            defense = "Show military and defense capabilities",
            links = "Show economic and political links to other sites",
            timeline = "Show founding and historical timeline",
        },
        journal = {
            population = "Auto-record population changes and migration waves",
            construction = "Auto-record major construction projects",
            defense = "Auto-record siege and military events",
        },
    },
    citizen = {
        init = {
            values = "Show personality values and beliefs",
            relationships = "Show family and social relationships",
            skills = "Show notable skills and proficiencies",
            appearance = "Show physical appearance description",
            needs = "Show current needs and desires",
            medical = "Show health status and injuries",
            timeline = "Show personal timeline of events",
        },
        journal = {
            pet_adopted = "Auto-record when a citizen adopts a pet",
            died = "Auto-record citizen deaths and causes",
            renamed = "Auto-record name changes",
        },
    },
    artifact = {
        init = {
            description = "Show artifact visual description",
            history = "Show artifact history and creation story",
            creator = "Link to the artifact's creator in history",
            location = "Show current location and holder of the artifact",
        },
        journal = {
            created = "Auto-record when new artifacts are created",
        },
    },
    event = {
        init = {
            participants = "Show key participants in the event",
            summary = "Show a brief summary of what happened",
            consequences = "Show aftermath and consequences",
        },
        journal = {
            new_events = "Auto-record newly generated world events",
        },
    },
}

local function desc(tab_id, category, key)
    local d = SETTING_DESCRIPTIONS[tab_id]
    return d and d[category] and d[category][key] or (capitalize(key) .. ' setting')
end

local function make_toggle(tab_id, category, key, initial_val, row)
    local display_name = capitalize(key)
    local padding = string.rep(' ', LABEL_WIDTH - #display_name)
    return wiki_widgets.ToggleLabel{
        view_id='toggle_' .. tab_id .. '_' .. category .. '_' .. key,
        frame={t=row, l=0, r=0},
        label=display_name .. padding .. ' ',
        initial_option=initial_val,
        on_change=function(val)
            local s = mfw_settings.get_settings()
            if s[tab_id] and s[tab_id][category] then
                s[tab_id][category][key] = val
                mfw_settings.save_settings(s)
            end
        end,
    }
end

local function create_tab_panel(tab_id)
    local settings = mfw_settings.get_settings()
    local t = settings[tab_id]
    if not t then
        return widgets.Panel{view_id='panel_' .. tab_id}
    end

    local subviews = {}
    local row = 0

    table.insert(subviews, widgets.Label{
        view_id='section_init_' .. tab_id,
        frame={t=row, l=0},
        text='Initialization',
        text_pen=COLOR_LIGHTCYAN,
    })
    row = row + 1

    local init_keys = {}
    for k, _ in pairs(t.init) do table.insert(init_keys, k) end
    table.sort(init_keys)
    for _, key in ipairs(init_keys) do
        table.insert(subviews, make_toggle(tab_id, 'init', key, t.init[key], row))
        row = row + 1
    end

    row = row + 1

    table.insert(subviews, widgets.Label{
        view_id='section_journal_' .. tab_id,
        frame={t=row, l=0},
        text='Auto-Journaling',
        text_pen=COLOR_LIGHTCYAN,
    })
    row = row + 1

    local journal_keys = {}
    for k, _ in pairs(t.journal) do table.insert(journal_keys, k) end
    table.sort(journal_keys)
    for _, key in ipairs(journal_keys) do
        table.insert(subviews, make_toggle(tab_id, 'journal', key, t.journal[key], row))
        row = row + 1
    end

    return widgets.Panel{
        view_id='panel_' .. tab_id,
        subviews=subviews,
    }
end

local settings_instance = nil

SettingsWindow = defclass(SettingsWindow, widgets.Window)
SettingsWindow.ATTRS {
    frame_title='Wiki Settings',
    frame={w=56, h=24},
    resizable=true,
    resize_min={w=56, h=16},
}

function SettingsWindow:init()
    self.current_tab_idx = 1
    self.current_tab_id = 'civ'
    self.tab_panels = {}

    local all_views = {
        TabBar{
            view_id='tab_bar',
            labels=TEMPLATE_LABELS,
            on_select=function(idx) self:onTabSelected(idx) end,
            get_cur_page=function() return self.current_tab_idx end,
            frame={t=0, l=0, r=0},
            key=false,
            key_back=false,
        },
    }

    for i, id in ipairs(TEMPLATE_IDS) do
        local panel = create_tab_panel(id)
        panel.frame = {t=3, l=0, r=0, b=2}
        panel.visible = (i == 1)
        table.insert(all_views, panel)
        self.tab_panels[id] = panel
    end

    table.insert(all_views, widgets.Label{
        view_id='help_bar',
        frame={b=0, l=0, r=0, h=1},
        text='Select a setting above to see its description',
        text_pen=COLOR_GREY,
    })

    self:addviews(all_views)
end

function SettingsWindow:onTabSelected(idx)
    local id = TEMPLATE_IDS[idx]
    if id then
        self.current_tab_idx = idx
        self.current_tab_id = id
        for panel_id, panel in pairs(self.tab_panels) do
            panel.visible = (panel_id == id)
        end
        self.subviews.help_bar:setText('Select a setting above to see its description')
    end
end

function SettingsWindow:updateHoverHelp()
    local found = false
    for panel_id, panel in pairs(self.tab_panels) do
        if panel.visible then
            for _, sv in ipairs(panel.subviews) do
                local vid = sv.view_id
                if vid and vid:match('^toggle_') then
                    local mx, my = sv:getMousePos()
                    if mx then
                        local tab_id, category, key = vid:match('^toggle_(.+)_(.+)_(.+)$')
                        if tab_id then
                            self.subviews.help_bar:setText(desc(tab_id, category, key))
                            found = true
                        end
                        break
                    end
                end
            end
            if found then break end
        end
    end
    if not found then
        local tab_id = self.current_tab_id
        local any_hovered = false
        for panel_id, panel in pairs(self.tab_panels) do
            if panel.visible then
                local mx, my = panel:getMousePos()
                if mx then any_hovered = true end
                break
            end
        end
        if not any_hovered then
            local mx, my = self:getMousePos()
            if not mx then
                self.subviews.help_bar:setText('Select a setting above to see its description')
            end
        end
    end
end

function SettingsWindow:onRenderBody(dc)
    SettingsWindow.super.onRenderBody(self, dc)
    self:updateHoverHelp()
end

SettingsScreen = defclass(SettingsScreen, gui.ZScreen)
SettingsScreen.ATTRS {
    focus_path='mfw-settings',
    pass_pause=true,
}

function SettingsScreen:init()
    self:addviews{SettingsWindow{}}
end

function SettingsScreen:onDismiss()
    settings_instance = nil
end

function show_settings()
    if settings_instance then
        settings_instance:raise()
    else
        settings_instance = SettingsScreen{}:show()
    end
end

return _ENV
