# Ideas for further reporting (and settings) for each Template

This is just a list of ideas of things that might be of interest to users, and might make the world feel more alive.

# Civilisation

* If possible describe where the civilisation finds itself on the world map. It might be a bit difficult if the civ is 'all over' but then the discription should be 'all over' the world.
* Civ should have a table of forts, with a field if it has ever been a player fort. The default sort should put that at the top. And the fort names that was player owned must have Links to the relevant pages 

# Fort(s)

* We should enable having multiple forts in the 'wiki' as the save will 'keep' the old wiki as the user changes forts.
    * The impacts of multiple forts:
        * Citizen should (optionally) show which fort is his residence
        * Civilisation page should include a list of player forts (clickable links?)
        * The forts page should also be a 'root' page, and the current fort should be a child.
* Add the continent and the general area's name to the fort template. 
    * Maybe put the fort's position on the world map in terms of compass directions as well:
    * Fort XXX is located in the west of the world (maybe give world name). Or Central
    * Maybe describe the general temperature? Does it snow or not?
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

* The table seems to have some issues when it's constrained (meaning the window width is less than the total widths required to display it well)
    * The symptom is that the Name column gets cut off a lot before the Birth Year column starts 
* I can't copy and paste tables (even the display parts)
* Editing a table removes the links (understandably tricky)
* FEATURE: HyperTextArea tables should have a field at the top that searches. (it should match all fields in the table)
    * Essentially it should search the whole 'row' of a table (could be a concatenated string) and if it hits any of the fields it's included
    * For all tables longer than 10 entries (total entries not 'just' displayed entries), it should have the word: "SEARCH:" at the top and when you select the table the cursor should move there. Blank shows all
    * The user should be able to disable / remove the search bar in the edit table UI, but by default all tables should have it
    * Don't link it to a hotkey, it must be dependent on where the cursor is. (in the table or 'outside it') 
* The function Modal popup has a weird behaviour (sometimes) when you select a function with the mouse where the 'statusbar' (bottom of the UI 'Enter: Insert | Escape : Cancel') gets hidden
* Create the actual HTML export



    