# Ideas for further reporting (and settings) for each Template

This is just a list of ideas of things that might be of interest to users, and might make the world feel more alive.

# World

* Gods / Religions? Should maybe live in Civ
* Meta info:
    * Maybe show the last 'save' human date?
* Geography:
    * Lakes and Oceans?
    * Named peaks should say in which mountain range they are
    * Rivers should not say 'major' if they are not major (but we can still list the top 5 or so)



# Civilization Root Template


## Bugs

# Civilization Template 

* Diplomatic Relations
    * Add links to the other Civs
    * Eg: The Ferocious Fountains are at war with:
* Major History (we should probably remove this - though it could be cool?)
    * When we get here, we should probably brainstorm on what it would mean
* Ruler
* Most Goblin Settlements are not all listed (at all) - Pits I think is the main ones not listed
* Elf Civs don't show all of their Retreats. (They seem to all be called Forest Retreats)


# Forts Root Page

# Fort Template

* Existing Headings should work
    * Economic links (maybe it's working and my current test fort just doesn't have it)
    * Infrastructure & Districts
        * A function for allocated bedrooms
        * A function for unallocated bedrooms
        * A guildhalls table
        * Defense status could be added (like count of traps, and a list of military squads)
* Fort should maybe be the 'homepage' for the player, meaning all important-ish things gets logged here.
    * Artifacts that get generated here
    * Immigrations
    * Emmigrations (when a dwarf gets 'expelled')
    * Deaths
    * 'Visitors' like monster slayers / entertainers etc.
    * Sieges
    * Maybe even the whole events / enemies should maybe be 'sub-sections' of Fort - thinking about a 'multi-fort' save game. Events at Fort 1 should not be part of Fort 2's events.

## Bugs


# Citizen Root page

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

Searching the cursor doesn't 'move on' when typing a search. (minor)

-- Basically do this only once we are pretty much happy with the AutoJournal
* Create the actual HTML export

    