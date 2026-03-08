-- stylemd.convert
-- Thin dispatcher: resolves styles then delegates to the configured backend.

local config = require("stylemd.config")

local M = {}

--- Convert a markdown string to inline-styled HTML.
-- @param markdown string Raw markdown input
-- @param style_overrides table|nil One-shot style overrides (for theme= arg)
-- @return string|nil html Rendered HTML with inline styles
-- @return string|nil err Error message on failure
function M.to_html(markdown, style_overrides)
  -- Resolve styles (allow one-shot override)
  local styles
  if style_overrides then
    styles = style_overrides
  else
    styles = config.get_styles()
  end

  -- Load the configured backend
  local backend_name = config.options.backend or "native"
  local ok, backend = pcall(require, "stylemd.backends." .. backend_name)
  if not ok then
    return nil, ("[stylemd] failed to load backend '%s': %s"):format(backend_name, backend)
  end

  return backend.convert(markdown, styles)
end

return M
