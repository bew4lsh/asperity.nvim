# asperity.nvim

Neovim plugin that converts markdown to inline-styled HTML and copies it to your system clipboard. Paste directly into Microsoft Teams, Outlook, Gmail, or any rich-text target — no raw markup, no broken formatting.

## How it works

```
 Buffer (markdown) → Parser (GFM → HTML) → Inline CSS injection → Clipboard (text/html)
```

The plugin converts markdown to HTML and attaches `style=""` attributes to every element. No `<style>` blocks, no `<link>` tags — just inline styles that email clients and chat apps actually render.

Two conversion backends are available:

| Backend | Dependencies | Description |
|---------|-------------|-------------|
| `native` (default) | None | Pure-Lua GFM parser. Zero external dependencies. |
| `pandoc` | [Pandoc](https://pandoc.org/installing.html) >= 2.11 | Uses pandoc with a bundled [Lua filter](filters/inline-style.lua). |

## Requirements

- **Neovim** >= 0.9
- **[Pandoc](https://pandoc.org/installing.html)** >= 2.11 — only if using `backend = "pandoc"`
- **Clipboard tool** — auto-detected per platform, no configuration needed:

| Platform | Tool | Notes |
|----------|------|-------|
| macOS | `osascript` | Built-in. Sets clipboard as native HTML (`NSPasteboardTypeHTML`). |
| Linux (X11) | `xclip` | Sets `text/html` MIME type. Install: `sudo apt install xclip` |
| Linux (Wayland) | `wl-copy` | Sets `text/html` MIME type. Install: `sudo apt install wl-clipboard` |
| WSL | `powershell.exe` | Usually on PATH by default. Uses CF_HTML format for correct rendering in Windows apps. |
| Windows | `powershell` / `pwsh` | Usually available by default. Uses CF_HTML format via .NET clipboard API. |

Custom clipboard commands can be set via `clipboard_cmd` in setup (see [Configuration](#configuration)).

## Installation

#### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "your-username/asperity.nvim",
  opts = {},
}
```

#### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "your-username/asperity.nvim",
  config = function()
    require("stylemd").setup()
  end,
}
```

#### Local development

```lua
-- lazy.nvim
{ dir = "~/Workspace/asperity.nvim", opts = {} }

-- or manually in init.lua
vim.opt.runtimepath:prepend("~/Workspace/asperity.nvim")
require("stylemd").setup()
```

## Usage

### Commands

| Command | Description |
|---|---|
| `:StyleMd` | Convert entire buffer to styled HTML and copy to clipboard |
| `:'<,'>StyleMd` | Convert visual selection and copy to clipboard |
| `:StyleMd theme=outlook` | One-shot theme override |

### Keymaps

No keymaps are set by default. Suggested bindings:

```lua
vim.keymap.set("n", "<leader>yy", "<cmd>StyleMd<cr>",  { desc = "Yank buffer as HTML" })
vim.keymap.set("v", "<leader>y",  ":'<,'>StyleMd<cr>", { desc = "Yank selection as HTML" })
```

### Lua API

```lua
local stylemd = require("stylemd")

stylemd.yank_buffer()                    -- full buffer → clipboard
stylemd.yank_range(10, 25)               -- lines 10–25 → clipboard
local html = stylemd.convert(md_string)  -- convert string, no clipboard
```

## Configuration

All options with their defaults:

```lua
require("stylemd").setup({
  -- Conversion backend: "native" (pure Lua, no deps) | "pandoc" (requires pandoc)
  backend = "native",

  -- Built-in theme: "github" | "outlook" | "minimal"
  theme = "github",

  -- Override individual element styles (merged into the active theme)
  style_overrides = {},

  -- Full custom style map (bypasses theme + overrides entirely)
  styles = nil,

  -- Custom clipboard command (nil = auto-detect platform)
  clipboard_cmd = nil,

  -- Path to pandoc executable (only used when backend = "pandoc")
  pandoc_path = "pandoc",

  -- Extra flags passed to pandoc (only used when backend = "pandoc")
  pandoc_args = {},

  -- Show notification on successful yank
  notify = true,
})
```

### Backends

The `backend` option controls how markdown is converted to HTML.

**`native`** (default) — a built-in pure-Lua parser. No external dependencies. Supports GFM features: headings, paragraphs, bold/italic/strikethrough, inline code, links, autolinks (`<url>`), images, fenced code blocks, ordered/unordered lists, task lists, blockquotes, tables with alignment and alternating row styles, and horizontal rules.

```lua
require("stylemd").setup({ backend = "native" })
```

**`pandoc`** — delegates to [pandoc](https://pandoc.org/) via a bundled Lua filter. Requires pandoc >= 2.11 to be installed. Use this if you need pandoc-specific features or extensions.

```lua
require("stylemd").setup({
  backend = "pandoc",
  pandoc_path = "/usr/local/bin/pandoc",  -- optional, default: "pandoc"
  pandoc_args = { "--wrap=none" },         -- optional extra flags
})
```

## Themes

Three presets are included:

| Theme | Description |
|---|---|
| `github` | GitHub-flavored light theme. Default. |
| `outlook` | Calibri-based, compact spacing, avoids CSS properties Outlook ignores (border-radius, shorthand margin). |
| `minimal` | Structural styles only — no colors, no backgrounds. Inherits the target app's font. |

### Customizing styles

Every theme is a table mapping HTML element names to CSS declaration strings. These are applied as inline `style=""` attributes.

**Override a few elements:**

```lua
require("stylemd").setup({
  theme = "github",
  style_overrides = {
    h1   = "font-size:28px; font-weight:700; color:#1a1a1a;",
    code = "font-family:'Fira Code',monospace; font-size:12px; background:#eee; padding:2px 4px;",
  },
})
```

**Full custom theme:**

```lua
require("stylemd").setup({
  styles = {
    h1         = "font-size:24px; font-weight:bold;",
    h2         = "font-size:20px; font-weight:bold;",
    p          = "font-size:14px; line-height:1.5;",
    code       = "font-family:monospace; background:#f0f0f0;",
    pre        = "font-family:monospace; background:#f0f0f0; padding:12px;",
    a          = "color:#0366d6;",
    strong     = "font-weight:700;",
    em         = "font-style:italic;",
    del        = "text-decoration:line-through;",
    blockquote = "border-left:3px solid #ccc; padding-left:12px; color:#666;",
    ul         = "padding-left:2em;",
    ol         = "padding-left:2em;",
    li         = "margin:4px 0;",
    table      = "border-collapse:collapse;",
    thead_row  = "background:#f0f0f0;",
    th         = "border:1px solid #ccc; padding:6px 10px; font-weight:600;",
    td         = "border:1px solid #ccc; padding:6px 10px;",
    tr_odd     = "",
    tr_even    = "background:#f9f9f9;",
    hr         = "border:none; border-top:1px solid #ccc; margin:20px 0;",
    img        = "max-width:100%;",
  },
})
```

### Style resolution order

```
styles (full custom)  →  used as-is
        ↓ (nil)
theme preset          →  merged with style_overrides
        ↓ (nil)
"github" preset       →  fallback default
```

### Supported elements

`h1` `h2` `h3` `h4` `h5` `h6` `p` `a` `strong` `em` `del` `code` `pre` `blockquote` `ul` `ol` `li` `table` `thead_row` `th` `td` `tr_odd` `tr_even` `hr` `img`

#### Table styling

Tables support fine-grained row styling via these virtual element keys:

| Key | Applied to | Description |
|-----|-----------|-------------|
| `table` | `<table>` | Table-level styles (border-collapse, width, margin) |
| `thead_row` | `<tr>` in `<thead>` | Header row background |
| `th` | `<th>` | Header cell styles (borders, padding, font-weight) |
| `td` | `<td>` | Body cell styles (borders, padding) |
| `tr_odd` | Odd `<tr>` in `<tbody>` | Odd body row background (row 1, 3, 5...) |
| `tr_even` | Even `<tr>` in `<tbody>` | Even body row background (row 2, 4, 6...) |

Example — zebra-striped table with a dark header:

```lua
style_overrides = {
  thead_row = "background:#24292e; color:#fff;",
  th        = "border:1px solid #444; padding:8px 12px; font-weight:600;",
  td        = "border:1px solid #dfe2e5; padding:8px 12px;",
  tr_odd    = "",
  tr_even   = "background:#f6f8fa;",
}
```

## License

MIT
