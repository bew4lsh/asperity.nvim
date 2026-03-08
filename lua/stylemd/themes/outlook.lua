-- stylemd.themes.outlook
-- Calibri-based, compact spacing theme optimized for Outlook rendering.
--
-- Outlook's HTML engine (Word-based) is notoriously limited. This preset
-- avoids CSS properties known to be ignored or broken in Outlook:
--   - border-radius (ignored)
--   - padding on inline elements (unreliable)
--   - shorthand margin/padding (use longhand)

-- TODO: test against Outlook desktop (Windows), Outlook web, Outlook Mac
-- TODO: verify table rendering in Outlook (Word engine)
-- TODO: consider mso-* CSS properties for Outlook-specific fixes

return {
  h1         = "font-family:Calibri,sans-serif; font-size:22px; font-weight:700; color:#1a1a1a; margin-top:16px; margin-bottom:8px;",
  h2         = "font-family:Calibri,sans-serif; font-size:18px; font-weight:600; color:#1a1a1a; margin-top:14px; margin-bottom:6px;",
  h3         = "font-family:Calibri,sans-serif; font-size:15px; font-weight:600; color:#1a1a1a; margin-top:12px; margin-bottom:4px;",
  h4         = "font-family:Calibri,sans-serif; font-size:14px; font-weight:600; color:#1a1a1a; margin-top:10px; margin-bottom:4px;",
  h5         = "font-family:Calibri,sans-serif; font-size:13px; font-weight:600; color:#1a1a1a; margin-top:8px; margin-bottom:4px;",
  h6         = "font-family:Calibri,sans-serif; font-size:13px; font-weight:600; color:#666666; margin-top:8px; margin-bottom:4px;",
  p          = "font-family:Calibri,sans-serif; font-size:14px; line-height:1.5; color:#1a1a1a; margin-top:0; margin-bottom:10px;",
  a          = "color:#0563C1; text-decoration:underline;",
  strong     = "font-weight:700;",
  em         = "font-style:italic;",
  del        = "text-decoration:line-through;",
  code       = "font-family:Consolas,'Courier New',monospace; font-size:13px; background-color:#f4f4f4;",
  pre        = "font-family:Consolas,'Courier New',monospace; font-size:13px; background-color:#f4f4f4; padding:10px; margin-top:0; margin-bottom:10px;",
  blockquote = "border-left:3px solid #cccccc; padding-left:12px; color:#555555; margin-top:0; margin-bottom:10px;",
  ul         = "padding-left:2em; margin-top:0; margin-bottom:10px;",
  ol         = "padding-left:2em; margin-top:0; margin-bottom:10px;",
  li         = "margin-top:2px; margin-bottom:2px;",
  table      = "border-collapse:collapse; margin-top:0; margin-bottom:10px; width:100%;",
  th         = "border:1px solid #cccccc; padding:6px 10px; font-weight:600; background-color:#f0f0f0; text-align:left;",
  td         = "border:1px solid #cccccc; padding:6px 10px; text-align:left;",
  hr         = "border:none; border-top:1px solid #cccccc; margin-top:20px; margin-bottom:20px;",
  img        = "max-width:100%;",
}
