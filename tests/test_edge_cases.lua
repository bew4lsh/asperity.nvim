-- Edge case tests for the native backend.

local native = require("stylemd.backends.native")

local styles = { p = "s:1;", h1 = "s:2;", pre = "s:3;", code = "s:4;", hr = "s:5;" }

local function convert(md)
  local html, err = native.convert(md, styles)
  assert(html ~= nil, "convert returned nil: " .. tostring(err))
  return html
end

describe("Edge cases: Empty and whitespace input", function()
  it("returns empty string for empty input", function()
    local html = native.convert("", styles)
    assert_eq(html, "")
  end)

  it("returns empty string for nil input", function()
    local html = native.convert(nil, styles)
    assert_eq(html, "")
  end)

  it("returns empty for whitespace-only input", function()
    local html = convert("   \n  \n   ")
    assert_eq(html, "")
  end)
end)

describe("Edge cases: HTML entity escaping", function()
  it("escapes < and > in paragraphs", function()
    local html = convert("a < b > c")
    assert_contains(html, "&lt;")
    assert_contains(html, "&gt;")
  end)

  it("escapes & in paragraphs", function()
    local html = convert("A & B")
    assert_contains(html, "&amp;")
  end)

  it("escapes quotes in attribute context", function()
    -- Quotes inside code content
    local html = convert('`he said "hi"`')
    assert_contains(html, "&quot;")
  end)
end)

describe("Edge cases: Nesting and special patterns", function()
  it("handles --- inside code block (not treated as hr)", function()
    local html = convert("```\n---\n```")
    assert_not_contains(html, "<hr")
    assert_contains(html, "---")
  end)

  it("handles unclosed bold gracefully", function()
    local html = convert("**unclosed bold")
    assert_contains(html, "**unclosed bold")
    assert_not_contains(html, "<strong")
  end)

  it("handles unclosed italic gracefully", function()
    local html = convert("*unclosed italic")
    assert_contains(html, "*unclosed italic")
  end)

  it("handles consecutive code blocks", function()
    local html = convert("```\na\n```\n\n```\nb\n```")
    local count = 0
    for _ in html:gmatch("<pre") do count = count + 1 end
    assert_eq(count, 2, "should have two code blocks")
  end)

  it("handles empty styles table", function()
    local html = native.convert("# Hello\n\nWorld", {})
    assert_contains(html, "<h1>")
    assert_contains(html, "<p>")
    assert_contains(html, "Hello")
    assert_contains(html, "World")
  end)

  it("handles special chars in URLs", function()
    local html = convert("[link](https://example.com/path?a=1&b=2)")
    assert_contains(html, "https://example.com/path?a=1&amp;b=2")
  end)

  it("handles backslash escapes", function()
    local html = convert("\\*not italic\\*")
    assert_not_contains(html, "<em")
    assert_contains(html, "*not italic*")
  end)

  it("handles mixed inline formatting", function()
    local html = convert("**bold** and *italic* and `code` and ~~del~~")
    assert_contains(html, "<strong")
    assert_contains(html, "<em")
    assert_contains(html, "<code")
    assert_contains(html, "<del")
  end)
end)
