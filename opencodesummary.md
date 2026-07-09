Here is the complete analysis of the codebase.

1. PROJECT OVERVIEW
What it is: A DFHack Lua mod for Dwarf Fortress (v50+ Steam) called "DF Autojournal" (ID: df_autojournal). Provides a wiki-like auto-journaling system inside Dwarf Fortress -- multi-page citizen/artifact/event/enemies wiki, real-time event capture via DFHack eventful hooks, historical event catch-up on initialization, family relationship tracking, overlay status icons, sortable timeline, category-filterable settings, and a rich-text editor with clickable links and table blocks. Features a multi-level page tree under each fort, progress bar during initialization, and fort-membership tracking for entities.
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
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\main_gui.lua	Main UI screen. Defines WikiWindow (Wiki TOC, Journal TOC, Editor), WikiContext (persistence layer), WikiScreen (ZScreen). PAGES table now has 3 root pages: World, Civilizations, Forts (Citizens/Artifacts/Events/Enemies/Visitors moved to per-fort section pages). Default page is `fort:<site_id>` after init. Auto-Journaling toggle wired to event_listener.start()/stop(). Loads fort membership map from persistent for tree building. (619 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\initializer.lua	Wiki Initializer. Refactored into step-based async methods with progress reporting. Builds: civ/fort track & render, indices, world page, citizens, artifacts, section pages (fort:X/citizens, fort:X/artifacts, etc.), historical catch-up (batches of 500), timeline, enemies, visitors. Builds and saves `mfw_fort_members` mapping entity IDs to fort section pages. Features: catchUpEvents (scans history events with progress via on_batch), renderEventsTimeline, renderEnemiesPage, renderVisitorsPage. (985 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\event_listener.lua	Real-time event listener (NEW in Phase 1, expanded Phase 2). Wraps require('plugins.eventful') with 6 hooks: onReport, onUnitDeath, onItemCreated, onUnitNewActive, onInvasion, onSyndrome. Routes parsed events to fort-specific pages via fortify_page_id() (e.g. "events" -> "fort:X/events"). Hooks are registered once per Lua session. Routes parsed events to wiki pages via direct dfhack.persistent access (no WikiContext dependency). Features: append_to_page (span-array format), timeline registry (mfw_event_timeline, 1000 entry cap), enemy registry (mfw_enemies with dedup by normalized name), seen-unit dedup set, category-level settings filtering (12 event toggles). Exports: append_to_page, register_timeline_entry, register_enemy_encounter, load_enemies. (603 lines)
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
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets.lua	Core widget re-exports. ToggleLabel, Shifter, TableOfContents, ProgressBarScreen, page tree helpers (multi-level recursive). (455 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\README.md	HyperTextArea documentation. (350 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\hyper_text_area.lua	HyperTextArea rich-text widget. Passes link_pages to LinkModal. (322 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\hyper_text_area_content.lua	Char-level editing engine. (698 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\hyper_wrapped_text.lua	Text wrapping engine. (307 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\hyper_table.lua	Table block rendering engine. (362 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\hta_utils.lua	Span/char-list utilities. (86 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\history_store.lua	Undo/redo manager. (67 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\toolbar.lua	Color picker + table/link buttons. (81 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\link_modal.lua	Link insertion dialog. Accepts optional `pages` attribute for full page list; defaults to static root list. (69 lines)
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
- Step-based async init with progress reporting (ProgressBarScreen overlay).
- Steps run via gui.script.start() coroutine, yielding 1 frame between steps for UI updates.
- Times each step with os.clock() and logs elapsed ms.

Step order:
1. **step_setup**: Gets site/civ IDs, settings, current civ/site
2. **step_track_entities**: Tracks known civs + forts from persistent + diplo/major scan
3. **step_render_subpages**: Renders civ:X and fort:X sub-pages, Civilizations/Forts index
4. **step_world**: Renders World page (eras, landmasses, season)
5. **step_citizens**: Iterates active units, renders citizen pages + Citizens index; builds fort membership map (citizen:ID -> fort:X/citizens)
6. **step_artifacts**: Iterates artifacts on site, renders artifact pages + Artifacts index; builds fort membership map (artifact:ID -> fort:X/artifacts)
7. **step_create_sections**: Creates per-fort section pages (fort:X/events, fort:X/enemies, fort:X/visitors), adds all section pages to dynamic_pages
8. **step_save_dynamic**: Saves dynamic_pages list + fort membership map (mfw_fort_members)
9. **step_events_and_catchup**: Creates Events placeholder, runs catchUpEvents (batches of 500 with on_batch progress), renders timeline + enemies + visitors pages
10. **step_finalize**: Sets initialized flag, calls on_complete, shows announcement

catchUpEvents(site_id):
- Scans df.global.world.history.events forward from last_done to current_max
- Filters by ev:getSite() == site_id
- Fortifies page_ids (events -> fort:X/events, etc.)
- Batches of 500 with progress reporting via on_batch(scanned, total, matched)
- Saves mfw_catchup_last_id marker for resumability
- Registers matched events in timeline registry + enemy registry for threat types

Real-Time Event Listener (event_listener.lua) — replaces the old batch-scan Chronicle
- Requires plugins.eventful, registers 6 hooks once per Lua session
- Event flow: eventful hook -> EventListener._on_*() -> event_parser.parse_*() -> route_parsed() -> append_to_page() + register_timeline_entry() + register_enemy_encounter()
- fortify_page_id() maps generic root page_ids to fort-specific: "events" -> "fort:X/events", "enemies" -> "fort:X/enemies", "fort" -> "fort:X", "visitors" -> "fort:X/visitors" (uses utils.get_site_id())
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

5. TABLE OF CONTENTS / PAGE TREE IMPLEMENTATION
Wiki Page TOC (Left Panel) — Multi-level recursive tree
- widgets.List with view_id='wiki_page_list'
- PAGES = {World, Civilizations, Forts} — Citizens/Artifacts/Events/Enemies/Visitors moved to per-fort section pages
- Dynamic pages organized into an N-level tree via recursive build_page_tree() and flatten_page_tree():
  - Root: World, Civilizations, Forts
  - Level 1: Each fort (fort:X)
  - Level 2: Fort section pages (fort:X/citizens, fort:X/artifacts, etc.)
  - Level 3: Individual entity pages (citizen:Y, artifact:Z) placed via fort membership map
- get_page_parent() handles both path-based IDs (fort:X/citizens -> fort:X) and prefix-based rules (citizen:X -> citizens)
- [+] / [-] icons always at column 0; text indented depth+1 spaces
- Expanded state tracked per page_id in self.expanded table
- refreshPageList() loads membership_map from mfw_fort_members and passes it to build_page_tree()
Journal Page TOC (Middle Panel)
- TableOfContents widget scans raw text for ## headers with line_cursor navigation
- Collapsible via Shifter widget (<< / >>) and CUSTOM_CTRL_O hotkey
Layout Management
- ensurePanelsRelSize() recalculates panel positions on open/close

6. TEMPLATE SYSTEM
Design: Each template exports render(). Initialization uses templates for initial page generation. Event listener appends entries to existing pages via append_to_page(). Section pages (fort:X/citizens, etc.) are created during init with filtered content.

Template	Arguments	Sections (active)
fort.lua	(none)	Population, Government, Links, Districts, Timeline, Defense, **Fort Timeline** (event entries appended)
civilization.lua	(none)	Type, Diplomatic Relations, Ethics, Major History
citizen.lua	unit	Profession, Gender, **Family & Relationships** (spouse/parent/child from histfig_links, clickable for citizens), Personal Journal, Values, Timeline
artifact.lua	item	Type, Value, Description, History (creator link), Location
event.lua	event_data	Metadata (year/season/category), Summary, **Key Participants** (clickable links), **Related links**, Detailed Account, Consequences
timeline.lua	entries[]	**Sortable timeline table** (Year, Season, Category with color, Summary, Link) + **Category counts** breakdown. Used by Events page.
enemies.lua	enemies[]	**Sortable enemy registry table** (Name, Type with color badge, First Year, Defeated, Encounters, Notes) + Encounter Log section. Used by Enemies page.

7. WIDGET/UI SYSTEM
Core DFHack widgets + Custom widgets:
- ToggleLabel: [√]/[x] bracket icons via tp_control_panel (wiki_widgets.lua)
- Shifter: Collapse/expand arrow button for Journal TOC (wiki_widgets.lua)
- TableOfContents: ## header scanner with cursor tracking (wiki_widgets.lua)
- ProgressBarScreen: ZScreen modal with full ToggleLabel-style bracket icons per step,
  ◄████► progress bar, per-step timing logs, sub-progress bar for catch-up batches (wiki_widgets.lua)
- Page tree helpers: multi-level recursive build_page_tree / flatten_page_tree
  with membership_map support (wiki_widgets.lua)
- HyperTextArea: rich text editor with spans/tables/functions (wiki_widgets/*)
  - Passes link_pages to LinkModal for dynamic page lists
- LinkModal: accepts optional `pages` attribute (defaults to static root list) (link_modal.lua)

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
   |     |-- Wiki Page List (left) — 3 root pages + multi-level tree via build_page_tree/flatten_page_tree
   |     |     Tree: World > Civilizations > Forts > fort:X > sections > entities
   |     |-- Journal TOC (middle) — section headers
   |     |-- HyperTextArea (right) — rich text editor
   |
   |-- WikiContext (persistence, prefix 'mfw_p_')
   |
   |-- [Initialize Wiki] button:
   |     ProgressBarScreen shown (ZScreen modal with step icons + progress bar)
   |     gui_script.start() coroutine runs initializer:perform_async()
   |       -> 10 step methods with 1-frame yields between each
   |       -> calls on_step callback to update ProgressBarScreen
   |       -> builds fort membership map (mfw_fort_members)
   |       -> creates per-fort section pages (fort:X/citizens, etc.)
   |       -> historical catch-up updates on_batch for sub-progress bar
   |       -> on completion, ProgressBarScreen dismissed, page list refreshed
   |
   |-- [Auto-Journaling] toggle:
   |     event_listener.start() / stop()
   |       -> eventful hooks (onReport, onUnitDeath, etc.) registered once
   |       -> on each hook: parser -> route_parsed (with fortify_page_id) -> append_to_page
   |       -> fortify maps "events" -> "fort:X/events", "enemies" -> "fort:X/enemies", etc.
   |       -> checks per-category settings before routing
   |
   |-- [Settings] button:
   |     TabBar (Civ/Fort/Citizen/Artifact/Event)
   |       -> 12 event-category journal toggles for granular control

Persistence:
   dfhack.persistent keys:
     mfw_p_<page_id>        — wiki page content (span arrays); page_ids can be nested (fort:X/citizens)
     mfw_auto_journal_enabled — listener on/off
     mfw_seen_units         — dedup set for unit arrival events
     mfw_event_timeline     — event timeline registry (1000 entries)
     mfw_enemies            — enemy registry (dedup by name)
     mfw_visitors           — visitor registry
     mfw_catchup_last_id    — historical catch-up progress marker
     mfw_settings           — JSON-encoded settings
     mfw_dynamic_pages      — dynamic sub-page list (citizen, artifact, fort sections, etc.)
     mfw_fort_members       — entity-to-fort membership map: {["citizen:123"]="fort:100/citizens", ...}
     mfw_initialized        — init completion flag
     mfw_window_frame       — window size/position
     mfw_known_civs         — tracked civilizations
     mfw_known_forts        — tracked forts

Data flow for event capture (fortified):
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
         2. fortify_page_id() maps generic page_ids to fort:X sections
         3. append_to_page() for each target (page_id + section)
         4. register_timeline_entry() -> mfw_event_timeline
         5. if parsed.enemy_name: register_enemy_encounter() -> mfw_enemies

Flow for historical catch-up (during initialization):
   df.global.world.history.events[0..N]
     -> filtered by ev:getSite() == site_id
     -> event_parser.parse(ev) for 15+ history event types
     -> fortify() maps page_ids to current fort sections
     -> event_listener.append_to_page() + register_timeline_entry() + register_enemy_encounter()
     -> progress saved every 500 events, on_batch callback for progress bar

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


## DFHack-run for variable exploration

When the game is running with a save loaded, use `dfhack-run` to probe DF data structures live:
```
& "D:\Steam\steamapps\common\DFHack\hack\dfhack-run" lua "print(...)"
```
Usage: `dfhack-run lua "lua code here"` — the argument after `lua` is the script string.

### Examples

**Print a single value:**
```
& "D:\Steam\steamapps\common\DFHack\hack\dfhack-run" lua "print(df.global.cur_year, df.global.plotinfo.site_id)"
```

**Print all fields of a struct (safe way — pairs() on the object works):**
```
& "D:\Steam\steamapps\common\DFHack\hack\dfhack-run" lua "local wd = df.global.world.world_data; for k, v in pairs(wd.rivers[0]) do print(k, type(v), '=', tostring(v)) end"
```

**Check vector/array sizes:**
```
& "D:\Steam\steamapps\common\DFHack\hack\dfhack-run" lua "local wd = df.global.world.world_data; print('rivers:', #wd.rivers, 'peaks:', #wd.mountain_peaks, 'landmasses:', #wd.landmasses)"
```

**List struct field names (via the type's `_fields` table):**
```
& "D:\Steam\steamapps\common\DFHack\hack\dfhack-run" lua "if df.world_region then for k, v in pairs(df.world_region._fields) do print(k, 'offset=', v.offset, 'type=', v.type) end end"
```

**List enum values:**
```
& "D:\Steam\steamapps\common\DFHack\hack\dfhack-run" lua "for i = 0, 10 do local ok, v = pcall(function() return df.world_region_type[i] end); if ok then print(i, '=', v) end end"
```

**Translate DF language names to English:**
```
& "D:\Steam\steamapps\common\DFHack\hack\dfhack-run" lua "local r = df.global.world.world_data.regions[0]; print(dfhack.translation.translateName(r.name, false), '->', dfhack.translation.translateName(r.name, true))"
```

### Gotchas & tips

- **`pairs()` on a DF struct instance lists its fields and values** — this is the primary way to discover what's available. `df.Type._fields` lists field metadata.
- **Accessing a non-existent field throws an error** — always wrap in `pcall()` if unsure: `pcall(function() return obj.field end)`.
- **Vector access uses 0-based indices** — `vec[0]` for the first element, `#vec` for count.
- **BitArray flags** are accessed by numeric index: `obj.flags[0]`, check enum via `df.enum_name._first_item` / `_last_item`.
- **`io.write()` output is invisible in dfhack-run** — always use `print()` or `table.concat`.
- ****`dfhack.translation.translateName(name, true)`** gives the English/game-readable name (e.g. "The Ardent Spine"). Without it you get the raw language string (e.g. "Rotecartha").
- ****`dfhack.df2utf()` / `dfhack.utf2df()`** convert between DF's internal CP437 and UTF-8. Needed when storing/displaying text.
- **The `--@ module = true` script pattern**: `reqscript()` returns the script's `_ENV` table, not its return value. Always assign exports to `_ENV` and `return _ENV`.
- **Struct types are in the `df` namespace** by their DF name: `df.world_region`, `df.historical_entity`, `df.unit`, etc. Check `df.<type_name>` to see if a type exists.
- **Nested fields like `obj.field.subfield` can fail at any level** — wrap entire access chains in `pcall`.

# Agent instructions

* Settings and features should always be synced. 
* Settings descriptions in settings_gui should be elaborate enough to undestand what it does
* If on windows, use the sync_mod.bat file after changes so the user can test.
* Significant Changes (not bugfixes, but features) to the HyperTextArea should also be noted in the relevant README.md file 
* Ask the user to explore objects using gui/gm-editor if you are struggling to find the exact name for an object
* Use git functions to read changes, but DO NOT COMMIT