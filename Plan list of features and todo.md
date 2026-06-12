# DFMyFortWiki plan, and list of features implemented

# Features working

* [✓] Saving works (of the predetermined pages)
* [✓] Table of content 'of pages' are working
* [✓] Table of content of existing journal is working
* [✓] Reformat the plan file so we have tickboxes.
* [✓] Create 'initialize' button - pressable only once (with overwrite prompt)
    * [✓] Phase 1: Just create a dedicated page per dwarf and artifact and event, so literally just the very basics of the citizen / artifact / event pages.
* [✓] Test creating new pages, and if they save / load correctly

# Todo Features and Testing Required

* [x] Test if an intialised wiki 'remembers' it's initialised after saving / loading - FAILED
* [✓] Phase 2: Plan how to do events in more detail (Basic template implemented)
    * [ ] The 'root' citizen/artifact/event pages should just list all of them and link them, and keep it updated with 
        * [ ] I don't think the 'Journal' - Which uses a 'TextArea' ui element supports 'tables'. It would be nice to show a table and be able to filter/sort on happiness, age etc.
        * [ ] If possible maybe we can support 'links' (clickable links to go to 'linked' pages) 
* [ ] Journal Table of Content should also 'indent' on subpages for citizens etc. If we can implement 'folding' we should.
* [✓] Autocreated content should create links (even if it's just special characters) to linkable content (dwarf 1 is dwarf 2's father).
  The respective links (on each page) should use .md file standard for creating 'links' [text to display](linklocation/ID)
* [ ] Plan the actual 'auto-journal-listener' that catches events as they happen and add them to the journal (we'll need to test if we can 'edit' the files when they are not 'open') (build a mini API to edit those files when we don't have them open?)
* [✓] Get much bigger default 'templates' for each of Civilization (and Government), Fort, Citizens, Artifacts, Events. They should include a timeline of things that happened relavant to it.
* [ ] in the HyperTextArea folder is example code of a text area which supports clickable 'links' however it doesn't support editing the area 'runtime'. Ideally we want to implement this, but somehow give the user the ability to enter links themselves and change colors etc. I want to keep the manual runtime editing feature of the current TextArea.
* [✓] Settings page that has toggle labels on what information they want to be autopopulated in the initialize and auto-journaling features
    * [✓] Split the 'initializing' settings from the 'auto-journaling' settings (Common settings base implemented)
    * [✓] Keep the settings page up to date every time you add 'components' to the initialization and auto-journaling code


# Name Bugs (addressed via UTF-8/CP437 transcription)
Note that Dwarf Fortress is in CP437, I am unsure if TextArea is UTF-8 or CP437 (or something else).

* [✓] Fixed display of special characters (ù, û, Å, è, î, é, ë) by implementing `to_ui` (utf2df) and `from_ui` (df2utf) transcription.

