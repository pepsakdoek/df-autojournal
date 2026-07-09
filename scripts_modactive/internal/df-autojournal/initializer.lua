--@ module = true
local logger = reqscript('internal/df-autojournal/logger')
local utils = reqscript('internal/df-autojournal/wiki_utils')
local event_parser = reqscript('internal/df-autojournal/event_parser')
local event_listener = reqscript('internal/df-autojournal/event_listener')
local wiki_settings = reqscript('internal/df-autojournal/wiki_settings')
local gui_script = require('gui.script')

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
local entity_template = reqscript('internal/df-autojournal/templates/entity')

local KNOWN_CIVS_KEY = 'mfw_known_civs'
local KNOWN_FORTS_KEY = 'mfw_known_forts'
local FORT_MEMBERS_KEY = 'mfw_fort_members'

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

local function load_fort_members()
    local members = {}
    pcall(function()
        local raw = dfhack.persistent.getSiteData(FORT_MEMBERS_KEY)
        if raw and raw.members then members = raw.members end
    end)
    return members
end

local function save_fort_members(members)
    pcall(dfhack.persistent.saveSiteData, FORT_MEMBERS_KEY, {members=members})
end

WikiInitializer = defclass(WikiInitializer)

function WikiInitializer:init(args)
    self.context = args.context
    self.on_complete = args.on_complete
end

function WikiInitializer:perform(screen)
    local ok, err = xpcall(function()
        logger.log("Starting Wiki initialization...")

        if not self:_step_setup() then return false end
        self:_step_track_entities()
        self:_step_render_subpages()
        self:_step_world()
        self:_step_citizens()
        self:_step_artifacts()
        self:_step_create_sections()
        self:_step_save_dynamic()
        self:_step_events_and_catchup()
        self:_step_finalize()

        return true
    end, function(err)
        return debug.traceback(err)
    end)

    if not ok then
        logger.log_error("Initialization failed: " .. tostring(err))
    end

    return ok
end

function WikiInitializer:_step_setup()
    self._site_id = utils.get_site_id()
    self._membership_map = {}
    logger.log("Current Site ID: " .. tostring(self._site_id))
    if not self._site_id or self._site_id == -1 then
        logger.log_error("No valid site ID found. Initialization aborted.")
        return false
    end

    self._civ_id = utils.get_civ_id()
    local settings = wiki_settings.get_settings()
    self._tracking_mode = settings.civ and settings.civ.init and settings.civ.init.tracking or 'diplomatic'
    self._current_civ = df.historical_entity.find(self._civ_id)
    self._current_site = dfhack.world.getCurrentSite()
    return true
end

function WikiInitializer:_step_track_entities()
    local known_civs = load_known_civs()
    logger.log("Loaded " .. #known_civs .. " known civs from storage")
    local known_map = {}
    for _, c in ipairs(known_civs) do
        known_map[c.civ_id] = true
        c._first_year_known = c.first_year
    end

    if self._current_civ and not known_map[self._civ_id] then
        local name = utils.get_readable_name(self._current_civ.name)
        table.insert(known_civs, {civ_id=self._civ_id, name=name, first_year=df.global.cur_year})
        known_map[self._civ_id] = true
        logger.log("Tracking new civ: " .. name)
    end

    pcall(function()
        if self._tracking_mode ~= 'player' and self._current_civ then
            local relations = self._current_civ.relations
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

    if self._tracking_mode == 'all_major' then
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

    save_known_civs(known_civs)
    self._known_civs = known_civs
    self._known_map = known_map

    local known_forts = load_known_forts()
    local fort_map = {}
    for _, f in ipairs(known_forts) do
        fort_map[f.site_id] = true
    end

    if not fort_map[self._site_id] then
        local site_name = self._current_site and utils.get_readable_name(self._current_site.name) or "Unknown Fort"
        local civ_name = self._current_civ and utils.get_readable_name(self._current_civ.name) or "Unknown"
        table.insert(known_forts, {site_id=self._site_id, name=site_name, civ_id=self._civ_id, civ_name=civ_name, first_year=df.global.cur_year})
        fort_map[self._site_id] = true
        logger.log("Tracking new fort: " .. site_name)
    end
    save_known_forts(known_forts)
    self._known_forts = known_forts
end

function WikiInitializer:_step_render_subpages()
    self._dynamic_pages = {}
    self._known_fort_set = {}
    for _, f in ipairs(self._known_forts) do self._known_fort_set[f.site_id] = true end

    for _, c in ipairs(self._known_civs) do
        local page_id = "civ:" .. tostring(c.civ_id)
        table.insert(self._dynamic_pages, {text=c.name, id=page_id})
        local content = civ_template.render(c.civ_id, self._known_fort_set)
        safe_save(self.context, page_id, utils.sanitize_content(content), 1)
    end

    for _, f in ipairs(self._known_forts) do
        local page_id = "fort:" .. tostring(f.site_id)
        table.insert(self._dynamic_pages, {text=f.name, id=page_id})
        local content = fort_template.render(f.site_id)
        safe_save(self.context, page_id, utils.sanitize_content(content), 1)
    end

    local civ_index_content = civilizations_template.render(self._known_civs, self._civ_id)
    safe_save(self.context, 'civilizations', utils.sanitize_content(civ_index_content), 1)

    local forts_index_content = forts_index_template.render(self._known_forts, self._site_id)
    safe_save(self.context, 'forts', utils.sanitize_content(forts_index_content), 1)
end

function WikiInitializer:_step_world()
    local world_name = "World"
    local world_eras = {}
    local world_landmasses = {}
    local world_season = ""
    local world_gen_params = nil
    local world_mountain_peaks = {}
    local world_rivers_count = 0
    pcall(function()
        local names = {"Early Spring", "Late Spring", "Early Summer", "Late Summer", "Early Autumn", "Late Autumn", "Early Winter", "Late Winter"}
        if df.global.cur_year_tick then
            local idx = math.floor(df.global.cur_year_tick / 16800) + 1
            if idx >= 1 and idx <= #names then world_season = names[idx] end
        end
    end)

    pcall(function()
        local wd = df.global.world.world_data
        if not wd then
            logger.log("WORLD: world_data is nil")
            return
        end

        local ok_n, name_n = pcall(utils.get_readable_name, wd.name)
        if ok_n and name_n and name_n ~= "" then world_name = name_n end

        logger.log("WORLD: world_data found, landmasses=" .. tostring(wd.landmasses and #wd.landmasses))

        -- Eras live in df.global.world.history.eras, NOT world_data.eras
        local hist_eras = df.global.world.history.eras
        if hist_eras then
            logger.log("WORLD: scanning " .. #hist_eras .. " era(s) from history")
            for i = 0, #hist_eras - 1 do
                local era = hist_eras[i]
                local year = era.year
                local name = era.title and era.title.name or nil
                if name and name ~= "" then
                    table.insert(world_eras, { year = year, name = name, is_current = false })
                    logger.log("WORLD: era: year=" .. tostring(year) .. " name=" .. name)
                end
            end
            table.sort(world_eras, function(a, b) return (a.year or 0) < (b.year or 0) end)
            if #world_eras > 0 then
                local cur = df.global.cur_year
                local current_era = world_eras[1]
                for _, e in ipairs(world_eras) do
                    if e.year <= cur then current_era = e end
                end
                current_era.is_current = true
            end
        else
            logger.log("WORLD: no history eras found")
        end

        if wd.landmasses then
            for _, lm in ipairs(wd.landmasses) do
                local ok_ln, lm_name = pcall(utils.get_readable_name, lm.name)
                if not ok_ln or not lm_name then lm_name = "Unknown" end
                local total_population = 0

                for _, site in ipairs(wd.sites) do
                    if site.pos and site.pos.x >= lm.min_x and site.pos.x <= lm.max_x
                        and site.pos.y >= lm.min_y and site.pos.y <= lm.max_y then
                        total_population = total_population + (site.infrastructure_pop_level or 0)
                    end
                end

                if total_population > 0 then
                    table.insert(world_landmasses, { name = lm_name, total_population = total_population })
                end
            end
            table.sort(world_landmasses, function(a, b) return (a.total_population or 0) > (b.total_population or 0) end)
            logger.log("WORLD: " .. #world_landmasses .. " landmass(es) populated")
        else
            logger.log("WORLD: no landmasses or no wd.landmasses field")
        end
    end)

    -- World gen parameters
    pcall(function()
        local wg = df.global.world.worldgen
        if wg and wg.worldgen_parms then
            local wp = wg.worldgen_parms
            world_gen_params = {
                title = wp.title or "",
                seed = wp.seed or "",
                history_seed = wp.history_seed or "",
                name_seed = wp.name_seed or "",
                creature_seed = wp.creature_seed or "",
                dim_x = wp.dim_x or 0,
                dim_y = wp.dim_y or 0,
                end_year = wp.end_year or 0,
                beast_end_year = wp.beast_end_year or 0,
                mineral_scarcity = wp.mineral_scarcity or 0,
                total_civ_number = wp.total_civ_number or 0,
                total_civ_population = wp.total_civ_population or 0,
                site_cap = wp.site_cap or 0,
                megabeast_cap = wp.megabeast_cap or 0,
                semimegabeast_cap = wp.semimegabeast_cap or 0,
                titan_number = wp.titan_number or 0,
                demon_number = wp.demon_number or 0,
                embark_points = wp.embark_points or 0,
            }
            logger.log("WORLD: gen params loaded, preset=" .. tostring(wp.title))
        end
    end)

    -- Mountain peaks
    pcall(function()
        local wd = df.global.world.world_data
        if wd and wd.mountain_peaks then
            for _, mp in ipairs(wd.mountain_peaks) do
                local name = utils.get_readable_name(mp.name)
                if name and name ~= "" then
                    local is_volcano = false
                    pcall(function() is_volcano = mp.flags[0] end)
                    table.insert(world_mountain_peaks, { name = name, is_volcano = is_volcano })
                end
            end
            logger.log("WORLD: " .. #world_mountain_peaks .. " mountain peak(s) found")
        end
    end)

    -- Mountain ranges (regions with type=3)
    local world_mountain_ranges = {}
    pcall(function()
        local wd = df.global.world.world_data
        if wd and wd.regions then
            for _, r in ipairs(wd.regions) do
                if r.type == 3 then
                    local eng = dfhack.translation.translateName(r.name, true)
                    if eng and eng ~= "" then
                        table.insert(world_mountain_ranges, { name = eng, size = r.size })
                    end
                end
            end
            table.sort(world_mountain_ranges, function(a, b) return (a.size or 0) > (b.size or 0) end)
            logger.log("WORLD: " .. #world_mountain_ranges .. " mountain range(s) found")
        end
    end)

    -- Rivers: count + major rivers (flow >= 100)
    local world_major_rivers = {}
    local world_all_rivers = {}
    pcall(function()
        local wd = df.global.world.world_data
        if wd and wd.rivers then
            world_rivers_count = #wd.rivers
            for i = 0, #wd.rivers - 1 do
                local r = wd.rivers[i]
                local name = utils.get_readable_name(r.name)
                if name and name ~= "" then
                    table.insert(world_all_rivers, { name = name, flow = r.flow[0] or 0 })
                    if r.flow and r.flow[0] and r.flow[0] >= 100 then
                        table.insert(world_major_rivers, { name = name, flow = r.flow[0] })
                    end
                end
            end
            table.sort(world_all_rivers, function(a, b) return (a.flow or 0) > (b.flow or 0) end)
            logger.log("WORLD: " .. world_rivers_count .. " rivers, " .. #world_major_rivers .. " major (flow>=100)")
        end
    end)

    local world_content = world_template.render({
        world_name = world_name,
        current_year = df.global.cur_year,
        current_month = math.floor(df.global.cur_year_tick / 33600) + 1,
        current_day = math.floor((df.global.cur_year_tick % 33600) / 1200) + 1,
        current_season = world_season or "",
        eras = world_eras,
        landmasses = world_landmasses,
        gen_params = world_gen_params,
        mountain_peaks = world_mountain_peaks,
        mountain_ranges = world_mountain_ranges,
        rivers_count = world_rivers_count,
        major_rivers_count = #world_major_rivers,
        major_rivers = world_major_rivers,
        rivers = world_all_rivers,
    })

    logger.log("WORLD: eras built=" .. #world_eras .. ", landmasses built=" .. #world_landmasses)

    if not world_content or #world_content == 0 then
        world_content = { { text = "# " .. world_name, pen = COLOR_YELLOW }, "\n\n", { text = "Current Date: ", pen = COLOR_LIGHTCYAN }, { text = "Year " .. tostring(df.global.cur_year or 0), pen = COLOR_WHITE }, "\n" }
        logger.log("WORLD: using fallback content (empty render)")
    end

    logger.log("Saving World page (" .. #world_content .. " spans)")
    world_content = utils.sanitize_content(world_content)
    local w_ok, w_err = pcall(dfhack.persistent.saveSiteData, 'mfw_p_world', {content=world_content, cursor={1}})
    if not w_ok then
        logger.log_error("Direct world save failed: " .. tostring(w_err))
    else
        logger.log("Direct world save succeeded")
    end
end

function WikiInitializer:_step_citizens()
    local citizens = {}
    local dead_citizen_rows = {}
    logger.log("Fetching units...")

    local all_units = {}
    pcall(function() all_units = df.global.world.units.all or {} end)

    local fort_section = 'fort:' .. self._site_id .. '/citizens'

    logger.log("Found " .. #all_units .. " total units in world.")
    local citizen_rows = {}
    for i = 0, #all_units - 1 do
        local unit = all_units[i]
        if dfhack.units.isCitizen(unit) then
            local raw_name = dfhack.units.getReadableName(unit)
            local name = utils.sanitize(raw_name)
            local id = 'citizen:' .. tostring(unit.id)
            self._membership_map[id] = fort_section

            local age = df.global.cur_year - unit.birth_year

            if not dfhack.units.isDead(unit) then
                table.insert(citizens, {name=name, id=id})
                table.insert(self._dynamic_pages, {text=name, id=id})

                local content = citizen_template.render(unit)
                safe_save(self.context, id, utils.sanitize_content(content), 1)
            end

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

            local dead = dfhack.units.isDead(unit)
            local death_status = dead and "Deceased" or "Alive"

            local age_str = tostring(age) .. (dead and " (at death)" or "")
            local age_pen = dead and COLOR_DARKGREY or COLOR_WHITE

            if dead then
                table.insert(dead_citizen_rows, {
                    { text = name, pen = COLOR_LIGHTBLUE, link = id },
                    { text = age_str, pen = age_pen },
                    { text = death_status, pen = COLOR_LIGHTRED },
                })
            else
                table.insert(citizen_rows, {
                    { text = name, pen = COLOR_LIGHTBLUE, link = id },
                    { text = age_str, pen = age_pen },
                    { text = happiness },
                    { text = death_status, pen = dead and COLOR_LIGHTRED or COLOR_LIGHTGREEN },
                })
            end
        end
    end
    logger.log("Processed " .. #citizen_rows .. " living citizens + " .. #dead_citizen_rows .. " fallen.")

    local citizen_root = {}
    table.insert(citizen_root, { text = "# Citizens", pen = COLOR_YELLOW })
    table.insert(citizen_root, "\n\n")
    table.insert(citizen_root, { text = "Total Citizens: ", pen = COLOR_LIGHTCYAN })
    table.insert(citizen_root, { text = tostring(#citizen_rows), pen = COLOR_WHITE })
    if #dead_citizen_rows > 0 then
        table.insert(citizen_root, { text = " (Fallen: ", pen = COLOR_LIGHTCYAN })
        table.insert(citizen_root, { text = tostring(#dead_citizen_rows), pen = COLOR_LIGHTRED })
        table.insert(citizen_root, { text = ")", pen = COLOR_LIGHTCYAN })
    end
    table.insert(citizen_root, "\n\n")
    if #citizen_rows > 0 then
        table.insert(citizen_root, {
            type = 'table',
            columns = {
                { header = 'Name', align = 'left', min_width = 15, max_width = 50, stretch = true },
                { header = 'Age', align = 'right', min_width = 6, stretch = false },
                { header = 'Happiness', align = 'left', min_width = 10, stretch = false },
                { header = 'Status', align = 'left', min_width = 8, stretch = false },
            },
            rows = citizen_rows
        })
    end
    if #dead_citizen_rows > 0 then
        table.insert(citizen_root, "\n\n")
        table.insert(citizen_root, { text = "## Fallen Citizens", pen = COLOR_YELLOW })
        table.insert(citizen_root, "\n\n")
        table.insert(citizen_root, {
            type = 'table',
            columns = {
                { header = 'Name', align = 'left', min_width = 15, max_width = 50, stretch = true },
                { header = 'Age at Death', align = 'right', min_width = 6, stretch = false },
                { header = 'Status', align = 'left', min_width = 8, stretch = false },
            },
            rows = dead_citizen_rows
        })
    end
    safe_save(self.context, 'citizens', utils.sanitize_content(citizen_root), 1)
    safe_save(self.context, 'fort:' .. self._site_id .. '/citizens', utils.sanitize_content(citizen_root), 1)
end

function WikiInitializer:_step_artifacts()
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
            self._membership_map[id] = 'fort:' .. self._site_id .. '/artifacts'
            logger.log("Found artifact on site: " .. name .. " (ID: " .. art_record.id .. ")")
            table.insert(artifacts, {name=name, id=id})
            self._dynamic_pages[#self._dynamic_pages + 1] = {text=name, id=id}

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
    safe_save(self.context, 'fort:' .. self._site_id .. '/artifacts', utils.sanitize_content(artifact_root), 1)
end

function WikiInitializer:_step_create_sections()
    local fort_id = 'fort:' .. self._site_id
    local function capitalize(str)
        return str:gsub("^%l", string.upper)
    end

    -- Desired order: Citizens, Artifacts, Events, Visitors, Enemies
    local all_sections = {
        {id = fort_id .. '/citizens',  title = 'Citizens'},
        {id = fort_id .. '/artifacts', title = 'Artifacts'},
        {id = fort_id .. '/events',    title = 'Events'},
        {id = fort_id .. '/visitors',  title = 'Visitors'},
        {id = fort_id .. '/enemies',   title = 'Enemies'},
    }
    for _, sec in ipairs(all_sections) do
        -- Citizens and Artifacts were already saved during their steps; skip saving
        local already_saved = sec.id:match('/citizens$') or sec.id:match('/artifacts$')
        if not already_saved then
            local content = {
                { text = '# ' .. sec.title, pen = COLOR_YELLOW },
                "\n\n",
                { text = 'This fort\'s ' .. sec.title:lower() .. '.', pen = COLOR_WHITE },
                "\n",
            }
            safe_save(self.context, sec.id, utils.sanitize_content(content), 1)
            logger.log("Created section page: " .. sec.id)
        end
        table.insert(self._dynamic_pages, {text=sec.title, id=sec.id})
    end
end

function WikiInitializer:_step_save_dynamic()
    logger.log("Saving " .. #self._dynamic_pages .. " dynamic pages...")
    self.context:save_dynamic_pages(self._dynamic_pages)
    save_fort_members(self._membership_map)
end

function WikiInitializer:_step_events_and_catchup()
    pcall(function()
        local events_root = {}
        table.insert(events_root, { text = "# Events", pen = COLOR_YELLOW })
        table.insert(events_root, "\n\n")
        table.insert(events_root, { text = "Loading events...", pen = COLOR_DARKGREY })
        table.insert(events_root, "\n")
        safe_save(self.context, 'events', utils.sanitize_content(events_root), 1)
    end)

    pcall(function() self:catchUpEvents(self._site_id) end)

    pcall(function() self:renderEventsTimeline() end)
    pcall(function() self:renderEnemiesPage() end)
    pcall(function() self:renderVisitorsPage() end)
end

function WikiInitializer:_step_finalize()
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
end

function WikiInitializer:perform_async()
    local completed = false
    local ok, err = xpcall(function()
        logger.log("Starting async Wiki initialization...")

        if not self:_step_setup() then return end

        local steps = {
            {name='Tracking civilizations & forts', fn=function() self:_step_track_entities() end},
            {name='Rendering index pages',          fn=function() self:_step_render_subpages() end},
            {name='World page',                     fn=function() self:_step_world() end},
            {name='Citizens',                       fn=function() self:_step_citizens() end},
            {name='Artifacts',                      fn=function() self:_step_artifacts() end},
            {name='Creating section pages',         fn=function() self:_step_create_sections() end},
            {name='Saving dynamic pages',           fn=function() self:_step_save_dynamic() end},
            {name='Historical catch-up',            fn=function() self:_step_events_and_catchup() end},
            {name='Finalizing',                     fn=function() self:_step_finalize() end},
        }

        -- Yield once so the progress bar renders before any work begins
        gui_script.sleep(1, 'frames')

        local total = #steps
        for i, step in ipairs(steps) do
            if self.on_step then self.on_step(i, total, step.name) end
            local t0 = os.clock()
            local ok_step, err_step = pcall(step.fn)
            local elapsed_ms = (os.clock() - t0) * 1000
            if ok_step then
                logger.log(string.format("  ✓ Step '%s' completed in %.0f ms", step.name, elapsed_ms))
            else
                logger.log_error(string.format("  ✗ Step '%s' FAILED in %.0f ms: %s", step.name, elapsed_ms, tostring(err_step)))
            end
            gui_script.sleep(1, 'frames')
        end

        completed = true
    end, function(err)
        return debug.traceback(err)
    end)

    if not ok then
        logger.log_error("Async initialization failed: " .. tostring(err))
    end
    return completed
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

    -- Map generic page_ids to this fort's section pages
    local function fortify(id)
        if id == "fort" then return "fort:" .. site_id
        elseif id == "events" then return "fort:" .. site_id .. "/events"
        elseif id == "enemies" then return "fort:" .. site_id .. "/enemies"
        elseif id == "visitors" then return "fort:" .. site_id .. "/visitors"
        end
        return id
    end

    local batch_size = 500
    local total_scanned = 0
    local total_matched = 0
    local max_index = #events - 1
    local total_to_scan = current_max - last_done

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
                event_listener.append_to_page(fortify(parsed.page_id), parsed.section, entry_text)
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

        -- Save progress every batch and notify progress bar
        if total_scanned % batch_size == 0 then
            pcall(dfhack.persistent.saveSiteData, catchup_key, {val=ev_id})
            if self.on_batch then
                self.on_batch(total_scanned, total_to_scan, total_matched)
            end
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
    safe_save(self.context, 'fort:' .. self._site_id .. '/enemies', utils.sanitize_content(content), 1)
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
                if is_known_visitor then
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
                end
            end
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
                        local page_content = entity_template.render(nil, {
                            entity_type = 'visitor',
                            name = safe_name,
                            subtitle = "Type: " .. (v.visitor_type or "unknown"),
                        })
                        safe_save(self.context, page_id, utils.sanitize_content(page_content), 1)
                        table.insert(dynamic_pages, { text = safe_name, id = page_id })
                        self._membership_map[page_id] = 'fort:' .. self._site_id .. '/visitors'
                        had_new_pages = true
                        logger.log("create_pages: created page " .. page_id)
                    end
                end
            end
            if had_new_pages then
                self.context:save_dynamic_pages(dynamic_pages)
                save_fort_members(self._membership_map)
                logger.log("create_pages: saved " .. #dynamic_pages .. " dynamic pages + membership map")
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
    safe_save(self.context, 'fort:' .. self._site_id .. '/visitors', utils.sanitize_content(content), 1)
    logger.log("renderVisitorsPage: saved visitors root page")
    logger.log("Visitors page rendered with " .. #visitors .. " entries")
end

return _ENV
