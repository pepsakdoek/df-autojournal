--@ module = true

-- Helper to safely get the current civilization ID
function get_civ_id()
    if df.global.plotinfo then
        return df.global.plotinfo.civ_id
    end
end

-- Helper to safely get the current site ID
function get_site_id()
    if df.global.plotinfo then
        return df.global.plotinfo.site_id
    end
end

-- Safely translate a DF name structure
function translate_name(name)
    if not name then return "" end
    local translated = ""
    -- Use dfhack.TranslateName if available (standard)
    if dfhack.translation then
        translated = dfhack.translation.translateName(name, true)
    elseif dfhack.names and dfhack.names.translateName then
        translated = dfhack.names.translateName(name)
    else
        -- Manual fallback if everything else fails
        -- This is a very basic attempt to get some string out of a name object
        if name.first_name and name.first_name ~= "" then
            translated = name.first_name
        else
            translated = "Unnamed"
        end
    end
    
    -- If it's still an object or nil, ensure we return a string
    if type(translated) ~= "string" then
        return "Unknown Name"
    end
    
    return translated
end

-- Sanitize converts from DF's internal CP437 to UTF-8 for storage/JSON
function sanitize(str)
    -- DO NOT convert to UTF-8 here! This is to make things not crash
    if not str then return "" end
    str = dfhack.df2utf(str)  -- Convert from CP437 to UTF-8

    local replacements = {
        -- Lowercase Vowels with Accents
        ["à"]="a", ["á"]="a", ["â"]="a", ["ã"]="a", ["ä"]="a", ["å"]="a", ["æ"]="ae", ["ā"]="a",
        ["è"]="e", ["é"]="e", ["ê"]="e", ["ë"]="e", ["ē"]="e", ["ė"]="e", ["ę"]="e",
        ["ì"]="i", ["í"]="i", ["î"]="i", ["ï"]="i", ["ī"]="i", ["į"]="i",
        ["ò"]="o", ["ó"]="o", ["ô"]="o", ["õ"]="o", ["ö"]="o", ["ø"]="o", ["ō"]="o", ["œ"]="oe",
        ["ù"]="u", ["ú"]="u", ["û"]="u", ["ü"]="u", ["ū"]="u",
        ["ý"]="y", ["ÿ"]="y",

        -- Uppercase Vowels with Accents
        ["À"]="A", ["Á"]="A", ["Â"]="A", ["Ã"]="A", ["Ä"]="A", ["Å"]="A", ["Æ"]="AE", ["Ā"]="A",
        ["È"]="E", ["É"]="E", ["Ê"]="E", ["Ë"]="E", ["Ē"]="E", ["Ė"]="E", ["Ę"]="E",
        ["Ì"]="I", ["Í"]="I", ["Î"]="I", ["Ï"]="I", ["Ī"]="I", ["Į"]="I",
        ["Ò"]="O", ["Ó"]="O", ["Ô"]="O", ["Õ"]="O", ["Ö"]="O", ["Ø"]="O", ["Ō"]="O", ["Œ"]="OE",
        ["Ù"]="U", ["Ú"]="U", ["Û"]="U", ["Ü"]="U", ["Ū"]="U",
        ["Ý"]="Y", ["Ÿ"]="Y",

        -- Consonants with Diacritics (Lowercase)
        ["ç"]="c", ["ć"]="c", ["ĉ"]="c", ["ċ"]="c", ["č"]="c",
        ["ď"]="d", ["đ"]="d",
        ["ĝ"]="g", ["ğ"]="g", ["ġ"]="g", ["ģ"]="g",
        ["ĥ"]="h", ["ħ"]="h",
        ["ĵ"]="j",
        ["ķ"]="k",
        ["ĺ"]="l", ["ļ"]="l", ["ľ"]="l", ["ŀ"]="l", ["ł"]="l",
        ["ñ"]="n", ["ń"]="n", ["ņ"]="n", ["ň"]="n", ["ŉ"]="n", ["ŋ"]="n",
        ["ŕ"]="r", ["ŗ"]="r", ["ř"]="r",
        ["ś"]="s", ["ŝ"]="s", ["ş"]="s", ["š"]="s", ["ș"]="s", ["ß"]="ss",
        ["ţ"]="t", ["ť"]="t", ["ŧ"]="t", ["ț"]="t",
        ["ŵ"]="w",
        ["ź"]="z", ["ż"]="z", ["ž"]="z",

        -- Consonants with Diacritics (Uppercase)
        ["Ç"]="C", ["Ć"]="C", ["Ĉ"]="C", ["Ċ"]="C", ["Č"]="C",
        ["Ď"]="D", ["Đ"]="D",
        ["Ĝ"]="G", ["Ğ"]="G", ["Ġ"]="G", ["Ģ"]="G",
        ["Ĥ"]="H", ["Ħ"]="H",
        ["Ĵ"]="J",
        ["Ķ"]="K",
        ["Ĺ"]="L", ["Ļ"]="L", ["Ľ"]="L", ["Ŀ"]="L", ["Ł"]="L",
        ["Ñ"]="N", ["Ń"]="N", ["Ņ"]="N", ["Ň"]="N", ["Ŋ"]="N",
        ["Ŕ"]="R", ["Ŗ"]="R", ["Ř"]="R",
        ["Ś"]="S", ["Ŝ"]="S", ["Ş"]="S", ["Š"]="S", ["Ș"]="S",
        ["Ţ"]="T", ["Ť"]="T", ["Ŧ"]="T", ["Ț"]="T",
        ["Ŵ"]="W",
        ["Ź"]="Z", ["Ż"]="Z", ["Ž"]="Z"
    }
    -- str = str:gsub("[%z\128-\255]", replacements)
    -- for weird_char, clean_char in pairs(replacements) do
    --     str = str:gsub(weird_char, clean_char)
    -- end

    str = str:gsub("[%z\1-\127\194-\244][\128-\191]*", replacements)

    str = dfhack.utf2df(str)  -- Convert back to CP437 for DF storage
    return str
end

-- Helper that combines translation and sanitization
function get_readable_name(name)
    return sanitize(translate_name(name))
end

-- Convert UTF-8 (from storage) to CP437 (for UI display)
function to_ui(str)
    -- if not str then return "" end
    -- return dfhack.utf2df(str)
    return str
end

-- Convert CP437 (from UI) to UTF-8 (for storage)
function from_ui(str)
    -- if not str then return "" end
    -- return dfhack.df2utf(str)
    return str
end

local MONTH_NAMES = {
    "Granite", "Slate", "Felsite",
    "Hematite", "Malachite", "Galena",
    "Limestone", "Sandstone", "Timber",
    "Moonstone", "Opal", "Obsidian"
}

local function get_ordinal(n)
    if n % 10 == 1 and n ~= 11 then return "st"
    elseif n % 10 == 2 and n ~= 12 then return "nd"
    elseif n % 10 == 3 and n ~= 13 then return "rd"
    else return "th" end
end

--- Current game date components.
--- Returns { year, month (1-12), day (1-28) }
--- Derives month/day from cur_year_tick (403200 ticks/year, 33600/month, 1200/day)
function get_current_date()
    local year = df.global.cur_year
    local tick = df.global.cur_year_tick
    local month = math.floor(tick / 33600) + 1
    local day = math.floor((tick % 33600) / 1200) + 1
    return year, month, day
end

--- Long date: "28th of Obsidian, 68"
--- Defaults to the current in-game date if not specified.
function get_nice_date(year, month, day)
    if not year then year, month, day = get_current_date() end
    month = month or 1
    day = day or 1
    local month_name = MONTH_NAMES[month] or "Unknown"
    return string.format("%d%s of %s, %d", day, get_ordinal(day), month_name, year)
end

--- Short (unsorted) date: "68-12-28"
--- Defaults to current in-game date. Good for simple display.
function get_short_date(year, month, day)
    if not year then year, month, day = get_current_date() end
    month = month or 1
    day = day or 1
    return string.format("%d-%02d-%02d", year, month, day)
end

--- Sort-safe date string with zero-padded year: "0068-12-28"
--- `width` controls the year pad (default 4).
--- Use for columns that must sort chronologically as strings.
function format_sortable_date(year, month, day, width)
    width = width or 4
    if not month then _, month, day = get_current_date() end
    month = month or 1
    day = day or 1
    return string.format("%0" .. width .. "d-%02d-%02d", year, month, day)
end

--- Batch version of format_sortable_date.
--- entries: array of {year, month?, day?}
--- Returns array of zero-padded date strings, all with the same year width.
function format_sortable_dates(entries)
    local max_width = 4
    for _, e in ipairs(entries) do
        local y = e[1] or 0
        local w = #tostring(math.abs(y))
        if w > max_width then max_width = w end
    end
    local result = {}
    for _, e in ipairs(entries) do
        table.insert(result, format_sortable_date(e[1], e[2], e[3], max_width))
    end
    return result
end

-- Legacy: year-tick format, kept for backward compatibility
function get_date_str()
    return tostring(df.global.cur_year) .. "-" .. tostring(df.global.cur_year_tick)
end

function sanitize_content(content)
    if type(content) == 'string' then
        return sanitize(content)
    elseif type(content) == 'table' then
        local result = {}
        for _, span in ipairs(content) do
            if type(span) == 'string' then
                table.insert(result, sanitize(span))
            elseif type(span) == 'table' and span.type == 'table' then
                local tbl = {}
                for k, v in pairs(span) do
                    tbl[k] = v
                end
                if tbl.columns then
                    for _, col in ipairs(tbl.columns) do
                        if col.header then
                            col.header = sanitize(col.header)
                        end
                    end
                end
                if tbl.rows then
                    for _, row in ipairs(tbl.rows) do
                        for _, cell in ipairs(row) do
                            if cell.text then
                                cell.text = sanitize(cell.text)
                            end
                        end
                    end
                end
                table.insert(result, tbl)
            elseif type(span) == 'table' and span.type == 'function' then
                -- Pass through function blocks unchanged
                table.insert(result, span)
            elseif type(span) == 'table' and span.text then
                table.insert(result, { text = sanitize(span.text), pen = span.pen, link = span.link })
            end
        end
        return result
    end
    return content
end

-- Helper to create a colored span
function colored(text, pen)
    return { text = text, pen = pen }
end

-- Helper to create a header span
function header(text, level)
    local prefix = string.rep('#', level or 1)
    return colored(prefix .. ' ' .. text, COLOR_YELLOW)
end

-- Helper to create a label span
function label(text)
    return colored(text, COLOR_LIGHTCYAN)
end

-- Helper to create a value span
function value(text)
    return colored(text, COLOR_WHITE)
end

-- Helper to create a muted/note span
function note(text)
    return colored(text, COLOR_DARKGREY)
end

--- Describe a civilization's position on the world map using a 5x5 grid system.
--- Returns nil if no position data is available.
--- Otherwise returns a table:
---   { description = "the far northwestern region", world_name = "The World", site_count = 5, continent = "The Continent" }
local X_NAMES = { "far west", "west", "central", "east", "far east" }
local Y_NAMES = { "far north", "north", "central", "south", "far south" }

--- Determine which landmasses (continents) the civ's sites are on.
--- Uses bounding box check since landmasses have min/max x/y fields.
local function get_landmasses_for_sites(site_positions, world_data)
    if not world_data.landmasses then return nil end
    local result, seen = {}, {}

    for _, pos in ipairs(site_positions) do
        for _, lm in ipairs(world_data.landmasses) do
            if not seen[lm.index] and pos.x >= lm.min_x and pos.x <= lm.max_x and pos.y >= lm.min_y and pos.y <= lm.max_y then
                seen[lm.index] = true
                local name = get_readable_name(lm.name)
                if name and name ~= "" then
                    table.insert(result, name)
                end
            end
        end
    end

    return #result > 0 and result or nil
end

--- Return a compass direction name for a 5x5 world grid cell.
--- bx: 0 (far west) to 4 (far east), by: 0 (far north) to 4 (far south)
local function grid_direction_name(bx, by)
    local Y_WORDS = { [0]="north", [1]="north", [3]="south", [4]="south" }
    local X_WORDS = { [0]="west", [1]="west", [3]="east", [4]="east" }
    local y_far, x_far = (by == 0 or by == 4), (bx == 0 or bx == 4)
    local function cap(s) return s:sub(1,1):upper() .. s:sub(2) end

    if bx == 2 and by == 2 then return "Central region" end
    if by == 2 then
        if x_far then return "Far " .. cap(X_WORDS[bx]) .. "ern" end
        return cap(X_WORDS[bx]) .. "ern"
    end
    if bx == 2 then
        if y_far then return "Far " .. cap(Y_WORDS[by]) .. "ern" end
        return cap(Y_WORDS[by]) .. "ern"
    end

    local yw, xw = Y_WORDS[by], X_WORDS[bx]
    if y_far and x_far then
        return "Far " .. cap(yw) .. "-" .. xw .. "ern"
    elseif y_far then
        return cap(yw) .. "-" .. yw .. " " .. xw .. "ern"
    elseif x_far then
        return cap(yw) .. "-" .. xw .. "-" .. xw
    else
        local x_part = (xw == "east") and "eastern" or xw
        return cap(yw) .. "-" .. x_part
    end
end

function describe_world_position(civ)
    if not civ then return nil end
    local world_data = df.global.world.world_data
    if not world_data or not world_data.sites then return nil end
    local world_width = world_data.world_width or 1
    local world_height = world_data.world_height or 1
    if world_width <= 0 or world_height <= 0 then return nil end

    local world_name = get_readable_name(world_data.name) or "the world"
    local bands_x, bands_y, count = {}, {}, 0
    local civ_id = civ.id
    local site_positions = {}

    for _, site in ipairs(world_data.sites) do
        if site and site.pos then
            local owns = false
            if site.entity_links then
                for _, link in ipairs(site.entity_links) do
                    if link.entity_id == civ_id then
                        owns = true
                        break
                    end
                end
            end
            if owns then
                table.insert(site_positions, site.pos)
                local bx = math.max(0, math.min(4, math.floor(site.pos.x / world_width * 5)))
                local by = math.max(0, math.min(4, math.floor(site.pos.y / world_height * 5)))
                bands_x[bx] = true
                bands_y[by] = true
                count = count + 1
            end
        end
    end

    if count == 0 then return nil end

    local xi, yi = {}, {}
    for k in pairs(bands_x) do xi[#xi+1] = k end
    for k in pairs(bands_y) do yi[#yi+1] = k end
    table.sort(xi)
    table.sort(yi)

    local function is_contiguous(arr)
        if #arr <= 1 then return true end
        for i = 2, #arr do
            if arr[i] ~= arr[i-1] + 1 then return false end
        end
        return true
    end

    if not is_contiguous(xi) or not is_contiguous(yi) then
        return {
            description = "scattered across the world",
            world_name = world_name,
            site_count = count,
            continent = nil,
        }
    end

    local function range_label(indices, names, half_left, half_right)
        local first, last = indices[1], indices[#indices]
        if first == last then
            return names[first + 1]
        end
        if first == 0 and last == 1 then return "the far " .. names[2] end
        if first == 0 and last == 2 then return "the " .. half_left end
        if first == 2 and last == 4 then return "the " .. half_right end
        if first == 3 and last == 4 then return "the far " .. names[last] end
        if first == 0 and last == 4 then return "the entire world" end
        return "from " .. names[first + 1] .. " to " .. names[last + 1]
    end

    -- Convert an X band name to its adjective form for use in "the <x> <y> region"
    local function x_adj(name)
        if name == "central" then return "central" end
        return name .. "ern"
    end

    -- Strip leading "the " for use in compound descriptions
    local function strip_the(s)
        return s:gsub("^the ", "")
    end

    -- Build description
    local x_only = #xi == 1
    local y_only = #yi == 1
    local x_all = xi[1] == 0 and xi[#xi] == 4
    local y_all = yi[1] == 0 and yi[#yi] == 4

    -- Produce range name without leading "the"
    local function range_name(indices, names, half_left, half_right)
        local first, last = indices[1], indices[#indices]
        if first == last then return names[first + 1] end
        if first == 0 and last == 1 then return "far " .. names[2] end
        if first == 0 and last == 2 then return half_left end
        if first == 2 and last == 4 then return half_right end
        if first == 3 and last == 4 then return "far " .. names[last] end
        if first == 0 and last == 4 then return "the world" end
        return "from " .. names[first + 1] .. " to " .. names[last + 1]
    end

    local description
    if x_all and y_all then
        description = "the entire world"
    elseif x_all then
        local y_label = range_name(yi, Y_NAMES, "northern half", "southern half")
        description = "the " .. y_label .. " of the world"
    elseif y_all then
        local x_label = range_name(xi, X_NAMES, "western half", "eastern half")
        description = "the " .. x_label .. " across the world"
    elseif x_only and y_only then
        description = "the " .. grid_direction_name(xi[1], yi[1]) .. " region"
    elseif x_only then
        local x_part = x_adj(X_NAMES[xi[1] + 1])
        local y_label = range_name(yi, Y_NAMES, "northern half", "southern half")
        description = "the " .. x_part .. " " .. y_label .. " region"
    elseif y_only then
        local x_label = range_name(xi, X_NAMES, "western half", "eastern half")
        local y_name = Y_NAMES[yi[1] + 1]
        description = "the " .. x_label .. " " .. y_name .. " region"
    else
        local x_label = range_name(xi, X_NAMES, "western half", "eastern half")
        local y_label = range_name(yi, Y_NAMES, "northern half", "southern half")
        description = "the " .. x_label .. ", reaching " .. y_label
    end

    -- Determine landmass(es)
    local continent = get_landmasses_for_sites(site_positions, world_data)

    return {
        description = description,
        world_name = world_name,
        site_count = count,
        continent = continent,
    }
end

--- Describe a single site's position on the world map.
--- Returns nil if no position data is available.
--- Otherwise returns a table:
---   { description = "the far northwestern region", world_name = "The World",
---     continent = "Great Forest", temperature = "cold, with heavy snowfall",
---     region_name = "Copper Mountains" }
function describe_site_position(site)
    if not site or not site.pos then return nil end
    local world_data = df.global.world.world_data
    if not world_data then return nil end
    local world_width = world_data.world_width or 1
    local world_height = world_data.world_height or 1
    if world_width <= 0 or world_height <= 0 then return nil end

    local world_name = get_readable_name(world_data.name) or "the world"

    -- Compass direction using 5x5 world grid
    local bx = math.max(0, math.min(4, math.floor(site.pos.x / world_width * 5)))
    local by = math.max(0, math.min(4, math.floor(site.pos.y / world_height * 5)))
    local dir_desc = "the " .. grid_direction_name(bx, by) .. " region"

    -- Region map data for biome, continent, temperature
    local region_ent = dfhack.maps.getRegionBiome(site.pos.x, site.pos.y)

    -- Continent name from landmass
    local continent = nil
    if region_ent and region_ent.landmass_id >= 0 then
        local lm = df.world_landmass.find(region_ent.landmass_id)
        if lm then
            local name = get_readable_name(lm.name)
            if name and name ~= "" then
                continent = name
            end
        end
    end

    -- Region/area name from world_region
    local region_name = nil
    if region_ent and region_ent.region_id >= 0 then
        local wr = df.world_region.find(region_ent.region_id)
        if wr then
            local rname = get_readable_name(wr.name)
            if rname and rname ~= "" then
                region_name = rname
            end
        end
    end

    -- Temperature description
    local temp_desc = nil
    if region_ent then
        local temp = region_ent.temperature
        local snowfall = region_ent.snowfall or 0

        if temp < 10000 then
            if snowfall > 500 then
                temp_desc = "frigid, with heavy snow"
            else
                temp_desc = "frigid"
            end
        elseif temp < 10100 then
            if snowfall > 500 then
                temp_desc = "very cold, with snow"
            elseif snowfall > 0 then
                temp_desc = "cold, with occasional snow"
            else
                temp_desc = "very cold"
            end
        elseif temp < 10300 then
            if snowfall > 300 then
                temp_desc = "cold, with snowfall"
            elseif snowfall > 0 then
                temp_desc = "cold, with light snow"
            else
                temp_desc = "cold"
            end
        elseif temp < 10500 then
            temp_desc = "cool"
        elseif temp < 10800 then
            temp_desc = "temperate"
        elseif temp < 11200 then
            temp_desc = "warm"
        elseif temp < 11600 then
            temp_desc = "hot"
        else
            temp_desc = "scorching"
        end
    end

    return {
        description = dir_desc,
        world_name = world_name,
        continent = continent,
        temperature = temp_desc,
        region_name = region_name,
    }
end
