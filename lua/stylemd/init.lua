-- stylemd.init
-- Public API and setup entrypoint for StyleMarkdown.nvim

local M = {}

--- Initialize the plugin with user options.
-- @param opts table|nil User configuration (see PRD §7 for full schema)
function M.setup(opts)
  local config = require("stylemd.config")
  local clipboard = require("stylemd.clipboard")

  config.setup(opts)

  -- Health check: pandoc (only when using pandoc backend)
  if config.options.backend == "pandoc" then
    local pandoc = config.options.pandoc_path or "pandoc"
    if vim.fn.executable(pandoc) ~= 1 then
      vim.notify(
        ("[stylemd] pandoc not found at '%s'. Install: https://pandoc.org/installing.html"):format(pandoc),
        vim.log.levels.ERROR
      )
    end
  end

  -- Cache platform detection
  clipboard.detect_platform()
end

--- Convert the entire buffer to styled HTML and copy to clipboard.
function M.yank_buffer()
  local config = require("stylemd.config")
  local convert = require("stylemd.convert")
  local clipboard = require("stylemd.clipboard")

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  if #lines == 0 or (#lines == 1 and lines[1] == "") then
    vim.notify("[stylemd] buffer is empty", vim.log.levels.WARN)
    return
  end

  local markdown = table.concat(lines, "\n")
  local html, err = convert.to_html(markdown)
  if not html then
    vim.notify(err or "[stylemd] conversion failed", vim.log.levels.ERROR)
    return
  end

  local ok, copy_err = clipboard.copy(html)
  if not ok then
    vim.notify(copy_err or "[stylemd] clipboard copy failed", vim.log.levels.ERROR)
    return
  end

  if config.options.notify then
    vim.notify("[stylemd] copied styled HTML to clipboard", vim.log.levels.INFO)
  end
end

--- Convert a line range to styled HTML and copy to clipboard.
-- @param start_line number 1-indexed start line (inclusive)
-- @param end_line number 1-indexed end line (inclusive)
-- @param one_shot_styles table|nil One-shot style overrides
function M.yank_range(start_line, end_line, one_shot_styles)
  local config = require("stylemd.config")
  local convert = require("stylemd.convert")
  local clipboard = require("stylemd.clipboard")

  -- nvim_buf_get_lines uses 0-indexed, end-exclusive
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  if #lines == 0 or (#lines == 1 and lines[1] == "") then
    vim.notify("[stylemd] selection is empty", vim.log.levels.WARN)
    return
  end

  local markdown = table.concat(lines, "\n")
  local html, err = convert.to_html(markdown, one_shot_styles)
  if not html then
    vim.notify(err or "[stylemd] conversion failed", vim.log.levels.ERROR)
    return
  end

  local ok, copy_err = clipboard.copy(html)
  if not ok then
    vim.notify(copy_err or "[stylemd] clipboard copy failed", vim.log.levels.ERROR)
    return
  end

  if config.options.notify then
    local count = end_line - start_line + 1
    vim.notify(
      ("[stylemd] copied %d line%s as styled HTML"):format(count, count == 1 and "" or "s"),
      vim.log.levels.INFO
    )
  end
end

--- Convert a markdown string to inline-styled HTML.
-- Does NOT touch the clipboard. Useful for programmatic access.
-- @param markdown string Raw markdown text
-- @return string|nil html Rendered HTML with inline styles
-- @return string|nil err Error message on failure
function M.convert(markdown)
  local convert = require("stylemd.convert")
  return convert.to_html(markdown)
end

return M
