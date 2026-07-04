# Ideas for further reporting (and settings) for each Template

This is just a list of ideas of things that might be of interest to users, and might make the world feel more alive.

# World

## Bugs 
* List of inhabited landmasses doesn't show
* Era doesn't show

# Civilisation

# Fort(s)

* Add the continent and the general area's name to the fort template. 
    * Maybe put the fort's position on the world map in terms of compass directions as well:
    * Fort XXX is located in the west of the world (maybe give world name). Or Central
    * Maybe describe the general temperature? Does it snow or not?
* Fort should maybe be the default 'homepage' for the player, meaning all important-ish things gets logged here.
    * Artifacts that get generated here
    * Immigrations
    * Emmigrations (when a dwarf gets 'expelled')
    * Deaths
    * 'Visitors' like monster slayers / entertainers etc.
    * Sieges
    * Maybe even the whole events / enemies should maybe be 'sub-sections' of Fort - thinking about a 'multi-fort' save game. Events at Fort 1 should not be part of Fort 2's events.

## Bugs

* Fort 'founding' is linked to when it gets journaled/initialized and not the actual founding date. 


# Citizen

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


* I can't copy and paste tables (even the display parts)
* Table editor should be able to insert both links and functions into them (I think it already supports it programatically, but not the editor)
* FEATURE: HyperTextArea tables should have a field at the top that searches. (it should match all fields in the table)
    * Essentially it should search the whole 'row' of a table (could be a concatenated string) and if it hits any of the fields it's included
    * For all tables longer than 10 entries (total entries not 'just' displayed entries), it should have the word: "SEARCH:" at the top and when you select the table the cursor should move there. Blank shows all
    * The user should be able to disable / remove the search bar in the edit table UI, but by default all tables should have it
    * Don't link it to a hotkey, it must be dependent on where the cursor is. (in the table or 'outside it') 
* Create the actual HTML export
* Function editor probably needs to be resizable, and default a bit wider. We may want to add an actual 'line' to indicate the end of the function list vs the 'information bar' 
* We probably want a progressbar for the initialization process, and maybe during save (we must still determine the impact of the listener to the performance of the game, if it's heavy we should 'sync' changes when the wiki is opened or when the game is saved) - on a big fort we will want that progressbar anyway, because it can probably take 1 minute or so.



    