--@module = true
-- function_modal.lua
--
-- A modal dialog for inserting function blocks into HyperTextArea.
-- Displays available functions from the registry and lets the user
-- configure arguments before inserting.

local gui = require('gui')
local widgets = require('gui.widgets')

FunctionModal = defclass(FunctionModal, gui.ZScreen)
FunctionModal.ATTRS {
    functions     = {},
    context       = {},  -- pre-filled arg values like { unit_id=123 }
    on_submit     = DEFAULT_NIL,
}

function FunctionModal:init()
    self.selected_fn = nil
    self.arg_fields = {}

    self.fn_list = widgets.List{
        frame = {t=1, l=0, r=0, b=8},
        choices = self:build_fn_choices(),
        on_submit = function(idx) self:onFunctionSelected(idx) end,
    }

    self.desc_label = widgets.Label{
        view_id = 'desc_label',
        frame = {b=5, l=0, r=0, h=2},
        text = '',
        text_pen = COLOR_GREY,
    }

    self.arg_panel = widgets.Panel{
        view_id = 'arg_panel',
        frame = {b=1, l=0, r=0, h=3},
    }

    self:addviews{
        widgets.Window{
            frame = {w=60, h=28},
            frame_title = 'Insert Function',
            resizable = true,
            resize_min = {w=50, h=20},
            subviews = {
                widgets.Label{
                    frame = {t=0, l=0},
                    text = 'Select Function:',
                },
                self.fn_list,
                self.desc_label,
                self.arg_panel,
                widgets.Divider{
                    frame = {b=9, l=0, r=0},
                },
                widgets.Label{
                    frame = {b=0, l=0},
                    text = 'Enter: Insert | Esc: Cancel',
                    pen = COLOR_GREY,
                },
            }
        }
    }
end

function FunctionModal:build_fn_choices()
    local choices = {}
    for _, fn in ipairs(self.functions) do
        table.insert(choices, {
            text = fn.label,
            fn_key = fn.fn_key,
            description = fn.description,
            args_schema = fn.args_schema,
        })
    end
    return choices
end

function FunctionModal:onFunctionSelected(idx)
    local choices = self.fn_list:getChoices()
    local choice = choices[idx]
    if not choice then return end

    self.selected_fn = choice
    self.desc_label:setText(choice.description or '')

    self.arg_fields = {}
    local schema = choice.args_schema or {}
    local n = #schema
    local subviews = {}
    for i, arg in ipairs(schema) do
        local label = arg.label or arg.key
        -- Pre-fill from context if a matching key exists
        local default_val = ''
        if self.context and self.context[arg.key] ~= nil then
            default_val = tostring(self.context[arg.key])
        end
        table.insert(subviews, widgets.Label{
            frame = {t=i-1, l=0},
            text = label .. ': ',
            text_pen = COLOR_LIGHTCYAN,
        })
        local field = widgets.EditField{
            view_id = 'arg_' .. arg.key,
            frame = {t=i-1, l=#label + 3, r=0},
            text = default_val,
        }
        table.insert(subviews, field)
        self.arg_fields[arg.key] = field
    end

    -- Properly replace subviews: set parent, call updateLayout
    for _, sv in ipairs(self.arg_panel.subviews) do
        sv.parent = nil
    end
    self.arg_panel.subviews = {}
    for _, sv in ipairs(subviews) do
        sv.parent = self.arg_panel
        table.insert(self.arg_panel.subviews, sv)
    end
    local panel_h = math.max(2, n + 1)
    self.arg_panel.frame.h = panel_h
    self.arg_panel.frame.b = 1

    -- Shift siblings to fit the resized panel
    self.desc_label.frame.b = panel_h + 2
    self.desc_label.frame.h = 2
    self.fn_list.frame.b = panel_h + 5

    self.arg_panel:updateLayout()
    self.desc_label:updateLayout()
    self.fn_list:updateLayout()
end

function FunctionModal:collect_args()
    local args = {}
    if not self.selected_fn then return nil end
    local schema = self.selected_fn.args_schema or {}
    for _, arg in ipairs(schema) do
        local field = self.arg_fields[arg.key]
        if field then
            local val = field.text
            if arg.type == 'number' then
                val = tonumber(val)
            end
            args[arg.key] = val
        end
    end
    return self.selected_fn.fn_key, args
end

function FunctionModal:onInput(keys)
    if keys.SELECT then
        local fn_key, args = self:collect_args()
        if fn_key and self.on_submit then
            self.on_submit(fn_key, args)
        end
        self:dismiss()
        return true
    end
    if keys.LEAVESCREEN then
        self:dismiss()
        return true
    end
    if keys._MOUSE_L then
        local mx, my = self:getMousePos()
        if self.fn_list:onInput(keys) then return true end
    end
    return FunctionModal.super.onInput(self, keys)
end

return FunctionModal
