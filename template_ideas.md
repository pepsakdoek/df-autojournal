# Ideas for further reporting (and settings) for each Template

This is just a list of ideas of things that might be of interest to users, and might make the world feel more alive.

# World

* Maybe major rivers & mountains? 
* Gods / Religions? Should maybe live in Civ
* Divine secrets? (I don't know this is a bit late game spoilery)
* Meta info:
    * Maybe show the last 'save' human date?
    * World seed + map seed (critical for sharing/recreating)
    * World generation parameters: size, history length, beast count, savagery, mineral scarcity, etc.
    * World gen preset name (e.g. "Pocket World", "Large Island") - If it was used


# Civilization Root Template

* Add a total Population 

## Bugs
* Civ type name should be Capitalized. Elf vs elf etc.

# Civilization Template 

* Diplomatic Relations
* Ethics and Values
* Major History (we should probably remove this - though it could be cool?)
    * When we get here, we should probably brainstorm on what it would mean
* Ruler
* Most Goblin Settlements are not all listed (at all) - Pits I think is the main ones not listed
* Elf Civs don't show all of their Retreats. (They seem to all be called Forest Retreats)


# Forts Root Page

# Fort Template

* Add the continent and the general area's name to the fort template. 
    * Maybe put the fort's position on the world map in terms of compass directions as well:
    * Fort XXX is located in the west of the world (maybe give world name). Or Central
    * If it's on a river or in a forest, or next to a mountain range or a beach etc (next to an ocean).
* Existing Headings should work
    * Economic links (maybe it's working and my current test fort just doesn't have it)
    * Infrastructure & Districts
        * A function for allocated bedrooms
        * A function for unallocated bedrooms
        * A guildhalls table
        * Defense status could be added (like count of traps, and a list of military squads)
        * History & Timeline should be combined with Fort Timeline (they are the same, and should come last in the template)
* Fort page should have links to it's children pages (citizens, artifacts etc.) - Should be near the top of the template.
* Fort should maybe be the default 'homepage' for the player, meaning all important-ish things gets logged here.
    * Artifacts that get generated here
    * Immigrations
    * Emmigrations (when a dwarf gets 'expelled')
    * Deaths
    * 'Visitors' like monster slayers / entertainers etc.
    * Sieges
    * Maybe even the whole events / enemies should maybe be 'sub-sections' of Fort - thinking about a 'multi-fort' save game. Events at Fort 1 should not be part of Fort 2's events.

## Bugs

* Fort 'founding' is linked to when it gets journaled/initialized and not the actual founding date. - check might be resolved
* I suspect the "climate" calc is wrong, Fridgid when the fort is closer to the non-pole edge of the map than the polar edge
* The location doesn't do the 'north/south' axis first:
    * the eastern south region of The Oracular Plane.

# Citizen Root page

* Cut off the table at 20 I'd say, people should use the search
* Happiness in the table should be sorted correctly (by happiness and not as text)
    * Might be tricky, and might need function change, or we can just 'cheat' it by adding 
    1,2,3,4,5,6,7 to the happiness states (not worth the effort to build a hidden sort field into the table structure)
* Currently says Total Citizens, but I assume those are 'alive' and not dead ones.
* Inititializing needs an option to include dead dwarfs (should be off by default)
* Needs an aggregate table (doesn't need to be an 'wiki table' - probably doesn't need to be) of Alive/Dead/Missing (stolen or body not found) citizens  
* Dead citizens might need their own little table with memorialized / non memorialized, and maybe a death cause too, combat / Age
* Game says 152 Citizens, and Total Citizens is 148 (maybe there are bards etc.)
    * There were 4 human bards in the fort, but a total of 9 humans


# Citizen Template

* Get the actual arrival date per citizen (especially on initialization) -- it currently uses the logged on date, it should never optionally use the 'logged on' date, and should use find the date the entity arrived at the fort (find it, else put unknown)
* Should include timeline and arrivals, new relationships, new skills (upon reaching master level), new medical requirements and history
* Military history (notable kills) - if it's in it's not working / showing
    
# Artifacts

* The create date should also be a column (could maybe call this age too?)
* All the fields from initialization should be pushed to Auto-journaling too (though I guess if we run the initialization code when the artifact is first created it's not much of a problem)
* Would need a field for if the location is known or not - It may have been traded in peace negotiations (or seige negotiations etc.) or just flat out stolen
    * Don't need/want the exact location, we want to know the 'status' (not sure if this is available in a vague 'lore' term in the engine) - I asked on the discord

# Enemies root page

# Enemies Template

# Visitors root Page

# Visitors Template

# Code issues and other possible irritations and issues

-- Basically do this only once we are pretty much happy with the AutoJournal
* Create the actual HTML export

    