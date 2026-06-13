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
    local replacements = {
        ["ù"]="u", ["û"]="u", ["Å"]="A", ["è"]="e", ["î"]="i", ["é"]="e",
        ["ë"]="e", ["ï"]="i", ["ô"]="o", ["ö"]="o", ["ò"]="o", ["ü"]="u", ["ÿ"]="y"
    }
    str = str:gsub("[%z\128-\255]", replacements)
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
