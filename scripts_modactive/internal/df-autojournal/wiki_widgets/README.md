# HyperTextArea

A rich-text display and editing widget for DFHack, built on top of the existing
`TextArea` infrastructure but with support for per-character colors and links.

## Installation

Copy the files in `internal/df-autojournal/wiki_widgets/` into your project.

## Concept: Data-Driven Links

Unlike standard widgets that use Lua closures for click handlers, `HyperTextArea`
stores **data** (strings or tables) in its spans. This makes the entire content
serializable and persistent.

| Field          | Purpose |
|----------------|---------|
| `raw_text`     | Plain ASCII string. Used for layout and wrapping. |
| `display_text` | List of span tables (or plain strings). Drives rendering and behavior. |

---

## Span format

Each entry in `display_text` is either a plain string, a span table, or a table block:

```lua
-- Plain string
"Some plain text"

-- Span table
{
    text = "Click me",      -- required
    pen  = COLOR_LIGHTBLUE, -- optional
    link = "TargetPage",    -- optional: any serializable data
}

-- Table block (read-only, sortable, full-row table)
{
    type     = 'table',
    columns  = {
        { header = "Name", align = 'left',  width = 0, min_width = 5 },
        { header = "Age",  align = 'right', width = 0, min_width = 3 },
    },
    rows = {
        { { text = "Urist", link = "dwarf/1" }, { text = "127" } },
        { { text = "Mister" },                    { text = "45"  } },
    },
    sort_col = nil,    -- current sort column (nil = unsorted)
    sort_asc = true,   -- sort direction
    max_rows = 50,     -- max visible rows (nil = show all)
}
```

---

## Widget attributes

| Attribute       | Default           | Description |
|-----------------|-------------------|-------------|
| `on_text_change`| `nil`             | Called when content is edited |
| `on_link_click` | `nil`             | Called with link data when a link is clicked |
| `on_click`      | `nil`             | Fallback click handler for non-link text |

---

## Programmatic Usage

You can update the content at any time using `setDisplayText`. You don't need to manually calculate the `raw_text`; the widget handles it for you.

```lua
local editor = self.subviews.editor

editor:setDisplayText({
    { text = "Important: ", pen = COLOR_RED },
    "This is a ",
    { text = "Link to Home", pen = COLOR_LIGHTBLUE, link = "Main" },
    "\n",
    { text = "Click for Units", link = { type = "filter", target = "units" } }
})
```

### Tables

Tables support multi-column display, sorting (click column headers), and clickable cells.

```lua
editor:setDisplayText({
    "Your dwarfs:\n",
    {
        type = 'table',
        columns = {
            { header = 'Name', align = 'left',  min_width = 10 },
            { header = 'Age',  align = 'right', min_width = 4  },
        },
        rows = {
            { { text = 'Urist',  link = 'dwarf/1' }, { text = '127' } },
            { { text = 'Mister', link = 'dwarf/2' }, { text = '45'  } },
        },
        max_rows = 5,
    },
    "\nCtrl+Click a dwarf name to follow the link.",
})
```

You can also add a table programmatically at the current cursor position:

```lua
editor:addTable(
    {
        { header = 'Name', align = 'left', min_width = 10 },
        { header = 'Skill', align = 'left', min_width = 8 },
    },
    {
        { { text = 'Urist', link = 'dwarf/1' }, { text = 'Miner' } },
        { { text = 'Bob' },                      { text = 'Farmer' } },
    },
    { max_rows = 10 }
)
```

Column attributes:

| Field      | Default   | Description |
|------------|-----------|-------------|
| `header`   | `''`      | Column header text |
| `align`    | `'left'`  | `'left'`, `'right'`, or `'center'` (documented in UI as "left, right, center") |
| `width`    | `0`       | Fixed width (0 = auto from content) |
| `min_width`| `3`       | Minimum width when auto-calculating |
| `max_width` | `0`      | Maximum width (0 = no limit). Text beyond this is truncated. Also used to fit the table into available space. |
| `stretch`  | `false`   | When true, column expands to fill leftover horizontal space equally with other stretch columns. Ignored for fixed-width columns. Can exceed `max_width`. |

Table options:

| Field      | Default   | Description |
|------------|-----------|-------------|
| `sort_col` | `nil`     | Column index to sort by (nil = unsorted) |
| `sort_asc` | `true`    | Sort direction |
| `max_rows` | `nil`     | Max visible rows (excess hidden with "... and N more") |

### Editing Tables via the UI

Click the **▲** button in the left toolbar (two rows above the link § button) to
open the Table Editor:

- **Existing table**: the nearest table to the cursor is opened for editing.
- **No table exists**: a new table is created at the cursor position.

The editor has two sections:

**Columns** — one line per column in the format `header|align|stretch`:

```
Name|left|true
Age|right|false
Role|center|true
```

Valid align values: `left`, `right`, `center`.

**Data** — pipe-delimited rows (first row = headers for visual reference,
values start from the second row):

```
Name|Age|Role
Urist|127|Miner
Bob|45|Farmer
```

| Key | Action |
|-----|--------|
| `F2` | Save and close |
| `Esc` | Discard and close |

### Span Formatting Details

*   **Colors**: Use standard DFHack color constants (e.g., `COLOR_RED`, `COLOR_LIGHTCYAN`).
*   **Links**: The `link` property can be a simple string (useful for page names) or a table of data (useful for specific IDs or types).
*   **Central Handling**: When a link is clicked, the widget triggers the `on_link_click` callback you provided during initialization.

---

## Function Blocks

In addition to plain strings, span tables, and table blocks, `display_text` supports
**function blocks** — dynamic, evaluated snippets that are re-computed each time the
editor renders:

```lua
-- Function block (evaluated at render time)
{
    type   = 'function',
    fn_key = 'dwarf_age',
    args   = { birth_year = 250, unit_id = 42 },
}
```

| Field    | Required | Description |
|----------|----------|-------------|
| `type`   | yes      | Must be `'function'` |
| `fn_key` | yes      | Registered function key (see registry below) |
| `args`   | yes      | Table of arguments matching the function's `args_schema` |

### Toolbar Button

Click the **Σ** (Sigma) button at the bottom of the left toolbar (3rd from bottom,
above the ▲ table button) to open the **Insert Function** modal.

### HTA Attributes

To wire up functions, set these attributes on your `HyperTextArea`:

| Attribute       | Type     | Description |
|-----------------|----------|-------------|
| `fn_functions`  | `table`  | List from `wiki_functions.list_functions()` — drives the modal's function list |
| `fn_evaluator`  | `function(fn_block) → string` | Called at render time to compute the function's output |
| `fn_context`    | `table`  | Pre-filled argument values passed to the function modal (e.g. `{ unit_id = 123 }`) |

```lua
local wiki_functions = reqscript('internal/df-autojournal/wiki_functions')

-- In your HyperTextArea definition:
HyperTextArea {
    fn_functions = wiki_functions.list_functions(),
    fn_evaluator = function(fn_block)
        return wiki_functions.evaluate(fn_block)
    end,
    fn_context = { unit_id = 123, birth_year = 250 },
}
```

### The Function Modal

Pressing **Σ** or calling `editor:openFunctionModal()` opens a `ZScreen` modal with:

- **Function list** — scrollable choices of all registered functions
- **Description label** — shows the selected function's description
- **Argument fields** — dynamic `EditField` widgets generated from the function's
  `args_schema`, pre-filled from `fn_context` where matching keys exist
- **Submit** — `Enter` collects args and calls `on_submit(fn_key, args)`
- **Cancel** — `Esc` dismisses

On submit, the widget calls `hyper_text_area:insertFunctionBlock(fn_key, args)`,
which evaluates the function, inserts the result as `COLOR_GREEN` text at the
cursor, and tracks the block in `fn_blocks` for future re-evaluation.

### Evaluation & Rendering

Function blocks are evaluated at two points:

1. **Content insertion** — `insertFunctionBlock()` evaluates immediately to insert
   the correct number of characters into the `char_list`.
2. **Render / rebuild** — both `HyperWrappedText:update()` and
   `rebuild_display_text()` re-evaluate each function block via `fn_evaluator`,
   updating the output whenever the widget re-renders.

Function output is always displayed in **`COLOR_GREEN`**.

The widget maintains a `fn_blocks` array tracking `{ pos, fn_key, args, len }`
for each function block. Positions are adjusted on insert/delete, and overlapping
blocks are destroyed when text is edited over them (the function block is lost
when its output range is modified — re-insert it if needed).

### Built-in Functions

| fn_key | Label | Args | Description |
|--------|-------|------|-------------|
| `dwarf_age` | Dwarf Age | `birth_year` (num, req), `unit_id` (num) | Current age in years (or months for children) |
| `current_profession` | Current Profession | `unit_id` (num, req) | Profession/nickname of the dwarf |
| `current_skills` | Current Skills | `unit_id` (num, req) | All skills with rating and title |
| `current_needs` | Current Needs | `unit_id` (num, req) | Unmet needs and desires |
| `current_health` | Current Health | `unit_id` (num, req) | Health status and injury count |
| `current_mood` | Current Mood | `unit_id` (num, req) | Current mood/emotional state |
| `population_count` | Fort Population | *(none)* | Number of citizen units |
| `fort_wealth` | Fort Wealth | *(none)* | Total fortress wealth in ☼ |

### fn_context Pre-fill

The `fn_context` attribute is updated per-page by the parent screen. Built-in pre-fills:

| Page Type | Context Keys |
|-----------|-------------|
| `citizen:<id>` | `unit_id` (the unit's ID), `birth_year` (from `unit.birth_year`) |
| `artifact:<id>` | `item_id` (the item's ID) |

This means when a user opens a citizen's page and clicks **Σ**, the Dwarf Age
function's `birth_year` and `unit_id` fields are already filled in automatically.

### Checking for Function Blocks in Code

```lua
local HUtils = reqscript('internal/df-autojournal/wiki_widgets/hta_utils')
if HUtils.is_function_block(entry) then
    -- entry is { type='function', fn_key=..., args=... }
end
```

---

## Implementing Navigation & Persistence

To support multiple pages and ensure changes are saved when clicking links, you should use a "Context" pattern outside the widget.

1.  **Define a Link**: Create a span with a `link` property (e.g., a page name).
2.  **Catch the Click**: Use the `on_link_click` callback to save the current page and load the new one.
3.  **Global Persistence**: Use `HTAContext` to save data to a JSON file, ensuring it survives restarts. (or use your own!)

#### Example Navigation Pattern:

```lua
-- In your script module level
local global_context = HTAContext{} -- <-- Or use your own context

-- In your Screen:init
self.current_page = "Main"
self.context = global_context

-- In your HyperTextArea definition
on_link_click = function(page_id)
    -- Save current page
    self.context:save_content(self.current_page, self.subviews.editor.display_text, self.subviews.editor.hyper_text_area.cursor)
    
    -- Load and show new page
    self.current_page = page_id
    local data, cursor = self.context:load_content(page_id)
    self.subviews.editor:setDisplayText(data)
end
```

This ensures that "clicking a link" isn't just a UI jump, but a data-aware transition that persists the user's edits to disk.
