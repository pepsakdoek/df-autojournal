--@ module = true

-- Helper to safely get the current civilization ID
function get_civ_id()
    if dfhack.world.getCivId then
        return dfhack.world.getCivId()
    end
    -- Fallback to plot_info for v50
    if df.global.plot_info then
        return df.global.plot_info.civ_id
    end
    -- Legacy/Alternative
    return df.global.ui.civ_id
end

-- Helper to safely get the current site ID
function get_site_id()
    if dfhack.world.getSiteId then
        return dfhack.world.getSiteId()
    end
    -- Fallback to plot_info for v50
    if df.global.plot_info then
        return df.global.plot_info.site_id
    end
    -- Legacy/Alternative
    return df.global.ui.site_id
end

-- Safely translate a DF name structure
function translate_name(name)
    if not name then return "" end
    local translated = ""
    -- Use dfhack.TranslateName if available (standard)
    if dfhack.TranslateName then
        translated = dfhack.TranslateName(name)
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
    if not str then return "" end
    -- Check if str is already a string
    if type(str) ~= "string" then
        str = tostring(str)
    end
    local utf8_str = dfhack.df2utf(str)
    -- Project mandate: replace em-dashes and en-dashes with -
    utf8_str = utf8_str:gsub("\226\128\148", "-"):gsub("\226\128\147", "-")
    return utf8_str
end

-- Helper that combines translation and sanitization
function get_readable_name(name)
    return sanitize(translate_name(name))
end

-- Convert UTF-8 (from storage) to CP437 (for UI display)
function to_ui(str)
    if not str then return "" end
    return dfhack.utf2df(str)
end

-- Convert CP437 (from UI) to UTF-8 (for storage)
function from_ui(str)
    if not str then return "" end
    return dfhack.df2utf(str)
end

function get_date_str()
    return tostring(df.global.cur_year) .. "-" .. tostring(df.global.cur_year_tick)
end
