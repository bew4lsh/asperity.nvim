-- Tests for the native (pure-Lua) backend.

local native = require("stylemd.backends.native")

local styles = {
  h1         = "font-size:24px;",
  h2         = "font-size:20px;",
  h3         = "font-size:16px;",
  h4         = "font-size:14px;",
  h5         = "font-size:12px;",
  h6         = "font-size:12px; color:#6a737d;",
  p          = "font-size:14px;",
  a          = "color:#0366d6;",
  strong     = "font-weight:700;",
  em         = "font-style:italic;",
  del        = "text-decoration:line-through;",
  code       = "font-family:monospace;",
  pre        = "background:#f6f8fa;",
  blockquote = "border-left:4px solid #dfe2e5;",
  ul         = "padding-left:2em;",
  ol         = "padding-left:2em;",
  li         = "margin:4px 0;",
  table      = "border-collapse:collapse;",
  th         = "border:1px solid #dfe2e5; padding:8px;",
  td         = "border:1px solid #dfe2e5; padding:8px;",
  hr         = "border:none; border-top:2px solid #e1e4e8;",
  img        = "max-width:100%;",
}

local function convert(md)
  local html, err = native.convert(md, styles)
  assert(html, "convert returned nil: " .. tostring(err))
  return html
end

---------------------------------------------------------------------------
-- Headers
---------------------------------------------------------------------------

describe("Native: Headers", function()
  it("renders h1–h6", function()
    for level = 1, 6 do
      local html = convert(string.rep("#", level) .. " Heading " .. level)
      assert_contains(html, "<h" .. level)
      assert_contains(html, "Heading " .. level)
      assert_contains(html, "</h" .. level .. ">")
    end
  end)

  it("strips trailing hashes", function()
    local html = convert("## Hello ##")
    assert_contains(html, "Hello")
    assert_not_contains(html, "##")
  end)

  it("applies inline formatting in headers", function()
    local html = convert("# **Bold** header")
    assert_contains(html, "<strong")
    assert_contains(html, "Bold")
  end)
end)

---------------------------------------------------------------------------
-- Paragraphs
---------------------------------------------------------------------------

describe("Native: Paragraphs", function()
  it("renders a simple paragraph", function()
    local html = convert("Hello world")
    assert_contains(html, '<p style="font-size:14px;">')
    assert_contains(html, "Hello world")
  end)

  it("joins continuation lines", function()
    local html = convert("Line one\nLine two")
    assert_contains(html, "Line one\nLine two")
    -- Should be a single <p>
    local count = 0
    for _ in html:gmatch("<p ") do count = count + 1 end
    assert_eq(count, 1, "should be one paragraph")
  end)

  it("separates paragraphs by blank lines", function()
    local html = convert("Para one\n\nPara two")
    local count = 0
    for _ in html:gmatch("<p ") do count = count + 1 end
    assert_eq(count, 2, "should be two paragraphs")
  end)
end)

---------------------------------------------------------------------------
-- Inline formatting
---------------------------------------------------------------------------

describe("Native: Inline formatting", function()
  it("renders bold with **", function()
    local html = convert("**bold**")
    assert_contains(html, "<strong")
    assert_contains(html, "bold")
  end)

  it("renders bold with __", function()
    local html = convert("__bold__")
    assert_contains(html, "<strong")
  end)

  it("renders italic with *", function()
    local html = convert("*italic*")
    assert_contains(html, "<em")
    assert_contains(html, "italic")
  end)

  it("renders italic with _", function()
    local html = convert("_italic_")
    assert_contains(html, "<em")
  end)

  it("renders strikethrough", function()
    local html = convert("~~deleted~~")
    assert_contains(html, "<del")
    assert_contains(html, "deleted")
  end)

  it("renders inline code", function()
    local html = convert("`code`")
    assert_contains(html, "<code")
    assert_contains(html, "code")
  end)

  it("code suppresses inner parsing", function()
    local html = convert("`**not bold**`")
    assert_not_contains(html, "<strong")
    assert_contains(html, "**not bold**")
  end)

  it("handles nested bold inside italic", function()
    local html = convert("*text **bold** more*")
    assert_contains(html, "<em")
    assert_contains(html, "<strong")
  end)
end)

---------------------------------------------------------------------------
-- Links and images
---------------------------------------------------------------------------

describe("Native: Links and images", function()
  it("renders a link", function()
    local html = convert("[Click](https://example.com)")
    assert_contains(html, 'href="https://example.com"')
    assert_contains(html, "Click")
    assert_contains(html, "</a>")
  end)

  it("renders a link with title", function()
    local html = convert('[Click](https://example.com "Title")')
    assert_contains(html, 'title="Title"')
  end)

  it("renders formatting inside link text", function()
    local html = convert("[**bold link**](https://example.com)")
    assert_contains(html, "<strong")
    assert_contains(html, "bold link")
    assert_contains(html, "</a>")
  end)

  it("renders an autolink (URL)", function()
    local html = convert("<https://example.com>")
    assert_contains(html, 'href="https://example.com"')
    assert_contains(html, "https://example.com</a>")
  end)

  it("renders an autolink (http)", function()
    local html = convert("<http://www.google.com>")
    assert_contains(html, 'href="http://www.google.com"')
    assert_contains(html, "http://www.google.com</a>")
  end)

  it("renders an email autolink", function()
    local html = convert("<user@example.com>")
    assert_contains(html, 'href="mailto:user@example.com"')
    assert_contains(html, "user@example.com</a>")
  end)

  it("renders an image", function()
    local html = convert("![alt text](image.png)")
    assert_contains(html, 'src="image.png"')
    assert_contains(html, 'alt="alt text"')
    assert_contains(html, "<img")
  end)

  it("renders an image with title", function()
    local html = convert('![alt](image.png "Photo")')
    assert_contains(html, 'title="Photo"')
  end)
end)

---------------------------------------------------------------------------
-- Code blocks
---------------------------------------------------------------------------

describe("Native: Code blocks", function()
  it("renders a fenced code block", function()
    local html = convert("```\nfoo\nbar\n```")
    assert_contains(html, "<pre")
    assert_contains(html, "<code")
    assert_contains(html, "foo\nbar")
  end)

  it("renders with language tag", function()
    local html = convert("```lua\nprint('hi')\n```")
    assert_contains(html, "<pre")
    assert_contains(html, "print")
  end)

  it("escapes HTML inside code blocks", function()
    local html = convert("```\n<div>&amp;\n```")
    assert_contains(html, "&lt;div&gt;")
    assert_contains(html, "&amp;amp;")
  end)
end)

---------------------------------------------------------------------------
-- Lists
---------------------------------------------------------------------------

describe("Native: Lists", function()
  it("renders an unordered list", function()
    local html = convert("- one\n- two\n- three")
    assert_contains(html, "<ul")
    assert_contains(html, "<li")
    assert_contains(html, "one")
    assert_contains(html, "two")
    assert_contains(html, "three")
  end)

  it("renders with * and + markers", function()
    local html = convert("* alpha\n+ beta")
    assert_contains(html, "alpha")
    assert_contains(html, "beta")
  end)

  it("renders an ordered list", function()
    local html = convert("1. first\n2. second")
    assert_contains(html, "<ol")
    assert_contains(html, "<li")
    assert_contains(html, "first")
  end)

  it("handles non-1 start number", function()
    local html = convert("3. third\n4. fourth")
    assert_contains(html, 'start="3"')
  end)

  it("renders task lists", function()
    local html = convert("- [x] done\n- [ ] todo")
    assert_contains(html, "&#9745;")  -- checked
    assert_contains(html, "&#9744;")  -- unchecked
    assert_contains(html, "done")
    assert_contains(html, "todo")
  end)
end)

---------------------------------------------------------------------------
-- Blockquotes
---------------------------------------------------------------------------

describe("Native: Blockquotes", function()
  it("renders a blockquote", function()
    local html = convert("> quoted text")
    assert_contains(html, "<blockquote")
    assert_contains(html, "quoted text")
  end)

  it("renders multi-line blockquote", function()
    local html = convert("> line one\n> line two")
    assert_contains(html, "line one")
    assert_contains(html, "line two")
  end)

  it("applies inline formatting in blockquotes", function()
    local html = convert("> **bold** in quote")
    assert_contains(html, "<strong")
    assert_contains(html, "bold")
  end)
end)

---------------------------------------------------------------------------
-- Tables
---------------------------------------------------------------------------

describe("Native: Tables", function()
  it("renders a basic table", function()
    local html = convert("| A | B |\n|---|---|\n| 1 | 2 |")
    assert_contains(html, "<table")
    assert_contains(html, "<th")
    assert_contains(html, "<td")
    assert_contains(html, "A")
    assert_contains(html, "1")
  end)

  it("respects alignment", function()
    local html = convert("| L | C | R |\n|:--|:--:|--:|\n| a | b | c |")
    assert_match(html, 'text%-align:center')
    assert_match(html, 'text%-align:right')
  end)

  it("applies inline formatting in cells", function()
    local html = convert("| **bold** | *em* |\n|---|---|\n| a | b |")
    assert_contains(html, "<strong")
    assert_contains(html, "<em")
  end)
end)

---------------------------------------------------------------------------
-- Horizontal rules
---------------------------------------------------------------------------

describe("Native: Horizontal rules", function()
  it("renders --- as hr", function()
    local html = convert("---")
    assert_contains(html, "<hr")
  end)

  it("renders *** as hr", function()
    local html = convert("***")
    assert_contains(html, "<hr")
  end)

  it("renders ___ as hr", function()
    local html = convert("___")
    assert_contains(html, "<hr")
  end)
end)

---------------------------------------------------------------------------
-- Styles
---------------------------------------------------------------------------

describe("Native: Style injection", function()
  it("injects styles into tags", function()
    local html = convert("# Hello")
    assert_contains(html, 'style="font-size:24px;"')
  end)

  it("works with empty styles", function()
    local html = native.convert("Hello", {})
    assert_contains(html, "<p>")
    assert_contains(html, "Hello")
  end)
end)
