# Ideas for further reporting (and settings) for each Template

This is just a list of ideas of things that might be of interest to users, and might make the world feel more alive.

# World

* Gods / Religions? Should maybe live in Civ
* Meta info:
    * Maybe show the last 'save' human date?




# Civilization Root Template

* BUG: Population I think is all time 'records' and not population that is alive

## Bugs

# Civilization Template 

* Diplomatic Relations
    * Add links to the other Civs
    * Eg: The Ferocious Fountains are at war with:
* Ruler
* Most Goblin Settlements are not all listed (at all) - Pits I think is the main ones not listed
* Elf Civs don't show all of their Retreats. (They seem to all be called Forest Retreats)

## Lower priority

* Major History (we should probably remove this - though it could be cool?)
    * When we get here, we should probably brainstorm on what it would mean


# Forts Root Page

# Fort Template

* The location string can have more colors (forested/biome type things could be green etc, rivers/lakes blue and volcano red)
* BUG: Building on mutliple rivers throws in WAY too many rivers. (Building on 1 river might also be broken at the moment - requires testing) 
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

## Bugs

# Citizen Root page

* Inititializing needs an option to include dead dwarfs (should be off by default)
* Needs an aggregate table (doesn't need to be an 'wiki table' - probably doesn't need to be) of Alive/Dead/Missing (stolen or body not found) citizens
* Dead citizens might need their own little table with memorialized / non memorialized, and maybe a death cause too, combat / Age


# Citizen Template

* Should include timeline and arrivals, new relationships, new skills (upon reaching master level), new medical requirements and history
* BUG: Notable kills are currently just all the NON notable kills
    * Notable kills get a history entry I think in the main game events. (in the game it's dated, and normal kills have places (notable kills should also have places where it happened))
* Feature improvement: The non notable kills in the game is currently split by gender (in the game and also sort of in the wiki, but we don't see it). IMO we should just group them. 4x goblins rather than currently 3x Goblin and a 1x Goblin entries at the moment. 

# Artifacts root page

* BUG: Year looks to be wrong on almost all of them in the table. 

# Artifacts template

* I asked on discord if there is a way to find the 'full item description' in dfhack, waiting on response
* BUG: Creation date is not displayed


# Events root page

* We need to fully explore events
    * Many events are not notable (most even)
    * The game's own settings has an 'announcement' page, and many of those would be the 'events' we are looking for, but also most of those would not be considered notable
* Events in general happen to 'the fort' or 'citizens'/'artifacts' etc. inside the fort

# Events template

* We might need templates for each type of notable events
* A dwarf that dies is an event. But 3 dwarf dying during a siege / raid etc. is 1 event. And IMO should be grouped 

# Enemies root page

# Enemies Template

# Visitors root Page

# Visitors Template

# Event Architecture (from 2026-07-10 planning session)

Note the numbers in this area (like 49 MIGRANT_ARRIVAL_NAMED is the event_type_id)

> **Restart required**: All changes below require DF restart due to `reqscript` module caching.

## Design Direction
- **Major events** (sieges, megabeasts, migrant waves, weddings, artifact creations, ghost attacks, war attacks on site) get first-class event pages with aggregated detail
- **Minor events** (master soldier, pet events, wounds, skill milestones) are timeline bullets only on entity pages

## Report Types to Implement

### Fort-level (add to REPORT_MAP):
- ~~49 MIGRANT_ARRIVAL_NAMED → population category → events/Population section~~
- ~~50 MIGRANT_ARRIVAL → population category → events/Population section~~
- ~~69 D_MIGRANTS_ARRIVAL → population category → events/Population section~~
- ~~83 BIRTH_CITIZEN → population category → events/Population + citizen:mother via speaker_id~~
- ~~95 BEAST_AMBUSH → threat category → events + enemies (existing threat routing)~~
- ~~139 GHOST_ATTACK → crisis category → events/Incidents & Crises~~

### Citizen-level (new journal toggles):
- ~~85 STRANGE_MOOD → achievement category → events/Achievements section~~
- ~~238 SOLDIER_BECOMES_MASTER → already in map, added citizen:speaker_id routing~~
- ~~248 PET_ADOPTED → social category → events/Social Events + citizen:owner via speaker_id~~
- ~~107 PET_DEATH → death category → events/Deaths + citizen:owner via speaker_id~~

### Still TODO (fort-level, needs event page design):
- Migrant wave event page with migrant table (currently routes to events/Population as timeline entry)

### Citizen-level (new journal toggles):

### Skip:
- 84 BIRTH_ANIMAL, 88 ITEM_ATTACHMENT, 
- 263 MANDATE_ENDS, 275 NEW_MANDATE, 268 CONSTRUCTION_SUSPENDED
- 292, 294, 295 (weather), 73, 74 (traps), 
- CANCEL_JOB (104), QUOTA_FILLED (270), VERMIN_BITE (249)
- All combat sub-types, adventure-mode events

### Skip for now, but consider/explore later

- 177 CONFLICT_CONVERSATION
- 323 (rumors)

## History Event Types to Add to Catch-Up

### IMPLEMENTED (2026-07-10):
- ~~Type 0 WAR_ATTACKED_SITE → Fort + civilization events~~
- ~~Type 2 CREATED_SITE → Civ settlements table + fort founding~~
- ~~Type 4 ADD_HF_ENTITY_LINK → Citizen page (entity joined civ historically)~~
- ~~Type 32 ADD_HF_SITE_LINK → Citizen page (visitors/historical figure links)~~
- ~~Type 46 WAR_FIELD_BATTLE → events page (battles at site)~~
- ~~Type 56 HIST_FIGURE_WOUNDED → Citizen page (wound history)~~
- ~~Type 84 CEREMONY → events/Social Events (ceremonies at fort)~~
- ~~Type 53 ITEM_STOLEN → events/Incidents & Crises (only if artifact)~~

### Need more exploration:
- Type 82 COMPETITION → What data does it carry? Worth adding?

### Skip:
- Type 30 CREATED_BUILDING, Type 81 PERFORMANCE
- Type 44 CHANGE_HF_STATE (3403 events, too numerous)
- Type 57 HIST_FIGURE_SIMPLE_BATTLE_EVENT (2036 events, too numerous)
- Type 45 CHANGE_HF_JOB (2860 events, too noisy)

## Siege Aggregation — NEEDS EXPLORATION
Find a save with a recent/current siege and explore:
1. How does the game track siege start vs. individual combat events?
2. Is there an "end of siege" trigger we can hook into?
3. Can we count casualties by faction during a siege?
4. Can we list individual participants?
5. What data does the invasion object (`df.global.world.invasions`) expose per-invasion?

## Migrant Wave Design (TODO)
Event page: "Migrant Wave of Year YYYY/Season"
- Table of migrants with name links to citizen pages
- Total count, notable skills
- Fort timeline entry: "Migrant wave of Year 100, Spring: 15 dwarfs arrived"

## Initialization
- ~~event_parser.lua missing --@ module = true _ENV export (had `return EventParser` instead of `_ENV`). All parser functions silently nil via reqscript.~~
- ~~Event listener now starts during initialization as its own progress step (between Historical catch-up and Finalizing)~~

## Settings Toggles to Consider
Current 12 event toggles might need:
- birth_events (separate from general birth_migrant)
- beast_ambush (separate from threat_events)
- ghost_events (new toggle for ghost attacks)

# Code issues and other possible irritations and issues

* ~~The UI should remember where you were last time you opened the wiki and reopen on that page~~
    * This feature is implemented but the main ToC isn't 'expanded' to the level where the current page is if the last page was a lower level page
* Searching the cursor doesn't 'move on' when typing a search. (minor)

-- Basically do this only once we are pretty much happy with the AutoJournal
* Create the actual HTML export

    