--@ module = true

-- Sanitize converts from DF's internal CP437 to UTF-8 for storage/JSON
function sanitize(str)
    if not str then return "" end
    local utf8_str = dfhack.df2utf(str)
    -- Project mandate: replace em-dashes and en-dashes with -
    utf8_str = utf8_str:gsub("\226\128\148", "-"):gsub("\226\128\147", "-")
    return utf8_str
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
