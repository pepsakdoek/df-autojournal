--@ module = true

local utils = {}

function utils.sanitize(str)
    if not str then return "" end
    -- Convert from DF's internal encoding to UTF-8
    local utf8_str = dfhack.df2utf(str)
    -- Project mandate: replace em-dashes and en-dashes with -
    -- em-dash (—) is \xE2\x80\x94 in UTF-8
    -- en-dash (–) is \xE2\x80\x93 in UTF-8
    utf8_str = utf8_str:gsub("\226\128\148", "-"):gsub("\226\128\147", "-")
    return utf8_str
end

function utils.get_date_str()
    return tostring(df.global.cur_year) .. "-" .. tostring(df.global.cur_year_tick)
end

return utils
