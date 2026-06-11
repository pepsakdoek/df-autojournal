--@ module = true
local logger = reqscript('internal/DFMyFortWiki/logger')

WikiInitializer = defclass(WikiInitializer)

function WikiInitializer:init(args)
    self.context = args.context
    self.on_complete = args.on_complete
end

local function sanitize(str)
    if not str then return "" end
    -- Convert from DF's internal encoding to UTF-8
    local utf8_str = dfhack.df2utf(str)
    -- Project mandate: replace em-dashes and en-dashes with -
    -- em-dash (—) is \xE2\x80\x94 in UTF-8
    -- en-dash (–) is \xE2\x80\x93 in UTF-8
    utf8_str = utf8_str:gsub("\226\128\148", "-"):gsub("\226\128\147", "-")
    return utf8_str
end

function WikiInitializer:perform(screen)
    local ok, err = xpcall(function()
        logger.log("Starting Wiki initialization inner...")
        
        -- 1. Citizens
        local citizens = {}
        local dynamic_pages = {}
        logger.log("Fetching units...")
        
        local units = df.global.world.units.active
        logger.log("Found " .. #units .. " total units in world/site.")
        
        for _, unit in ipairs(units) do
            if dfhack.units.isCitizen(unit) then
                local name = dfhack.units.getReadableName(unit)
                -- name = dfhack.df2utf(name)

                local id = 'citizen:' .. tostring(unit.id)
                table.insert(citizens, {name=name, id=id})
                table.insert(dynamic_pages, {text="  " .. name, id=id})

                local prof = sanitize(dfhack.units.getProfessionName(unit)) or "None"
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
        local artifact_items = df.global.world.items.other.ANY_ARTIFACT
        if artifact_items then
            for _, item in ipairs(artifact_items) do
                -- Only process if the item is actually on the map (on-site)
                if dfhack.items.getPosition(item) then
                    local art_ref = dfhack.items.getGeneralRef(item, df.general_ref_type.ARTIFACT)
                    if art_ref then
                        local art_record = df.artifact_record.find(art_ref.artifact_id)
                        if art_record then
                            local name = sanitize(dfhack.items.getReadableDescription(item))
                            local id = 'artifact:' .. tostring(art_record.id)
                            table.insert(artifacts, {name=name, id=id})

                            local itype = item:getType()
                            local type_name = df.item_type[itype] or "Unknown"
                            local content = "# " .. name .. "\n\n" ..
                                            "Type: " .. type_name .. "\n"
                            self.context:save_content(id, content, 1)
                        end
                    end
                end
            end
        else
            logger.log("Warning: Could not access ANY_ARTIFACT list")
        end
        logger.log("Processed " .. #artifacts .. " artifacts.")

        local artifact_root_content = "# Artifacts\n\nTotal Artifacts: " .. #artifacts .. "\n\n"
        for _, a in ipairs(artifacts) do
            artifact_root_content = artifact_root_content .. "* [" .. a.name .. "](" .. a.id .. ")\n"
        end
        self.context:save_content('artifacts', artifact_root_content, 1)

        -- Save the dynamic page list
        self.context:save_dynamic_pages(dynamic_pages)

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
