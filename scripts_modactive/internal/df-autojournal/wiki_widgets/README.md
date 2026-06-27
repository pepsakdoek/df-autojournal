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
