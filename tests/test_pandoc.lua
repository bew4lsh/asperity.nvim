-- Tests for the pandoc backend.
-- Skipped when pandoc or Neovim vim API is not available.

describe("Pandoc backend", function()
  -- The pandoc backend requires vim.fn, vim.json, vim.system etc.
  -- which are only available inside Neovim. Skip in standalone Lua.
  it("skipped — requires Neovim runtime", function()
    -- Placeholder: these tests should be run inside Neovim via:
    --   nvim --headless -c "luafile tests/test_pandoc_nvim.lua" -c "qa!"
    assert_truthy(true)
  end)
end)
