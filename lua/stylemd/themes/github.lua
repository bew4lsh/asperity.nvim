-- stylemd.themes.github
-- GitHub-flavored light theme. Default preset.
--
-- Every key is an HTML element name; every value is a CSS declaration
-- string applied as an inline style attribute.

-- TODO: finalize values against actual GitHub markdown rendering
-- TODO: verify rendering fidelity in Teams, Outlook, and Gmail

return {
  h1         = "font-size:24px; font-weight:700; color:#24292e; margin:16px 0 8px; border-bottom:1px solid #e1e4e8; padding-bottom:6px;",
  h2         = "font-size:20px; font-weight:600; color:#24292e; margin:14px 0 6px; border-bottom:1px solid #e1e4e8; padding-bottom:4px;",
  h3         = "font-size:16px; font-weight:600; color:#24292e; margin:12px 0 4px;",
  h4         = "font-size:14px; font-weight:600; color:#24292e; margin:10px 0 4px;",
  h5         = "font-size:12px; font-weight:600; color:#24292e; margin:8px 0 4px;",
  h6         = "font-size:12px; font-weight:600; color:#6a737d; margin:8px 0 4px;",
  p          = "font-size:14px; line-height:1.6; color:#24292e; margin:0 0 12px;",
  a          = "color:#0366d6; text-decoration:none;",
  strong     = "font-weight:700;",
  em         = "font-style:italic;",
  del        = "text-decoration:line-through;",
  code       = "font-family:Consolas,'Courier New',monospace; font-size:13px; background:#f6f8fa; padding:2px 6px; border-radius:3px;",
  pre        = "font-family:Consolas,'Courier New',monospace; font-size:13px; background:#f6f8fa; padding:12px 16px; border-radius:6px; overflow-x:auto; margin:0 0 12px;",
  blockquote = "border-left:4px solid #dfe2e5; padding:0 16px; color:#6a737d; margin:0 0 12px;",
  ul         = "padding-left:2em; margin:0 0 12px;",
  ol         = "padding-left:2em; margin:0 0 12px;",
  li         = "margin:4px 0;",
  table      = "border-collapse:collapse; margin:0 0 12px; width:100%;",
  thead_row  = "background:#f6f8fa;",
  th         = "border:1px solid #dfe2e5; padding:8px 12px; font-weight:600; text-align:left;",
  td         = "border:1px solid #dfe2e5; padding:8px 12px; text-align:left;",
  tr_odd     = "",
  tr_even    = "background:#f6f8fa;",
  hr         = "border:none; border-top:2px solid #e1e4e8; margin:24px 0;",
  img        = "max-width:100%;",
}
