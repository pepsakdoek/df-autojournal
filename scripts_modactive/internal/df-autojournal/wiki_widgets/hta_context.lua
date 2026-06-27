--@module = true
-- hta_context.lua
--
-- A persistence handler for HyperTextArea using dfhack.persistent for per-save storage.
--

HTAContext = defclass(HTAContext)
HTAContext.ATTRS{
    save_prefix = 'wiki_widgets_p:', -- Versioned prefix to avoid collisions
}

function HTAContext:get_page_key(page_id)
    return self.save_prefix .. page_id
end

function HTAContext:save_content(page_id, display_text, cursor)
    if not page_id or not dfhack.isWorldLoaded() then return end
    
    -- Save to the current fortress/site data (strictly per-save)
    dfhack.persistent.saveSiteData(
        self:get_page_key(page_id),
        { content = display_text, cursor = {cursor} }
    )
end

function HTAContext:load_content(page_id)
    if not page_id or not dfhack.isWorldLoaded() then return nil end
    
    local data = dfhack.persistent.getSiteData(self:get_page_key(page_id))
    if data then
        return data.content, (data.cursor and data.cursor[1] or 1)
    end
    return nil
end

function HTAContext:delete_content(page_id)
    if dfhack.isWorldLoaded() then
        dfhack.persistent.deleteSiteData(self:get_page_key(page_id))
    end
end

return HTAContext
