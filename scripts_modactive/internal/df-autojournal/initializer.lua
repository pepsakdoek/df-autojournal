--@ module = true
local logger = reqscript('internal/df-autojournal/logger')
local utils = reqscript('internal/df-autojournal/wiki_utils')

-- Templates
local citizen_template = reqscript('internal/df-autojournal/templates/citizen')
local artifact_template = reqscript('internal/df-autojournal/templates/artifact')
local fort_template = reqscript('internal/df-autojournal/templates/fort')
local civ_template = reqscript('internal/df-autojournal/templates/civilization')
local event_template = reqscript('internal/df-autojournal/templates/event')

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
        self.context:save_content('civ', utils.sanitize_content(civ_content), 1)
        self.context:save_content('fort', utils.sanitize_content(fort_template.render()), 1)

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
                self.context:save_content(id, utils.sanitize_content(content), 1)
            end
        end
        logger.log("Processed " .. #citizens .. " citizens.")

        local citizen_root = {}
        table.insert(citizen_root, { text = "# Citizens", pen = COLOR_YELLOW })
        table.insert(citizen_root, "\n\n")
        table.insert(citizen_root, { text = "Total Citizens: ", pen = COLOR_LIGHTCYAN })
        table.insert(citizen_root, { text = tostring(#citizens), pen = COLOR_WHITE })
        table.insert(citizen_root, "\n\n")
        for _, c in ipairs(citizens) do
            table.insert(citizen_root, "* ")
            table.insert(citizen_root, { text = c.name, pen = COLOR_LIGHTBLUE, link = c.id })
            table.insert(citizen_root, "\n")
        end
        self.context:save_content('citizens', utils.sanitize_content(citizen_root), 1)

        -- 2. Artifacts
        logger.log("Processing artifacts...")
        local artifacts = {}

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
                self.context:save_content(id, utils.sanitize_content(content), 1)
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
        for _, a in ipairs(artifacts) do
            table.insert(artifact_root, "* ")
            table.insert(artifact_root, { text = a.name, pen = COLOR_LIGHTBLUE, link = a.id })
            table.insert(artifact_root, "\n")
        end
        self.context:save_content('artifacts', utils.sanitize_content(artifact_root), 1)

        -- Save the dynamic page list
        logger.log("Saving " .. #dynamic_pages .. " dynamic pages...")
        self.context:save_dynamic_pages(dynamic_pages)

        -- 3. Events (Simple list for now)
        local events_root = {}
        table.insert(events_root, { text = "# Events", pen = COLOR_YELLOW })
        table.insert(events_root, "\n\n")
        table.insert(events_root, { text = "Events will be listed here.", pen = COLOR_DARKGREY })
        table.insert(events_root, "\n")
        self.context:save_content('events', utils.sanitize_content(events_root), 1)

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

return _ENV
