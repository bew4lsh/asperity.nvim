-- stylemd.themes.minimal
-- Structural styles only — no colors, no backgrounds.
-- Useful as a clean base for user overrides.

-- TODO: verify that the absence of font-family lets the target app's
--       default font take over (Teams uses Segoe UI, Outlook uses Calibri)

return {
  h1         = "font-size:24px; font-weight:700; margin:16px 0 8px;",
  h2         = "font-size:20px; font-weight:600; margin:14px 0 6px;",
  h3         = "font-size:16px; font-weight:600; margin:12px 0 4px;",
  h4         = "font-size:14px; font-weight:600; margin:10px 0 4px;",
  h5         = "font-size:12px; font-weight:600; margin:8px 0 4px;",
  h6         = "font-size:12px; font-weight:600; margin:8px 0 4px;",
  p          = "font-size:14px; line-height:1.6; margin:0 0 12px;",
  a          = "text-decoration:underline;",
  strong     = "font-weight:700;",
  em         = "font-style:italic;",
  del        = "text-decoration:line-through;",
  code       = "font-family:monospace; font-size:13px;",
  pre        = "font-family:monospace; font-size:13px; padding:12px; margin:0 0 12px;",
  blockquote = "border-left:3px solid #999; padding:0 16px; margin:0 0 12px;",
  ul         = "padding-left:2em; margin:0 0 12px;",
  ol         = "padding-left:2em; margin:0 0 12px;",
  li         = "margin:4px 0;",
  table      = "border-collapse:collapse; margin:0 0 12px;",
  thead_row  = "",
  th         = "border:1px solid #999; padding:6px 10px; font-weight:600; text-align:left;",
  td         = "border:1px solid #999; padding:6px 10px; text-align:left;",
  tr_odd     = "",
  tr_even    = "",
  hr         = "border:none; border-top:1px solid #999; margin:20px 0;",
  img        = "max-width:100%;",
}
