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
* [ ] Phase 2: Plan how to do events in more detail
    * [ ] The 'root' citizen/artifact/event pages should just list all of them and link them, and keep it updated with 
        * [ ] I don't think the 'Journal' - Which uses a 'TextArea' ui element supports 'tables'. It would be nice to show a table and be able to filter/sort on happiness, age etc.
        * [ ] If possible maybe we can support 'links' (clickable links to go to 'linked' pages) 
* [ ] Journal Table of Content should also 'indent' on subpages for citizens etc. If we can implement 'folding' we should.
* [ ] Autocreated content should create links (even if it's just special characters) to linkable content (dwarf 1 is dwarf 2's father).
  The respective links (on each page) should use .md file standard for creating 'links' [text to display](linklocation/ID)
* [ ] Plan the actual 'auto-journal-listener' that catches events as they happen and add them to the journal (we'll need to test if we can 'edit' the files when they are not 'open') (build a mini API to edit those files when we don't have them open?)
* [ ] Get much bigger default 'templates' for each of Civilization (and Government), Fort, Citizens, Artifacts, Events. They should include a timeline of things that happened relavant to it.


# Name Bugs
Note that Dwarf Fortress is in CP437, I am unsure if TextArea is UTF-8 or CP437 (or something else).

* [ ] ├╣shrir Tomusbomrek "Shovewhipped", broker -- the buggy letter is: ù
* [ ] Limul K├╗bukarzes "Lanceknight", Dwarven Child -- the buggy letter is: û
* [ ] Monom ├Ñblelnish "Busttrades", Dwarven Child -- the buggy letter is: Å
* [ ] Astesh Bardum├¿rith "Fightlabor", Miner -- the buggy letter is: è
* [ ] Fath Umstizzunt├«r "Sizzledanvil", Metalsmith -- the buggy letter is: î
* [ ] Id ├│rathel "Drinkring", Metalsmith -- the buggy letter is: é
* [ ] B├½mbul Oddomasd├╗g "Cloisterdrum", chief medical dwarf -- the buggy letters are: ë,û

