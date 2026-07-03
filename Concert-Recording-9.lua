-- Concert-Recording-9.lua
-- Export master mix to FLAC and generate MD5
-- Run Concert-Recording-8 first to validate all settings
-- Idempotent: warns if FLAC already exists, but proceeds if you click OK

local r = reaper
local function P(s) r.ShowConsoleMsg(s .. "\n") end

P("=== Concert-Recording-9: Export FLAC + MD5 ===")

-- Get render output path
local _, render_file = r.GetSetProjectInfo_String(0, "RENDER_FILE", "", false)
if not render_file or render_file == "" then
  r.ShowMessageBox("Render output path not set.\nRun Concert-Recording-1 first.", "Export Error", 0)
  error("Render output path not set")
end

local folder = render_file:match("^(.-)/?$")
P("Output folder: " .. folder)

-- Check if a FLAC already exists in the output folder
local h_check = io.popen(string.format('find "%s" -maxdepth 1 -name "*.flac" 2>/dev/null', folder))
local existing_flac = nil
if h_check then
  existing_flac = h_check:read("*l")
  h_check:close()
end

if existing_flac and existing_flac ~= "" then
  local resp = r.ShowMessageBox(
    "A FLAC file already exists:\n" .. existing_flac:match("[^/]+$") .. "\n\nRender again and overwrite?",
    "Export", 4) -- 4 = Yes/No
  if resp ~= 6 then -- 6 = Yes
    P("Export cancelled by user.")
    P("=== Done (cancelled) ===")
    return
  end
end

-- Save before rendering
r.Main_OnCommand(40026, 0)
P("Project saved. Opening render dialog...")
P("Verify: FLAC / 24-bit / 96000 Hz / Normalize = OFF")
P("Then click 'Render 1 file'.")

-- Open render dialog (modal — script pauses until closed)
r.Main_OnCommand(40015, 0)

-- Find the FLAC that was just created (most recent in folder)
local flac_path = nil
local h = io.popen(string.format(
  'find "%s" -maxdepth 1 -name "*.flac" -newer "%s" 2>/dev/null | head -1', folder, folder))
if h then
  local line = h:read("*l"); h:close()
  if line and line ~= "" then flac_path = line end
end

-- Fallback: newest .flac by modification time
if not flac_path then
  local h2 = io.popen(string.format(
    'ls -t "%s"/*.flac 2>/dev/null | head -1', folder))
  if h2 then
    local line = h2:read("*l"); h2:close()
    if line and line ~= "" then flac_path = line end
  end
end

if not flac_path then
  P("No FLAC file found after render.")
  P("If render completed, run this manually:")
  P(string.format('  md5 -r "<filename>.flac" > "<filename>.flac.md5"'))
  P("=== Done (no FLAC found) ===")
  return
end

P("FLAC: " .. flac_path)

-- Generate MD5
local md5_path = flac_path .. ".md5"
os.execute(string.format('md5 -r "%s" > "%s"', flac_path, md5_path))

local mf = io.open(md5_path, "r")
if mf then
  local md5_str = mf:read("*l"); mf:close()
  P("MD5:  " .. (md5_str or "error"))
else
  P("MD5 file not created. Run: md5 -r \"" .. flac_path .. "\"")
end

r.Main_OnCommand(40026, 0)
P("=== Done ===")
