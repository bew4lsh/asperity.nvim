-- stylemd.clipboard
-- Platform detection and HTML clipboard dispatch.

local config = require("stylemd.config")

local M = {}

--- Detected platform. Cached after first call to detect_platform().
-- One of: "macos", "x11", "wayland", "wsl", "windows", "custom", "unknown"
M.platform = nil

--- Build a CF_HTML envelope around raw HTML.
-- Required by Windows/.NET clipboard APIs for the HTML clipboard format.
-- Uses %010d zero-padded byte offsets so header length is stable.
-- @param html string Raw HTML content
-- @return string CF_HTML formatted string
local function build_cf_html(html)
  -- The header has a fixed structure; compute byte offsets.
  -- Template with placeholders to measure header length:
  local header_template = "Version:0.9\r\n"
    .. "StartHTML:%010d\r\n"
    .. "EndHTML:%010d\r\n"
    .. "StartFragment:%010d\r\n"
    .. "EndFragment:%010d\r\n"
  -- Header length is constant because we use %010d (10 digits)
  local header_len = #header_template:format(0, 0, 0, 0)

  local prefix = "<html>\r\n<body>\r\n<!--StartFragment-->"
  local suffix = "<!--EndFragment-->\r\n</body>\r\n</html>"

  local start_html = header_len
  local start_fragment = header_len + #prefix
  local end_fragment = start_fragment + #html
  local end_html = end_fragment + #suffix

  local header = header_template:format(start_html, end_html, start_fragment, end_fragment)
  return header .. prefix .. html .. suffix
end

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
  elseif vim.fn.has("win32") == 1 then
    M.platform = "windows"
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
  x11     = "Install xclip: sudo apt install xclip (xsel is not supported — it cannot set text/html MIME type)",
  wayland = "Install wl-clipboard: sudo apt install wl-clipboard",
  wsl     = "PowerShell should be available in WSL. Check that powershell.exe is on PATH.",
  windows = "PowerShell should be available on Windows. Check that powershell or pwsh is on PATH.",
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
    return { "osascript" }
  end

  if platform == "x11" then
    if vim.fn.executable("xclip") == 1 then
      return { "xclip", "-selection", "clipboard", "-t", "text/html" }
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

  if platform == "windows" then
    if vim.fn.executable("powershell") == 1 then
      return { "powershell" }
    end
    if vim.fn.executable("pwsh") == 1 then
      return { "pwsh" }
    end
    if vim.fn.executable("powershell.exe") == 1 then
      return { "powershell.exe" }
    end
    return nil, "[stylemd] no PowerShell found. " .. INSTALL_HINTS.windows
  end

  return nil, "[stylemd] could not detect clipboard platform. Set clipboard_cmd in setup()."
end

--- Build the platform-specific stdin payload and command.
-- Some platforms (macOS, WSL, Windows) need special handling beyond simple stdin piping.
-- @param html string The HTML content
-- @param cmd string[] Base command array
-- @return string[] Final command array
-- @return string|nil stdin_data Data to pipe to stdin
-- @return string|nil tmpfile Path to temp file to clean up after exit
local function prepare_dispatch(html, cmd)
  local platform = M.detect_platform()

  if platform == "macos" then
    local tmpfile = vim.fn.tempname() .. ".html"
    local f = io.open(tmpfile, "wb")
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
    return { "osascript", "-e", applescript }, nil, tmpfile
  end

  if platform == "wsl" then
    local cf_html = build_cf_html(html)
    local tmpfile = vim.fn.tempname() .. ".html"
    local f = io.open(tmpfile, "wb")
    if f then
      f:write(cf_html)
      f:close()
    end
    local wsl_path = tmpfile:gsub("/", "\\")
    local ps_script = ([[
      Add-Type -AssemblyName System.Windows.Forms
      $html = [System.IO.File]::ReadAllText('%s')
      [System.Windows.Forms.Clipboard]::SetText($html, [System.Windows.Forms.TextDataFormat]::Html)
    ]]):format(wsl_path)
    return { "powershell.exe", "-STA", "-NoProfile", "-Command", ps_script }, nil, tmpfile
  end

  if platform == "windows" then
    local cf_html = build_cf_html(html)
    local tmpfile = vim.fn.tempname() .. ".html"
    local f = io.open(tmpfile, "wb")
    if f then
      f:write(cf_html)
      f:close()
    end
    local ps_script = ([[
      Add-Type -AssemblyName System.Windows.Forms
      $html = [System.IO.File]::ReadAllText('%s')
      [System.Windows.Forms.Clipboard]::SetText($html, [System.Windows.Forms.TextDataFormat]::Html)
    ]]):format(tmpfile)
    -- Use -STA for non-pwsh PowerShell (required for WinForms clipboard access)
    local sta_flag = cmd[1] ~= "pwsh" and "-STA" or nil
    local final_cmd = { cmd[1] }
    if sta_flag then
      table.insert(final_cmd, sta_flag)
    end
    table.insert(final_cmd, "-NoProfile")
    table.insert(final_cmd, "-Command")
    table.insert(final_cmd, ps_script)
    return final_cmd, nil, tmpfile
  end

  -- x11, wayland, custom: pipe HTML to stdin
  return cmd, html, nil
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

  local final_cmd, stdin_data, tmpfile = prepare_dispatch(html, cmd)

  if vim.system then
    -- Neovim >= 0.10
    -- Clipboard tools like xclip and wl-copy stay alive to serve clipboard
    -- contents, so we cannot use a blocking :wait() — it would hang forever.
    -- Run async and report errors via vim.notify.
    vim.system(final_cmd, {
      stdin = stdin_data or false,
    }, function(result)
      if tmpfile then
        os.remove(tmpfile)
      end
      if result.code ~= 0 and (result.signal or 0) == 0 then
        vim.schedule(function()
          vim.notify(
            ("[stylemd] clipboard command failed (exit %d): %s"):format(
              result.code, result.stderr or ""
            ),
            vim.log.levels.ERROR
          )
        end)
      end
    end)
    return true, nil
  else
    -- Fallback for Neovim < 0.10: use vim.fn.jobstart (non-blocking, avoids
    -- the hang that vim.fn.system() causes with xclip/wl-copy).
    local job_cmd
    if type(final_cmd) == "table" then
      job_cmd = final_cmd
    else
      job_cmd = { final_cmd }
    end

    local job_id = vim.fn.jobstart(job_cmd, {
      on_exit = function(_, exit_code)
        if tmpfile then
          os.remove(tmpfile)
        end
        if exit_code ~= 0 then
          vim.schedule(function()
            vim.notify(
              "[stylemd] clipboard command failed (exit " .. exit_code .. ")",
              vim.log.levels.ERROR
            )
          end)
        end
      end,
    })

    if job_id <= 0 then
      if tmpfile then
        os.remove(tmpfile)
      end
      return false, "[stylemd] failed to start clipboard command"
    end

    if stdin_data then
      vim.fn.chansend(job_id, stdin_data)
      vim.fn.chanclose(job_id, "stdin")
    end

    return true, nil
  end
end

--- Reset cached platform (useful for testing or after config change).
function M.reset()
  M.platform = nil
end

return M
