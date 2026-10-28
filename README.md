# bujo.nvim

A bullet journal for Neovim. Entries are logged by day in plain text files and
shown in a floating window, a two-page spread, or a side panel.

```
2026-10-20 ------------------------------------- tuesday
× call mom
› fix bike
~• cancelled thing
– coffee was good
▽ standup 10am
▷ dentist next tue
• buy milk
```

Requires Neovim 0.11+.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "j-chau/bujo.nvim",
  cmd = "Bujo",
  opts = {},
}
```

`setup()` is optional; call it only to change the defaults.

## Usage

| Command | Opens |
| --- | --- |
| `:Bujo` / `:Bujo today` | Today in a floating window |
| `:Bujo spread` | The previous day and today side by side |
| `:Bujo side` | Toggles the side panel |
| `:Bujo open [YYYY-MM-DD]` | A day's raw file for editing (default today) |

The same views are available from Lua: `require("bujo").today()`, `.spread()`,
`.side()` and `.open(date)`.

### Views

- **Today** shows today's entries, with the cursor on the newest one.
- **Spread** shows the latest earlier day with a file on the left (or the
  calendar day before, if there is none) and today on the right. Below
  `float.min_spread_width` columns the pages stack vertically.
- **Side panel** shows today and the last `side_days - 1` earlier days that
  have a file, oldest at the top, scrolled to the bottom. Above them it lists
  open tasks from older days, going back `side_lookback_days` days. A task
  there disappears once it is completed, cancelled or migrated.

Views are read-only; every change goes through a keymap. Changes in one view
show up in every open view.

### Keymaps

| Key | Action |
| --- | --- |
| `x` | Complete the task under the cursor |
| `c` | Cancel the task or event under the cursor |
| `m` | Migrate the task under the cursor |
| `r` | Reopen (undo complete, cancel or migrate) |
| `t` / `n` / `e` / `E` | Add a task / note / event / future event to today |
| `a` | Choose an entry type, then add it to today |
| `gf` | Open the day file under the cursor |
| `<Tab>` | Switch pages in the spread |
| `q` / `<Esc>` | Close the view |

Migrating a task from today adds it to tomorrow; migrating a task from an
earlier day adds it to today. Either way the original becomes `›`.

New entries always go to today, whichever page or day the cursor is on.

## File format

Each day is a file at `<data_dir>/YYYY/YYYY-MM-DD.md`, one entry per line:

| Line | Meaning |
| --- | --- |
| `• text` | Task |
| `× text` | Completed task |
| `› text` | Migrated task |
| `– text` | Note |
| `▽ text` | Event today |
| `▷ text` | Future event |
| `~• text` / `~▽ text` / `~▷ text` | Cancelled task or event (shown struck through) |

The files are meant to be edited by hand too (`gf` or `:Bujo open`):

- `* text` and a missing space after the glyph (`•text`) are read as `• text`.
- Entries with no text are dropped.
- Any other line is kept as it is and shown dimmed, with no actions.

Files are written with LF line endings, through a temp file and a rename.

## Configuration

Defaults:

```lua
require("bujo").setup({
  data_dir = vim.fn.stdpath("data") .. "/bujo",
  -- Days with a file shown in full in the side panel, including today.
  side_days = 7,
  -- How many days back the side panel lists open tasks; 0 for none.
  side_lookback_days = 30,
  side_width = 50,
  float = {
    width = 60,
    height = 0.7, -- fraction of the editor height
    border = "rounded",
    min_spread_width = 80,
  },
  keymaps = {
    complete = "x",
    cancel = "c",
    migrate = "m",
    reopen = "r",
    add = "a",
    add_task = "t",
    add_note = "n",
    add_event = "e",
    add_future = "E",
    open_file = "gf",
    switch_page = "<Tab>",
    close = { "q", "<Esc>" },
  },
})
```

### Highlights

| Group | Default | Used for |
| --- | --- | --- |
| `BujoHeader` | `Title` | Day headers |
| `BujoRule` | `NonText` | The dashes in day headers |
| `BujoGlyph` | `Special` | Glyphs of open entries |
| `BujoDone` | `Comment` | Completed and migrated tasks |
| `BujoCancelled` | `Comment` + strikethrough | Cancelled entries |
| `BujoRaw` | `Comment` | Lines that aren't entries |
| `BujoEmpty` | `Comment` | The "no entries" placeholder |

Strikethrough needs terminal support. If yours lacks it, override
`BujoCancelled`.

## Fonts

Some fonts draw `•`, `▽` and `▷` as double width or with ambiguous width,
which throws off alignment. If entries look misaligned, try another font or
set `:set ambiwidth=single`.

## Tests

```sh
scripts/test.sh                     # all specs
scripts/test.sh tests/side_spec.lua # one spec
```

Uses [plenary.nvim](https://github.com/nvim-lua/plenary.nvim), found at
`$PLENARY_DIR`, `.tests/plenary.nvim` or lazy.nvim's data directory, or cloned
into `.tests/`.
