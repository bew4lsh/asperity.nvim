-- stylemd.backends.pandoc
-- Pandoc-based markdown → inline-styled HTML conversion.

local config = require("stylemd.config")

local M = {}

--- Return the absolute path to the plugin's root directory.
-- @return string Plugin root path
local function plugin_root()
  -- Resolve from this file's location: lua/stylemd/backends/pandoc.lua → ../../../
  local source = debug.getinfo(1, "S").source:sub(2) -- strip leading @
  local dir = vim.fn.fnamemodify(source, ":h")        -- lua/stylemd/backends/
  return vim.fn.fnamemodify(dir .. "/../../../", ":p") -- plugin root
end

--- Return the absolute path to the bundled pandoc Lua filter.
-- @return string Path to filters/inline-style.lua
local function filter_path()
  return plugin_root() .. "filters/inline-style.lua"
end

--- Serialize the resolved style map to a temp JSON file for the pandoc filter.
-- @param styles table<string, string> The resolved style map
-- @return string Path to the temporary JSON file
local function write_style_metadata(styles)
  local json = vim.json.encode(styles)
  local path = vim.fn.tempname() .. "-stylemd-styles.json"
  local f = io.open(path, "w")
  if not f then
    error("[stylemd] failed to write temp style file: " .. path)
  end
  f:write(json)
  f:close()
  return path
end

--- Build the pandoc CLI argument list.
-- @param style_meta_path string Path to the temp JSON style file
-- @return string[] Argument array for vim.system / vim.fn.system
local function build_cmd(style_meta_path)
  local cmd = {
    config.options.pandoc_path or "pandoc",
    "-f", "gfm",
    "-t", "html",
    "--lua-filter=" .. filter_path(),
    "--metadata=stylemd-styles-file:" .. style_meta_path,
  }

  -- Append any user-specified extra pandoc args
  if config.options.pandoc_args then
    for _, arg in ipairs(config.options.pandoc_args) do
      table.insert(cmd, arg)
    end
  end

  return cmd
end

--- Convert a markdown string to inline-styled HTML via pandoc.
-- @param markdown string Raw markdown input
-- @param styles table<string, string> Resolved style map
-- @return string|nil html Rendered HTML with inline styles
-- @return string|nil err Error message if pandoc fails
function M.convert(markdown, styles)
  -- Check pandoc is available
  local pandoc = config.options.pandoc_path or "pandoc"
  if vim.fn.executable(pandoc) ~= 1 then
    return nil, ("[stylemd] pandoc not found at '%s'. Install: https://pandoc.org/installing.html"):format(pandoc)
  end

  -- Write style map to temp file
  local style_meta_path = write_style_metadata(styles)

  -- Build command
  local cmd = build_cmd(style_meta_path)

  local html, err

  if vim.system then
    -- Neovim >= 0.10
    local result = vim.system(cmd, { stdin = markdown }):wait()

    if result.code ~= 0 then
      err = ("[stylemd] pandoc failed (exit %d): %s"):format(result.code, result.stderr or "")
    else
      html = result.stdout
    end
  else
    -- Fallback for Neovim < 0.10
    html = vim.fn.system(table.concat(cmd, " "), markdown)
    if vim.v.shell_error ~= 0 then
      err = "[stylemd] pandoc failed (exit " .. vim.v.shell_error .. "): " .. (html or "")
      html = nil
    end
  end

  -- Clean up temp file
  os.remove(style_meta_path)

  return html, err
end

return M
