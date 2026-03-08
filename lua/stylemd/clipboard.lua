-- stylemd.clipboard
-- Platform detection and HTML clipboard dispatch.

local config = require("stylemd.config")

local M = {}

--- Detected platform. Cached after first call to detect_platform().
-- One of: "macos", "x11", "wayland", "wsl", "custom", "unknown"
M.platform = nil

--- Detect the current platform and cache the result.
-- @return string Platform identifier
function M.detect_platform()
  if M.platform then
    return M.platform
  end

  if config.options.clipboard_cmd then
    M.platform = "custom"
    return M.platform
  end

  if vim.fn.has("mac") == 1 or vim.fn.has("macunix") == 1 then
    M.platform = "macos"
  elseif vim.fn.has("wsl") == 1 then
    M.platform = "wsl"
  elseif os.getenv("WAYLAND_DISPLAY") and os.getenv("WAYLAND_DISPLAY") ~= "" then
    M.platform = "wayland"
  elseif os.getenv("DISPLAY") and os.getenv("DISPLAY") ~= "" then
    M.platform = "x11"
  else
    M.platform = "unknown"
  end

  return M.platform
end

--- Platform-specific install hints for missing clipboard tools.
local INSTALL_HINTS = {
  macos   = "Clipboard support is built-in on macOS via osascript.",
  x11     = "Install xclip: sudo apt install xclip (or xsel: sudo apt install xsel)",
  wayland = "Install wl-clipboard: sudo apt install wl-clipboard",
  wsl     = "PowerShell should be available in WSL. Check that powershell.exe is on PATH.",
}

--- Return the clipboard command for the detected platform.
-- @return string[]|nil Command array, or nil if unavailable
-- @return string|nil Error message if no suitable tool found
local function clipboard_cmd()
  local platform = M.detect_platform()

  if platform == "custom" then
    local cmd = config.options.clipboard_cmd
    if type(cmd) == "string" then
      return { cmd }
    end
    return cmd
  end

  if platform == "macos" then
    -- osascript to set clipboard as «class HTML»
    -- The actual HTML is piped via a helper; we use a hex-encoding approach
    -- so osascript can handle arbitrary HTML without quoting issues.
    -- For simplicity we pipe to pbcopy first and use osascript for HTML type.
    return { "osascript" }
  end

  if platform == "x11" then
    if vim.fn.executable("xclip") == 1 then
      return { "xclip", "-selection", "clipboard", "-t", "text/html" }
    end
    if vim.fn.executable("xsel") == 1 then
      return { "xsel", "--clipboard", "--input" }
    end
    return nil, "[stylemd] no clipboard tool found. " .. INSTALL_HINTS.x11
  end

  if platform == "wayland" then
    if vim.fn.executable("wl-copy") == 1 then
      return { "wl-copy", "--type", "text/html" }
    end
    return nil, "[stylemd] wl-copy not found. " .. INSTALL_HINTS.wayland
  end

  if platform == "wsl" then
    if vim.fn.executable("powershell.exe") == 1 then
      return { "powershell.exe" }
    end
    return nil, "[stylemd] powershell.exe not found. " .. INSTALL_HINTS.wsl
  end

  return nil, "[stylemd] could not detect clipboard platform. Set clipboard_cmd in setup()."
end

--- Build the platform-specific stdin payload and command.
-- Some platforms (macOS, WSL) need special handling beyond simple stdin piping.
-- @param html string The HTML content
-- @param cmd string[] Base command array
-- @return string[] Final command array
-- @return string stdin_data Data to pipe to stdin
local function prepare_dispatch(html, cmd)
  local platform = M.detect_platform()

  if platform == "macos" then
    -- Use osascript to set the clipboard with HTML data
    local script = ([[
      set the clipboard to ""
      set theHTML to (do shell script "cat" & return)
      tell application "System Events"
        set the clipboard to theHTML
      end tell
    ]])
    -- Simpler approach: write HTML to temp file, use osascript to read it
    local tmpfile = vim.fn.tempname() .. ".html"
    local f = io.open(tmpfile, "w")
    if f then
      f:write(html)
      f:close()
    end
    local applescript = ([[
      use framework "AppKit"
      set htmlData to (current application's NSData's dataWithContentsOfFile:"%s")
      set pb to current application's NSPasteboard's generalPasteboard()
      pb's clearContents()
      pb's setData:htmlData forType:(current application's NSPasteboardTypeHTML)
    ]]):format(tmpfile)
    return { "osascript", "-e", applescript }, nil
  end

  if platform == "wsl" then
    -- PowerShell: use Add-Type to set HTML clipboard via .NET
    local tmpfile = vim.fn.tempname() .. ".html"
    local f = io.open(tmpfile, "w")
    if f then
      f:write(html)
      f:close()
    end
    local ps_script = ([[
      Add-Type -AssemblyName System.Windows.Forms
      $html = [System.IO.File]::ReadAllText('%s')
      [System.Windows.Forms.Clipboard]::SetText($html, [System.Windows.Forms.TextDataFormat]::Html)
    ]]):format(tmpfile:gsub("/", "\\"))
    return { "powershell.exe", "-NoProfile", "-Command", ps_script }, nil
  end

  -- x11, wayland, custom: pipe HTML to stdin
  return cmd, html
end

--- Copy HTML string to the system clipboard.
-- @param html string The HTML content to copy
-- @return boolean success
-- @return string|nil err Error message on failure
function M.copy(html)
  local cmd, err = clipboard_cmd()
  if not cmd then
    return false, err
  end

  local final_cmd, stdin_data = prepare_dispatch(html, cmd)

  if vim.system then
    -- Neovim >= 0.10
    local result = vim.system(final_cmd, {
      stdin = stdin_data or false,
    }):wait()

    if result.code ~= 0 then
      return false, ("[stylemd] clipboard command failed (exit %d): %s"):format(
        result.code, result.stderr or ""
      )
    end
    return true, nil
  else
    -- Fallback for Neovim < 0.10
    if stdin_data then
      local cmd_str = table.concat(final_cmd, " ")
      vim.fn.system(cmd_str, stdin_data)
    else
      vim.fn.system(final_cmd)
    end

    if vim.v.shell_error ~= 0 then
      return false, "[stylemd] clipboard command failed (exit " .. vim.v.shell_error .. ")"
    end
    return true, nil
  end
end

--- Reset cached platform (useful for testing or after config change).
function M.reset()
  M.platform = nil
end

return M
