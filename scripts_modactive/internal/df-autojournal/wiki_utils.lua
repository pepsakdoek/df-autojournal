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

-- Sanitize content that can be either a string or a display_text array
function sanitize_content(content)
    if type(content) == 'string' then
        return sanitize(content)
    elseif type(content) == 'table' then
        local result = {}
        for _, span in ipairs(content) do
            if type(span) == 'string' then
                table.insert(result, sanitize(span))
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
