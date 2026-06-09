# DFMyFortWiki plan, and list of features implemented

# Features working

* Saving works (of the predetermined pages)
* Table of content 'of pages' are working
* Table of content of existing journal is working

# Todo Features and Testing Required

* Test creating new pages, and if they save / load correctly
* Create 'initialize' button - pressable only once (I think?)
 * Phase 1: Just create a dedicated page per dwarf and artifact and event, so literally just the very basics of the citizen / artifact / event pages.
  * We should 'plan' how to do this, especially events, artifacts are easy
  * The 'root' citizen/artifact/event pages should just list all of them and link them, and keep it updated with 
   * I don't think the 'Journal' - Which uses a 'TextArea' ui element supports 'tables'. It would be nice to show a table and be able to filter/sort on happiness, age etc. 
* Journal Table of Content should also 'indent' on subpages for citizens etc. If we can implement 'folding' we should.
* Autocreated content should create links (even if it's just special characters) to linkable content (dwarf 1 is dwarf 2's father).
  The respective links (on each page) should use .md file standard for creating 'links' [text to display](linklocation/ID)
