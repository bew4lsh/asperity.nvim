-- stylemd.config
-- Default configuration and option merging logic.

local M = {}

--- Known theme preset names.
local VALID_THEMES = { github = true, outlook = true, minimal = true }

--- Known backend names.
local VALID_BACKENDS = { native = true, pandoc = true }

--- Default configuration values.
-- See PRD §7 for documentation of every field.
M.defaults = {
  -- Conversion backend: "native" (pure Lua, no deps) | "pandoc" (requires pandoc)
  backend = "native",

  -- Theme preset: "github" | "outlook" | "minimal"
  theme = "github",

  -- Element-level style overrides (merged into active theme)
  style_overrides = {},

  -- Full custom style map (overrides theme + style_overrides when non-nil)
  styles = nil,

  -- Override the clipboard command.
  -- When nil, platform is auto-detected.
  -- When set, receives HTML string as first argument.
  clipboard_cmd = nil,

  -- Path to the pandoc executable
  pandoc_path = "pandoc",

  -- Extra flags appended to the pandoc invocation
  pandoc_args = {},

  -- Show vim.notify on successful yank
  notify = true,
}

--- Active (resolved) configuration. Populated by setup().
M.options = {}

--- Load a built-in theme preset by name.
-- @param name string Theme name ("github", "outlook", "minimal")
-- @return table Style map table
local function load_theme(name)
  local ok, theme = pcall(require, "stylemd.themes." .. name)
  if not ok then
    error(("[stylemd] failed to load theme '%s': %s"):format(name, theme))
  end
  return theme
end

--- Resolve the final style map following the precedence chain:
--   1. opts.styles (full custom) → use as-is
--   2. theme preset → shallow-merge with opts.style_overrides
--   3. fallback to "github" preset
-- @param opts table Merged options
-- @return table Resolved style map
local function resolve_styles(opts)
  -- Full custom map bypasses everything
  if opts.styles then
    return opts.styles
  end

  local base = load_theme(opts.theme)

  -- Shallow-merge overrides on top of preset (override replaces per-key)
  if opts.style_overrides and next(opts.style_overrides) then
    local merged = {}
    for k, v in pairs(base) do
      merged[k] = v
    end
    for k, v in pairs(opts.style_overrides) do
      merged[k] = v
    end
    return merged
  end

  return base
end

--- Merge user options into defaults and resolve the active style map.
-- @param opts table|nil User-supplied options from setup()
function M.setup(opts)
  opts = opts or {}

  -- Shallow-merge opts into defaults
  M.options = {}
  for k, v in pairs(M.defaults) do
    M.options[k] = v
  end
  for k, v in pairs(opts) do
    M.options[k] = v
  end

  -- Validate backend name
  if not VALID_BACKENDS[M.options.backend] then
    local names = table.concat(vim.tbl_keys(VALID_BACKENDS), ", ")
    vim.notify(
      ("[stylemd] unknown backend '%s'. Available: %s"):format(M.options.backend, names),
      vim.log.levels.ERROR
    )
    M.options.backend = "native"
  end

  -- Validate theme name
  if not VALID_THEMES[M.options.theme] then
    local names = table.concat(vim.tbl_keys(VALID_THEMES), ", ")
    vim.notify(
      ("[stylemd] unknown theme '%s'. Available: %s"):format(M.options.theme, names),
      vim.log.levels.ERROR
    )
    M.options.theme = "github"
  end

  -- Resolve final style map
  M.options.resolved_styles = resolve_styles(M.options)
end

--- Return the resolved style map table.
-- @return table<string, string> Element → inline CSS declarations
function M.get_styles()
  return M.options.resolved_styles or load_theme("github")
end

return M
