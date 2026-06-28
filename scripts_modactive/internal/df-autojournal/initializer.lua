--@ module = true
local logger = reqscript('internal/df-autojournal/logger')
local utils = reqscript('internal/df-autojournal/wiki_utils')
local event_parser = reqscript('internal/df-autojournal/event_parser')
local event_listener = reqscript('internal/df-autojournal/event_listener')

-- Templates
local citizen_template = reqscript('internal/df-autojournal/templates/citizen')
local artifact_template = reqscript('internal/df-autojournal/templates/artifact')
local fort_template = reqscript('internal/df-autojournal/templates/fort')
local civ_template = reqscript('internal/df-autojournal/templates/civilization')
local event_template = reqscript('internal/df-autojournal/templates/event')

local function safe_save(context, page_id, content, cursor)
    local ok, err = pcall(context.save_content, context, page_id, content, cursor)
    if not ok then
        logger.log_error("Failed to save page '" .. tostring(page_id) .. "': " .. tostring(err))
    else
        logger.log("Saved page '" .. tostring(page_id) .. "' (" .. tostring(#content) .. " spans)")
    end
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

        -- 0. Civ & Fort
        logger.log("Initializing Civ and Fort pages...")
        local civ_content = civ_template.render()
        safe_save(self.context, 'civ', utils.sanitize_content(civ_content), 1)
        safe_save(self.context, 'fort', utils.sanitize_content(fort_template.render()), 1)

        -- 1. Citizens
        local citizens = {}
        local dynamic_pages = {}
        logger.log("Fetching units...")

        local units = df.global.world.units.active
        if not units then
            logger.log_error("df.global.world.units.active is nil!")
            return false
        end
        logger.log("Found " .. #units .. " total active units.")

        local citizen_rows = {}
        for i = 0, #units - 1 do
            local unit = units[i]
            if dfhack.units.isCitizen(unit) then
                local raw_name = dfhack.units.getReadableName(unit)
                local name = utils.sanitize(raw_name)
                local id = 'citizen:' .. tostring(unit.id)

                logger.log("Processing citizen: " .. name .. " (ID: " .. unit.id .. ")")
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

        -- 2. Artifacts
        logger.log("Processing artifacts...")
        local artifacts = {}
        local artifact_rows = {}

        local artifact_records = df.global.world.artifacts.all
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

        -- 3. Events page (placeholder, will be populated by catch-up)
        local events_root = {}
        table.insert(events_root, { text = "# Events", pen = COLOR_YELLOW })
        table.insert(events_root, "\n\n")
        table.insert(events_root, { text = "Events will be listed here.", pen = COLOR_DARKGREY })
        table.insert(events_root, "\n")
        safe_save(self.context, 'events', utils.sanitize_content(events_root), 1)

        -- 4. Historical catch-up: scan past events for this site
        self:catchUpEvents(site_id)

        -- Set initialized flag
        dfhack.persistent.saveSiteData(self.context.save_prefix .. 'initialized', {val={1}})

        if self.on_complete then
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

    local current_max = df.global.world.history.event_id
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
            end
        end

        -- Save progress every batch
        if total_scanned % batch_size == 0 then
            pcall(dfhack.persistent.saveSiteData, catchup_key, {val=ev_id})
            logger.log("Catch-up: scanned " .. total_scanned .. ", matched " .. total_matched)
        end

        ::continue::
    end

    -- Save final marker
    pcall(dfhack.persistent.saveSiteData, catchup_key, {val=current_max})
    logger.log("Catch-up complete: scanned " .. total_scanned .. " events, matched " .. total_matched)
end

return _ENV
