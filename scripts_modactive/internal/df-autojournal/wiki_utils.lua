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
        description = "spans the entire world"
    elseif x_all then
        description = "spans the " .. range_name(yi, Y_NAMES, "northern half", "southern half") .. " of the world"
    elseif y_all then
        description = "spans the " .. range_name(xi, X_NAMES, "western half", "eastern half") .. " across the world"
    elseif x_only and y_only then
        if X_NAMES[xi[1] + 1] == "central" and Y_NAMES[yi[1] + 1] == "central" then
            description = "the central region of the world"
        elseif X_NAMES[xi[1] + 1] == "central" then
            description = "the central " .. Y_NAMES[yi[1] + 1] .. " region"
        else
            description = "the " .. X_NAMES[xi[1] + 1] .. " " .. Y_NAMES[yi[1] + 1] .. " region"
        end
    elseif x_only then
        local x_part = x_adj(X_NAMES[xi[1] + 1])
        local y_part = range_name(yi, Y_NAMES, "northern half", "southern half")
        if #yi == 2 and yi[1] == 0 and yi[#yi] == 1 then
            description = "the " .. x_part .. " " .. y_part .. " region"
        elseif #yi == 2 and yi[1] == 3 and yi[#yi] == 4 then
            description = "the " .. x_part .. " " .. y_part .. " region"
        elseif #yi <= 2 then
            description = "the " .. x_part .. " " .. y_part .. " region"
        else
            description = "the " .. x_part .. " region, spanning " .. y_part
        end
    elseif y_only then
        local x_part = range_name(xi, X_NAMES, "western half", "eastern half")
        local y_name = Y_NAMES[yi[1] + 1]
        if #xi <= 2 then
            description = "the " .. x_part .. " " .. y_name .. " region"
        elseif xi[1] == 0 and xi[#xi] == 2 then
            description = "the " .. x_part .. " " .. y_name .. " region"
        elseif xi[1] == 2 and xi[#xi] == 4 then
            description = "the " .. x_part .. " " .. y_name .. " region"
        else
            description = "the " .. x_part .. " of the " .. y_name .. " region"
        end
    else
        local x_part = range_name(xi, X_NAMES, "western half", "eastern half")
        local y_part = range_name(yi, Y_NAMES, "northern half", "southern half")
        if x_part:match("^half") or y_part:match("^half") then
            description = "spans " .. x_part .. ", covering " .. y_part
        else
            description = "spans " .. x_part .. ", reaching " .. y_part
        end
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
