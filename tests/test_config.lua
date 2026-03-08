-- Tests for config module.
-- Uses vim API shims for testing outside Neovim.

-- Provide minimal vim shims so config.lua can load
if not vim then
  _G.vim = {
    tbl_keys = function(t)
      local keys = {}
      for k in pairs(t) do keys[#keys + 1] = k end
      return keys
    end,
    notify = function() end,
    log = { levels = { ERROR = 4, WARN = 3, INFO = 2 } },
  }
end

-- Force re-require to pick up shims
package.loaded["stylemd.config"] = nil
local config = require("stylemd.config")

describe("Config: Defaults", function()
  it("has native as default backend", function()
    assert_eq(config.defaults.backend, "native")
  end)

  it("has github as default theme", function()
    assert_eq(config.defaults.theme, "github")
  end)
end)

describe("Config: Setup", function()
  it("merges user options", function()
    config.setup({ notify = false })
    assert_eq(config.options.notify, false)
    assert_eq(config.options.theme, "github")  -- default preserved
  end)

  it("validates backend and falls back to native", function()
    local warned = false
    vim.notify = function() warned = true end
    config.setup({ backend = "invalid" })
    assert_eq(config.options.backend, "native")
    assert_truthy(warned, "should have warned about invalid backend")
  end)

  it("validates theme and falls back to github", function()
    local warned = false
    vim.notify = function() warned = true end
    config.setup({ theme = "nonexistent" })
    assert_eq(config.options.theme, "github")
    assert_truthy(warned, "should have warned about invalid theme")
  end)

  it("loads theme styles", function()
    config.setup({ theme = "github" })
    local s = config.get_styles()
    assert_truthy(s.h1, "github theme should have h1 style")
    assert_truthy(s.p, "github theme should have p style")
  end)

  it("merges style_overrides", function()
    config.setup({
      theme = "github",
      style_overrides = { h1 = "color:red;" },
    })
    local s = config.get_styles()
    assert_eq(s.h1, "color:red;")
    assert_truthy(s.p, "non-overridden styles should remain")
  end)

  it("uses full custom styles when provided", function()
    config.setup({ styles = { h1 = "custom:yes;" } })
    local s = config.get_styles()
    assert_eq(s.h1, "custom:yes;")
    assert_eq(s.p, nil, "custom styles should not include theme defaults")
  end)

  it("accepts pandoc as valid backend", function()
    vim.notify = function() end
    config.setup({ backend = "pandoc" })
    assert_eq(config.options.backend, "pandoc")
  end)
end)
