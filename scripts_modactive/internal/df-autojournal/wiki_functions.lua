--@ module = true
-- wiki_functions.lua
--
-- Pluggable function registry for dynamic content in HyperTextArea.
-- Functions are registered by key and evaluated at render time.
-- All DF-specific functions live here, separate from the widget code.

local registry = {}

--- Register a function definition.
-- @param fn_key  unique string identifier (e.g. 'dwarf_age')
-- @param def     { label, description, args_schema, handler }
--   label:        display name shown in the function picker
--   description:  help text for the function
--   args_schema:  array of { key, label, type, required }
--   handler:      function(args) -> string (returned text, may contain newlines)
function register_function(fn_key, def)
    registry[fn_key] = def
end

--- Evaluate a function block and return the resulting string.
-- @param fn_block  { fn_key, args }
-- @return string   evaluated result (may contain newlines)
function evaluate(fn_block)
    if not fn_block then return '' end
    local def = registry[fn_block.fn_key]
    if not def then return '[unknown: ' .. tostring(fn_block.fn_key) .. ']' end
    local ok, result = pcall(def.handler, fn_block.args or {})
    if not ok then
        return '[error: ' .. tostring(result) .. ']'
    end
    return tostring(result)
end

--- Get a sorted list of registered functions (for the modal picker).
-- Returns array of { fn_key, label, description, args_schema }
function list_functions()
    local list = {}
    for key, def in pairs(registry) do
        table.insert(list, {
            fn_key = key,
            label = def.label,
            description = def.description,
            args_schema = def.args_schema,
        })
    end
    table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
    return list
end

-- ---------------------------------------------------------------------------
-- Built-in DF functions
-- ---------------------------------------------------------------------------

register_function('dwarf_age', {
    label = 'Dwarf Age',
    description = "Shows a dwarf's current age based on their birth year",
    args_schema = {
        { key = 'birth_year', label = 'Birth Year', type = 'number', required = true },
    },
    handler = function(args)
        local birth_year = tonumber(args.birth_year)
        if not birth_year then return '[needs birth_year]' end
        local age = df.global.cur_year - birth_year
        return tostring(age) .. ' years'
    end,
})

register_function('current_profession', {
    label = 'Current Profession',
    description = "Shows the dwarf's current profession/nickname",
    args_schema = {
        { key = 'unit_id', label = 'Unit ID', type = 'number', required = true },
    },
    handler = function(args)
        local unit_id = tonumber(args.unit_id)
        if not unit_id then return '[needs unit]' end
        local unit = df.unit.find(unit_id)
        if not unit then return 'Deceased' end
        return dfhack.units.getProfessionName(unit) or 'Unknown'
    end,
})

register_function('current_skills', {
    label = 'Current Skills',
    description = "Lists all skills with their current levels and titles",
    args_schema = {
        { key = 'unit_id', label = 'Unit ID', type = 'number', required = true },
    },
    handler = function(args)
        local unit_id = tonumber(args.unit_id)
        if not unit_id then return '[needs unit]' end
        local unit = df.unit.find(unit_id)
        if not unit then return 'Deceased' end
        local soul = unit.status.current_soul
        if not soul or not soul.skills then return 'No skills' end

        local lines = {}
        for _, skill in ipairs(soul.skills) do
            if skill.rating and skill.rating > 0 then
                local name = tostring(df.skill_type[skill.id] or 'Unknown')
                name = name:gsub('_', ' '):lower()
                local title = dfhack.units.getSkillTitle(skill)
                local line = name .. ': ' .. tostring(skill.rating)
                if title and #title > 0 then
                    line = line .. ' (' .. title .. ')'
                end
                table.insert(lines, line)
            end
        end
        if #lines == 0 then return 'No notable skills' end
        return table.concat(lines, '\n')
    end,
})

register_function('current_needs', {
    label = 'Current Needs',
    description = "Shows unmet needs and desires of the dwarf",
    args_schema = {
        { key = 'unit_id', label = 'Unit ID', type = 'number', required = true },
    },
    handler = function(args)
        local unit_id = tonumber(args.unit_id)
        if not unit_id then return '[needs unit]' end
        local unit = df.unit.find(unit_id)
        if not unit then return 'Deceased' end
        local soul = unit.status.current_soul
        if not soul or not soul.needs then return 'No needs data' end

        local unmet = {}
        for _, need in ipairs(soul.needs) do
            if need.focus_level and need.focus_level < 50000 then
                local name = tostring(df.need_type[need.id] or 'Unknown')
                name = name:gsub('_', ' '):lower()
                table.insert(unmet, name)
            end
        end
        if #unmet == 0 then return 'All needs satisfied' end
        return table.concat(unmet, ', ')
    end,
})

register_function('current_health', {
    label = 'Current Health',
    description = "Describes the dwarf's current health and injury status",
    args_schema = {
        { key = 'unit_id', label = 'Unit ID', type = 'number', required = true },
    },
    handler = function(args)
        local unit_id = tonumber(args.unit_id)
        if not unit_id then return '[needs unit]' end
        local unit = df.unit.find(unit_id)
        if not unit then return 'Deceased' end

        if not unit.body then return 'Healthy' end
        if not unit.body.wounds or #unit.body.wounds == 0 then
            return 'Healthy'
        end

        local count = #unit.body.wounds
        local severe = false
        for _, wound in ipairs(unit.body.wounds) do
            if wound.parts then
                for _, part in ipairs(wound.parts) do
                    if part.severity and part.severity > 1 then
                        severe = true
                        break
                    end
                end
            end
            if severe then break end
        end
        local status = 'Injured (' .. tostring(count) .. ' wound' .. (count > 1 and 's' or '') .. ')'
        if severe then status = 'Severely ' .. status:lower() end
        return status
    end,
})

register_function('current_mood', {
    label = 'Current Mood',
    description = "Shows the dwarf's current mood and emotional state",
    args_schema = {
        { key = 'unit_id', label = 'Unit ID', type = 'number', required = true },
    },
    handler = function(args)
        local unit_id = tonumber(args.unit_id)
        if not unit_id then return '[needs unit]' end
        local unit = df.unit.find(unit_id)
        if not unit then return 'Deceased' end

        if unit.mood == -1 then return 'Content' end
        local mood_name = tostring(df.mood_type[unit.mood] or 'Unknown')
        return mood_name:gsub('_', ' '):lower()
    end,
})

register_function('current_location', {
    label = 'Current Location',
    description = "Describes the dwarf's current position or room",
    args_schema = {
        { key = 'unit_id', label = 'Unit ID', type = 'number', required = true },
    },
    handler = function(args)
        local unit_id = tonumber(args.unit_id)
        if not unit_id then return '[needs unit]' end
        local unit = df.unit.find(unit_id)
        if not unit then return 'Deceased' end

        local pos = unit.pos
        if not pos then return 'Unknown' end

        local tile = dfhack.maps.getTileBlock(pos)
        if not tile then return 'Undiscovered' end

        local region = dfhack.maps.getRegionBiome(pos)
        if region then
            local bio = tostring(region.type):gsub('_', ' '):lower()
            return bio
        end
        return 'Surface'
    end,
})

register_function('current_job', {
    label = 'Current Job',
    description = "Shows the dwarf's current job or task",
    args_schema = {
        { key = 'unit_id', label = 'Unit ID', type = 'number', required = true },
    },
    handler = function(args)
        local unit_id = tonumber(args.unit_id)
        if not unit_id then return '[needs unit]' end
        local unit = df.unit.find(unit_id)
        if not unit then return 'Deceased' end

        if not unit.job or not unit.job.job_type then return 'Idle' end
        local job_name = tostring(df.job_type[unit.job.job_type] or 'Unknown')
        return job_name:gsub('_', ' '):lower()
    end,
})

register_function('population_count', {
    label = 'Fort Population',
    description = "Current number of citizens in the fort",
    args_schema = {},
    handler = function()
        if not dfhack.world.isFortressMode() then return 'N/A' end
        local count = 0
        for _, unit in ipairs(df.global.world.units.active) do
            if dfhack.units.isCitizen(unit) then count = count + 1 end
        end
        return tostring(count)
    end,
})

register_function('fort_wealth', {
    label = 'Fort Wealth',
    description = "Current total wealth of the fortress",
    args_schema = {},
    handler = function()
        if not dfhack.world.isFortressMode() then return 'N/A' end
        local plotinfo = df.global.plotinfo
        if not plotinfo or not plotinfo.tasks then return 'Unknown' end
        local wealth = plotinfo.tasks.wealth
        if not wealth then return 'Unknown' end
        return tostring(wealth.total or 0) .. ' dorf bucks'
    end,
})

return _ENV
