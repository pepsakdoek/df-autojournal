Here is the complete analysis of the codebase.

1. PROJECT OVERVIEW
What it is: A DFHack Lua mod for Dwarf Fortress (v50+ Steam) called "DF Autojournal" (ID: df_autojournal). Provides a wiki-like auto-journaling system inside Dwarf Fortress -- multi-page citizen/artifact/event/enemies wiki, real-time event capture via DFHack eventful hooks, historical event catch-up on initialization, family relationship tracking, overlay status icons, sortable timeline, category-filterable settings, and a rich-text editor with clickable links and table blocks.
Author: pepsakdoek  
Version: 0.1.0  
Stack: Dwarf Fortress Steam v50.xx + DFHack (Lua API)

2. COMPLETE FILE LISTING WITH PURPOSES
Documentation & Planning
File	Purpose
D:\P\df-autojournal\info.txt	DFHack mod metadata (ID, name, author, version, description)
D:\P\df-autojournal\gemini.md	Master project description, architecture overview, UI requirements, coding mandates
D:\P\df-autojournal\AUTO_JOURNAL_PLAN.md	Detailed plan for the batch-scan auto-journaling system (Chronicle model, concurrency, event categorization)
D:\P\df-autojournal\template_ideas.md	Ideas for future template enhancements (world position, temperature, birth year vs. age)
D:\P\df-autojournal\Plan list of features and todo.md	Feature checklist, TODO items, working features

Entry Point & Overlay
File	Purpose
D:\P\df-autojournal\scripts_modactive\df-autojournal.lua	Mod entry point. Requires main_gui + event_listener, calls main_gui.main() when run directly. (9 lines)
D:\P\df-autojournal\scripts_modactive\df-autojournal-status.lua	Overlay script (--@ overlay df-autojournal-status). Shows top-right status icons (ON/OFF) for the event listener. Registers onStateChange handler to auto-start listener on map load and stop on world unload. Checks persisted state directly without depending on listener module being fully loaded. (67 lines)

Core Logic (internal/df-autojournal/)
File	Purpose
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\main_gui.lua	Main UI screen. Defines WikiWindow (Wiki TOC, Journal TOC, Editor), WikiContext (persistence layer), WikiScreen (ZScreen). PAGES table includes Civilisation, Fort, Citizens, Artifacts, Events, Enemies. Auto-Journaling toggle wired to event_listener.start()/stop(). (502 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\initializer.lua	Wiki Initializer. Scans fortress for active units, renders civ/fort/citizen/artifact templates. Added: historical event catch-up (catchUpEvents, scans history events forward in batches of 500), timeline rendering on Events page (renderEventsTimeline), enemies page from registry (renderEnemiesPage), timeline registry registration for threat events, enemy registry registration for threat-type history events. (420 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\event_listener.lua	Real-time event listener (NEW in Phase 1, expanded Phase 2). Wraps require('plugins.eventful') with 6 hooks: onReport, onUnitDeath, onItemCreated, onUnitNewActive, onInvasion, onSyndrome. Hooks are registered once per Lua session. Routes parsed events to wiki pages via direct dfhack.persistent access (no WikiContext dependency). Features: append_to_page (span-array format), timeline registry (mfw_event_timeline, 1000 entry cap), enemy registry (mfw_enemies with dedup by normalized name), seen-unit dedup set, category-level settings filtering (12 event toggles). Exports: append_to_page, register_timeline_entry, register_enemy_encounter, load_enemies. (464 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\chronicle.lua	Legacy batch-scan Chronicle. Disabled in favor of real-time event_listener. Remains for backward compatibility. (109 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\event_parser.lua	Comprehensive event parser. Two subsystems:
- Real-time: parse_report() classifies 55+ DFHack report type IDs into 9 categories (threat, achievement, social, trade, crisis, military, environment, world, combat). Each category has a dedicated format function with date stamping, speaker extraction, and wiki link generation. Plus parse_death(), parse_item_created(), parse_new_unit(), parse_invasion(), parse_syndrome() for eventful hooks. Extracts enemy_name from threat report text via heuristic parser.
- Historical: parse() handles 15+ df.history_event_type values (HIST_FIGURE_DIED, ATTACK, ABDUCTED, BECAME_VAMPIRE, BECAME_WEREBEAST, GAINS_SYNDROME, ENTITY_MIGRANT, MASTERPIECE_*, CREATURE_DEVOURED, ADD_HF_HF_LINK, CREATED_STRUCTURE, and the original 4 types). Uses is_our_hf() helper that checks entity links to our civ (works even for dead/unloaded units). (1144 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\logger.lua	Logger. Writes to wiki_debug.log in DF root + DFHack console. (24 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_utils.lua	Utilities. get_civ_id(), get_site_id(), translate_name(), sanitize(), get_readable_name(), get_date_str(), sanitize_content() (handles strings, spans, table blocks), plus helper functions colored(), header(), label(), value(), note(). (194 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_settings.lua	Settings data model. DEFAULT_SETTINGS: civ (5 init), fort (6 init), citizen (7 init + 3 journal), artifact (4 init + 1 journal), event (3 init + 12 journal toggles added in Phase 6 update: threat_events, achievement_events, social_events, trade_events, crisis_events, military_events, environment_events, world_events, death_events, birth_migrant_events, syndrome_events, siege_events). Loads/saves from dfhack.persistent via JSON. Provides set_preset(). Auto-migration from old flat format. (254 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\settings_gui.lua	Settings UI screen. TabBar with 5 tabs (Civ, Fort, Citizen, Artifact, Event). Dynamic toggle generation from settings model. Help bar shows descriptions on hover. (295 lines)

Templates (internal/df-autojournal/templates/)
File	Purpose
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\templates\fort.lua	Fort template. Adds Fort Timeline section at end for auto-appended event entries. (94 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\templates\civilization.lua	Civilization template. Sections: Type, Diplomatic Relations, Ethics, Major History. (103 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\templates\citizen.lua	Citizen template. Family & Relationships section added: queries unit.hist_figure_id -> histfig_links, renders Spouse(s), Parents, Children with clickable wiki links for citizen relatives (COLOR_LIGHTBLUE) and plain text for non-citizen. (100 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\templates\artifact.lua	Artifact template. Sections: Type, Value, Description, History (creator link), Location. (92 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\templates\event.lua	Event detail page template. Rewritten to accept structured event_data: title, year, season, category, participants[] (with name+link), description, consequences, links[]. Renders: header, metadata, Summary, Key Participants (clickable), Related links, Detailed Account (editable), Consequences. (90 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\templates\timeline.lua	Timeline rendering (NEW in Phase 4). Two functions: render_timeline(entries) generates a sortable table (Year, Season, Category with color, Summary with wiki-markup stripped, Link column), sorted newest-first with 200-row cap; render_counts(categories) generates category breakdown by count. (179 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\templates\enemies.lua	Enemies page (NEW in Phase 6). Renders a sortable table (Name, Type with colored badges, First Year, Defeated Y/N with color, Encounters, Notes) sorted by first-year, plus an Encounter Log section header for appended entries. (93 lines)


Widget/UI System (internal/df-autojournal/wiki_widgets/)
File	Purpose
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets.lua	Core widget re-exports. ToggleLabel, Shifter, TableOfContents, page tree helpers. (311 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\README.md	HyperTextArea documentation. (213 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\hyper_text_area.lua	HyperTextArea rich-text widget. (303 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\hyper_text_area_content.lua	Char-level editing engine. (698 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\hyper_wrapped_text.lua	Text wrapping engine. (307 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\hyper_table.lua	Table block rendering engine. (362 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\hta_utils.lua	Span/char-list utilities. (86 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\history_store.lua	Undo/redo manager. (67 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\toolbar.lua	Color picker + table/link buttons. (81 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\link_modal.lua	Link insertion dialog. (69 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\table_editor_modal.lua	Table editor modal. (365 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\hta_context.lua	Optional JSON persistence. (42 lines)

3. SETTINGS PAGE IMPLEMENTATION
Data Model (wiki_settings.lua)
- Storage key: 'mfw_settings' in dfhack.persistent.getSiteData/saveSiteData
- Default settings keyed by template type, each with init + journal booleans:
- civ: init(leadership, ethics, relations, wars, history) journal(diplomacy, wars, leadership)
- fort: init(wealth, gov, districts, defense, links, timeline) journal(population, construction, defense)
- citizen: init(values, relationships, skills, appearance, needs, medical, timeline) journal(pet_adopted, died, renamed)
- artifact: init(description, history, creator, location) journal(created)
- event: init(participants, summary, consequences) journal(threat_events, achievement_events, social_events, trade_events, crisis_events, military_events, environment_events, world_events, death_events, birth_migrant_events, syndrome_events, siege_events)
- 12 granular event journal toggles replaced the original blanket new_events toggle
- Settings are JSON-encoded with auto-migration from old flat format
- Presets: set_preset(settings, template, 'all'|'minimal'|'recommended')
Settings GUI (settings_gui.lua)
- SettingsWindow extends widgets.Window with 5-tab TabBar
- Each tab reads the settings model and creates ToggleLabels dynamically
- Help bar shows per-setting description on mouse hover
- event tab's journal section shows all 12 category toggles with descriptive help text

4. INITIALIZATION AND AUTO-JOURNALING CODE
Initialization (initializer.lua)
- WikiInitializer:perform(screen) full scan order:
1. Gets site ID, aborts if invalid
2. Renders Civ page + Fort page (fort template now includes Fort Timeline section)
3. Iterates active units, renders citizen pages (now with Family & Relationships section)
4. Builds Citizens index page with sortable table block
5. Iterates artifacts, renders artifact pages
6. Builds Artifacts index page with sortable table block
7. Creates Events page placeholder
8. **catchUpEvents(site_id)**: Scans df.global.world.history.events forward from event 0 to current max, filters by getSite() == site_id, calls event_parser.parse(ev) for each match, appends entries via event_listener.append_to_page(). Batches of 500 with progress logging. Saves mfw_catchup_last_id marker for resumability. Registers matched events in timeline registry + enemy registry for threat types.
9. **renderEventsTimeline()**: Loads mfw_event_timeline registry, builds category counts, renders via timeline_template.render_counts() + render_timeline(), merges into Events page after # Events header.
10. **renderEnemiesPage()**: Loads mfw_enemies registry via event_listener.load_enemies(), renders via enemies_template.render(), saves as enemies page.
11. Saves dynamic page list, sets initialized flag, calls on_complete.

Real-Time Event Listener (event_listener.lua) — replaces the old batch-scan Chronicle
- Requires plugins.eventful, registers 6 hooks once per Lua session
- Event flow: eventful hook -> EventListener._on_*() -> event_parser.parse_*() -> route_parsed() -> append_to_page() + register_timeline_entry() + register_enemy_encounter()
- append_to_page() works with span-array content format, finds/creates ## Section headers
- is_category_enabled() checks mfw_settings per-category toggles before routing
- route_parsed() respects settings, logs all routed events
- Timeline registry (mfw_event_timeline): stores {year, season, category, event_type, summary} capped at 1000 entries
- Enemy registry (mfw_enemies): stores {name, enemy_type, first_year, encounters, defeated, last_year} deduplicated by normalized name key
- Seen unit IDs persisted to avoid duplicate migrant/birth events

Chronicle (chronicle.lua) — legacy batch-scan, currently disabled in favor of real-time listener

Historical Event Parser (event_parser.lua)
Two parsing subsystems:
- Real-time (parse_report, parse_death, parse_item_created, parse_new_unit, parse_invasion, parse_syndrome):
  - Classifies 55+ DF report type IDs into 9 categories
  - Returns structured {targets, year, season, category, event_type, is_major, importance, summary, enemy_name?}
  - Each category has a dedicated format function with date stamp, speaker/participant extraction, wiki link generation
  - extract_enemy_name() heuristic: parses "A THING, Name, has come" / "Name has come" / "The Goblins" patterns
  - parse_death() routes citizen deaths to citizen History & Timeline + events Deaths; enemy deaths to enemies Kill List
  - parse_invasion() counts invaders, identifies race/civ, routes to events + fort + enemies
  - parse_syndrome() filters mundane syndromes (alcohol, etc.), routes notable syndromes to citizen + events
- Historical (parse):
  - Handles 15+ df.history_event_type values (original 4 + new: ATTACK, SITE_CONFLICT, ABDUCTED, BECAME_VAMPIRE, BECAME_WEREBEAST, GAINS_SYNDROME, ENTITY_MIGRANT, MASTERPIECE_*, CREATURE_DEVOURED, ADD_HF_HF_LINK, CREATED_STRUCTURE)
  - Uses is_our_hf() that checks entity links to our civ (works for dead/unloaded units)
  - Returns {page_id, section, text, importance} format for backward compatibility with Chronicle

Overlay Script (df-autojournal-status.lua)
- --@ overlay marker for DFHack overlay system auto-discovery
- Checks persisted state directly via dfhack.persistent.getSiteData (no module dependency for state check)
- Registers onStateChange handler: on SC_MAP_LOADED reads mfw_auto_journal_enabled and starts listener; on SC_WORLD_UNLOADED stops listener
- OVERLAY_VIEWS defines a top-right Panel showing ON/OFF labels with color: ON green when active, OFF red when disabled, both dim otherwise
- All event_listener calls guarded with nil checks for graceful degradation

5. TABLE OF CONTENTS IMPLEMENTATION
Wiki Page TOC (Left Panel)
- widgets.List with view_id='wiki_page_list'
- PAGES = {Civilisation, Fort, Citizens, Artifacts, Events, Enemies} — Enemies added in Phase 6
- Dynamic pages (citizen/artifact/enemy sub-pages) appended via refreshPageList() with collapsible [+] / [-] tree
Journal Page TOC (Middle Panel)
- TableOfContents widget scans raw text for ## headers with line_cursor navigation
- Collapsible via Shifter widget (<< / >>) and CUSTOM_CTRL_O hotkey
Layout Management
- ensurePanelsRelSize() recalculates panel positions on open/close

6. TEMPLATE SYSTEM
Design: Each template exports render(). Initialization uses templates for initial page generation. Event listener appends entries to existing pages via append_to_page().

Template	Arguments	Sections (active)
fort.lua	(none)	Population, Government, Links, Districts, Timeline, Defense, **Fort Timeline** (event entries appended)
civilization.lua	(none)	Type, Diplomatic Relations, Ethics, Major History
citizen.lua	unit	Profession, Gender, **Family & Relationships** (spouse/parent/child from histfig_links, clickable for citizens), Personal Journal, Values, Timeline
artifact.lua	item	Type, Value, Description, History (creator link), Location
event.lua	event_data	Metadata (year/season/category), Summary, **Key Participants** (clickable links), **Related links**, Detailed Account, Consequences
timeline.lua	entries[]	**Sortable timeline table** (Year, Season, Category with color, Summary, Link) + **Category counts** breakdown. Used by Events page.
enemies.lua	enemies[]	**Sortable enemy registry table** (Name, Type with color badge, First Year, Defeated, Encounters, Notes) + Encounter Log section. Used by Enemies page.

7. WIDGET/UI SYSTEM
(same as previously documented — unchanged by Phases 1-6)

8. ARCHITECTURAL SUMMARY
Game starts
   |
   v
DFHack overlay system loads df-autojournal-status.lua (--@ overlay)
   |-- Registers onStateChange handler (auto-start listener on map load)
   |-- Shows ON/OFF status icons top-right
   |-- If fortress already loaded, checks persisted state and starts listener
   |
User runs "df-autojournal"
   |
   v
df-autojournal.lua (entry point)
   |-- Requires event_listener (modules loaded, hooks not yet registered)
   |-- Requires main_gui
   |-- Calls main_gui.main() -> WikiScreen:show()
   |
   v
WikiScreen (ZScreen)
   |-- WikiWindow (main UI container)
   |     |-- Wiki Page List (left) — 6 root pages + dynamic sub-pages
   |     |-- Journal TOC (middle) — section headers
   |     |-- HyperTextArea (right) — rich text editor
   |
   |-- WikiContext (persistence, prefix 'mfw_p_')
   |
   |-- [Initialize Wiki] button:
   |     WikiInitializer:perform()
   |       -> civ + fort + citizens + artifacts rendered
   |       -> catchUpEvents(site_id): scans world.history.events forward
   |       -> renderEventsTimeline(): timeline table + counts on Events page
   |       -> renderEnemiesPage(): enemy registry table on Enemies page
   |
   |-- [Auto-Journaling] toggle:
   |     event_listener.start() / stop()
   |       -> eventful hooks (onReport, onUnitDeath, etc.) registered once
   |       -> on each hook: parser -> route_parsed -> append_to_page + timeline + enemy registry
   |       -> checks per-category settings before routing
   |
   |-- [Settings] button:
   |     TabBar (Civ/Fort/Citizen/Artifact/Event)
   |       -> 12 event-category journal toggles for granular control

Persistence:
   dfhack.persistent keys:
     mfw_p_<page_id>      — wiki page content (span arrays)
     mfw_auto_journal_enabled — listener on/off
     mfw_seen_units       — dedup set for unit arrival events
     mfw_event_timeline   — event timeline registry (1000 entries)
     mfw_enemies          — enemy registry (dedup by name)
     mfw_catchup_last_id  — historical catch-up progress marker
     mfw_settings         — JSON-encoded settings
     mfw_dynamic_pages    — citizen/artifact sub-page list
     mfw_initialized      — init completion flag
     mfw_window_frame     — window size/position

Data flow for event capture:
   DF game event occurs
     -> eventful plugin fires callback (e.g. onReport)
     -> EventListener._on_report(report_id)
     -> Finds report object, extracts type + text
     -> event_parser.parse_report(type, text, report)
         -> classifies by report type (REPORT_MAP / combat ranges / ambush ranges)
         -> formats entry with date, links, sanitized text
         -> returns {targets[], year, season, category, event_type, is_major, importance, summary}
     -> route_parsed(parsed)
         1. is_category_enabled(parsed.category) — skips if disabled in settings
         2. append_to_page() for each target (page_id + section)
         3. register_timeline_entry() -> mfw_event_timeline
         4. if parsed.enemy_name: register_enemy_encounter() -> mfw_enemies

Flow for historical catch-up (during initialization):
   df.global.world.history.events[0..N]
     -> filtered by ev:getSite() == site_id
     -> event_parser.parse(ev) for 15+ history event types
     -> event_listener.append_to_page() + register_timeline_entry() + register_enemy_encounter()
     -> progress saved every 500 events

9. DFHACK WIDGET & MODULE INSIGHTS (from source investigation)

   ToggleHotkeyLabel (You cibrary\lua\gui\widgets\labels\toggle_hotkey_label.lua):
     - Options are {label='On', value=true, pen=COLOR_GREEN} / {label='Off', value=false}
     - getOptionValue() returns the `value` field (boolean true/false)
     - on_change receives (new_value, old_value) — both booleans
     - initial_option can be a boolean; setOption() compares with == against each option's value field
     - initial_option falls back to index 1 if no match

   CycleHotkeyLabel (D:\p\dfhack\dfhack\library\lua\gui\widgets\labels\cycle_hotkey_label.lua):
     - init() calls self:setOption(self.initial_option) — must NOT be a function here
     - setOption(value_or_index): tries value match -> index match -> defaults to option 1
     - cycle(backwards): updates option_idx, then calls on_change(new_value, old_value)
     - getOptionValue(option_idx) returns options[option_idx].value (or the raw option if flat array)
     - Text is constructed in init() with {key, label, {gap=..., text=getOptionLabel, pen=getOptionPen}}
      - Always clickable (shouldHover returns true)

   Custom ToggleLabel (wiki_widgets.lua:30-69):
     - Extends DFHack's ToggleHotkeyLabel: options are {value=true, label='On'} / {value=false, label='Off'}
     - Custom icon rendering: replaces the default "On"/"Off" text with bracket icons:
       [√] (green, enabled) / [x] (red, disabled) using DFHack's tp_control_panel tilesheet
     - `initial_option`: supports both a raw boolean and a function that returns boolean.
       The function is resolved BEFORE calling super.init() because CycleHotkeyLabel:init()
       calls setOption(initial_option) directly and can't handle function values.
     - `on_change(val)` receives boolean true/false (the option's `value` field)
     - `getOptionValue()` returns boolean true/false
     - opt_is_on() helper handles both string and boolean: `return opt == 'On' or opt == true`
       (defensive — ToggleHotkeyLabel uses booleans but the comment in init mentions "On"/"Off" text tokens)

   How to use ToggleLabel:
     - Import: `local wiki_widgets = reqscript('internal/df-autojournal/wiki_widgets')`
     - Create: `wiki_widgets.ToggleLabel{ view_id='...', label='My Setting ', key='CUSTOM_ALT_X',
         initial_option=function() return my_current_state() end,
         on_change=function(val) save_my_state(val) end, }`
     - `initial_option` can be a function (evaluated once at creation) or a direct boolean
     - `on_change` receives boolean: `true` = enabled, `false` = disabled

   How to save/restore ToggleLabel state:
     - The ToggleLabel itself does NOT persist its state — it only displays and calls on_change.
     - To persist: in on_change, write to dfhack.persistent or your own in-memory state.
     - To restore: in initial_option, read from your persistent/store and return a boolean.
     - on_change receives the NEW value after the user clicks (NOT the old value).
     - Example (persist to dfhack.persistent):
         initial_option=function()
           local data = dfhack.persistent.getSiteData('my_key')
           return data and data.val and data.val[1] == 1 or false
         end,
         on_change=function(val)
           dfhack.persistent.saveSiteData('my_key', {val=val and {1} or {0}})
         end
     - IMPORTANT: Compare val explicitly rather than truthy-checking, since
       non-empty strings are truthy in Lua but ToggleHotkeyLabel uses booleans:
         if val == 'On' or val == true then  -- correct
         if val then                         -- broken (string 'Off' is truthy)
     - For settings tables saved as JSON, normalize on save: `s[key] = (val == 'On' or val == true)`

   --@ module = true behavior (reqscript returns _ENV, not the return value):
     - When a script has `--@ module = true`, DFHack's reqscript returns the module environment
       (_ENV), NOT the script's explicit `return` value.
     - All functions/variables that callers need must be assigned to _ENV (the module table).
     - `return EventListener` is ignored — the module table (_ENV) is what callers receive.
     - Other project modules correctly use `return _ENV` at the end.
     - Fix: iterate the local table and copy its entries to _ENV before returning:
         for k, v in pairs(MyTable) do _ENV[k] = v end
         return _ENV
     - Module environment _ENV always has keys: moduleMode, dfhack_flags

   overlay_onupdate_max_freq_seconds (plugins/lua/overlay.lua):
     - Default: 5 seconds (throttles how often overlay_onupdate is called)
     - Set to 0 for every-frame updates (no throttle)
     - Overlay widgets only get update ticks when their registered viewscreens are active;
       ZScreens on top may block dwarfmode overlay updates until dismissed.
     - Hotspot widgets (hotspot=true) get update ticks on ALL viewscreens.

   reqscript module caching:
     - reqscript caches by module name string across all callers
     - Cache persists for the Lua session (restart DF to clear)
     - Edits to module files are NOT picked up until restart (no hot-reload)
     - `devel/scan-scripts` may reload overlay scripts but does NOT clear reqscript cache
     - Files in `internal/` directories are SKIPPED by foreach_module_script() (line 18 of
       script-manager.lua: `f.path:startswith('internal/')`)

   DFHack persistent API (dfhack.persistent):
     - saveSiteData(key, nil) effectively deletes a key (used in reset_all_data)
     - getSiteData returns nil for missing keys (not an error)
     - Keys used: mfw_p_<page_id> (content), mfw_settings (JSON-encoded),
       mfw_event_timeline, mfw_enemies, mfw_seen_units, mfw_catchup_last_id,
       mfw_initialized, mfw_dynamic_pages, mfw_window_frame

   Interpreting Lua truthiness with DFHack input keys:
     - keys._STRING is the typed character's code (0-255)
     - CRITICAL: 0 is truthy in Lua! So `if keys._STRING then` catches both
       printable chars AND backspace (which sends _STRING=0). Always check
       `keys._STRING == 0` BEFORE `keys._STRING` for printable chars.

   Dialog API (gui.dialogs vs gui):
     - showYesNoPrompt lives in require('gui.dialogs'), NOT in require('gui')
     - Signature: showYesNoPrompt(title, text, tcolor, on_accept, on_cancel, on_pause, on_settings)

   Panel subviews lifecycle:
     - Direct assignment `panel.subviews = {...}` does NOT set .parent on children
       and does NOT call updateLayout(). This causes children to render with
       stale/nil frame_body, potentially overlapping siblings.
     - Proper replacement: clear old subviews' .parent, set new subviews' .parent,
       then call panel:updateLayout() on each modified widget.
     - When dynamically resizing a child panel, also update sibling frame attrs
       to prevent overlap (desc_label, fn_list in function_modal).

  HyperTextArea data architecture (hyper_text_area_content.lua):
     - display_text is the canonical content: array of text spans, table blocks,
       and function blocks.
     - char_list is derived from display_text but SKIPS table blocks entirely
       (tables have no character-level representation).
     - table_blocks are extracted into a separate array with {pos, columns, rows,
       sort_col, sort_asc, max_rows, id, search_query}. The `pos` field is the
       character position in char_list where the table logically sits (between
       surrounding text).
     - fn_blocks similarly track function block positions.
     - rebuild_display_text() merges char_list + table_blocks + fn_blocks back
       into display_text for persistence.
     - updateContent() rebuilds display_text and re-renders wrapped_text but does
       NOT re-extract special blocks (table_blocks/fn_blocks persist in memory).

   Table rendering (hyper_table.lua):
     - calc_column_widths runs 3 phases: base widths from content → shrink
       proportionally to fit → stretch remaining space.
     - Proportional shrink: columns with more content overflow (text beyond
       min_width) get a larger share of constrained space, replacing the old
       equal-distribution that gave "Name" and "Age" the same width.
     - render_row takes a row OBJECT (not an index), so filtered rows can be
       passed directly during search.
     - get_handler_at must account for search bar line offset when present.

   Table search feature:
     - Search query is stored in table_blocks (in-memory only, not persisted).
     - Searching re-renders just the affected table via rerender_table() in
       hyper_wrapped_text.lua, which replaces lines in-place and handles
       insertion/removal if line count changes.
     - Search input is routed when cursor is at a table boundary position
       (cursor == tb.pos). Printable chars append to query, backspace removes,
       escape clears. This intercept happens in onTextManipulationInput.

   Table copy/paste:
     - copy() was extended to serialize table blocks within the selection range
       as pipe-delimited text (same format as table editor).
     - Table positions in the selection are detected by checking tb.pos against
       sel_from/sel_to ranges during char_list iteration.
     - Visual selection highlighting was added for table lines by building a
       table_selected_at[] line map from table_ranges.

   Function modal dynamic layout (function_modal.lua):
     - arg_panel height is dynamically set based on args_schema count.
     - Sibling frames (desc_label, fn_list) must be shifted accordingly to
       prevent overlap with the statusbar.
     - updateLayout() must be called on each modified widget after frame changes.

Widget dependencies:
   DFHack gui/gui.widgets (standard) + Custom widgets:
      wiki_widgets/:
        toolbar.lua, link_modal.lua, hyper_wrapped_text.lua,
        hyper_text_area_content.lua, hyper_text_area.lua,
        hyper_table.lua, table_editor_modal.lua, hta_utils.lua,
        history_store.lua, hta_context.lua

Templates:
   templates/:
      fort.lua, civilization.lua, citizen.lua, artifact.lua,
      event.lua, timeline.lua, enemies.lua


# Agent instructions

* Settings and features should always be synced. 
* Settings descriptions in settings_gui should be elaborate enough to undestand what it does
* If on windows, use the sync_mod.bat file after changes so the user can test.
* Significant Changes (not bugfixes, but features) to the HyperTextArea should also be noted in the relevant README.md file 
* Ask the user to explore objects using gui/gm-editor if you are struggling to find the exact name for an object
* Use git functions to read changes, but DO NOT COMMIT