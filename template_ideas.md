# Ideas for further reporting (and settings) for each Template

This is just a list of ideas of things that might be of interest to users, and might make the world feel more alive.

# Civilisation

* If possible describe where the civilisation finds itself on the world map. It might be a bit difficult if the civ is 'all over' but then the discription should be 'all over' the world. 

# Fort

* Add the continent and the general area's name to the fort template. * Maybe put the fort's position on the world map in terms of compass directions as well:
    * Fort XXX is located in the west of the world (maybe give world name). Or Central
    * Maybe describe the general temperature? Does it snow or not?

## Bugs
    * Fort 'founding' is linked to when it gets journaled/initialized and not the actual founding date. 


# Citizen

* Don't do age, because it changes the whole time, and we don't want to update values the whole time
    * Maybe add a "Birth Year" field instead, which is static and doesn't change over time?
* Get the actual arrival date per citizen (especially on initialization)
* Auto-journaling settings should include timeline and arrivals, new relationships, new skills (upon reaching master level), new medical requirements and history

    
# Artifacts

* The create date should also be a column
* All the fields from initialization should be pushed to Auto-journaling too (though I guess if we run the initialization code when the artifact is first created it's not much of a problem)

# Code issues

* The overlay button should be connected to the status on the maingui (the AutoJournal_on.png should be displayed with autojournaling is on, and similarly the 'off' one should be displayed when it's set off)
    * It seems the settings are not saving
    * It seems the 'auto journal' toggle label is also not saving and retrieving the settings as saved (this is saving in 'memory' nevermind saving through a file)
* The table seems to have some issues when it's constrained (meaning the window width is less than the total widths required to display it well)
    * The symptom is that the Name column gets cut off a lot before the Birth Year column starts 
    * I can't copy and paste tables (even the display parts)
    * Editing a table removes the links (understandably tricky)
* HyperTextArea might need to support 'functions' to do age, and 'current needs' etc. Something  that will 'auto' update when the citizen's needs are met etc.


