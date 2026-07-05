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
                    frame = {l=0, r=0, b=6, h=1},
                    frame_style_l = false,
                    frame_style_r = false,
                    interior_l = true,
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

    local schema = choice.args_schema or {}
    -- Build comma-separated default values from context
    local defaults = {}
    for _, arg in ipairs(schema) do
        local val = ''
        if self.context and self.context[arg.key] ~= nil then
            val = tostring(self.context[arg.key])
        end
        table.insert(defaults, val)
    end

    -- Single-row arg input: "Args:" label + comma-delimited EditField
    for _, sv in ipairs(self.arg_panel.subviews) do
        sv.parent = nil
    end
    self.arg_panel.subviews = {}
    self.arg_panel.frame.h = 1
    self.arg_panel.frame.b = 1

    local arg_label = widgets.Label{
        frame = {l=0},
        text = 'Args: ',
        text_pen = COLOR_LIGHTCYAN,
    }
    arg_label.parent = self.arg_panel
    table.insert(self.arg_panel.subviews, arg_label)

    local arg_input = widgets.EditField{
        view_id = 'arg_input',
        frame = {l=6, r=0},
        text = table.concat(defaults, ', '),
    }
    arg_input.parent = self.arg_panel
    table.insert(self.arg_panel.subviews, arg_input)
    self.arg_input = arg_input

    -- Fixed positions: arg_panel is 1 row at b=1, desc_label sits above it
    self.desc_label.frame.b = 3
    self.desc_label.frame.h = 2
    self.fn_list.frame.b = 6

    self.arg_panel:updateLayout()
    self.desc_label:updateLayout()
    self.fn_list:updateLayout()
end

function FunctionModal:collect_args()
    if not self.selected_fn then return nil end
    local schema = self.selected_fn.args_schema or {}
    if #schema == 0 then
        return self.selected_fn.fn_key, {}
    end
    local raw = self.arg_input and self.arg_input.text or ''
    local parts = {}
    for p in raw:gmatch('[^,]+') do
        local trimmed = p:match('^%s*(.-)%s*$')
        table.insert(parts, trimmed)
    end
    local args = {}
    for i, arg in ipairs(schema) do
        local val = parts[i] or ''
        if arg.type == 'number' then
            val = tonumber(val)
        end
        args[arg.key] = val
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
