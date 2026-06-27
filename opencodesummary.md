Here is the complete analysis of the codebase.

1. PROJECT OVERVIEW
What it is: A DFHack Lua mod for Dwarf Fortress (v50+ Steam) called "DF Autojournal" (ID: df_autojournal). It provides a wiki-like auto-journaling system inside Dwarf Fortress -- similar to the vanilla Journal but with multi-page support, auto-generated citizen/artifact/event pages, a table of contents, templates, settings, and a rich-text editor with clickable links.
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

Entry Point
File	Purpose
D:\P\df-autojournal\scripts_modactive\df-autojournal.lua	Mod entry point. Requires main_gui and calls main_gui.main() when run directly (not as a module). 8 lines.

Core Logic (internal/df-autojournal/)
File	Purpose
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\main_gui.lua	Main UI screen. Defines WikiWindow (the main window with Wiki TOC, Journal TOC, Editor), WikiContext (persistent data storage wrapper), and WikiScreen (the full-screen ZScreen). Orchestrates the entire UI. (443 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\initializer.lua	Wiki Initializer. Scans the fortress for active units, renders templates for civ/fort/citizens/artifacts, saves content via WikiContext. Defines WikiInitializer class. Builds root Citizens and Artifacts pages with sortable table blocks. Uses safe_save() wrapper with pcall logging. (207 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\chronicle.lua	Auto-Journaling Chronicle. Batch-scans world.history.events, filters by site, parses events, and appends entries to the appropriate wiki pages. Runs as a background dfhack.timeout loop every 1 minute. (99 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\event_parser.lua	Event Parser. Maps DF history event types (HIST_FIGURE_NEW_PET, HIST_FIGURE_DIED, ARTIFACT_CREATED, HIST_FIGURE_RENAME) into structured entries with page_id, section, and text. Provides helper functions for unit/HF links. (79 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\logger.lua	Logger. Writes timestamped logs to wiki_debug.log in the DF root directory and prints to DFHack console. (21 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_utils.lua	Utilities. get_civ_id(), get_site_id(), translate_name(), sanitize() (CP437 to UTF-8 accent-stripping and back), get_readable_name(), get_date_str(), sanitize_content() (handles strings, spans, and table blocks), plus helper functions colored(), header(), label(), value(), note(). (174 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_settings.lua	Settings data model. Defines DEFAULT_SETTINGS (nested table per template type), loads/saves from persistent DF site data using JSON encoding, provides set_preset() for "all/minimal/recommended" presets. (219 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\settings_gui.lua	Settings UI screen. Defines SettingsWindow (a widgets.Window) and SettingsScreen (a gui.ZScreen). Creates toggle labels for every template setting (civ: 5, fort: 6, citizen: 7, artifact: 4), with quick preset buttons (All/Min/Rec). (255 lines)

Templates (internal/df-autojournal/templates/)
File	Purpose
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\templates\fort.lua	Fort template renderer. Reads mfw_settings.get_settings().fort, generates markdown with sections: Population, Government, Links, Districts, Timeline, Defense. (77 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\templates\civilization.lua	Civilization template renderer. Reads mfw_settings.get_settings().civ, generates markdown with sections: Type, Diplomatic Relations, Ethics, Major History. Leadership code is commented out. (101 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\templates\citizen.lua	Citizen template renderer. Reads mfw_settings.get_settings().citizen, generates markdown: Profession, Gender, Personal Journal, Values (active), Appearance/Needs/Relationships/Skills (commented out), Timeline. (123 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\templates\artifact.lua	Artifact template renderer. Reads mfw_settings.get_settings().artifact, generates: Type, Value, Description, History (with creator link), Location. (67 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\templates\event.lua	Event template renderer. Static template with sections: Summary, Key Participants, Detailed Account, Consequences. (27 lines)


Widget/UI System (internal/df-autojournal/wiki_widgets/)
File	Purpose
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets.lua	Core widget re-exports. Defines three custom widgets: ToggleLabel (toggle switch with [X] / [ ] icons), Shifter (collapse/expand arrow button for Journal TOC), TableOfContents (scannable section list with Prev/Next navigation). Also defines page tree helpers: build_page_tree(), flatten_page_tree(), get_page_parent(), tree_contains_id() used for collapsible [+] / [-] Wiki TOC. (281 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\README.md	HyperTextArea documentation: span format, table block format, programmatic usage, table editor instructions. (163 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\hyper_text_area.lua	HyperTextArea -- the rich-text display/editor widget. Wraps toolbar + content area + scrollbar + info box. Handles color selection (Ctrl+Shift+Up/Down), link insertion (Ctrl+Insert), clipboard, cursor movement, scroll. Also manages table blocks: setDisplayText() passes table entries through, addTable() inserts at cursor. (274 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\hyper_text_area_content.lua	HyperTextAreaContent -- the internal rendering/editing engine. Manages a flat char_list (character-level records with pen/link). Handles input: typing, cursor movement, selection, copy/cut/paste, undo/redo, mouse hit-testing with link click detection. Extracts table blocks separately from char_list and manages their positions, supports sortable columns (click header to sort), placeholders, and scroll awareness. (635 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\hyper_wrapped_text.lua	HyperWrappedText -- text-wrapping engine that operates on display_text/raw_text pairs. Produces lines and line_spans arrays. Provides coordsToIndex, indexToCoords, and getClickHandlerAt for hit-testing. Handles table-block line tracking (is_table_line marks table rows as non-editable). (268 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\hyper_table.lua	HyperTable -- table block rendering engine. Renders multi-column tables with headers, sort indicators (^/v), row clipping, line drawing (horiz/vert rules with CP437 box-drawing chars), and cell alignment. (318 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\hta_utils.lua	HTA Utilities: to_span(), is_table_block(), build_char_list(), collapse_chars(), char_list_to_raw(). (79 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\history_store.lua	HistoryStore -- undo/redo manager for HyperTextArea. Stores up to 25 entries, coalesces consecutive same-type edits. (60 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\toolbar.lua	Toolbar -- vertical color picker widget (15 colors) with a link-insert button at the bottom and a table-insert button (▲) above it. (72 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\link_modal.lua	LinkModal -- a modal ZScreen for inserting internal wiki links. Shows an EditField for display text and a List of destination pages. (63 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\table_editor_modal.lua	TableEditorModal -- modal for editing table blocks. Two sections: Columns (header|align|stretch format) and Data (pipe-delimited rows). Supports F2 save and Esc discard. (331 lines)
D:\P\df-autojournal\scripts_modactive\internal\df-autojournal\wiki_widgets\hta_context.lua	HTAContext -- optional serialization context (JSON-based persistence for HyperTextArea content). (36 lines)

3. SETTINGS PAGE IMPLEMENTATION
Data Model (wiki_settings.lua)
- Storage key: 'mfw_settings' in dfhack.persistent.getSiteData/saveSiteData
- Default settings are a nested table keyed by template type (civ, fort, citizen, artifact, event), each containing boolean toggles:
- civ: leadership, ethics, relations, wars, history
- fort: wealth, gov, districts, defense, links, timeline
- citizen: values, relationships, skills, appearance, needs, medical, timeline
- artifact: description, history, creator, location
- event: participants, summary, consequences
- Settings are JSON-encoded for storage with legacy table support
- Presets: set_preset(settings, template, 'all'|'minimal'|'recommended')
Settings GUI (settings_gui.lua)
- SettingsWindow extends widgets.Window with frame={w=60, h=40}
- SettingsScreen extends gui.ZScreen with focus_path='mfw-settings'
- Uses a local create_toggle(label, template, key) closure that returns a ToggleLabel bound to the specific setting, with auto-save on change
- Uses a local create_preset_buttons(template) closure that creates "All", "Min", "Rec" quick preset labels
- To update toggles after a preset change: SettingsWindow:update_toggles() re-reads settings and sets each toggle
- Limitation: The settings panel is currently a flat list -- no tabs for "initialization" vs "auto-journaling" yet, and no scrollbar (it can overflow the window)

4. INITIALIZATION AND AUTO-JOURNALING CODE
Initialization (initializer.lua)
- WikiInitializer:perform(screen) does a full scan:
1. Gets site ID, aborts if invalid
2. Renders and saves Civ page (civ_template.render()) and Fort page (fort_template.render())
3. Iterates df.global.world.units.active, filters to citizens via dfhack.units.isCitizen(unit)
4. For each citizen, renders citizen_template.render(unit) and saves under key 'citizen:' .. unit.id
5. Builds a root Citizens index page with a **sortable table block** (columns: Name, Birth Year, Happiness, Title/Role, Death Status) with linked names
6. Iterates artifacts, renders artifact_template.render(item), saves under key 'artifact:' .. art_record.id
7. Builds a root Artifacts index page with a **sortable table block** (columns: Name, Creator, Type, Value) with linked names
8. Saves the dynamic page list and sets initialized flag
9. Calls on_complete callback to refresh the page list
- All save_content calls use safe_save() wrapper with pcall error capture and logging
Auto-Journaling: Chronicle (chronicle.lua)
- Batch-scan approach (not real-time event listening)
- Chronicle.get_state() reads last_event_id and is_running from persistent site data
- Chronicle.process_events(context) is the core:
1. Reads current max event ID from df.global.world.history.event_id
2. Scans backwards from event_id - 1 down to last_event_id (max 500 events per cycle)
3. Filters by site (if the event has a getSite() method)
4. Parses each event via event_parser.parse(event), which returns {page_id, section, text} or nil
5. Appends parsed entries to the appropriate page via Chronicle.append_to_page()
- Chronicle.append_to_page(context, page_id, section_title, text) finds the ## Section header in the page content and inserts the new text after it (or creates the section if missing)
- Background loop: Chronicle.start_background_task(context) runs every 1 minute via dfhack.timeout(1, 'min', tick). Checks if mfw_auto_journal_enabled is true and fortress mode is active.
- Currently commented out in WikiScreen:init(): -- chronicle.start_background_task(self.context) -- because it was crashing during testing.
Event Parser (event_parser.lua)
Handles 4 event types currently:
- HIST_FIGURE_NEW_PET -> citizen page, "History & Timeline" section (adopted pet/child)
- HIST_FIGURE_DIED -> citizen page, "History & Timeline" section (death with cause)
- ARTIFACT_CREATED -> artifacts root page, "Recent Events" section
- HIST_FIGURE_RENAME -> citizen page, "History & Timeline" section (new name)


5. TABLE OF CONTENTS IMPLEMENTATION
Wiki Page TOC (Left Panel)
- Defined in WikiWindow:init() as a widgets.List with view_id='wiki_page_list'
- Hardcoded pages: PAGES = {{text='Civilisation', id='civ'}, {text='Fort', id='fort'}, {text='Citizens', id='citizens'}, {text='Artifacts', id='artifacts'}, {text='Events', id='events'}}
- Dynamic pages (citizen/artifact sub-pages) are appended to this list via WikiScreen:refreshPageList() which uses build_page_tree() + flatten_page_tree() to create a collapsible tree with [+] / [-] icons
- Selection triggers onWikiPageSubmit(idx, choice): for parent items (Citizens/Artifacts/Events), clicking the [+] / [-] icon toggles expand/collapse, clicking the text navigates to the root page. Non-parent items always navigate.
Journal Page TOC (Middle Panel)
- Implemented as TableOfContents widget (defined in wiki_widgets.lua)
- TableOfContents extends widgets.Panel with an internal widgets.List (view_id='table_of_contents')
- TableOfContents:reload(text, cursor) scans the raw text for markdown headers (^#+ .+), builds a list of sections with line_cursor positions
- Navigation: Prev Section (A_MOVE_N_DOWN) and Next Section (A_MOVE_S_DOWN) buttons
- currentSection() finds the section closest to the current cursor position
- setSelectedSection(section_index) highlights the current section in the list
- The Journal TOC is collapsible via the Shifter widget (an arrow button with <</>> characters)
- Visibility is toggled via the "Toggle page TOC" hotkey (CUSTOM_CTRL_O)
- When visible, the editor area shifts right to make room
Layout Management
- WikiWindow:ensurePanelsRelSize() recalculates the l (left) positions of divider and editor panels as the Wiki TOC and Journal TOC panels are shown/hidden
- WikiWindow:preUpdateLayout() calls ensurePanelsRelSize()

6. TEMPLATE SYSTEM
Design: Each template type is a standalone Lua module in templates/ that exports a render() function. Templates are unaware of the event parser -- they are only used during initialization to generate the initial page content. The event parser uses a different mechanism (Chronicle.append_to_page) to append to existing pages.
How templates use settings: All active templates (fort.lua, civilization.lua, citizen.lua, artifact.lua) call mfw_settings.get_settings().<template_type> and conditionally render sections based on boolean toggles.
Template details:
Template	Arguments	Settings sections (active)
fort.lua	(none)	Population, Government, Links, Districts, Timeline, Defense
civilization.lua	(none)	Type, Diplomatic Relations, Ethics, Major History
citizen.lua	unit	Profession, Gender, Personal Journal, Values, Timeline
artifact.lua	item	Type, Value, Description, History (creator link), Location
event.lua	event_data	Summary, Key Participants, Detailed Account, Consequences (all static)
Limitations noted in code/comments:
- Many template sections are commented out due to DF API errors or nil-value crashes
- Templates use utils.sanitize() for output sanitization
- Age is intentionally omitted from citizen template (would need constant updates)
- Event template is fully static (no dynamic data from settings or game state)


7. WIDGET/UI SYSTEM
The project uses DFHack's standard GUI framework (gui, gui.widgets) plus a custom rich-text widget system:
Standard DFHack Widgets Used
- widgets.Window -- base for WikiWindow, SettingsWindow
- widgets.Panel -- container panels (Wiki TOC, settings panel)
- widgets.Label -- text labels (section headers, key hints)
- widgets.List -- scrollable lists (page list, section TOC)
- widgets.HotkeyLabel -- action buttons with keybindings (Initialize, Settings, Export, Toggle TOC)
- widgets.ToggleHotkeyLabel -- base for the custom ToggleLabel
- widgets.Divider -- vertical separators between panels
- widgets.EditField -- text input in link modal
- gui.ZScreen -- base for WikiScreen and SettingsScreen
- gui.widgets.scrollbar -- scrollbar in HyperTextArea
Custom Widgets (in wiki_widgets.lua and wiki_widgets/)
1. ToggleLabel -- A styled toggle button using [O] / [X] icons from DF's control panel tile sheet. Extends ToggleHotkeyLabel.
2. Shifter -- A collapse/expand arrow used to show/hide the Journal TOC. Shows << or >> characters.
3. TableOfContents -- A section header scanner + navigable list with Prev/Next buttons.
4. Page tree helpers (build_page_tree, flatten_page_tree, etc.) -- Collapsible Wiki TOC with parent/child grouping and [+] / [-] icons.
5. HyperTextArea (wiki_widgets/hyper_text_area.lua) -- The main rich-text widget:
- Contains a Toolbar (color picker + link button + table insert button)
- Contains HyperTextAreaContent (the editable text engine)
- Contains a Scrollbar
- Contains an InfoBox showing keyboard shortcuts
6. HyperTextAreaContent (wiki_widgets/hyper_text_area_content.lua) -- Character-level text editor with:
- Flat char_list array of {char, pen, link} records
- Text manipulation (insert, delete, backspace, enter)
- Selection (mouse drag, Ctrl+A, Shift+cursor)
- Clipboard (Ctrl+C/X/V)
- Undo/redo (Ctrl+Z/Y) via HistoryStore
- Link click handling (Ctrl+click) with hover highlighting
- Cursor navigation (arrows, home/end, Ctrl+left/right, Ctrl+home/end)
- **Table block management**: extracts table blocks from display_text into separate table_blocks array with position tracking; handles insert/delete adjustments, sorting, placeholder lines
7. HyperWrappedText (wiki_widgets/hyper_wrapped_text.lua) -- Text wrapping engine that bridges display_text (rich spans) to raw_text (plain string). Produces lines and line_spans for rendering. Tracks table lines (is_table_line) and manages table block line accounting.
8. **HyperTable** (wiki_widgets/hyper_table.lua) -- Dedicated table block renderer. Handles column layout (auto-width, fixed-width, stretch), sorting (click header to sort by column), row clipping (with "and N more" overflow line), text alignment, box-drawing borders.
9. Toolbar (wiki_widgets/toolbar.lua) -- Vertical strip of 15 color blocks with selection indicator, a link-insert button at the bottom, and a **table-insert button** (▲) above the link button.
10. LinkModal (wiki_widgets/link_modal.lua) -- Dialog for inserting [text](page) links over the text.
11. **TableEditorModal** (wiki_widgets/table_editor_modal.lua) -- Modal for editing table blocks. Two text areas: Columns (header|align|stretch format) and Data (pipe-delimited). F2 to save, Esc to discard.
12. HistoryStore (wiki_widgets/history_store.lua) -- Undo/redo stack with coalescing of same-type edits, up to 25 entries deep.
13. HTAContext (wiki_widgets/hta_context.lua) -- Optional JSON-based serialization context for HyperTextArea content persistence.
Link System
- Links use the format [display text](page_id) where page_id can be civ, fort, citizens, artifacts, events, or citizen:<unit_id>
- Links are parsed at the character level in HyperTextAreaContent
- Mouse hit-testing: HyperWrappedText:getClickHandlerAt(x, y) checks which span fragment is under the cursor and returns the link data
- Ctrl+Click navigates to the linked page via on_link_click
Table Blocks
- Tables are a first-class type in the display_text model: { type='table', columns={...}, rows={...}, sort_col=nil, sort_asc=true, max_rows=nil }
- Table columns support: header, align (left/right/center), width, min_width, max_width, stretch
- Tables are extracted into a separate table_blocks array (not part of char_list) and rendered as read-only full-width blocks
- Table header clicks trigger sorting; sort indicator shown as ^/v on the sorted column header
- The table editor modal (▲ button in toolbar) allows editing the nearest table's columns and data

8. ARCHITECTURAL SUMMARY
User launches mod
       |
       v
df-autojournal.lua (entry point)
       |
       v
main_gui.lua -> WikiScreen (ZScreen)
       |
       +-- WikiWindow (main UI container)
       |     +-- Wiki Page List (left) -- collapsible tree with [+]/[-], click icon to toggle, click text to navigate
       |     +-- Shifter + Journal TOC (middle) -- collapsible section headers
       |     +-- HyperTextArea (right) -- rich text editor with table block support
       |     +-- Bottom bar (hotkey hints)
       |
       +-- WikiContext (persistence layer)
       |     +-- save_content / load_content (per page) with pcall error logging
       |     +-- save_dynamic_pages / get_dynamic_pages
       |     +-- Uses dfhack.persistent.saveSiteData with prefix 'mfw_'
       |
       +-- Initialization flow:
       |     WikiInitializer:perform()
       |       -> reads civ_template, fort_template, citizen_template, artifact_template
       |       -> renders and saves content for each citizen and artifact
       |       -> builds root Citizens and Artifacts pages with sortable table blocks
       |       -> saves index pages with links, using safe_save() wrapper for error capture
       |
       +-- Auto-Journaling flow (currently disabled):
             Chronicle:process_events()
               -> event_parser:parse() for each new history event
               -> Chronicle:append_to_page() to insert into correct section
               -> runs every 1 minute via dfhack.timeout
       |
       +-- Settings flow:
             SettingsScreen -> SettingsWindow
               -> reads mfw_settings.get_settings()
               -> creates ToggleLabels for each template option
               -> save_settings() via JSON-encoded persistent storage

Widget System:
  DFHack gui/gui.widgets (standard) + Custom widgets:
    wiki_widgets/:
      toolbar.lua              -- color picker + table insert button
      link_modal.lua           -- link inserter
      hyper_wrapped_text.lua   -- text wrapping engine with table-line tracking
      hyper_text_area_content.lua -- char-level editor with table block management
      hyper_text_area.lua      -- combined rich-text widget
      hyper_table.lua          -- table block rendering engine
      table_editor_modal.lua   -- table editor modal
      hta_utils.lua            -- span/char list utilities + table block detection
      history_store.lua        -- undo/redo
      hta_context.lua          -- optional JSON persistence

Templates:
  templates/:
    fort.lua, civilization.lua, citizen.lua, artifact.lua, event.lua
    Each reads mfw_settings and conditionally renders sections
