--@ module = true
local gui = require('gui')
local widgets = require('gui.widgets')
local wiki_widgets = reqscript('internal/DFMyFortWiki/wiki_widgets')
local mfw_settings = reqscript('internal/DFMyFortWiki/wiki_settings')

local logger = reqscript('internal/DFMyFortWiki/logger')

SettingsWindow = defclass(SettingsWindow, widgets.Window)
SettingsWindow.ATTRS {
    frame_title='Wiki Settings',
    frame={w=60, h=40},
}

function SettingsWindow:init()
    self.settings = mfw_settings.get_settings()

    local function create_toggle(label, template, key)
        if not self.settings[template] then
            logger.log_error("Settings missing template: " .. tostring(template))
            return widgets.Label{text="Error: " .. tostring(template)}
        end
        return wiki_widgets.ToggleLabel{
            label=label .. ' ',
            initial_option=self.settings[template][key],
            on_change=function(val)
                self.settings[template][key] = val
                mfw_settings.save_settings(self.settings)
            end
        }
    end

    local function create_preset_buttons(template)
        return widgets.Panel{
            frame={h=1},
            subviews={
                widgets.Label{frame={l=0}, text='Quick: '},
                widgets.Label{
                    frame={l=7, w=3},
                    text='All',
                    text_pen=COLOR_LIGHTGREEN,
                    on_click=function()
                        mfw_settings.set_preset(self.settings, template, 'all')
                        self:update_toggles()
                    end
                },
                widgets.Label{
                    frame={l=11, w=3},
                    text='Min',
                    text_pen=COLOR_LIGHTRED,
                    on_click=function()
                        mfw_settings.set_preset(self.settings, template, 'minimal')
                        self:update_toggles()
                    end
                },
                widgets.Label{
                    frame={l=15, w=3},
                    text='Rec',
                    text_pen=COLOR_LIGHTCYAN,
                    on_click=function()
                        mfw_settings.set_preset(self.settings, template, 'recommended')
                        self:update_toggles()
                    end
                },
            }
        }
    end

    self:addviews{
        widgets.Panel{
            view_id='settings_panel',
            frame={t=0, l=0, r=0, b=0},
            subviews={
                -- Civilization
                widgets.Label{frame={t=0, l=0}, text='Civilization Template', text_pen=COLOR_LIGHTCYAN},
                create_preset_buttons('civ'):assign{frame={t=1, l=2}},
                create_toggle('Leadership', 'civ', 'leadership'):assign{frame={t=2, l=2}, view_id='civ_leadership'},
                create_toggle('Ethics', 'civ', 'ethics'):assign{frame={t=3, l=2}, view_id='civ_ethics'},
                create_toggle('Relations', 'civ', 'relations'):assign{frame={t=4, l=2}, view_id='civ_relations'},
                create_toggle('Wars/Peace', 'civ', 'wars'):assign{frame={t=5, l=2}, view_id='civ_wars'},

                -- Fort
                widgets.Label{frame={t=7, l=0}, text='Fort Template', text_pen=COLOR_LIGHTCYAN},
                create_preset_buttons('fort'):assign{frame={t=8, l=2}},
                create_toggle('Wealth', 'fort', 'wealth'):assign{frame={t=9, l=2}, view_id='fort_wealth'},
                create_toggle('Government', 'fort', 'gov'):assign{frame={t=10, l=2}, view_id='fort_gov'},
                create_toggle('Links', 'fort', 'links'):assign{frame={t=11, l=2}, view_id='fort_links'},
                create_toggle('Timeline', 'fort', 'timeline'):assign{frame={t=12, l=2}, view_id='fort_timeline'},

                -- Citizen
                widgets.Label{frame={t=14, l=0}, text='Citizen Template', text_pen=COLOR_LIGHTCYAN},
                create_preset_buttons('citizen'):assign{frame={t=15, l=2}},
                create_toggle('Relationships', 'citizen', 'relationships'):assign{frame={t=16, l=2}, view_id='citizen_relationships'},
                create_toggle('Skills', 'citizen', 'skills'):assign{frame={t=17, l=2}, view_id='citizen_skills'},
                create_toggle('Appearance', 'citizen', 'appearance'):assign{frame={t=18, l=2}, view_id='citizen_appearance'},
                create_toggle('Needs/Medical', 'citizen', 'needs'):assign{frame={t=19, l=2}, view_id='citizen_needs'},
                create_toggle('Timeline', 'citizen', 'timeline'):assign{frame={t=20, l=2}, view_id='citizen_timeline'},

                -- Artifact
                widgets.Label{frame={t=22, l=0}, text='Artifact Template', text_pen=COLOR_LIGHTCYAN},
                create_preset_buttons('artifact'):assign{frame={t=23, l=2}},
                create_toggle('Description', 'artifact', 'description'):assign{frame={t=24, l=2}, view_id='artifact_description'},
                create_toggle('History', 'artifact', 'history'):assign{frame={t=25, l=2}, view_id='artifact_history'},
                create_toggle('Creator Link', 'artifact', 'creator'):assign{frame={t=26, l=2}, view_id='artifact_creator'},
            }
        }
    }
end

function SettingsWindow:update_toggles()
    self.settings = mfw_settings.get_settings()
    for template, keys in pairs(self.settings) do
        for key, val in pairs(keys) do
            local view_id = template .. '_' .. key
            if self.subviews[view_id] then
                self.subviews[view_id]:setOption(val)
            end
        end
    end
end

SettingsScreen = defclass(SettingsScreen, gui.ZScreen)
SettingsScreen.ATTRS {
    focus_path='mfw-settings',
}

function SettingsScreen:init()
    self:addviews{SettingsWindow{}}
end

function show_settings()
    SettingsScreen{}:show()
end

return _ENV
