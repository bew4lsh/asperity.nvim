-- stylemd.backends.native
-- Pure-Lua GFM markdown → inline-styled HTML converter.
-- No vim.* APIs — testable outside Neovim.

local M = {}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local ENTITY_MAP = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;" }

--- Escape HTML special characters.
-- @param s string
-- @return string
local function escape_html(s)
  return (s:gsub("[&<>\"]", ENTITY_MAP))
end

--- Return an opening tag with an optional inline style.
-- @param tag string HTML tag name
-- @param styles table Style map
-- @param attrs string|nil Extra attributes (already escaped)
-- @return string
local function open_tag(tag, styles, attrs)
  local style = styles[tag]
  local parts = { "<", tag }
  if style then
    parts[#parts + 1] = ' style="'
    parts[#parts + 1] = style
    parts[#parts + 1] = '"'
  end
  if attrs then
    parts[#parts + 1] = " "
    parts[#parts + 1] = attrs
  end
  parts[#parts + 1] = ">"
  return table.concat(parts)
end

--- Return a self-closing / void tag with an optional inline style.
-- @param tag string HTML tag name
-- @param styles table Style map
-- @param attrs string|nil Extra attributes
-- @return string
local function void_tag(tag, styles, attrs)
  local style = styles[tag]
  local parts = { "<", tag }
  if style then
    parts[#parts + 1] = ' style="'
    parts[#parts + 1] = style
    parts[#parts + 1] = '"'
  end
  if attrs then
    parts[#parts + 1] = " "
    parts[#parts + 1] = attrs
  end
  parts[#parts + 1] = " />"
  return table.concat(parts)
end

---------------------------------------------------------------------------
-- Inline parser
---------------------------------------------------------------------------

--- Parse inline markdown formatting and return HTML.
-- Handles: backtick code, images, links, strikethrough, bold, italic, plain text.
-- @param text string Raw inline text
-- @param styles table Style map
-- @return string HTML
local function parse_inlines(text, styles)
  local out = {}
  local i = 1
  local len = #text

  while i <= len do
    local ch = text:sub(i, i)

    -- Backtick code span
    if ch == "`" then
      -- Count opening backticks
      local tick_start = i
      while i <= len and text:sub(i, i) == "`" do
        i = i + 1
      end
      local ticks = text:sub(tick_start, i - 1)
      local close = text:find(ticks, i, true)
      if close then
        local code = text:sub(i, close - 1)
        -- Strip one leading and one trailing space if both present
        if #code >= 2 and code:sub(1, 1) == " " and code:sub(-1) == " " then
          code = code:sub(2, -2)
        end
        out[#out + 1] = open_tag("code", styles) .. escape_html(code) .. "</code>"
        i = close + #ticks
      else
        -- No closing ticks — emit literal
        out[#out + 1] = escape_html(ticks)
      end

    -- Image ![alt](src "title")
    elseif ch == "!" and i + 1 <= len and text:sub(i + 1, i + 1) == "[" then
      local alt_start = i + 2
      local alt_end = text:find("]", alt_start, true)
      if alt_end and alt_end + 1 <= len and text:sub(alt_end + 1, alt_end + 1) == "(" then
        local paren_end = text:find(")", alt_end + 2, true)
        if paren_end then
          local alt = text:sub(alt_start, alt_end - 1)
          local inside = text:sub(alt_end + 2, paren_end - 1)
          local src, title = inside:match('^(.-)%s+"(.*)"$')
          if not src then
            src = inside
          end
          local attrs = 'src="' .. escape_html(src) .. '" alt="' .. escape_html(alt) .. '"'
          if title then
            attrs = attrs .. ' title="' .. escape_html(title) .. '"'
          end
          out[#out + 1] = void_tag("img", styles, attrs)
          i = paren_end + 1
        else
          out[#out + 1] = escape_html("![")
          i = alt_start
        end
      else
        out[#out + 1] = escape_html("![")
        i = alt_start
      end

    -- Link [text](href "title")
    elseif ch == "[" then
      local link_start = i + 1
      -- Find matching ] accounting for nested brackets
      local depth = 1
      local j = link_start
      while j <= len and depth > 0 do
        local c = text:sub(j, j)
        if c == "[" then depth = depth + 1
        elseif c == "]" then depth = depth - 1 end
        j = j + 1
      end
      local bracket_end = j - 1 -- position of ]
      if depth == 0 and bracket_end + 1 <= len and text:sub(bracket_end + 1, bracket_end + 1) == "(" then
        local paren_end = text:find(")", bracket_end + 2, true)
        if paren_end then
          local link_text = text:sub(link_start, bracket_end - 1)
          local inside = text:sub(bracket_end + 2, paren_end - 1)
          local href, title = inside:match('^(.-)%s+"(.*)"$')
          if not href then
            href = inside
          end
          local attrs = 'href="' .. escape_html(href) .. '"'
          if title then
            attrs = attrs .. ' title="' .. escape_html(title) .. '"'
          end
          out[#out + 1] = open_tag("a", styles, attrs) .. parse_inlines(link_text, styles) .. "</a>"
          i = paren_end + 1
        else
          out[#out + 1] = escape_html("[")
          i = link_start
        end
      else
        out[#out + 1] = escape_html("[")
        i = link_start
      end

    -- Strikethrough ~~text~~
    elseif ch == "~" and i + 1 <= len and text:sub(i + 1, i + 1) == "~" then
      local close = text:find("~~", i + 2, true)
      if close then
        local inner = text:sub(i + 2, close - 1)
        out[#out + 1] = open_tag("del", styles) .. parse_inlines(inner, styles) .. "</del>"
        i = close + 2
      else
        out[#out + 1] = "~~"
        i = i + 2
      end

    -- Bold **text** or __text__
    elseif (ch == "*" and i + 1 <= len and text:sub(i + 1, i + 1) == "*")
        or (ch == "_" and i + 1 <= len and text:sub(i + 1, i + 1) == "_") then
      local marker = text:sub(i, i + 1)
      local close = text:find(marker, i + 2, true)
      if close then
        local inner = text:sub(i + 2, close - 1)
        out[#out + 1] = open_tag("strong", styles) .. parse_inlines(inner, styles) .. "</strong>"
        i = close + 2
      else
        out[#out + 1] = escape_html(marker)
        i = i + 2
      end

    -- Italic *text* or _text_
    elseif ch == "*" or ch == "_" then
      -- Find closing single delimiter that is not part of a double delimiter
      local close = nil
      local search = i + 1
      while search <= len do
        local pos = text:find(ch, search, true)
        if not pos then break end
        -- Check if this is a double delimiter (bold)
        if pos + 1 <= len and text:sub(pos + 1, pos + 1) == ch then
          -- Skip past the double delimiter and its matched closing pair
          local bold_close = text:find(ch .. ch, pos + 2, true)
          if bold_close then
            search = bold_close + 2
          else
            search = pos + 2
          end
        else
          close = pos
          break
        end
      end
      if close then
        local inner = text:sub(i + 1, close - 1)
        out[#out + 1] = open_tag("em", styles) .. parse_inlines(inner, styles) .. "</em>"
        i = close + 1
      else
        out[#out + 1] = escape_html(ch)
        i = i + 1
      end

    -- HTML entity passthrough (&amp; etc.)
    elseif ch == "&" then
      -- Check if this looks like an entity (e.g. &amp; &lt; &#123; &#x1F;)
      local entity = text:match("^(&[%a%d#]+;)", i)
      if entity then
        out[#out + 1] = entity
        i = i + #entity
      else
        out[#out + 1] = "&amp;"
        i = i + 1
      end

    -- Angle brackets: check for autolinks first
    elseif ch == "<" then
      local autolink = text:match("^<(https?://[^%s>]+)>", i)
      if not autolink then
        autolink = text:match("^<(mailto:[^%s>]+)>", i)
      end
      if not autolink then
        local email = text:match("^<([%w._%+%-]+@[%w._%-]+%.[%a]+)>", i)
        if email then
          autolink = "mailto:" .. email
        end
      end
      if autolink then
        local display = autolink:gsub("^mailto:", "")
        local attrs = 'href="' .. escape_html(autolink) .. '"'
        out[#out + 1] = open_tag("a", styles, attrs) .. escape_html(display) .. "</a>"
        i = i + #text:match("^<[^>]+>", i)
      else
        out[#out + 1] = "&lt;"
        i = i + 1
      end
    elseif ch == ">" then
      out[#out + 1] = "&gt;"
      i = i + 1

    -- Escaped characters
    elseif ch == "\\" and i + 1 <= len then
      local next_ch = text:sub(i + 1, i + 1)
      if next_ch:match("[\\`*_%[%]()~#>!|%-]") then
        out[#out + 1] = escape_html(next_ch)
        i = i + 2
      else
        out[#out + 1] = "\\"
        i = i + 1
      end

    -- Plain text
    else
      out[#out + 1] = escape_html(ch)
      i = i + 1
    end
  end

  return table.concat(out)
end

---------------------------------------------------------------------------
-- Block parser
---------------------------------------------------------------------------

--- Parse lines into a block AST.
-- @param lines string[] Array of text lines
-- @return table[] Array of block nodes
local function parse_blocks(lines)
  local blocks = {}
  local i = 1
  local n = #lines

  while i <= n do
    local line = lines[i]

    -- Blank line — skip
    if line:match("^%s*$") then
      i = i + 1

    -- Fenced code block (``` or ~~~)
    elseif line:match("^%s*```") or line:match("^%s*~~~") then
      local fence = line:match("^%s*(`+)") or line:match("^%s*(~+)")
      local lang = line:match("^%s*[`~]+(%S*)")
      if lang == "" then lang = nil end
      local code_lines = {}
      i = i + 1
      while i <= n and not lines[i]:match("^%s*" .. fence:sub(1, 1):rep(#fence)) do
        code_lines[#code_lines + 1] = lines[i]
        i = i + 1
      end
      if i <= n then i = i + 1 end -- skip closing fence
      blocks[#blocks + 1] = { type = "code_block", lang = lang, text = table.concat(code_lines, "\n") }

    -- ATX heading
    elseif line:match("^(#+)%s") then
      local hashes, text = line:match("^(#+)%s+(.*)")
      local level = #hashes
      if level > 6 then level = 6 end
      -- Strip trailing hashes
      text = text:gsub("%s+#+%s*$", "")
      blocks[#blocks + 1] = { type = "header", level = level, text = text }
      i = i + 1

    -- Horizontal rule
    elseif line:match("^%s*%-%-%-+%s*$") or line:match("^%s*%*%*%*+%s*$") or line:match("^%s*___+%s*$") then
      blocks[#blocks + 1] = { type = "hr" }
      i = i + 1

    -- Table (line with |, next line is separator)
    elseif line:find("|", 1, true) and i + 1 <= n and lines[i + 1]:match("^[|%s%-:]+$") then
      local header_line = line
      local sep_line = lines[i + 1]

      -- Parse alignments from separator
      local alignments = {}
      for cell in sep_line:gmatch("[^|]+") do
        cell = cell:match("^%s*(.-)%s*$") -- trim
        if cell ~= "" then
          local left = cell:sub(1, 1) == ":"
          local right = cell:sub(-1) == ":"
          if left and right then
            alignments[#alignments + 1] = "center"
          elseif right then
            alignments[#alignments + 1] = "right"
          else
            alignments[#alignments + 1] = "left"
          end
        end
      end

      -- Parse header cells
      local head = {}
      local h = header_line:match("^|?(.*)|?$")
      for cell in h:gmatch("[^|]+") do
        head[#head + 1] = cell:match("^%s*(.-)%s*$")
      end

      -- Parse body rows
      local rows = {}
      i = i + 2
      while i <= n and lines[i]:find("|", 1, true) and not lines[i]:match("^%s*$") do
        local row = {}
        local r = lines[i]:match("^|?(.*)|?$")
        for cell in r:gmatch("[^|]+") do
          row[#row + 1] = cell:match("^%s*(.-)%s*$")
        end
        rows[#rows + 1] = row
        i = i + 1
      end

      blocks[#blocks + 1] = { type = "table", alignments = alignments, head = head, rows = rows }

    -- Blockquote
    elseif line:match("^%s*>") then
      local quote_lines = {}
      while i <= n and (lines[i]:match("^%s*>") or (lines[i]:match("^%s*%S") and not lines[i]:match("^%s*$"))) do
        local content = lines[i]:match("^%s*>%s?(.*)$")
        if content then
          quote_lines[#quote_lines + 1] = content
        else
          -- Continuation line (lazy blockquote)
          if lines[i]:match("^%s*>") then
            quote_lines[#quote_lines + 1] = ""
          else
            break
          end
        end
        i = i + 1
      end
      blocks[#blocks + 1] = { type = "blockquote", children = parse_blocks(quote_lines) }

    -- Unordered list
    elseif line:match("^%s*[%-%*%+]%s") then
      local items = {}
      while i <= n and (lines[i]:match("^%s*[%-%*%+]%s") or lines[i]:match("^%s+%S")) do
        if lines[i]:match("^%s*[%-%*%+]%s") then
          -- Check for horizontal rule pattern: --- with nothing else
          if lines[i]:match("^%s*%-%-%-+%s*$") then break end

          local indent = #(lines[i]:match("^(%s*)"))
          local content = lines[i]:match("^%s*[%-%*%+]%s+(.*)")
          local task = nil

          -- Task list
          if content:match("^%[[ xX]%]%s") then
            local check = content:match("^%[([xX ])%]")
            task = (check == "x" or check == "X")
            content = content:match("^%[[ xX]%]%s+(.*)")
          end

          local item_lines = { content }
          local content_indent = indent + 2
          i = i + 1
          while i <= n and not lines[i]:match("^%s*$") do
            local sub_indent = #(lines[i]:match("^(%s*)"))
            if sub_indent > indent then
              item_lines[#item_lines + 1] = lines[i]:sub(content_indent + 1)
            elseif lines[i]:match("^%s*[%-%*%+]%s") or lines[i]:match("^%s*%d+[.)]%s") then
              break
            else
              break
            end
            i = i + 1
          end

          local children = parse_blocks(item_lines)
          items[#items + 1] = { children = children, task = task }
        else
          i = i + 1
        end
      end
      blocks[#blocks + 1] = { type = "bullet_list", items = items }

    -- Ordered list
    elseif line:match("^%s*%d+[.)]%s") then
      local start_num = tonumber(line:match("^%s*(%d+)"))
      local items = {}
      while i <= n and (lines[i]:match("^%s*%d+[.)]%s") or lines[i]:match("^%s+%S")) do
        if lines[i]:match("^%s*%d+[.)]%s") then
          local indent = #(lines[i]:match("^(%s*)"))
          local marker = lines[i]:match("^%s*(%d+[.)])")
          local content = lines[i]:match("^%s*%d+[.)]%s+(.*)")
          local item_lines = { content }
          local content_indent = indent + #marker + 1
          i = i + 1
          while i <= n and not lines[i]:match("^%s*$") do
            local sub_indent = #(lines[i]:match("^(%s*)"))
            if sub_indent > indent then
              item_lines[#item_lines + 1] = lines[i]:sub(content_indent + 1)
            elseif lines[i]:match("^%s*[%-%*%+]%s") or lines[i]:match("^%s*%d+[.)]%s") then
              break
            else
              break
            end
            i = i + 1
          end
          local children = parse_blocks(item_lines)
          items[#items + 1] = { children = children }
        else
          i = i + 1
        end
      end
      blocks[#blocks + 1] = { type = "ordered_list", start = start_num, items = items }

    -- Paragraph (default)
    else
      local para_lines = {}
      while i <= n and not lines[i]:match("^%s*$")
          and not lines[i]:match("^#+%s")
          and not lines[i]:match("^%s*```")
          and not lines[i]:match("^%s*~~~")
          and not lines[i]:match("^%s*>")
          and not lines[i]:match("^%s*[%-%*%+]%s")
          and not lines[i]:match("^%s*%d+[.)]%s")
          and not lines[i]:match("^%s*%-%-%-+%s*$")
          and not lines[i]:match("^%s*%*%*%*+%s*$")
          and not lines[i]:match("^%s*___+%s*$") do
        para_lines[#para_lines + 1] = lines[i]
        i = i + 1
      end
      if #para_lines > 0 then
        blocks[#blocks + 1] = { type = "paragraph", text = table.concat(para_lines, "\n") }
      end
    end
  end

  return blocks
end

---------------------------------------------------------------------------
-- HTML emitter
---------------------------------------------------------------------------

local emit_block -- forward declaration

--- Emit a single block node as HTML.
-- @param node table Block AST node
-- @param styles table Style map
-- @return string HTML fragment
emit_block = function(node, styles)
  local t = node.type

  if t == "header" then
    local tag = "h" .. node.level
    return open_tag(tag, styles) .. parse_inlines(node.text, styles) .. "</" .. tag .. ">\n"

  elseif t == "paragraph" then
    return open_tag("p", styles) .. parse_inlines(node.text, styles) .. "</p>\n"

  elseif t == "code_block" then
    local code = escape_html(node.text)
    return open_tag("pre", styles) .. open_tag("code", styles) .. code .. "</code></pre>\n"

  elseif t == "hr" then
    return void_tag("hr", styles) .. "\n"

  elseif t == "blockquote" then
    local inner = emit_blocks(node.children, styles)
    return open_tag("blockquote", styles) .. "\n" .. inner .. "</blockquote>\n"

  elseif t == "bullet_list" then
    local parts = { open_tag("ul", styles) .. "\n" }
    for _, item in ipairs(node.items) do
      local li_content = ""
      if item.task ~= nil then
        local checkbox = item.task and "&#9745; " or "&#9744; "
        li_content = checkbox
      end
      li_content = li_content .. emit_blocks_inline(item.children, styles)
      parts[#parts + 1] = open_tag("li", styles) .. li_content .. "</li>\n"
    end
    parts[#parts + 1] = "</ul>\n"
    return table.concat(parts)

  elseif t == "ordered_list" then
    local attrs = nil
    if node.start and node.start ~= 1 then
      attrs = 'start="' .. node.start .. '"'
    end
    local parts = { open_tag("ol", styles, attrs) .. "\n" }
    for _, item in ipairs(node.items) do
      local li_content = emit_blocks_inline(item.children, styles)
      parts[#parts + 1] = open_tag("li", styles) .. li_content .. "</li>\n"
    end
    parts[#parts + 1] = "</ol>\n"
    return table.concat(parts)

  elseif t == "table" then
    local parts = { open_tag("table", styles) .. "\n" }
    -- Header row
    local thead_row_style = styles.thead_row or ""
    if thead_row_style ~= "" then
      parts[#parts + 1] = '<thead><tr style="' .. thead_row_style .. '">\n'
    else
      parts[#parts + 1] = "<thead><tr>\n"
    end
    for col, cell in ipairs(node.head) do
      local align = node.alignments[col]
      local th_style = styles.th or ""
      if align and align ~= "left" then
        th_style = th_style .. " text-align:" .. align .. ";"
      end
      parts[#parts + 1] = '<th style="' .. th_style .. '">' .. parse_inlines(cell, styles) .. "</th>\n"
    end
    parts[#parts + 1] = "</tr></thead>\n"
    -- Body rows
    parts[#parts + 1] = "<tbody>\n"
    for row_idx, row in ipairs(node.rows) do
      local row_style = row_idx % 2 == 0 and (styles.tr_even or "") or (styles.tr_odd or "")
      if row_style ~= "" then
        parts[#parts + 1] = '<tr style="' .. row_style .. '">\n'
      else
        parts[#parts + 1] = "<tr>\n"
      end
      for col, cell in ipairs(row) do
        local align = node.alignments[col]
        local td_style = styles.td or ""
        if align and align ~= "left" then
          td_style = td_style .. " text-align:" .. align .. ";"
        end
        parts[#parts + 1] = '<td style="' .. td_style .. '">' .. parse_inlines(cell, styles) .. "</td>\n"
      end
      parts[#parts + 1] = "</tr>\n"
    end
    parts[#parts + 1] = "</tbody>\n</table>\n"
    return table.concat(parts)
  end

  return ""
end

--- Emit a list of block nodes as HTML.
-- @param blocks table[] Block AST nodes
-- @param styles table Style map
-- @return string HTML
function emit_blocks(blocks, styles)
  local parts = {}
  for _, block in ipairs(blocks) do
    parts[#parts + 1] = emit_block(block, styles)
  end
  return table.concat(parts)
end

--- Emit blocks for inline list-item context.
-- If there's a single paragraph, unwrap it (no <p> tags inside <li>).
-- @param blocks table[] Block AST nodes
-- @param styles table Style map
-- @return string HTML
function emit_blocks_inline(blocks, styles)
  if #blocks == 1 and blocks[1].type == "paragraph" then
    return parse_inlines(blocks[1].text, styles)
  end
  return emit_blocks(blocks, styles)
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Convert markdown to inline-styled HTML.
-- @param markdown string Raw markdown input
-- @param styles table<string, string> Resolved style map
-- @return string|nil html Rendered HTML
-- @return string|nil err Error message (always nil for native backend)
function M.convert(markdown, styles)
  if not markdown or markdown == "" then
    return "", nil
  end

  styles = styles or {}

  -- Split input into lines
  local lines = {}
  for line in (markdown .. "\n"):gmatch("([^\n]*)\n") do
    lines[#lines + 1] = line
  end

  local blocks = parse_blocks(lines)
  local html = emit_blocks(blocks, styles)

  return html, nil
end

return M
