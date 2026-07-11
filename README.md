# DF Autojournal

A wiki-like auto-journaling system for Dwarf Fortress (Steam v50+). Keeps a living wiki of your fortress — citizens, artifacts, events, enemies, visitors, and more — automatically updated in real time.

**Author:** pepsakdoek  
**Version:** 0.1.0  
**ID:** df_autojournal

## Features

- **Multi-page wiki** with a tree-structured table of contents: World → Civilizations → Forts (each fort has its own Citizens, Artifacts, Events, Enemies, Visitors)
- **Real-time event capture** via DFHack eventful hooks — threats, achievements, social events, trade, crises, military, environment, deaths, births/migrants, syndromes, sieges
- **Historical event catch-up** on initialization — scans world history for events tied to your site
- **Rich text editor** (HyperTextArea) with clickable wiki links, tables, colors, and undo/redo
- **Family & relationship tracking** for citizens (spouses, parents, children with clickable links)
- **Sortable timeline** and **enemy registry** with encounter logging
- **Category-filterable settings** — toggle exactly which event types get journaled
- **Overlay status icons** in the top-right corner showing auto-journaling ON/OFF
- **Progress bar** during initialization with per-step timing

## Installation

Eventually it will be put on the steam workshop.

### Prerequisites

- Dwarf Fortress Steam v50.xx
- [DFHack](https://dfhack.org) (latest stable for your DF version)

### Manual install

1. Close Dwarf Fortress if it's running.
2. Copy everything from `scripts_modactive/` into your DFHack scripts folder:
   - `df-autojournal.lua` and `df-autojournal-status.lua` → `<DF>\dfhack-config\scripts\`
   - The entire `internal\df-autojournal\` folder → `<DF>\dfhack-config\scripts\internal\df-autojournal\`
3. Copy the icon images from `scripts_modinstalled/` to `<DF>\dfhack-config\scripts\`:
   - `AutoJournal.png`, `AutoJournal_on.png`, `AutoJournal_off.png`
4. Launch Dwarf Fortress. The mod will be loaded automatically by DFHack's overlay system.

### Quick sync (Windows)

Run `sync_mod.bat` — it copies all files to the expected DFHack scripts folder automatically.  
*(Note: update the paths at the top of the .bat file if your Dwarf Fortress install is in a different location.)*

## First-time setup

1. Load your fortress save in Dwarf Fortress.
2. Open the DFHack console and type:
   ```
   df-autojournal
   ```
   This opens the wiki window.
3. Click the **"Initialize Wiki"** button.
   - A progress bar will appear showing 10 initialization steps.
   - The mod scans your fort's citizens, artifacts, world history, and builds all wiki pages.
   - Wait for it to finish (may take a while on large worlds with long histories).
4. Once initialized, toggle **"Auto-Journaling"** to ON to start capturing events in real time.

## Loading into an already-started game

If you've been playing a fortress for a while and want to add DF Autojournal mid-save:

### Step 1: Install the mod files

Follow the installation steps above. You do **not** need to start a new fortress — the mod works with existing saves.

### Step 2: Load your save and run the mod

1. Launch Dwarf Fortress and load your existing fortress save as normal.
2. Open the DFHack console (typically `Ctrl+Shift+F12` or click the DFHack terminal icon).
3. Type the following command and press Enter:
   ```
   df-autojournal
   ```
   The wiki window will appear on screen.

### Step 3: Initialize

Click the **"Initialize Wiki"** button in the wiki window. The mod will scan your already-running fort and all its history to build the wiki pages. This may take a minute or two depending on your world's history length.

### Step 4: Enable auto-journaling

After initialization finishes, toggle **"Auto-Journaling"** to ON. From this point forward, every event that happens in your fort (battles, births, syndromes, sieges, etc.) will be automatically recorded to the wiki.

To verify it's working, look for the green **ON** indicator in the top-right corner of the screen (the overlay status icon).

### What gets captured retroactively?

When you initialize mid-save, the mod catches up on:
- All historical events tied to your fort's site from world history
- All current citizens and their relationships
- All artifacts present on site
- All known civilizations and forts

Only events happening **after** initialization will be captured in real time by the auto-journaling system.

### Resetting

If something goes wrong or you want to start fresh, you can reset all wiki data by running this in the DFHack console:
```
lua dfhack.persistent.deleteSiteData('mfw_initialized')
```
Then open the wiki again and click **"Initialize Wiki"**.

## Usage

- **Wiki Page List** (left panel): Browse the page tree. Expand forts to see sections (Citizens, Artifacts, Events, Enemies, Visitors) and individual pages.
- **Journal TOC** (middle panel): Shows section headers for the current page. Collapse/expand with `<<` / `>>`.
- **Editor** (right panel): Read and edit wiki pages. Click on colored links to navigate. Use the toolbar for formatting (colors, tables, links).
- **Settings**: Configure which civ, fort, citizen, artifact, and event categories are generated and journaled.
- **Auto-Journaling toggle**: Start/stop real-time event capture at any time.

## File structure

```
dfhack-config/scripts/
├── df-autojournal.lua                  # Mod entry point
├── df-autojournal-status.lua           # Overlay status icons
├── AutoJournal.png                     # Overlay icon
├── AutoJournal_on.png                  # Overlay icon (active)
├── AutoJournal_off.png                 # Overlay icon (inactive)
└── internal/df-autojournal/
    ├── main_gui.lua                    # Main UI screen
    ├── initializer.lua                 # Wiki initialization
    ├── event_listener.lua              # Real-time event capture
    ├── event_parser.lua                # Event parsing (real-time + historical)
    ├── chronicle.lua                   # Legacy batch scanner
    ├── wiki_utils.lua                  # Utility functions
    ├── wiki_settings.lua               # Settings data model
    ├── settings_gui.lua                # Settings UI
    ├── logger.lua                      # Debug logging
    ├── wiki_functions.lua              # Function blocks system
    ├── wiki_widgets.lua                # Core widget re-exports
    ├── wiki_widgets/                   # HyperTextArea rich-text system
    │   ├── hyper_text_area.lua
    │   ├── hyper_text_area_content.lua
    │   ├── hyper_wrapped_text.lua
    │   ├── hyper_table.lua
    │   ├── toolbar.lua
    │   ├── link_modal.lua
    │   ├── table_editor_modal.lua
    │   ├── function_modal.lua
    │   ├── hta_utils.lua
    │   ├── hta_context.lua
    │   ├── history_store.lua
    │   └── README.md
    └── templates/                      # Page rendering templates
        ├── world.lua
        ├── civilizations.lua
        ├── civilization.lua
        ├── forts.lua
        ├── fort.lua
        ├── citizen.lua
        ├── artifact.lua
        ├── event.lua
        ├── timeline.lua
        ├── enemies.lua
        ├── visitors.lua
        └── entity.lua
```

## Development

The source files in `scripts_modactive/` are the working copies. After making changes, run `sync_mod.bat` to copy them into your DFHack scripts folder for testing. A game restart may be needed (DFHack caches `reqscript` modules per session).

For exploring DF data structures live from the command line, use:
```
& "<DF>\hack\dfhack-run" lua "print(df.global.cur_year, df.global.plotinfo.site_id)"
```
