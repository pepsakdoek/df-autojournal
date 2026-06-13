--@ module = true
local logger = reqscript('internal/DFMyFortWiki/logger')
local utils = reqscript('internal/DFMyFortWiki/wiki_utils')

-- Templates
local citizen_template = reqscript('internal/DFMyFortWiki/templates/citizen')
local artifact_template = reqscript('internal/DFMyFortWiki/templates/artifact')
local fort_template = reqscript('internal/DFMyFortWiki/templates/fort')
local civ_template = reqscript('internal/DFMyFortWiki/templates/civilization')
local event_template = reqscript('internal/DFMyFortWiki/templates/event')

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
        local civ_string = civ_template.render()

        self.context:save_content('civ', utils.sanitize(civ_string), 1)
        self.context:save_content('fort', utils.sanitize(fort_template.render()), 1)

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
            -- Filter to only true citizens (dwarves/citizens of the fort)
            -- This excludes pets, livestock, and most visitors unless they are residents
            if dfhack.units.isCitizen(unit) then
                local raw_name = dfhack.units.getReadableName(unit)
                local name = utils.sanitize(raw_name)
                local id = 'citizen:' .. tostring(unit.id)
                
                logger.log("Processing citizen: " .. name .. " (ID: " .. unit.id .. ")")
                table.insert(citizens, {name=name, id=id})
                table.insert(dynamic_pages, {text="  " .. name, id=id})

                local content = citizen_template.render(unit)
                self.context:save_content(id, utils.sanitize(content), 1)
            end
        end
        logger.log("Processed " .. #citizens .. " citizens.")

        local citizen_root_content = "# Citizens\n\nTotal Citizens: " .. #citizens .. "\n\n"
        for _, c in ipairs(citizens) do
            citizen_root_content = citizen_root_content .. "* [" .. c.name .. "](" .. c.id .. ")\n"
        end
        self.context:save_content('citizens', utils.sanitize(citizen_root_content), 1)

        -- 2. Artifacts
        -- TODO: Skipping artifacts for now
        -- logger.log("Processing artifacts...")
        -- local artifacts = {}
        
        -- -- Better way: Iterate through all artifact records and check if they have an item on site
        -- local artifact_records = df.global.world.artifacts.all
        -- logger.log("Total artifact records in world: " .. #artifact_records)
        
        -- for i = 0, #artifact_records - 1 do
        --     local art_record = artifact_records[i]
        --     if art_record.item_id ~= -1 then
        --         local item = df.item.find(art_record.item_id)
        --         if item then
        --             local pos = dfhack.items.getPosition(item)
        --             if pos then
        --                 local name = utils.sanitize(dfhack.items.getReadableDescription(item))
        --                 local id = 'artifact:' .. tostring(art_record.id)
        --                 logger.log("Found artifact on site: " .. name .. " (ID: " .. art_record.id .. ")")
        --                 table.insert(artifacts, {name=name, id=id})

        --                 local content = artifact_template.render(item)
        --                 self.context:save_content(id, utils.sanitize(content), 1)
        --             end
        --         end
        --     end
        -- end
        -- logger.log("Processed " .. #artifacts .. " artifacts on site.")

        -- local artifact_root_content = "# Artifacts\n\nTotal Artifacts: " .. #artifacts .. "\n\n"
        -- for _, a in ipairs(artifacts) do
        --     artifact_root_content = artifact_root_content .. "* [" .. a.name .. "](" .. a.id .. ")\n"
        -- end
        -- self.context:save_content('artifacts', utils.sanitize(artifact_root_content), 1)

        -- Save the dynamic page list
        logger.log("Saving " .. #dynamic_pages .. " dynamic pages...")
        self.context:save_dynamic_pages(dynamic_pages)

        -- 3. Events (Simple list for now)
        local events_root_content = "# Events\n\nEvents will be listed here.\n"
        self.context:save_content('events', utils.sanitize(events_root_content), 1)

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
