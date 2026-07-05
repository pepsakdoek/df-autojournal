--@ module = true
local logger = reqscript('internal/df-autojournal/logger')
local utils = reqscript('internal/df-autojournal/wiki_utils')
local event_parser = reqscript('internal/df-autojournal/event_parser')
local event_listener = reqscript('internal/df-autojournal/event_listener')
local wiki_settings = reqscript('internal/df-autojournal/wiki_settings')

-- Templates
local citizen_template = reqscript('internal/df-autojournal/templates/citizen')
local artifact_template = reqscript('internal/df-autojournal/templates/artifact')
local fort_template = reqscript('internal/df-autojournal/templates/fort')
local civ_template = reqscript('internal/df-autojournal/templates/civilization')
local event_template = reqscript('internal/df-autojournal/templates/event')
local timeline_template = reqscript('internal/df-autojournal/templates/timeline')
local enemies_template = reqscript('internal/df-autojournal/templates/enemies')
local visitors_template = reqscript('internal/df-autojournal/templates/visitors')
local world_template = reqscript('internal/df-autojournal/templates/world')
local civilizations_template = reqscript('internal/df-autojournal/templates/civilizations')
local forts_index_template = reqscript('internal/df-autojournal/templates/forts')

local KNOWN_CIVS_KEY = 'mfw_known_civs'
local KNOWN_FORTS_KEY = 'mfw_known_forts'

local function safe_save(context, page_id, content, cursor)
    local ok, err = pcall(context.save_content, context, page_id, content, cursor)
    if not ok then
        logger.log_error("Failed to save page '" .. tostring(page_id) .. "': " .. tostring(err))
    else
        -- logger.log("Saved page '" .. tostring(page_id) .. "' (" .. tostring(#content) .. " spans)")
    end
end

local function load_known_civs()
    local civs = {}
    pcall(function()
        local raw = dfhack.persistent.getSiteData(KNOWN_CIVS_KEY)
        if raw and raw.civs then civs = raw.civs end
    end)
    return civs
end

local function save_known_civs(civs)
    pcall(dfhack.persistent.saveSiteData, KNOWN_CIVS_KEY, {civs=civs})
end

local function load_known_forts()
    local forts = {}
    pcall(function()
        local raw = dfhack.persistent.getSiteData(KNOWN_FORTS_KEY)
        if raw and raw.forts then forts = raw.forts end
    end)
    return forts
end

local function save_known_forts(forts)
    pcall(dfhack.persistent.saveSiteData, KNOWN_FORTS_KEY, {forts=forts})
end

WikiInitializer = defclass(WikiInitializer)

function WikiInitializer:init(args)
    self.context = args.context
    self.on_complete = args.on_complete
end

function WikiInitializer:perform(screen)
    local ok, err = xpcall(function()
        logger.log("Starting Wiki initialization...")

        local site_id = utils.get_site_id()
        logger.log("Current Site ID: " .. tostring(site_id))
        if not site_id or site_id == -1 then
            logger.log_error("No valid site ID found. Initialization aborted.")
            return false
        end

        local civ_id = utils.get_civ_id()
        local settings = wiki_settings.get_settings()
        local tracking_mode = settings.civ and settings.civ.init and settings.civ.init.tracking or 'diplomatic'

        logger.log("=== Initialization step 0: tracking civs (tracking_mode=" .. tostring(tracking_mode) .. ") ===")
        -- 0. Track known civilizations
        local known_civs = load_known_civs()
        logger.log("Loaded " .. #known_civs .. " known civs from storage")
        local known_map = {}
        for _, c in ipairs(known_civs) do
            known_map[c.civ_id] = true
            c._first_year_known = c.first_year
        end

        local current_civ = df.historical_entity.find(civ_id)

        -- Add current player civ
        if current_civ and not known_map[civ_id] then
            local name = utils.get_readable_name(current_civ.name)
            table.insert(known_civs, {civ_id=civ_id, name=name, first_year=df.global.cur_year})
            known_map[civ_id] = true
            logger.log("Tracking new civ: " .. name)
        end

        -- Add diplomatic relations civs
        pcall(function()
            if tracking_mode ~= 'player' and current_civ then
                local relations = current_civ.relations
                if not relations then return end
                for _, rel in ipairs(relations) do
                    local other_id = rel.entity_id
                    if other_id ~= -1 and not known_map[other_id] then
                        local other = df.historical_entity.find(other_id)
                        if other and other.type == df.historical_entity_type.Civilization then
                            local name = utils.get_readable_name(other.name)
                            table.insert(known_civs, {civ_id=other_id, name=name, first_year=nil})
                            known_map[other_id] = true
                            logger.log("Tracking diplomatic civ: " .. name)
                        end
                    end
                end
            end
        end)

        logger.log("After tracking, known civs = " .. #known_civs)

        -- Add all major civs (scan entity_links on all sites)
        if tracking_mode == 'all_major' then
            local world_data = df.global.world.world_data
            if world_data and world_data.sites then
                for _, site in ipairs(world_data.sites) do
                    if site.entity_links then
                        for _, link in ipairs(site.entity_links) do
                            local eid = link.entity_id
                            if eid ~= -1 and not known_map[eid] then
                                local entity = df.historical_entity.find(eid)
                                if entity and entity.type == df.historical_entity_type.Civilization then
                                    local name = utils.get_readable_name(entity.name)
                                    table.insert(known_civs, {civ_id=eid, name=name, first_year=nil})
                                    known_map[eid] = true
                                    logger.log("Tracking major civ: " .. name)
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Enrich known civs with race and settlement count
        local wd_sites = nil
        if df.global.world.world_data then
            wd_sites = df.global.world.world_data.sites
        end
        for _, c in ipairs(known_civs) do
            c.site_count = 0
            local entity = df.historical_entity.find(c.civ_id)
            if entity then
                pcall(function()
                    local race_raw = df.creature_raw.find(entity.race)
                    c.race = race_raw and utils.sanitize(race_raw.name[0]) or "Unknown"
                end)
            end
            if not c.race then c.race = "Unknown" end
        end

        -- Count sites per civ
        if wd_sites then
            for _, site in ipairs(wd_sites) do
                if site.entity_links then
                    for _, link in ipairs(site.entity_links) do
                        for _, c in ipairs(known_civs) do
                            if c.civ_id == link.entity_id then
                                c.site_count = (c.site_count or 0) + 1
                                break
                            end
                        end
                    end
                end
            end
        end

        logger.log("Final known civs: " .. #known_civs)
        for _, c in ipairs(known_civs) do
            logger.log("  - " .. tostring(c.name) .. " (id=" .. tostring(c.civ_id) .. ")")
        end
        save_known_civs(known_civs)

        -- 0b. Track known forts
        local known_forts = load_known_forts()
        local fort_map = {}
        for _, f in ipairs(known_forts) do
            fort_map[f.site_id] = true
        end

        local current_site = dfhack.world.getCurrentSite()
        if not fort_map[site_id] then
            local site_name = current_site and utils.get_readable_name(current_site.name) or "Unknown Fort"
            local civ_name = current_civ and utils.get_readable_name(current_civ.name) or "Unknown"
            table.insert(known_forts, {site_id=site_id, name=site_name, civ_id=civ_id, civ_name=civ_name, first_year=df.global.cur_year})
            fort_map[site_id] = true
            logger.log("Tracking new fort: " .. site_name)
        end
        save_known_forts(known_forts)

        -- 0c. Dynamic pages for civs and forts
        local dynamic_pages = {}

        -- Build known fort set for linking in civ pages
        local known_fort_set = {}
        for _, f in ipairs(known_forts) do known_fort_set[f.site_id] = true end

        -- Render civ sub-pages
        for _, c in ipairs(known_civs) do
            local page_id = "civ:" .. tostring(c.civ_id)
            table.insert(dynamic_pages, {text=c.name, id=page_id})
            local content = civ_template.render(c.civ_id, known_fort_set)
            safe_save(self.context, page_id, utils.sanitize_content(content), 1)
        end

        -- Render fort sub-pages
        for _, f in ipairs(known_forts) do
            local page_id = "fort:" .. tostring(f.site_id)
            table.insert(dynamic_pages, {text=f.name, id=page_id})
            local content = fort_template.render(f.site_id)
            safe_save(self.context, page_id, utils.sanitize_content(content), 1)
        end

        -- 0d. Render Civilizations index (before world, so it's saved even if world fails)
        local civ_index_content = civilizations_template.render(known_civs, civ_id)
        safe_save(self.context, 'civilizations', utils.sanitize_content(civ_index_content), 1)

        -- 0e. Render Forts index
        local forts_index_content = forts_index_template.render(known_forts, site_id)
        safe_save(self.context, 'forts', utils.sanitize_content(forts_index_content), 1)

        -- 0f. Render World page via template
        logger.log("=== Initialization step 0f: World page ===")
        local world_name = "World"
        local world_eras = {}
        local world_landmasses = {}
        local world_season = ""
        pcall(function()
            local names = {"Early Spring", "Late Spring", "Early Summer", "Late Summer", "Early Autumn", "Late Autumn", "Early Winter", "Late Winter"}
            if df.global.cur_year_tick then
                local idx = math.floor(df.global.cur_year_tick / 16800) + 1
                if idx >= 1 and idx <= #names then world_season = names[idx] end
            end
        end)

        pcall(function()
            local wd = df.global.world.world_data
            if not wd then return end

            local ok_n, name_n = pcall(utils.get_readable_name, wd.name)
            if ok_n and name_n and name_n ~= "" then world_name = name_n end

            -- Eras
            if wd.eras then
                for _, era_elem in ipairs(wd.eras) do
                    local ok_en, era_name = pcall(utils.get_readable_name, era_elem.name)
                    if ok_en and era_name then
                        table.insert(world_eras, { year = era_elem.first_year, name = era_name, is_current = false })
                    end
                end
                table.sort(world_eras, function(a, b) return (a.year or 0) < (b.year or 0) end)
                if #world_eras > 0 then
                    local cur = df.global.cur_year
                    local cur_name = world_eras[1].name
                    for _, e in ipairs(world_eras) do
                        if e.year <= cur then cur_name = e.name end
                    end
                    for _, e in ipairs(world_eras) do
                        if e.name == cur_name then e.is_current = true; break end
                    end
                end
            end

            -- Landmasses
            if wd.landmasses then
                for _, lm in ipairs(wd.landmasses) do
                    local ok_ln, lm_name = pcall(utils.get_readable_name, lm.name)
                    if not ok_ln or not lm_name then lm_name = "Unknown" end
                    local known = {}
                    local unknown_count = 0

                    for _, site in ipairs(wd.sites) do
                        if site.pos and site.pos.x >= lm.min_x and site.pos.x <= lm.max_x
                            and site.pos.y >= lm.min_y and site.pos.y <= lm.max_y then
                            if site.entity_links then
                                for _, link in ipairs(site.entity_links) do
                                    local entity = df.historical_entity.find(link.entity_id)
                                    if entity and entity.type == df.historical_entity_type.Civilization then
                                        local eid = entity.id
                                        if known_map[eid] then
                                            local already = false
                                            for _, kc in ipairs(known) do
                                                if kc.civ_id == eid then already = true; kc.site_count = (kc.site_count or 0) + 1; break end
                                            end
                                            if not already then
                                                local ename = utils.get_readable_name(entity.name)
                                                table.insert(known, {civ_id=eid, name=ename, site_count=1, link="civ:" .. tostring(eid)})
                                            end
                                        else
                                            unknown_count = unknown_count + 1
                                        end
                                        break
                                    end
                                end
                            end
                        end
                    end

                    if #known > 0 or unknown_count > 0 then
                        table.insert(world_landmasses, { name = lm_name, known_civs = known, unknown_count = unknown_count, site_count = #known + unknown_count })
                    end
                end
                table.sort(world_landmasses, function(a, b) return #b.known_civs < #a.known_civs end)
            end
        end)

        local world_content = world_template.render({
            world_name = world_name,
            current_year = df.global.cur_year,
            current_season = world_season or "",
            eras = world_eras,
            landmasses = world_landmasses,
        })

        if not world_content or #world_content == 0 then
            world_content = { { text = "# " .. world_name, pen = COLOR_YELLOW }, "\n\n", { text = "Current Date: ", pen = COLOR_LIGHTCYAN }, { text = "Year " .. tostring(df.global.cur_year or 0), pen = COLOR_WHITE }, "\n" }
        end

        logger.log("Saving World page (" .. #world_content .. " spans)")
        local w_ok, w_err = pcall(dfhack.persistent.saveSiteData, 'mfw_p_world', {content=world_content, cursor={1}})
        if not w_ok then
            logger.log_error("Direct world save failed: " .. tostring(w_err))
        else
            logger.log("Direct world save succeeded")
        end

        -- 1. Citizens
        local citizens = {}
        logger.log("Fetching units...")

        local units = {}
        pcall(function() units = df.global.world.units.active or {} end)
        if #units == 0 then
            logger.log("No active units found, skipping citizens")
        else
        logger.log("Found " .. #units .. " total active units.")

        local citizen_rows = {}
        for i = 0, #units - 1 do
            local unit = units[i]
            if dfhack.units.isCitizen(unit) then
                local raw_name = dfhack.units.getReadableName(unit)
                local name = utils.sanitize(raw_name)
                local id = 'citizen:' .. tostring(unit.id)

                -- logger.log("Processing citizen: " .. name .. " (ID: " .. unit.id .. ")")
                table.insert(citizens, {name=name, id=id})
                table.insert(dynamic_pages, {text=name, id=id})

                local content = citizen_template.render(unit)
                safe_save(self.context, id, utils.sanitize_content(content), 1)

                local birth_year = tostring(unit.birth_year)

                local happiness = "Unknown"
                if unit and unit.status.current_soul and unit.status.current_soul.personality then
                    local stress = unit.status.current_soul.personality.stress
                    if stress < -50000 then happiness = "Euphoric"
                    elseif stress < -25000 then happiness = "Very Happy"
                    elseif stress < -10000 then happiness = "Happy"
                    elseif stress < 10000 then happiness = "Content"
                    elseif stress < 25000 then happiness = "Unhappy"
                    elseif stress < 50000 then happiness = "Very Unhappy"
                    else happiness = "Miserable"
                    end
                end

                local profession = utils.sanitize(dfhack.units.getProfessionName(unit))

                local dead = dfhack.units.isDead(unit)
                local death_status = dead and "Deceased" or "Alive"

                table.insert(citizen_rows, {
                    { text = name, pen = COLOR_LIGHTBLUE, link = id },
                    { text = birth_year, pen = COLOR_WHITE },
                    { text = happiness },
                    { text = death_status, pen = dead and COLOR_LIGHTRED or COLOR_LIGHTGREEN },
                })
            end
        end
        logger.log("Processed " .. #citizens .. " citizens.")

        local citizen_root = {}
        table.insert(citizen_root, { text = "# Citizens", pen = COLOR_YELLOW })
        table.insert(citizen_root, "\n\n")
        table.insert(citizen_root, { text = "Total Citizens: ", pen = COLOR_LIGHTCYAN })
        table.insert(citizen_root, { text = tostring(#citizens), pen = COLOR_WHITE })
        table.insert(citizen_root, "\n\n")
        table.insert(citizen_root, {
            type = 'table',
            columns = {
                { header = 'Name', align = 'left', min_width = 15, max_width = 50, stretch = true },
                { header = 'Birth Year', align = 'right', min_width = 6, stretch = false },
                { header = 'Happiness', align = 'left', min_width = 10, stretch = false },
                { header = 'Death Status', align = 'left', min_width = 8, stretch = false },
            },
            rows = citizen_rows
        })
        safe_save(self.context, 'citizens', utils.sanitize_content(citizen_root), 1)
        end

        -- 2. Artifacts
        logger.log("Processing artifacts...")
        local artifacts = {}
        local artifact_rows = {}

        local artifact_records = {}
        pcall(function() artifact_records = df.global.world.artifacts.all or {} end)
        logger.log("Total artifact records in world: " .. #artifact_records)

        for i = 0, #artifact_records - 1 do
            local art_record = artifact_records[i]
            local item = nil
            local ok_item
            ok_item, item = pcall(function()
                if art_record.item then
                    return art_record.item
                elseif art_record.item_id then
                    return df.item.find(art_record.item_id)
                end
                return nil
            end)
            if not ok_item or not item then
                goto continue_artifact
            end
            local pos = dfhack.items.getPosition(item)
            if pos then
                local name = utils.sanitize(dfhack.items.getReadableDescription(item))
                local id = 'artifact:' .. tostring(art_record.id)
                logger.log("Found artifact on site: " .. name .. " (ID: " .. art_record.id .. ")")
                table.insert(artifacts, {name=name, id=id})
                dynamic_pages[#dynamic_pages + 1] = {text=name, id=id}

                local content = artifact_template.render(item)
                safe_save(self.context, id, utils.sanitize_content(content), 1)

                local itype = item:getType()
                local type_name = tostring(df.item_type[itype]):gsub("_", " "):lower():gsub("^%l", string.upper)
                local value = dfhack.items.getValue(item)

                local creator_cell = { text = "Unknown", pen = COLOR_DARKGREY }
                local art_ref = dfhack.items.getGeneralRef(item, df.general_ref_type.ARTIFACT)
                local artifact_record = nil
                if art_ref then
                    artifact_record = df.artifact_record.find(art_ref.artifact_id)
                end
                if artifact_record then
                    local creator_ref = dfhack.items.getGeneralRef(item, df.general_ref_type.UNIT_CREATOR)
                    if creator_ref then
                        local unit = df.unit.find(creator_ref.unit_id)
                        if unit then
                            local unit_name = utils.sanitize(dfhack.units.getReadableName(unit))
                            creator_cell = { text = unit_name, pen = COLOR_LIGHTBLUE, link = "citizen:" .. tostring(unit.id) }
                        end
                    end
                end

                table.insert(artifact_rows, {
                    { text = name, pen = COLOR_LIGHTBLUE, link = id },
                    creator_cell,
                    { text = type_name },
                    { text = tostring(value), pen = COLOR_LIGHTGREEN },
                })
            end
            ::continue_artifact::
        end
        logger.log("Processed " .. #artifacts .. " artifacts on site.")

        local artifact_root = {}
        table.insert(artifact_root, { text = "# Artifacts", pen = COLOR_YELLOW })
        table.insert(artifact_root, "\n\n")
        table.insert(artifact_root, { text = "Total Artifacts: ", pen = COLOR_LIGHTCYAN })
        table.insert(artifact_root, { text = tostring(#artifacts), pen = COLOR_WHITE })
        table.insert(artifact_root, "\n\n")
        table.insert(artifact_root, {
            type = 'table',
            columns = {
                { header = 'Name', align = 'left', min_width = 20 },
                { header = 'Creator', align = 'left', min_width = 15 },
                { header = 'Type', align = 'left', min_width = 10 },
                { header = 'Value', align = 'right', min_width = 8 },
            },
            rows = artifact_rows,
            max_rows = 50,
        })
        safe_save(self.context, 'artifacts', utils.sanitize_content(artifact_root), 1)

        -- Save the dynamic page list
        logger.log("Saving " .. #dynamic_pages .. " dynamic pages...")
        self.context:save_dynamic_pages(dynamic_pages)

        -- 3. Events page
        pcall(function()
            local events_root = {}
            table.insert(events_root, { text = "# Events", pen = COLOR_YELLOW })
            table.insert(events_root, "\n\n")
            table.insert(events_root, { text = "Loading events...", pen = COLOR_DARKGREY })
            table.insert(events_root, "\n")
            safe_save(self.context, 'events', utils.sanitize_content(events_root), 1)
        end)

        -- 4. Historical catch-up
        pcall(function() self:catchUpEvents(site_id) end)

        -- 5. Render timeline
        pcall(function() self:renderEventsTimeline() end)

        -- 6. Render Enemies page
        pcall(function() self:renderEnemiesPage() end)

        -- 7. Render Visitors page
        pcall(function() self:renderVisitorsPage() end)

        -- Set initialized flag
        logger.log("Setting mfw_initialized flag")
        dfhack.persistent.saveSiteData(self.context.save_prefix .. 'initialized', {val={1}})
        local verify = dfhack.persistent.getSiteData(self.context.save_prefix .. 'initialized')
        logger.log("Verified mfw_initialized: " .. tostring(verify))

        if self.on_complete then
            logger.log("Calling on_complete")
            self.on_complete()
        end

        dfhack.gui.showAnnouncement("Wiki initialized successfully!", COLOR_LIGHTGREEN)
        logger.log("Wiki initialization complete.")
        return true
    end, function(err)
        return debug.traceback(err)
    end)

    if not ok then
        logger.log_error("Initialization failed: " .. tostring(err))
    end

    return ok
end

---------------------------------------------------------------------------
--- Historical event catch-up: scan all past events for this site.
--- Runs during initialization, after citizen/artifact pages are built.
--- Batches in chunks of 500 with progress logging, persists a marker
--- so subsequent inits only catch up from where we left off.
---------------------------------------------------------------------------

function WikiInitializer:catchUpEvents(site_id)
    local events = df.global.world.history.events
    if not events or #events == 0 then
        logger.log("Catch-up: no history events to scan.")
        return
    end

    local current_max = #events
    local catchup_key = self.context.save_prefix .. 'catchup_last_id'

    -- Read last caught-up event ID
    local last_done = 0
    local ok_load, data = pcall(function()
        return dfhack.persistent.getSiteData(catchup_key)
    end)
    if ok_load and data and data.val then
        last_done = data.val
    end

    if last_done >= current_max then
        logger.log("Catch-up: already up to date (last=" .. last_done .. ", max=" .. current_max .. ")")
        return
    end

    logger.log("Catch-up: scanning events " .. last_done .. " to " .. current_max)

    local batch_size = 500
    local total_scanned = 0
    local total_matched = 0
    local max_index = #events - 1

    for i = 0, max_index do
        local ev = events[i]
        if not ev then goto continue end

        local ev_id = ev.id
        if ev_id < last_done then goto continue end
        if ev_id >= current_max then break end

        total_scanned = total_scanned + 1

        -- Filter by site
        local ev_site = -1
        pcall(function()
            if ev.getSite then ev_site = ev:getSite() end
        end)

        if ev_site == site_id then
            local parsed = event_parser.parse(ev)
            if parsed and parsed.page_id then
                local entry_text = "* " .. parsed.text .. "\n"
                event_listener.append_to_page(parsed.page_id, parsed.section, entry_text)
                total_matched = total_matched + 1

                -- Register in timeline registry
                local pseudo = {
                    year = ev.year or df.global.cur_year,
                    season = "",
                    category = "general",
                    event_type = tostring(ev:getType()),
                    summary = parsed.text,
                    targets = {},
                }
                event_listener.register_timeline_entry(pseudo)

                -- Register threat events in enemy registry
                local etype = ev:getType()
                if etype == df.history_event_type.HIST_FIGURE_ATTACK
                    or etype == df.history_event_type.HIST_FIGURE_SITE_CONFLICT
                    or etype == df.history_event_type.HIST_FIGURE_ABDUCTED
                    or etype == df.history_event_type.CREATURE_DEVOURED then
                    local enemy_name = "Unknown Threat"
                    pcall(function()
                        local type_str = tostring(etype):gsub("HIST_FIGURE_", ""):gsub("_", " "):lower()
                        enemy_name = parsed.text:match("attacked (.+) in year")
                            or parsed.text:match("Abducted (.+) in year")
                            or parsed.text:match("Devoured (.+) in year")
                            or "Historical " .. type_str
                    end)
                    event_listener.register_enemy_encounter(
                        enemy_name,
                        "Historical Threat",
                        ev.year or df.global.cur_year,
                        false
                    )
                end
            end
        end

        -- Save progress every batch
        if total_scanned % batch_size == 0 then
            pcall(dfhack.persistent.saveSiteData, catchup_key, {val=ev_id})
            -- logger.log("Catch-up: scanned " .. total_scanned .. ", matched " .. total_matched)
        end

        ::continue::
    end

    -- Save final marker
    pcall(dfhack.persistent.saveSiteData, catchup_key, {val=current_max})
    logger.log("Catch-up complete: scanned " .. total_scanned .. " events, matched " .. total_matched)
end

---------------------------------------------------------------------------
--- Render timeline table + category counts on the Events page.
--- Called after catch-up completes so the registry has entries.
---------------------------------------------------------------------------

function WikiInitializer:renderEventsTimeline()
    -- Load timeline registry
    local entries = {}
    local ok_load = pcall(function()
        local data = dfhack.persistent.getSiteData('mfw_event_timeline')
        if data and data.entries then
            entries = data.entries
        end
    end)
    if not ok_load then
        logger.log("renderTimeline: no timeline data found")
        return
    end

    -- Build category counts
    local categories = {}
    local cat_count = 0
    for _, e in ipairs(entries) do
        local cat = e.category or "general"
        if not categories[cat] then
            categories[cat] = 0
            cat_count = cat_count + 1
        end
        categories[cat] = categories[cat] + 1
    end

    -- Render timeline content
    local timeline_content = {}
    for _, item in ipairs(timeline_template.render_counts(categories)) do
        table.insert(timeline_content, item)
    end
    for _, item in ipairs(timeline_template.render_timeline(entries)) do
        table.insert(timeline_content, item)
    end

    -- Load existing Events page content
    local page_data = self.context:load_content('events')
    local existing = page_data.content or {}
    if type(existing) == 'string' then
        existing = {{text=existing, pen=COLOR_LIGHTCYAN}}
    end

    -- Merge: keep existing content (category sections from catch-up),
    -- but insert timeline content after the # Events header
    local merged = {}
    local header_done = false
    for _, item in ipairs(existing) do
        table.insert(merged, item)
        if not header_done then
            local text = type(item) == 'table' and item.text or tostring(item)
            if text and text:match("^# Events") then
                -- Insert timeline section after the header
                table.insert(merged, "\n")
                for _, t_item in ipairs(timeline_content) do
                    table.insert(merged, t_item)
                end
                table.insert(merged, "\n")
                table.insert(merged, { text = "## Event Log", pen = COLOR_YELLOW })
                table.insert(merged, "\n")
                header_done = true
            end
        end
    end

    safe_save(self.context, 'events', utils.sanitize_content(merged), 1)
    logger.log("Events timeline rendered with " .. #entries .. " entries across " .. cat_count .. " categories")
end

---------------------------------------------------------------------------
--- Render the Enemies page from the enemy registry.
--- Called after catch-up completes so the registry has entries.
---------------------------------------------------------------------------

function WikiInitializer:renderEnemiesPage()
    if not event_listener.load_enemies then
        logger.log_error("event_listener.load_enemies not available, skipping enemies page")
        return
    end
    local enemies = event_listener.load_enemies()
    local settings = wiki_settings.get_settings().enemies or { init={registry=true, stats=true}, journal={encounter_log=true, kill_list=true, notable_victories=true} }
    local kills = event_listener.load_enemy_kills and event_listener.load_enemy_kills() or {}
    local content = enemies_template.render(enemies, settings, kills)
    safe_save(self.context, 'enemies', utils.sanitize_content(content), 1)
    logger.log("Enemies page rendered with " .. #enemies .. " entries")
end

function WikiInitializer:renderVisitorsPage()
    -- Scan visible non-citizen units for visitors currently on the map
    local visitors = {}
    local seen = {}

    pcall(function()
        local units = df.global.world.units.active or {}
        for i = 0, #units - 1 do
            local unit = units[i]
            if unit and dfhack.units.isAlive(unit) and not dfhack.units.isCitizen(unit)
                and not dfhack.units.isInvader(unit) and not dfhack.units.isAnimal(unit) then
                -- Only include units that the game considers visitors/merchants/diplomats
                local is_known_visitor = false
                pcall(function() is_known_visitor = dfhack.units.isVisitor(unit) or dfhack.units.isMerchant(unit) or dfhack.units.isDiplomat(unit) end)
                if not is_known_visitor then goto continue end

                local name = utils.sanitize(dfhack.units.getReadableName(unit))
                if name and name ~= "" then
                    local key = name:lower():gsub("[^%w]", "_")
                    if not seen[key] then
                        seen[key] = true

                        local visitor_type = "petitioner"
                        pcall(function()
                            local prof = dfhack.units.getProfessionName(unit) or ""
                            local pl = prof:lower()
                            if dfhack.units.isMerchant(unit) then
                                visitor_type = "trader"
                            elseif dfhack.units.isDiplomat(unit) then
                                visitor_type = "diplomat"
                            elseif pl:match("bard") or pl:match("poet") or pl:match("dancer") or pl:match("musician") or pl:match("performer") or pl:match("storyteller") or pl:match("entertain") then
                                visitor_type = "entertainer"
                            elseif pl:match("scholar") or pl:match("researcher") or pl:match("student") or pl:match("scientist") then
                                visitor_type = "scholar"
                            elseif pl:match("slayer") or pl:match("hunter") or pl:match("monster") then
                                visitor_type = "monster_slayer"
                            elseif pl:match("mercenary") or pl:match("soldier") or pl:match("sword") or pl:match("spear") or pl:match("crossbow") or pl:match("axe") then
                                visitor_type = "mercenary"
                            end
                        end)

                        table.insert(visitors, {
                            name = name,
                            visitor_type = visitor_type,
                            first_year = df.global.cur_year,
                            first_season = "",
                            last_year = df.global.cur_year,
                            last_season = "",
                            encounters = 1,
                            departed = false,
                            notes = "",
                        })
                    end
                end
                ::continue::
        end
    end)

    -- Merge with existing registry from persistent storage
    local existing = {}
    if event_listener.load_visitors then
        existing = event_listener.load_visitors()
    end
    for _, v in ipairs(existing) do
        local key = (v.name or ""):lower():gsub("[^%w]", "_")
        if not seen[key] then
            seen[key] = true
            table.insert(visitors, v)
        end
    end

    -- Save merged registry
    pcall(function()
        local save_data = {}
        for _, v in ipairs(visitors) do
            local key = (v.name or ""):lower():gsub("[^%w]", "_")
            save_data[key] = v
        end
        dfhack.persistent.saveSiteData('mfw_visitors', {visitors=save_data})
    end)

    local settings = wiki_settings.get_settings().visitors or { init={registry=true, departed=true}, journal={} }
    logger.log("renderVisitorsPage: settings.init.create_pages=" .. tostring(settings.init and settings.init.create_pages) .. ", visitors count=" .. #visitors)

    -- Optionally create individual sub-pages for each visitor
    local create_pages = settings.init and settings.init.create_pages
    if create_pages and #visitors > 0 then
        local ok_pages, err_pages = pcall(function()
            logger.log("create_pages: starting for " .. #visitors .. " visitors")
            local dynamic_pages = self.context:get_dynamic_pages()
            logger.log("create_pages: loaded " .. #dynamic_pages .. " existing dynamic pages")
            local had_new_pages = false
            for _, v in ipairs(visitors) do
                local safe_name = tostring(v.name or "")
                if safe_name ~= "" then
                    local page_key = safe_name:lower():gsub("[^%w]", "_")
                    local page_id = "visitor:" .. page_key
                    logger.log("create_pages: checking " .. page_id)
                    local already = false
                    for _, dp in ipairs(dynamic_pages) do
                        if dp.id == page_id then already = true; break end
                    end
                    if not already then
                        local page_content = {
                            { text = "# " .. safe_name, pen = COLOR_YELLOW },
                            "\n\n",
                            { text = "Type: ", pen = COLOR_LIGHTCYAN },
                            { text = (v.visitor_type or "unknown"), pen = COLOR_WHITE },
                            "\n\n",
                            { text = "## Visits", pen = COLOR_YELLOW },
                            "\n",
                        }
                        safe_save(self.context, page_id, utils.sanitize_content(page_content), 1)
                        table.insert(dynamic_pages, { text = safe_name, id = page_id })
                        had_new_pages = true
                        logger.log("create_pages: created page " .. page_id)
                    end
                end
            end
            if had_new_pages then
                self.context:save_dynamic_pages(dynamic_pages)
                logger.log("create_pages: saved " .. #dynamic_pages .. " dynamic pages")
            end
        end)
        if not ok_pages then
            logger.log_error("create_pages FAILED: " .. tostring(err_pages))
        end
    end

    logger.log("renderVisitorsPage: about to render template")
    local content = visitors_template.render(visitors, settings)
    logger.log("renderVisitorsPage: template rendered, " .. #content .. " spans")
    safe_save(self.context, 'visitors', utils.sanitize_content(content), 1)
    logger.log("renderVisitorsPage: saved visitors root page")
    logger.log("Visitors page rendered with " .. #visitors .. " entries")
end

return _ENV
