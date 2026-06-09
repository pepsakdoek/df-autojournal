# Project Description
This is a DF Hack Mod for Dwarf Fortress. (Lua, v50+ Steam)

Stack: Dwarf Fortress Steam (v50.xx) + DFHack (latest stable), Lua. Ref: https://docs.dfhack.org/

For the 'latest' documentation of the API:
https://docs.dfhack.org/en/latest/docs/dev/Lua%20API.html

For a guide on modding:
https://docs.dfhack.org/en/latest/docs/guides/modding-guide.html

# Overview

The aim it to 'replicate' the Journal logic, but with the following 'new features':
* More than one page, with a default structure (with the Journal Table of contents that is for the multi-page Journal)
 * Civilisation (The civ the fort belongs to and the leader, the site government etc.)
 * Fort (Interally the entity is called the site)
 * Citizens (all the citizens in the fort)
  * Every citizen will get their own journal page based off a template
 * Artifacts (important items)
  * Every artifact will get its own journal page based off a template
 * Events (Sieges, kids being captured etc)
  * Every event will get its own journal page based off a template (events might be a bit too complex to have 1 template)

## User Interface

The UI should be the same as the current one, but with the dedicated Jounal Table of Contents to the left of the current Table of Contents.
In the same 'panel' as the Journal table of contents should also be: 
* a toggle button that is a on off switch to "Enable Auto-Journaling" (default off). 
 * The button should look like the ones in togglelabelExample\spectate.lua.
* a settings button (which will lead you to a settings page that will determine which types of content constitutes an entry into the journal)
 * The buttons in the settings page should look like the ones in togglelabelExample\spectate.lua.
* an 'export' button that will export it to an html page 

Auto journaling will 'automatically' add entries to different citizens and entities' pages as they happen.

Every 'type' of page will get a default template, with different headings (Headings work like .md headings (it adds to the page's table of contents), the Journal table of contents should just list pages, not their headings, but because citizens each get)

# File structure

Keep the file structure updated as we add more files (like the templates etc).

```text
D:\p\DFMyFortWiki\
├───CurrentJournal\          # Reference copy of standard DFHack journal
│   ├───journal.lua
│   └───internal\
│       └───journal\
│           ├───journal_context.lua
│           ├───shifter.lua
│           ├───table_of_contents.lua
│           └───contexts\
│               ├───adventure.lua
│               ├───dummy.lua
│               └───fortress.lua
├───scripts_modactive\       # Active mod scripts
│   ├───my-fort-wiki.lua
│   └───internal\
│       └───DFMyFortWiki\
│           └───main_gui.lua
└───togglelabelExample\      # UI Toggle Button implementation example
    └───spectate.lua
```

# Coding practices

* Consise and correct, do not over comment.
* No em-dashes in printed strings; DF can't render them. Use -
* Comments: lean, logical, human-readable