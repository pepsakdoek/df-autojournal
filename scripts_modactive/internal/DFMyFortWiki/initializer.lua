--@ module = true
local logger = reqscript('internal/DFMyFortWiki/logger')

WikiInitializer = defclass(WikiInitializer)

function WikiInitializer:init(args)
    self.context = args.context
    self.on_complete = args.on_complete
end

function WikiInitializer:perform(screen)
    local ok, err = xpcall(function()
        logger.log("Starting Wiki initialization inner...")
        
        -- 1. Citizens
        local citizens = {}
        logger.log("Fetching units...")
        
        -- Using dfhack.units.getUnits() and filtering for citizens
        local units = dfhack.units.getUnits()
        logger.log("Found " .. #units .. " total units in world/site.")
        
        for _, unit in ipairs(units) do
            if dfhack.units.isCitizen(unit) then
                local name = dfhack.units.getReadableName(unit)
                local id = 'citizen:' .. tostring(unit.id)
                table.insert(citizens, {name=name, id=id})

                local prof = dfhack.units.getProfessionName(unit) or "None"
                local sex = "Unknown"
                if unit.sex == 0 then sex = "Female"
                elseif unit.sex == 1 then sex = "Male" end

                local content = "# " .. name .. "\n\n" ..
                                "Occupation: " .. prof .. "\n" ..
                                "Gender: " .. sex .. "\n"
                self.context:save_content(id, content, 1)
            end
        end
        logger.log("Processed " .. #citizens .. " citizens.")

        local citizen_root_content = "# Citizens\n\nTotal Citizens: " .. #citizens .. "\n\n"
        for _, c in ipairs(citizens) do
            citizen_root_content = citizen_root_content .. "* [" .. c.name .. "](" .. c.id .. ")\n"
        end
        self.context:save_content('citizens', citizen_root_content, 1)

        -- 2. Artifacts
        logger.log("Processing artifacts...")
        local artifacts = {}
        if df.global.world and df.global.world.artifacts and df.global.world.artifacts.all then
            for _, art in ipairs(df.global.world.artifacts.all) do
                if art.item then
                    local name = dfhack.df2console(dfhack.items.getReadableDescription(art.item))
                    local id = 'artifact:' .. tostring(art.id)
                    table.insert(artifacts, {name=name, id=id})

                    local itype = art.item:getType()
                    local type_name = df.item_type[itype] or "Unknown"
                    local content = "# " .. name .. "\n\n" ..
                                    "Type: " .. type_name .. "\n"
                    self.context:save_content(id, content, 1)
                end
            end
        else
            logger.log("Warning: Could not access artifacts list")
        end
        logger.log("Processed " .. #artifacts .. " artifacts.")

        local artifact_root_content = "# Artifacts\n\nTotal Artifacts: " .. #artifacts .. "\n\n"
        for _, a in ipairs(artifacts) do
            artifact_root_content = artifact_root_content .. "* [" .. a.name .. "](" .. a.id .. ")\n"
        end
        self.context:save_content('artifacts', artifact_root_content, 1)

        -- 3. Events (Simple list for now)
        local events_root_content = "# Events\n\nEvents will be listed here.\n"
        self.context:save_content('events', events_root_content, 1)

        -- Set initialized flag
        dfhack.persistent.saveSiteData(self.context.save_prefix .. 'initialized', {val={1}})

        if self.on_complete then
            self.on_complete()
        end

        dfhack.gui.showAnnouncement("Wiki initialized successfully!", COLOR_LIGHTGREEN)
        logger.log("Wiki initialization complete.")
    end, function(err)
        return debug.traceback(err)
    end)
    
    if not ok then
        logger.log_error("Initialization failed: " .. tostring(err))
    end
    
    return ok
end

return _ENV
