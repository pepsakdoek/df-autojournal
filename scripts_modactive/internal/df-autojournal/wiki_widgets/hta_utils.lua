--@module = true
-- hyper_text_area_utils.lua
--
-- Shared utility functions for HyperTextArea.
--


-- Normalise a display_text entry into a canonical span table.
function to_span(entry)
    if type(entry) == 'string' then
        return { text = entry, pen = nil, link = nil }
    end
    if entry.type == 'table' then
        return entry  -- pass through table blocks unmodified
    end
    return {
        text = entry.text or '',
        pen  = entry.pen  or nil,
        link = entry.link or nil,
    }
end

-- Return true if the display_text entry is a table block.
function is_table_block(entry)
    -- type(entry) == 'table' is it a LUA table and is it our HTA type 'table'
    return type(entry) == 'table' and entry.type == 'table'
end

-- Return true if the display_text entry is a function block.
function is_function_block(entry)
    -- type(entry) == 'table' is it a LUA table and is it our HTA type 'function'
    return type(entry) == 'table' and entry.type == 'function'
end

-- Build a flat list of character-level records from display_text spans.
-- Table blocks are skipped (they are handled separately by the renderer).
function build_char_list(display_text)
    local chars = {}
    for _, entry in ipairs(display_text) do
        if not is_table_block(entry) then
            local span = to_span(entry)
            for i = 1, #span.text do
                chars[#chars + 1] = {
                    char = span.text:sub(i, i),
                    pen  = span.pen,
                    link = span.link,
                }
            end
        end
    end
    return chars
end

-- Collapse a run of adjacent chars that share the same pen/link into
-- a single fragment.
function collapse_chars(char_list)
    local frags = {}
    local cur = nil
    for _, c in ipairs(char_list) do
        local links_match = false
        if cur then
            if type(cur.link) == 'table' and type(c.link) == 'table' then
                -- Shallow compare for tables should be enough for simple data
                links_match = true
                for k, v in pairs(cur.link) do
                    if c.link[k] ~= v then links_match = false; break end
                end
                for k, v in pairs(c.link) do
                    if cur.link[k] ~= v then links_match = false; break end
                end
            else
                links_match = (cur.link == c.link)
            end
        end

        if cur and cur.pen == c.pen and links_match then
            cur.text = cur.text .. c.char
        else
            cur = { text = c.char, pen = c.pen, link = c.link }
            frags[#frags + 1] = cur
        end
    end
    return frags
end

-- Convert a list of char objects back to a raw string.
function char_list_to_raw(char_list)
    local t = {}
    for _, c in ipairs(char_list) do
        t[#t+1] = c.char
    end
    return table.concat(t)
end
