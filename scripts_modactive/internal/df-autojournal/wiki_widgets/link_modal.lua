--@module = true
-- link_modal.lua
--
-- A modal dialog for inserting links into HyperTextArea.
--

local gui = require('gui')
local widgets = require('gui.widgets')

LinkModal = defclass(LinkModal, gui.ZScreen)
LinkModal.ATTRS {
    on_submit = DEFAULT_NIL,
    pages = DEFAULT_NIL,
}

function LinkModal:init()
    local pages = self.pages or {"Civilisation", "Fort", "Citizens", "Artifacts", "Events", "Constructions", "Main"}
    local choices = {}
    for _, p in ipairs(pages) do
        table.insert(choices, {text=p.text or p, id=p.id or p})
    end
    
    self.text_input = widgets.EditField{
        frame = {t=1, l=0, r=0},
        text = ""
    }
    
    self.page_list = widgets.List{
        frame = {t=4, l=0, r=0, b=2},
        choices = choices,
    }

    self:addviews{
        widgets.Window{
            frame = {w=40, h=20},
            frame_title = "Insert Link",
            subviews = {
                widgets.Label{
                    frame = {t=0, l=0},
                    text = "Display Text:"
                },
                self.text_input,
                widgets.Label{
                    frame = {t=3, l=0},
                    text = "Select Page:"
                },
                self.page_list,
                widgets.Label{
                    frame = {b=0, l=0},
                    text = "Enter: Insert | Esc: Cancel",
                    pen = COLOR_GREY
                }
            }
        }
    }
end

function LinkModal:onInput(keys)
    if keys.SELECT then
        local text = self.text_input.text
        local sel = self.page_list:getSelected()
        local choices = self.page_list:getChoices()
        local choice = choices[sel]
        local page = choice and (choice.id or choice.text or choice) or ""
        if #text == 0 then text = page end
        if self.on_submit then self.on_submit(text, page) end
        self:dismiss()
        return true
    end
    if keys.LEAVESCREEN then
        self:dismiss()
        return true
    end
    return LinkModal.super.onInput(self, keys)
end

return LinkModal
