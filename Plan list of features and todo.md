# DFMyFortWiki plan, and list of features implemented

## TODO Next

* [ ] Settings page that has toggle labels (wiki widgets) on what information they want to be autopopulated in the initialize and auto-journaling features, at the moment the Settings page has a Civilisation area, with no visible settings at all
    * [ ] Split the 'initializing' settings from the 'auto-journaling' settings (Common settings base implemented)
    * [ ] Each page type should have it's own tab full of settings, split into initialization settings and autojournal settings
    * [ ] Keep the settings page up to date every time you add 'components' to the initialization and auto-journaling code
    * [ ] The UI window must be resizable, and gain a scroll bar when things don't fit. Ensure the min width is enough to fit all the option descriptions





## Todo Features and Testing Required

* [x] Test if an intialised wiki 'remembers' it's initialised after saving / loading - FAILED
* [✓] Phase 2: Plan how to do events in more detail (Basic template implemented)
    * [ ] The 'root' citizen/artifact/event pages should just list all of them and link them, and keep it updated with 
        * [ ] I don't think the 'Journal' - Which uses a 'TextArea' ui element supports 'tables'. It would be nice to show a table and be able to filter/sort on happiness, age etc.
        * [ ] If possible maybe we can support 'links' (clickable links to go to 'linked' pages) 
* [✓] Autocreated content should create links (even if it's just special characters) to linkable content (dwarf 1 is dwarf 2's father).
  The respective links (on each page) should use .md file standard for creating 'links' [text to display](linklocation/ID)
* [ ] Plan the actual 'auto-journal-listener' that catches events as they happen and add them to the journal (we'll need to test if we can 'edit' the files when they are not 'open') (build a mini API to edit those files when we don't have them open?)
* [✓] Get much bigger default 'templates' for each of Civilization (and Government), Fort, Citizens, Artifacts, Events. They should include a timeline of things that happened relavant to it.

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