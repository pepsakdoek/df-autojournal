# DFMyFortWiki plan, and list of features implemented

# Always keep doing

    * Keep the settings page up to date every time you add 'components' to the initialization and auto-journaling code
    * For every feature implemented add it to the testing (we should maybe split testing and Todo at a point)


## TODO Next



## Longer TODO list

* [ ] Insert link button's UI should include search, when you have many dwarves and artifacts searching is good
* [ ] Check if we can implement 'proper' tables inside the HyperTextArea, so we can list/sort dwarves/artifacts/events
* [ ] Plan and implement the actual 'auto-journal-listener' that catches events as they happen and add them to the journal 
* [ ] Plan how to do events in more detail (Basic template implemented)
* [ ] Implement much 'deeper' initialization thinking, check can we actually find out when a dwarf arrived in dfhack etc. Generally massively improve the templates.
* [ ] Maybe an animals and Pets page?
* [ ] Civilization
    * [ ] Diplomatic Relations 
        * My test civ actually has 'contact' with 2 other 'civs' as well as my own civ. We need to discreminate between Civ (High Hammer), and 'local government' (Dented Halls) -- we do that on the fort page
    * [ ] Ethics and Values
        * I think dwarves all have the same sets of ethics, and not quite sure how much detail we want to dive into on the Civ page (but where else), but do not 'hardcode' it because mods might change and make goblins playable or add more races
    * [ ] Ruling monarch? 
    * [ ] General location on the map (not sure if we can do this, but one should be able to say most of the Civ X's population is in the North, or central, or they are all over the world)
    * [ ] Reference the 'world name' on the civ page.
    * [ ] Ask AI what other things one might find interesting about your own civ and we can check if we can track it
* [ ] Fort
    * [ ] Economic and Political Links
        * Make it actually list it if it's available
    * [ ] Infrastructure & Districts
        * For sure have things like a count of bedrooms
        * Guildhalls/Temples/Inns (list each)
            * Agreements (outstanding maybe? and completed) 
        * Maybe workshop list and counts
    * [ ] List animals? - Also see the animals and pets possible page
    * [ ] Deepest depths mined? Highest structure? Ground level?




## Testing Required

* [x] Test if an intialised wiki 'remembers' it's initialised after saving / loading - FAILED

# Implemented changes

* [✓] Improve the 'templates' to use colors and hopefully links
* [✓] The 'page' table of contents should be 'expandable' and 'collapsable'
    * [✓] And all the citizens/artifact/events should fall under their respective pages in the table of contents
Eg:
├───Civilization -- use the z spelling as it's consistent with the game spelling
├───Fort
├───Citizens
│   ├───Citizen1
│   ├───Citizen2
│   ├───...
├───Artifacts
│   ├───Artifact1
│   ├───Artifact2
│   ├───...
└───Events
    ├───Event1
    ├───Event2
    ├───...

* [✓] Settings page that has toggle labels (wiki widgets) on what information they want to be autopopulated in the initialize and auto-journaling features, at the moment the Settings page has a Civilisation area, with no visible settings at all
    * [✓] Split the 'initializing' settings from the 'auto-journaling' settings (Common settings base implemented)
    * [✓] Each page type should have it's own tab full of settings, split into initialization settings and autojournal settings
    * [✓] The UI window must be resizable, and gain a scroll bar when things don't fit. Ensure the min width is enough to fit all the option descriptions

* [✓] Get much bigger default 'templates' for each of Civilization (and Government), Fort, Citizens, Artifacts, Events. They should include a timeline of things that happened relavant to it.

* [✓] If possible maybe we can support 'links' (clickable links to go to 'linked' pages) 
* [✓] Autocreated content should create links (even if it's just special characters) to linkable content (dwarf 1 is dwarf 2's father).

* [✓] The 'root' citizen/artifact/event pages should just list all of them and link them, and keep it updated with 