--@module = true
-- hyper_wrapped_text.lua
--
-- Like WrappedText, but operates on a mixed display_text / raw_text pair.
--
-- display_text is a list of span tables (or plain strings):
--   { text = "some text", pen = COLOR_WHITE, on_click = function() end }
--   Plain strings are treated as spans with no special pen or click handler.
--
-- raw_text is the plain ASCII equivalent of display_text concatenated.
-- It MUST match the visible character sequence of display_text exactly so
-- that wrapping widths and mouse-to-index conversion are correct.
--
-- After :update() the public fields are:
--   self.lines        -- array of raw line strings (same as WrappedText.lines)
--   self.line_spans   -- array (indexed by line number) of span-fragment lists
--                        Each fragment: { text, pen, on_click }

HyperWrappedText = defclass(HyperWrappedText)

HyperWrappedText.ATTRS {
    raw_text     = '',
    display_text = {},   -- list of span tables or plain strings
    wrap_width   = math.huge,
}

function HyperWrappedText:init()
    self:update(self.raw_text, self.display_text, self.wrap_width)
end

-- ---------------------------------------------------------------------------
-- helpers
-- ---------------------------------------------------------------------------

-- Normalise a display_text entry into a canonical span table.
local function to_span(entry)
    if type(entry) == 'string' then
        return { text = entry, pen = nil, on_click = nil }
    end
    return {
        text     = entry.text     or '',
        pen      = entry.pen      or nil,
        on_click = entry.on_click or nil,
    }
end

-- Build a flat list of character-level records from display_text spans.
-- Each record: { char, pen, on_click }
-- This makes per-character reassembly during line splitting trivial.
local function build_char_list(display_text)
    local chars = {}
    for _, entry in ipairs(display_text) do
        local span = to_span(entry)
        for i = 1, #span.text do
            chars[#chars + 1] = {
                char     = span.text:sub(i, i),
                pen      = span.pen,
                on_click = span.on_click,
            }
        end
    end
    return chars
end

-- Collapse a run of adjacent chars that share the same pen/on_click into
-- a single fragment.  Returns a list of { text, pen, on_click }.
local function collapse_chars(char_run)
    local frags = {}
    local cur = nil
    for _, c in ipairs(char_run) do
        if cur and cur.pen == c.pen and cur.on_click == c.on_click then
            cur.text = cur.text .. c.char
        else
            cur = { text = c.char, pen = c.pen, on_click = c.on_click }
            frags[#frags + 1] = cur
        end
    end
    return frags
end

-- ---------------------------------------------------------------------------
-- main update
-- ---------------------------------------------------------------------------

function HyperWrappedText:update(raw_text, display_text, wrap_width)
    self.raw_text     = raw_text
    self.display_text = display_text
    self.wrap_width   = wrap_width

    -- 1. Wrap raw_text exactly like WrappedText does.
    self.lines = raw_text:wrap(
        wrap_width,
        {
            return_as_table        = true,
            keep_trailing_spaces   = true,
            keep_original_newlines = true,
        }
    )

    -- 2. Build a per-character decoration list from display_text.
    local char_list = build_char_list(display_text)

    -- 3. Walk lines and slice char_list into matching fragments.
    --    We advance a global character index through char_list.
    self.line_spans = {}
    local char_idx = 1

    for _, raw_line in ipairs(self.lines) do
        local line_len  = #raw_line
        local line_chars = {}
        for _ = 1, line_len do
            line_chars[#line_chars + 1] = char_list[char_idx] or
                { char = ' ', pen = nil, on_click = nil }
            char_idx = char_idx + 1
        end
        self.line_spans[#self.line_spans + 1] = collapse_chars(line_chars)
    end
end

-- ---------------------------------------------------------------------------
-- coordinate conversion (identical logic to WrappedText)
-- ---------------------------------------------------------------------------

function HyperWrappedText:coordsToIndex(x, y)
    local offset = 0
    local normalized_y = math.max(1, math.min(y, #self.lines))
    local line_bonus   = normalized_y == #self.lines and 1 or 0
    local normalized_x = math.max(
        1,
        math.min(x, #self.lines[normalized_y] + line_bonus)
    )
    for i = 1, normalized_y - 1 do
        offset = offset + #self.lines[i]
    end
    return offset + normalized_x
end

function HyperWrappedText:indexToCoords(index)
    local offset = index
    for y, line in ipairs(self.lines) do
        local line_bonus = y == #self.lines and 1 or 0
        if offset <= #line + line_bonus then
            return offset, y
        end
        offset = offset - #line
    end
    return #self.lines[#self.lines] + 1, #self.lines
end

-- ---------------------------------------------------------------------------
-- hit-test: given (x, y) in wrapped-text coordinates, return the on_click
-- handler of the span fragment under that position, or nil.
-- ---------------------------------------------------------------------------

function HyperWrappedText:getClickHandlerAt(x, y)
    local norm_y = math.max(1, math.min(y, #self.line_spans))
    local frags  = self.line_spans[norm_y]
    if not frags then return nil end

    local col = 0
    for _, frag in ipairs(frags) do
        local frag_end = col + #frag.text
        if x > col and x <= frag_end then
            return frag.on_click
        end
        col = frag_end
    end
    return nil
end

return HyperWrappedText
