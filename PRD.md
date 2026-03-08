# StyleMarkdown.nvim — Product Requirements Document

Neovim Lua plugin that yanks markdown buffer content to the system clipboard as
inline-styled HTML, ready to paste into Microsoft Teams, Outlook, Gmail, and
other rich-text targets.

---

## 1. Problem

Copying markdown from Neovim and pasting into Teams/Outlook produces raw markup.
Users need a single command that converts markdown to styled HTML and places it
on the system clipboard as `text/html` so the target application renders it as
rich text.

## 2. Goals

- Convert markdown (CommonMark + GFM extensions) to HTML with inline CSS.
- Copy the result to the system clipboard as `text/html` on macOS, Linux
  (X11 + Wayland), and WSL.
- Support visual selection, range, and full-buffer operations.
- Ship sensible default styles with theme presets and full user override
  capability.
- Keep the plugin small, fast, and easy to install.

## 3. Non-Goals

- Rendering or previewing the HTML inside Neovim.
- Supporting non-markdown filetypes (reStructuredText, AsciiDoc, etc.).
- Bundling or auto-installing pandoc.

---

## 4. Architecture

```
 ┌──────────┐     ┌──────────┐     ┌──────────────┐     ┌───────────┐
 │  Buffer   │────▶│  Pandoc  │────▶│ Inline-style │────▶│ Clipboard │
 │ (md text) │     │ md→html  │     │  injection   │     │ (text/html)│
 └──────────┘     └──────────┘     └──────────────┘     └───────────┘
                        │
                   pandoc lua
                    filter
```

### 4.1 Conversion Backend — Pandoc

Pandoc is a required external dependency. The plugin gates all functionality
behind a startup health check (`vim.fn.executable("pandoc")`).

Pandoc is invoked with:

```
pandoc -f gfm -t html --lua-filter=<plugin>/filters/inline-style.lua
```

Input is piped via stdin; output is captured from stdout. A single
`vim.system()` (Neovim >= 0.10) or `vim.fn.system()` call handles the
round-trip.

**Why pandoc:**

- Spec-compliant GFM parsing (tables, task lists, fenced code, footnotes,
  strikethrough, autolinks).
- Pandoc Lua filters allow inline-style injection at conversion time — no
  HTML post-processing needed.
- Universally available (`brew install pandoc`, `apt install pandoc`,
  `scoop install pandoc`).
- Clipboard access already requires external tools; one more system dep is
  acceptable.

### 4.2 Inline Style Injection — Pandoc Lua Filter

A pandoc Lua filter (`filters/inline-style.lua`) walks the AST and attaches
`style` attributes to every emitted HTML element. The filter reads a
JSON-serialized style map passed via pandoc's `--metadata` flag or a temp file.

This keeps all style logic inside the pandoc pass — no regex/string-based
HTML rewriting in Neovim.

The filter handles these node types:

| AST node       | HTML element        |
|----------------|---------------------|
| Header 1–6     | `<h1>` – `<h6>`    |
| Para           | `<p>`               |
| BulletList     | `<ul>`, `<li>`      |
| OrderedList    | `<ol>`, `<li>`      |
| CodeBlock      | `<pre>`, `<code>`   |
| Code (inline)  | `<code>`            |
| BlockQuote     | `<blockquote>`      |
| Table          | `<table>`, `<th>`, `<td>` |
| Link           | `<a>`               |
| Image          | `<img>`             |
| Strong         | `<strong>`          |
| Emph           | `<em>`              |
| Strikeout      | `<del>`             |
| HorizontalRule | `<hr>`              |

### 4.3 Clipboard Dispatch

The plugin detects the platform and dispatches HTML to the appropriate
clipboard tool:

| Platform   | Command                                              |
|------------|------------------------------------------------------|
| macOS      | `osascript -e 'set the clipboard to ...'` or a swift helper to set `public.html` UTI |
| Linux/X11  | `xclip -selection clipboard -t text/html`            |
| Wayland    | `wl-copy --type text/html`                           |
| WSL        | `powershell.exe -c Set-Clipboard` (with HTML type)   |

Platform is detected once at setup via `vim.fn.has()` and `$WAYLAND_DISPLAY` /
`$DISPLAY` checks. The detection result is cached.

Users can override the clipboard command entirely via config if their
environment is nonstandard.

---

## 5. Theme System

### 5.1 Style Map

All styling is driven by a single Lua table: the **style map**. Each key is an
HTML element name; each value is a CSS declaration string that will be applied
as an inline `style` attribute.

```lua
-- Example style map (subset)
{
  h1         = "font-size:24px; font-weight:700; color:#24292e; margin:16px 0 8px;",
  h2         = "font-size:20px; font-weight:600; color:#24292e; margin:14px 0 6px;",
  h3         = "font-size:16px; font-weight:600; color:#24292e; margin:12px 0 4px;",
  p          = "font-size:14px; line-height:1.6; color:#24292e; margin:0 0 12px;",
  a          = "color:#0366d6; text-decoration:none;",
  strong     = "font-weight:700;",
  em         = "font-style:italic;",
  del        = "text-decoration:line-through;",
  code       = "font-family:Consolas,'Courier New',monospace; font-size:13px; background:#f6f8fa; padding:2px 6px; border-radius:3px;",
  pre        = "font-family:Consolas,'Courier New',monospace; font-size:13px; background:#f6f8fa; padding:12px 16px; border-radius:6px; overflow-x:auto; margin:0 0 12px;",
  blockquote = "border-left:4px solid #dfe2e5; padding:0 16px; color:#6a737d; margin:0 0 12px;",
  ul         = "padding-left:2em; margin:0 0 12px;",
  ol         = "padding-left:2em; margin:0 0 12px;",
  li         = "margin:4px 0;",
  table      = "border-collapse:collapse; margin:0 0 12px; width:100%;",
  th         = "border:1px solid #dfe2e5; padding:8px 12px; font-weight:600; background:#f6f8fa; text-align:left;",
  td         = "border:1px solid #dfe2e5; padding:8px 12px; text-align:left;",
  hr         = "border:none; border-top:2px solid #e1e4e8; margin:24px 0;",
  img        = "max-width:100%;",
}
```

### 5.2 Built-in Presets

The plugin ships with three theme presets:

| Preset       | Description                                            |
|--------------|--------------------------------------------------------|
| `github`     | GitHub-flavored light theme. The default.              |
| `outlook`    | Calibri-based, compact spacing, Outlook-safe palette.  |
| `minimal`    | No colors, no backgrounds — structural styles only.    |

Presets are plain Lua files under `lua/stylemd/themes/<name>.lua`, each
returning a complete style map table.

### 5.3 User Customization

Users customize styles through the `setup()` call using three mechanisms
(applied in this order of precedence):

1. **Select a preset** — `theme = "github"` (default).
2. **Override individual elements** — `style_overrides = { h1 = "color:red;" }`
   merges into the active preset. Any key present in overrides replaces the
   preset value for that key entirely.
3. **Provide a full custom style map** — `styles = { ... }` bypasses presets
   entirely.

```lua
require("stylemd").setup({
  -- Pick a base preset
  theme = "outlook",

  -- Override specific elements on top of the preset
  style_overrides = {
    h1   = "font-size:28px; font-weight:700; color:#1a1a1a;",
    code = "font-family:'Fira Code',monospace; font-size:12px; background:#eee; padding:2px 4px;",
  },

  -- OR provide a complete custom style map (ignores theme + overrides)
  -- styles = { ... },
})
```

### 5.4 Style Resolution Order

```
styles (full custom)  ──▶  used as-is, nothing else consulted
        │ (nil)
        ▼
theme preset table    ──▶  deep-merged with style_overrides
        │ (nil)
        ▼
"github" preset       ──▶  fallback default
```

---

## 6. Plugin API

### 6.1 Commands

| Command                     | Behavior                                          |
|-----------------------------|---------------------------------------------------|
| `:StyleMd`                  | Convert entire buffer and copy to clipboard.      |
| `:'<,'>StyleMd`             | Convert visual selection and copy to clipboard.   |
| `:StyleMd theme=<name>`     | One-shot override: use specified theme.            |

### 6.2 Lua API

```lua
local stylemd = require("stylemd")

-- Convert and yank the full buffer
stylemd.yank_buffer()

-- Convert and yank lines start..end (1-indexed, inclusive)
stylemd.yank_range(start_line, end_line)

-- Convert markdown string, return HTML string (no clipboard)
stylemd.convert(markdown_string)
```

### 6.3 Keymaps

No default keymaps are set. Users bind to taste:

```lua
vim.keymap.set("n", "<leader>yy", "<cmd>StyleMd<cr>",  { desc = "Yank buffer as HTML" })
vim.keymap.set("v", "<leader>y",  ":'<,'>StyleMd<cr>", { desc = "Yank selection as HTML" })
```

---

## 7. Configuration

Full `setup()` signature with defaults:

```lua
require("stylemd").setup({
  -- Theme preset: "github" | "outlook" | "minimal"
  theme = "github",

  -- Element-level style overrides (merged into active theme)
  style_overrides = {},

  -- Full custom style map (overrides theme + style_overrides when set)
  styles = nil,

  -- Override the clipboard command.
  -- Receives the HTML string as the first argument.
  -- nil = auto-detect platform.
  clipboard_cmd = nil,

  -- Pandoc executable path
  pandoc_path = "pandoc",

  -- Extra pandoc flags appended to the command
  pandoc_args = {},

  -- Notify on successful yank
  notify = true,
})
```

---

## 8. File Structure

```
StyleMarkdown.nvim/
├── lua/
│   └── stylemd/
│       ├── init.lua            -- setup(), public API
│       ├── config.lua          -- defaults, option merging
│       ├── convert.lua         -- pandoc invocation
│       ├── clipboard.lua       -- platform detection, dispatch
│       └── themes/
│           ├── github.lua      -- github preset style map
│           ├── outlook.lua     -- outlook preset style map
│           └── minimal.lua     -- minimal preset style map
├── filters/
│   └── inline-style.lua        -- pandoc lua filter
├── plugin/
│   └── stylemd.lua             -- vim command registration
├── doc/
│   └── stylemd.txt             -- vimdoc help file
└── README.md
```

---

## 9. Requirements

| Requirement                  | Detail                              |
|------------------------------|-------------------------------------|
| Neovim                       | >= 0.9                              |
| Pandoc                       | >= 2.11 (Lua filter support)        |
| Clipboard tool               | Platform-specific (see §4.3)        |
| Lua                          | Neovim built-in LuaJIT              |

---

## 10. Error Handling

| Condition                   | Behavior                                       |
|-----------------------------|-------------------------------------------------|
| Pandoc not found            | `vim.notify(..., vim.log.levels.ERROR)` on setup and on every command invocation. |
| Clipboard tool not found    | Error with platform-specific install hint.      |
| Pandoc exits non-zero       | Surface stderr in notification.                 |
| Empty selection / buffer    | Warn and no-op.                                 |
| Unknown theme name          | Error listing available presets.                |

---

## 11. Future Considerations

Items explicitly out of scope for v1 but worth tracking:

- **Syntax-highlighted code blocks** — use a pandoc highlight style or inject
  highlight.js compatible classes/inline styles.
- **Custom pandoc Lua filters** — allow users to supply additional filters via
  config for advanced AST transforms.
- **Image embedding** — base64-encode local images inline for Outlook
  compatibility.
- **Operator-pending mode** — `yh` motion to yank-as-html over a text object.
- **Template wrapping** — wrap output in a full `<html><body>` skeleton with
  configurable wrapper styles (background, max-width, font-family).
