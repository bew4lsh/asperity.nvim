-- filters/inline-style.lua
-- Pandoc Lua filter that injects inline CSS styles into HTML output.
--
-- Invoked by pandoc via:
--   pandoc --lua-filter=inline-style.lua \
--          --metadata=stylemd-styles-file:/path/to/styles.json
--
-- The styles file is a JSON object mapping HTML element names to CSS
-- declaration strings. This filter reads it once, then attaches
-- style="" attributes to every matching AST node.

local styles = {}

-----------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------

--- Read and decode the JSON style map from the file path in metadata.
local function load_styles(meta)
  local file_val = meta["stylemd-styles-file"]
  if not file_val then
    io.stderr:write("[stylemd filter] no stylemd-styles-file in metadata\n")
    return
  end

  -- Extract the plain string from the MetaInlines/MetaString value
  local filepath
  if type(file_val) == "string" then
    filepath = file_val
  elseif file_val.t == "MetaInlines" then
    filepath = pandoc.utils.stringify(file_val)
  elseif file_val.t == "MetaString" then
    filepath = file_val.text or pandoc.utils.stringify(file_val)
  else
    filepath = pandoc.utils.stringify(file_val)
  end

  local f = io.open(filepath, "r")
  if not f then
    io.stderr:write(("[stylemd filter] cannot open styles file: %s\n"):format(filepath))
    return
  end

  local json_str = f:read("*a")
  f:close()

  -- pandoc ships with pandoc.json (>= 3.0) or we fall back to the built-in
  local decode
  if pandoc.json and pandoc.json.decode then
    decode = pandoc.json.decode
  else
    -- For older pandoc, use a minimal JSON decode via the Lua runtime
    -- that pandoc bundles (based on dkjson or similar).
    decode = function(s)
      -- pandoc's Lua environment always has some JSON support
      local ok, mod = pcall(require, "dkjson")
      if ok then return mod.decode(s) end
      ok, mod = pcall(require, "cjson")
      if ok then return mod.decode(s) end
      -- last resort: pandoc.read a code block
      error("[stylemd filter] no JSON decoder available")
    end
  end

  local ok, decoded = pcall(decode, json_str)
  if not ok then
    io.stderr:write(("[stylemd filter] JSON decode error: %s\n"):format(tostring(decoded)))
    return
  end

  styles = decoded or {}
end

--- Get inline style string for an element name, or empty string.
local function s(element_name)
  return styles[element_name] or ""
end

--- Render a list of pandoc Inlines to an HTML string.
local function inlines_to_html(inlines)
  return pandoc.write(pandoc.Pandoc({ pandoc.Plain(inlines) }), "html")
end

--- Render a list of pandoc Blocks to an HTML string.
local function blocks_to_html(blocks)
  return pandoc.write(pandoc.Pandoc(blocks), "html")
end

--- Wrap content in an HTML tag with an optional inline style.
local function styled_tag(tag, content, element_name, attrs)
  local style = s(element_name)
  local attr_str = ""
  if attrs then
    for k, v in pairs(attrs) do
      attr_str = attr_str .. (' %s="%s"'):format(k, v)
    end
  end
  if style ~= "" then
    return ("<%s style=\"%s\"%s>%s</%s>"):format(tag, style, attr_str, content, tag)
  end
  return ("<%s%s>%s</%s>"):format(tag, attr_str, content, tag)
end

--- Wrap content in a self-closing HTML tag with an optional inline style.
local function styled_void_tag(tag, element_name, attrs)
  local style = s(element_name)
  local attr_str = ""
  if attrs then
    for k, v in pairs(attrs) do
      attr_str = attr_str .. (' %s="%s"'):format(k, v)
    end
  end
  if style ~= "" then
    return ("<%s style=\"%s\"%s />"):format(tag, style, attr_str)
  end
  return ("<%s%s />"):format(tag, attr_str)
end

-----------------------------------------------------------------------
-- Filter functions
-----------------------------------------------------------------------

local function Meta(meta)
  load_styles(meta)
  return meta
end

local function Header(el)
  local tag = "h" .. el.level
  local content = inlines_to_html(el.content)
  return pandoc.RawBlock("html", styled_tag(tag, content, tag))
end

local function Para(el)
  local content = inlines_to_html(el.content)
  return pandoc.RawBlock("html", styled_tag("p", content, "p"))
end

local function CodeBlock(el)
  local lang_class = ""
  if el.classes and #el.classes > 0 then
    lang_class = (' class="language-%s"'):format(el.classes[1])
  end
  local code_style = s("code")
  local code_tag
  if code_style ~= "" then
    code_tag = ('<code style="%s"%s>%s</code>'):format(
      code_style, lang_class, el.text
    )
  else
    code_tag = ("<code%s>%s</code>"):format(lang_class, el.text)
  end
  return pandoc.RawBlock("html", styled_tag("pre", code_tag, "pre"))
end

local function Code(el)
  return pandoc.RawInline("html", styled_tag("code", el.text, "code"))
end

local function BlockQuote(el)
  local content = blocks_to_html(el.content)
  return pandoc.RawBlock("html", styled_tag("blockquote", content, "blockquote"))
end

local function BulletList(el)
  local items = {}
  for _, item in ipairs(el.content) do
    local item_html = blocks_to_html(item)
    table.insert(items, styled_tag("li", item_html, "li"))
  end
  return pandoc.RawBlock("html", styled_tag("ul", table.concat(items, "\n"), "ul"))
end

local function OrderedList(el)
  local items = {}
  for _, item in ipairs(el.content) do
    local item_html = blocks_to_html(item)
    table.insert(items, styled_tag("li", item_html, "li"))
  end
  local attrs = {}
  if el.start and el.start ~= 1 then
    attrs.start = tostring(el.start)
  end
  return pandoc.RawBlock("html", styled_tag("ol", table.concat(items, "\n"), "ol", attrs))
end

local function Strong(el)
  local content = inlines_to_html(el.content)
  return pandoc.RawInline("html", styled_tag("strong", content, "strong"))
end

local function Emph(el)
  local content = inlines_to_html(el.content)
  return pandoc.RawInline("html", styled_tag("em", content, "em"))
end

local function Strikeout(el)
  local content = inlines_to_html(el.content)
  return pandoc.RawInline("html", styled_tag("del", content, "del"))
end

local function Link(el)
  local content = inlines_to_html(el.content)
  return pandoc.RawInline("html", styled_tag("a", content, "a", { href = el.target }))
end

local function Image(el)
  local attrs = { src = el.src }
  if el.title and el.title ~= "" then
    attrs.title = el.title
  end
  local alt = pandoc.utils.stringify(el.caption or el.content or {})
  if alt ~= "" then
    attrs.alt = alt
  end
  return pandoc.RawInline("html", styled_void_tag("img", "img", attrs))
end

local function HorizontalRule()
  return pandoc.RawBlock("html", styled_void_tag("hr", "hr"))
end

local function Table(el)
  -- Render table cells with inline styles.
  -- Pandoc Table AST (>= 2.17): el.head, el.bodies, el.foot

  local function render_cell(cell, element_name)
    local content = blocks_to_html(cell.contents or cell[2] or {})
    local colspan = cell.col_span or (cell.attr and cell[4]) or 1
    local rowspan = cell.row_span or (cell.attr and cell[3]) or 1
    local attrs = {}
    if colspan > 1 then attrs.colspan = tostring(colspan) end
    if rowspan > 1 then attrs.rowspan = tostring(rowspan) end
    local tag = element_name == "th" and "th" or "td"
    return styled_tag(tag, content, element_name, attrs)
  end

  local function render_row(row, element_name)
    local cells = {}
    -- row can be a pandoc.Row or a list of cells
    local cell_list = row.cells or row[2] or row
    for _, cell in ipairs(cell_list) do
      table.insert(cells, render_cell(cell, element_name))
    end
    return "<tr>" .. table.concat(cells) .. "</tr>"
  end

  local rows = {}

  -- Table head
  if el.head then
    local head_rows = el.head.rows or el.head[2] or {}
    for _, row in ipairs(head_rows) do
      table.insert(rows, render_row(row, "th"))
    end
  end

  -- Table bodies
  if el.bodies then
    for _, body in ipairs(el.bodies) do
      -- Each TableBody has head rows and body rows
      local body_head = body.head or body[3] or {}
      for _, row in ipairs(body_head) do
        table.insert(rows, render_row(row, "th"))
      end
      local body_rows = body.body or body[4] or {}
      for _, row in ipairs(body_rows) do
        table.insert(rows, render_row(row, "td"))
      end
    end
  end

  -- Table foot
  if el.foot then
    local foot_rows = el.foot.rows or el.foot[2] or {}
    for _, row in ipairs(foot_rows) do
      table.insert(rows, render_row(row, "td"))
    end
  end

  local inner = table.concat(rows, "\n")
  return pandoc.RawBlock("html", styled_tag("table", inner, "table"))
end

-----------------------------------------------------------------------
-- Filter return — Meta runs first to load styles, then element filters
-----------------------------------------------------------------------
return {
  { Meta = Meta },
  {
    Header = Header,
    Para = Para,
    CodeBlock = CodeBlock,
    BulletList = BulletList,
    OrderedList = OrderedList,
    Table = Table,
    BlockQuote = BlockQuote,
    Code = Code,
    Link = Link,
    Image = Image,
    Strong = Strong,
    Emph = Emph,
    Strikeout = Strikeout,
    HorizontalRule = HorizontalRule,
  },
}
