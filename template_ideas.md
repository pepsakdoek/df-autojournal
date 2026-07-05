# Ideas for further reporting (and settings) for each Template

This is just a list of ideas of things that might be of interest to users, and might make the world feel more alive.

# World

## Bugs 
* List of inhabited landmasses doesn't show
* Era doesn't show


# Civilization Root Template

* Add a total Population 

# Civilization Template 

* Diplomatic Relations
* Ethics and Values
* Major History (we should probably remove this - though it could be cool?)
* Goblin Settlements are not all listed (at all) - Pits I think is the main ones not listed
* Elf Civs don't show all of their Retreats. (They seem to all be called Forest Retreats)


# Forts Root Page

# Fort Template

* Add the continent and the general area's name to the fort template. 
    * Maybe put the fort's position on the world map in terms of compass directions as well:
    * Fort XXX is located in the west of the world (maybe give world name). Or Central
    * Maybe describe the general temperature? Does it snow or not?
* Existing Headings should work
    * Economic links (maybe it's working and my current test fort just doesn't have it)
    * Infrastructure & Districts
        * A function for allocated bedrooms
        * A function for unallocated bedrooms
        * A guildhalls table
        * Defense status could be added (like count of traps, and a list of military squads)
        * History & Timeline should be combined with Fort Timeline (they are the same, and should come last in the template)
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
* I suspect the "climate" calc is wrong

# Citizen Root page

* Maybe should be called Citizens and Visitors?
* Currently says Total Citizens, but I assume those are 'alive' and not dead ones.


# Citizen Template

* Now that we have functions, change the birth year to age
* Get the actual arrival date per citizen (especially on initialization)
* Auto-journaling settings should include timeline and arrivals, new relationships, new skills (upon reaching master level), new medical requirements and history
* Military history (notable kills)


## Citizen Root page

* Age here (in the table) should just be a year, so that sorting on it works fine

    
# Artifacts

* The create date should also be a column
* All the fields from initialization should be pushed to Auto-journaling too (though I guess if we run the initialization code when the artifact is first created it's not much of a problem)
* Would need a field for if the location is known or not - It may have been traded in peace negotiations (or seige negotiations etc.) or just flat out stolen
    * Don't need/want the exact location, we want to know the 'status' (not sure if this is available in a vague 'lore' term in the engine) - I asked on the discord

# Enemies

* Settings tab and settings for enemies should be implemented
* They should have their notable kills

# Code issues and other possible irritations and issues



* We want a progressbar for the initialization process, and maybe during save (we must still determine the impact of the listener to the performance of the game, if it's heavy we should 'sync' changes when the wiki is opened or when the game is saved) - on a big fort we will want that progressbar anyway, because it can probably take 1 minute or so, as well as the HTML export (though maybe it can be 'asynchronous' - saving while you are continuing with the game)
* We need support for pages that go down multiple levels - Because Citizens, Artifacts, Events, Enemies, Visitors are all actually sub sections of the Fort. The way it should be implemented:
    * At the moment every 'root' level page has left space for the [+]/[-] part (this should remain)
    * The [+]/[-] parts should always be in the same place to make programming the mouse code easier (we should probably code keyboard shortcuts for navigating that part)
    * Every level 'below' the root must be indented by 1
    Example:
    [-] Forts
    [-]  Shellrelics
    [+]   Citizens
    [+]   Artifacts
    [+]   Events
    [+]   Enemies
    [+]   Visitors

* Wiki Wide search... (should be in the main ToC page)
* Inititializing needs an option to include dead dwarfs (should be off by default)

-- Basically do this only once we are pretty much happy with the AutoJournal
* Create the actual HTML export

    