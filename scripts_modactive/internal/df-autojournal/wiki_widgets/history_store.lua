--@module = true
-- history_store.lua
--
-- Manages undo/redo history for HyperTextArea.
--


HistoryStore = defclass(HistoryStore)
HistoryStore.HISTORY_ENTRY = {
    TEXT_BLOCK = 1,
    WHITESPACE_BLOCK = 2,
    BACKSPACE = 3,
    DELETE = 4,
    OTHER = 5
}
local HISTORY_ENTRY = HistoryStore.HISTORY_ENTRY
HistoryStore.ATTRS{
    history_size = 25,
}

function HistoryStore:init()
    self.past = {}
    self.future = {}
end

function HistoryStore:store(entry_type, char_list, cursor)
    local last_entry = self.past[#self.past]
    if not last_entry or entry_type == HISTORY_ENTRY.OTHER or
       last_entry.entry_type ~= entry_type then
        table.insert(self.past, {
            entry_type = entry_type,
            char_list  = copyall(char_list),
            cursor     = cursor
        })
    end
    self.future = {}
    if #self.past > self.history_size then
        table.remove(self.past, 1)
    end
end

function HistoryStore:undo(curr_char_list, curr_cursor)
    if #self.past == 0 then return nil end
    local entry = table.remove(self.past, #self.past)
    table.insert(self.future, {
        entry_type = HISTORY_ENTRY.OTHER,
        char_list  = copyall(curr_char_list),
        cursor     = curr_cursor
    })
    return entry
end

function HistoryStore:redo(curr_char_list, curr_cursor)
    if #self.future == 0 then return nil end
    local entry = table.remove(self.future, #self.future)
    table.insert(self.past, {
        entry_type = HISTORY_ENTRY.OTHER,
        char_list  = copyall(curr_char_list),
        cursor     = curr_cursor
    })
    return entry
end

return HistoryStore
