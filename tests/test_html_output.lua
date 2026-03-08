-- Tests that validate exact HTML output for representative markdown inputs.

local native = require("stylemd.backends.native")

-- Minimal styles to keep assertions readable
local S = {
  h1 = "font-size:24px;",
  h2 = "font-size:20px;",
  h3 = "font-size:16px;",
  p = "margin:0 0 12px;",
  a = "color:blue;",
  strong = "font-weight:700;",
  em = "font-style:italic;",
  del = "text-decoration:line-through;",
  code = "font-family:monospace;",
  pre = "background:#f6f8fa;",
  blockquote = "border-left:4px solid #ddd;",
  ul = "padding-left:2em;",
  ol = "padding-left:2em;",
  li = "margin:4px 0;",
  table = "border-collapse:collapse;",
  th = "border:1px solid #ddd; padding:8px;",
  td = "border:1px solid #ddd; padding:8px;",
  hr = "border-top:1px solid #ccc;",
  img = "max-width:100%;",
}

local function convert(md)
  return (native.convert(md, S))
end

describe("HTML output: Headings", function()
  it("h1 with inline formatting", function()
    assert_eq(
      convert("# Hello **world**"),
      '<h1 style="font-size:24px;">Hello <strong style="font-weight:700;">world</strong></h1>\n'
    )
  end)

  it("h2 with trailing hashes stripped", function()
    assert_eq(
      convert("## Section ##"),
      '<h2 style="font-size:20px;">Section</h2>\n'
    )
  end)
end)

describe("HTML output: Paragraphs", function()
  it("simple paragraph", function()
    assert_eq(
      convert("Hello world"),
      '<p style="margin:0 0 12px;">Hello world</p>\n'
    )
  end)

  it("two paragraphs separated by blank line", function()
    assert_eq(
      convert("First\n\nSecond"),
      '<p style="margin:0 0 12px;">First</p>\n<p style="margin:0 0 12px;">Second</p>\n'
    )
  end)

  it("continuation lines stay in one paragraph", function()
    assert_eq(
      convert("Line one\nLine two"),
      '<p style="margin:0 0 12px;">Line one\nLine two</p>\n'
    )
  end)
end)

describe("HTML output: Inline formatting", function()
  it("bold", function()
    assert_eq(
      convert("**bold**"),
      '<p style="margin:0 0 12px;"><strong style="font-weight:700;">bold</strong></p>\n'
    )
  end)

  it("italic", function()
    assert_eq(
      convert("*italic*"),
      '<p style="margin:0 0 12px;"><em style="font-style:italic;">italic</em></p>\n'
    )
  end)

  it("strikethrough", function()
    assert_eq(
      convert("~~gone~~"),
      '<p style="margin:0 0 12px;"><del style="text-decoration:line-through;">gone</del></p>\n'
    )
  end)

  it("inline code", function()
    assert_eq(
      convert("`x = 1`"),
      '<p style="margin:0 0 12px;"><code style="font-family:monospace;">x = 1</code></p>\n'
    )
  end)

  it("bold inside italic", function()
    assert_eq(
      convert("*a **b** c*"),
      '<p style="margin:0 0 12px;"><em style="font-style:italic;">a <strong style="font-weight:700;">b</strong> c</em></p>\n'
    )
  end)

  it("inline code preserves special chars literally", function()
    assert_eq(
      convert("`<div>&`"),
      '<p style="margin:0 0 12px;"><code style="font-family:monospace;">&lt;div&gt;&amp;</code></p>\n'
    )
  end)
end)

describe("HTML output: Links", function()
  it("simple link", function()
    assert_eq(
      convert("[click](https://example.com)"),
      '<p style="margin:0 0 12px;"><a style="color:blue;" href="https://example.com">click</a></p>\n'
    )
  end)

  it("link with bold text", function()
    assert_eq(
      convert("[**bold**](url)"),
      '<p style="margin:0 0 12px;"><a style="color:blue;" href="url"><strong style="font-weight:700;">bold</strong></a></p>\n'
    )
  end)
end)

describe("HTML output: Images", function()
  it("basic image", function()
    assert_eq(
      convert("![alt](pic.png)"),
      '<p style="margin:0 0 12px;"><img style="max-width:100%;" src="pic.png" alt="alt" /></p>\n'
    )
  end)
end)

describe("HTML output: Code blocks", function()
  it("fenced code block", function()
    assert_eq(
      convert("```\nfoo\nbar\n```"),
      '<pre style="background:#f6f8fa;"><code style="font-family:monospace;">foo\nbar</code></pre>\n'
    )
  end)

  it("HTML is escaped inside code blocks", function()
    assert_eq(
      convert("```\n<b>hi</b>\n```"),
      '<pre style="background:#f6f8fa;"><code style="font-family:monospace;">&lt;b&gt;hi&lt;/b&gt;</code></pre>\n'
    )
  end)
end)

describe("HTML output: Lists", function()
  it("unordered list", function()
    assert_eq(
      convert("- alpha\n- beta"),
      '<ul style="padding-left:2em;">\n'
      .. '<li style="margin:4px 0;">alpha</li>\n'
      .. '<li style="margin:4px 0;">beta</li>\n'
      .. '</ul>\n'
    )
  end)

  it("ordered list starting at 1", function()
    assert_eq(
      convert("1. first\n2. second"),
      '<ol style="padding-left:2em;">\n'
      .. '<li style="margin:4px 0;">first</li>\n'
      .. '<li style="margin:4px 0;">second</li>\n'
      .. '</ol>\n'
    )
  end)

  it("ordered list starting at 5", function()
    assert_eq(
      convert("5. five\n6. six"),
      '<ol style="padding-left:2em;" start="5">\n'
      .. '<li style="margin:4px 0;">five</li>\n'
      .. '<li style="margin:4px 0;">six</li>\n'
      .. '</ol>\n'
    )
  end)

  it("task list", function()
    local html = convert("- [x] done\n- [ ] todo")
    assert_contains(html, '<li style="margin:4px 0;">&#9745; done</li>')
    assert_contains(html, '<li style="margin:4px 0;">&#9744; todo</li>')
  end)
end)

describe("HTML output: Blockquotes", function()
  it("simple blockquote wraps paragraph", function()
    assert_eq(
      convert("> hello"),
      '<blockquote style="border-left:4px solid #ddd;">\n'
      .. '<p style="margin:0 0 12px;">hello</p>\n'
      .. '</blockquote>\n'
    )
  end)
end)

describe("HTML output: Horizontal rule", function()
  it("renders self-closing hr", function()
    assert_eq(
      convert("---"),
      '<hr style="border-top:1px solid #ccc;" />\n'
    )
  end)
end)

describe("HTML output: Tables", function()
  it("basic 2x2 table", function()
    local html = convert("| A | B |\n|---|---|\n| 1 | 2 |")
    assert_contains(html, '<table style="border-collapse:collapse;">')
    assert_contains(html, '<th style="border:1px solid #ddd; padding:8px;">A</th>')
    assert_contains(html, '<td style="border:1px solid #ddd; padding:8px;">1</td>')
  end)

  it("right-aligned column", function()
    local html = convert("| X |\n|--:|\n| 9 |")
    assert_contains(html, "text-align:right;")
  end)
end)

describe("HTML output: Entity escaping in text", function()
  it("escapes < > & in paragraph text", function()
    assert_eq(
      convert("a < b & c > d"),
      '<p style="margin:0 0 12px;">a &lt; b &amp; c &gt; d</p>\n'
    )
  end)

  it("backslash escapes prevent formatting", function()
    assert_eq(
      convert("\\*not italic\\*"),
      '<p style="margin:0 0 12px;">*not italic*</p>\n'
    )
  end)
end)

describe("HTML output: Combined document", function()
  it("renders a small document correctly", function()
    local md = table.concat({
      "# Title",
      "",
      "A paragraph with **bold** and *italic*.",
      "",
      "- item one",
      "- item two",
    }, "\n")
    local html = convert(md)
    assert_contains(html, '<h1 style="font-size:24px;">Title</h1>')
    assert_contains(html, '<p style="margin:0 0 12px;">A paragraph with <strong style="font-weight:700;">bold</strong> and <em style="font-style:italic;">italic</em>.</p>')
    assert_contains(html, '<ul style="padding-left:2em;">')
    assert_contains(html, '<li style="margin:4px 0;">item one</li>')
    assert_contains(html, '<li style="margin:4px 0;">item two</li>')
  end)
end)
