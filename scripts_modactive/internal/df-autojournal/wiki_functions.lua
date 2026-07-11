--@ module = true
-- wiki_functions.lua
--
-- Pluggable function registry for dynamic content in HyperTextArea.
-- Functions are registered by key and evaluated at render time.
-- All DF-specific functions live here, separate from the widget code.

local registry = {}

function register_function(fn_key, def)
    registry[fn_key] = def
end

local function to_text(v)
    if type(v) == 'string' then return v end
    if type(v) == 'table' and v.text then return v.text end
    return tostring(v)
end

function evaluate(fn_block)
    if not fn_block then return '' end
    local def = registry[fn_block.fn_key]
    if not def then return '[unknown: ' .. tostring(fn_block.fn_key) .. ']' end
    local ok, result = pcall(def.handler, fn_block.args or {})
    if not ok then
        return '[error: ' .. tostring(result) .. ']'
    end
    return result
end

function result_char_count(result)
    if type(result) == 'string' then
        return #result
    elseif type(result) == 'table' then
        if result.type == 'table' then
            return 0
        elseif result.text then
            return #(result.text or '')
        else
            local total = 0
            for _, v in ipairs(result) do
                total = total + #to_text(v)
            end
            return total
        end
    end
    return #tostring(result)
end

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
    description = "Shows a dwarf's current age in years and months",
    args_schema = {
        { key = 'birth_year', label = 'Birth Year', type = 'number', required = true },
        { key = 'unit_id', label = 'Unit ID', type = 'number', required = false },
    },
    handler = function(args)
        local birth_year = tonumber(args.birth_year)
        if not birth_year then return '[needs birth_year]' end

        local age_years
        local unit_id = tonumber(args.unit_id)
        if unit_id then
            local unit = df.unit.find(unit_id)
            if unit then
                age_years = dfhack.units.getAge(unit, true)
            end
        end
        if not age_years then
            age_years = df.global.cur_year - birth_year
        end

        local years = math.floor(age_years)
        if years < 6 then
            local months = math.floor((age_years - years) * 12)
            if months < 0 then months = 0 end
            if years <= 0 then
                return tostring(months) .. ' month' .. (months ~= 1 and 's' or '')
            end
            return tostring(years) .. ' year' .. (years ~= 1 and 's' or '') .. ', ' .. tostring(months) .. ' month' .. (months ~= 1 and 's' or '')
        end
        return tostring(years) .. ' years'
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
                local name = tostring(df.job_skill[skill.id] or 'Unknown')
                name = name:gsub('_', ' '):lower()
                local attr = df.job_skill.attrs[skill.id]
                local title = attr and attr.caption_noun or nil
                if not title then
                    title = dfhack.units.getSkillTitle(skill)
                end
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
        if not soul then return 'No needs data' end
        local personality = soul.personality
        if not personality or not personality.needs then return 'No needs data' end

        local unmet = {}
        for _, need in ipairs(personality.needs) do
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

local HAPPY_RANKS = {
    { label = "Euphoric",    min = -math.huge, max = -50001, rank = 1 },
    { label = "Very Happy",  min = -50000,     max = -25001, rank = 2 },
    { label = "Happy",       min = -25000,     max = -10001, rank = 3 },
    { label = "Content",     min = -10000,     max = 9999,   rank = 4 },
    { label = "Unhappy",     min = 10000,      max = 24999,  rank = 5 },
    { label = "Very Unhappy",min = 25000,      max = 49999,  rank = 6 },
    { label = "Miserable",   min = 50000,      max = math.huge, rank = 7 },
}

register_function('current_happiness', {
    label = 'Current Happiness',
    description = "Shows the dwarf's current happiness level with a sortable prefix (1.Euphoric..7.Miserable)",
    args_schema = {
        { key = 'unit_id', label = 'Unit ID', type = 'number', required = true },
    },
    handler = function(args)
        local unit_id = tonumber(args.unit_id)
        if not unit_id then return '[needs unit]' end
        local unit = df.unit.find(unit_id)
        if not unit then return 'Deceased' end
        local soul = unit.status.current_soul
        if not soul or not soul.personality then return 'Unknown' end
        local stress = soul.personality.stress
        for _, r in ipairs(HAPPY_RANKS) do
            if stress >= r.min and stress <= r.max then
                return tostring(r.rank) .. '. ' .. r.label
            end
        end
        return 'Unknown'
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

local CURRENCY_SYMBOL = string.char(15)

register_function('fort_wealth', {
    label = 'Fort Wealth',
    description = 'Current total wealth of the fortress in ' .. CURRENCY_SYMBOL,
    args_schema = {},
    handler = function()
        if not dfhack.world.isFortressMode() then return 'N/A' end
        local plotinfo = df.global.plotinfo
        if not plotinfo or not plotinfo.tasks then return 'Unknown' end
        local wealth = plotinfo.tasks.wealth
        if not wealth then return 'Unknown' end
        return tostring(wealth.total or 0) .. CURRENCY_SYMBOL
    end,
})

register_function('civ_population', {
    label = 'Civilization Population',
    description = "Total population of a civilization across all sites",
    args_schema = {
        { key = 'civ_id', label = 'Civilization ID', type = 'number', required = true },
    },
    handler = function(args)
        local civ_id = tonumber(args.civ_id)
        if not civ_id then return '[needs civ_id]' end
        local total = 0
        pcall(function()
            local pops = df.global.world.entity_populations
            if not pops then return end
            for i = 0, #pops - 1 do
                local pop = pops[i]
                if pop.civ_id == civ_id then
                    for j = 0, #pop.counts - 1 do
                        total = total + pop.counts[j]
                    end
                end
            end
        end)
        return tostring(total)
    end,
})

return _ENV
