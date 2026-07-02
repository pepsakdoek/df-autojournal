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
            frame = {w=50, h=24},
            frame_title = 'Insert Function',
            subviews = {
                widgets.Label{
                    frame = {t=0, l=0},
                    text = 'Select Function:',
                },
                self.fn_list,
                self.desc_label,
                self.arg_panel,
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
    self.arg_panel.subviews = subviews
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
