#!/usr/bin/env lua
-- Minimal test runner for StyleMarkdown.
-- Run: lua tests/run.lua

-- Set up package path so we can require stylemd modules
local script_dir = arg[0]:match("(.*/)")  or "./"
local root = script_dir .. "../"
package.path = root .. "lua/?.lua;" .. root .. "lua/?/init.lua;" .. package.path

---------------------------------------------------------------------------
-- Test framework
---------------------------------------------------------------------------

local total, passed, failed = 0, 0, 0
local current_suite = ""
local failures = {}

function describe(name, fn)
  current_suite = name
  print("\n  " .. name)
  fn()
end

function it(name, fn)
  total = total + 1
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print("    \27[32m✓\27[0m " .. name)
  else
    failed = failed + 1
    print("    \27[31m✗\27[0m " .. name)
    print("      " .. tostring(err))
    failures[#failures + 1] = current_suite .. " > " .. name .. ": " .. tostring(err)
  end
end

function pending(name)
  total = total + 1
  print("    \27[33m-\27[0m " .. name .. " (pending)")
end

function assert_eq(actual, expected, msg)
  if actual ~= expected then
    local prefix = msg and (msg .. ": ") or ""
    error(prefix .. "expected:\n      " .. tostring(expected) .. "\n      got:\n      " .. tostring(actual), 2)
  end
end

function assert_contains(haystack, needle, msg)
  if not haystack or not haystack:find(needle, 1, true) then
    local prefix = msg and (msg .. ": ") or ""
    error(prefix .. "expected string to contain: " .. tostring(needle) .. "\n      got: " .. tostring(haystack), 2)
  end
end

function assert_match(haystack, pattern, msg)
  if not haystack or not haystack:match(pattern) then
    local prefix = msg and (msg .. ": ") or ""
    error(prefix .. "expected string to match: " .. pattern .. "\n      got: " .. tostring(haystack), 2)
  end
end

function assert_not_contains(haystack, needle, msg)
  if haystack and haystack:find(needle, 1, true) then
    local prefix = msg and (msg .. ": ") or ""
    error(prefix .. "expected string NOT to contain: " .. tostring(needle) .. "\n      got: " .. tostring(haystack), 2)
  end
end

function assert_truthy(val, msg)
  if not val then
    error(msg or "expected truthy value, got: " .. tostring(val), 2)
  end
end

---------------------------------------------------------------------------
-- Load and run test files
---------------------------------------------------------------------------

print("StyleMarkdown test suite")
print("========================")

local test_files = {
  "tests/test_native",
  "tests/test_html_output",
  "tests/test_config",
  "tests/test_edge_cases",
  "tests/test_pandoc",
}

for _, mod in ipairs(test_files) do
  local path = root .. mod .. ".lua"
  local chunk, err = loadfile(path)
  if chunk then
    chunk()
  else
    print("\n  \27[31mFailed to load " .. path .. ": " .. tostring(err) .. "\27[0m")
  end
end

---------------------------------------------------------------------------
-- Summary
---------------------------------------------------------------------------

print("\n========================")
if failed == 0 then
  print(("\27[32m  %d/%d tests passed\27[0m"):format(passed, total))
else
  print(("\27[31m  %d/%d tests passed, %d failed\27[0m"):format(passed, total, failed))
  print("\n  Failures:")
  for _, f in ipairs(failures) do
    print("    - " .. f)
  end
end

os.exit(failed == 0 and 0 or 1)
