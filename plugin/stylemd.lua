-- plugin/stylemd.lua
-- Vim command registration for asperity.nvim
-- This file is auto-sourced by Neovim's plugin loader.

if vim.g.loaded_stylemd then
  return
end
vim.g.loaded_stylemd = true

vim.api.nvim_create_user_command("StyleMd", function(opts)
  local stylemd = require("stylemd")

  -- Parse optional theme=<name> argument
  local one_shot_styles
  if opts.fargs and #opts.fargs > 0 then
    for _, arg in ipairs(opts.fargs) do
      local theme_name = arg:match("^theme=(.+)$")
      if theme_name then
        local ok, theme = pcall(require, "stylemd.themes." .. theme_name)
        if ok then
          one_shot_styles = theme
        else
          vim.notify(
            ("[stylemd] unknown theme '%s'. Available: github, outlook, minimal"):format(theme_name),
            vim.log.levels.ERROR
          )
          return
        end
      end
    end
  end

  if opts.range == 2 then
    stylemd.yank_range(opts.line1, opts.line2, one_shot_styles)
  else
    if one_shot_styles then
      -- Full buffer with one-shot theme: use yank_range with full range
      local line_count = vim.api.nvim_buf_line_count(0)
      stylemd.yank_range(1, line_count, one_shot_styles)
    else
      stylemd.yank_buffer()
    end
  end
end, {
  range = true,
  nargs = "?",
  complete = function(_, cmd_line)
    -- Complete theme= argument
    if cmd_line:match("theme=") then
      return {}
    end
    return { "theme=github", "theme=outlook", "theme=minimal" }
  end,
  desc = "Convert markdown to styled HTML and yank to clipboard",
})
